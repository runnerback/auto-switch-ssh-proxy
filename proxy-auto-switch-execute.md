# Ubuntu 代理自适应 - 执行手册 (Bootstrap + 部署)

> 接续 `proxy-auto-switch-implementation.md`。本文档解决一个核心障碍：**家里无法 apt install socat（因为旧代理失效，没有网络）**，并给出可一气呵成执行的最终命令序列。

---

## 0. 当前已确认信息

| 项 | 值 |
|---|---|
| 主机 | `zhang-Legion-Y9000P-IRX9` |
| 用户 | `zhang` |
| 家庭网关 | `192.168.123.1` ✓ |
| 家庭代理后端 | `192.168.123.225:6152` (Mac mini Surge, Allow LAN 已开) ✓ |
| 公司隧道目标 | `zhangjianbo@10.167.68.126` |
| 公司隧道命令（旧） | `autossh -M 0 -N -L 6152:127.0.0.1:6152 zhangjianbo@10.167.68.126` |
| 公司网关 | **暂未知**（回公司后再补） |
| 抽象代理入口 | `http://127.0.0.1:6152`（上层全部固定使用） |

---

## 1. 破解 Bootstrap 困境

**问题**：家里现有 `surge-tunnel.service` 试图连公司内网 IP，必然失败 → `127.0.0.1:6152` 不监听 → apt 用代理装不了 socat。

**方案**：apt 的 `-o` 参数可以**临时覆盖代理**，直连家里 Mac，不走 127.0.0.1。

### 1.1 停掉无用的旧隧道

```bash
sudo systemctl stop surge-tunnel.service
# 验证旧 autossh/ssh 进程已退
ps -ef | grep -E 'autossh|ssh.*10\.167' | grep -v grep
# 期望：无输出
```

### 1.2 用临时代理直连家里 Mac，apt 装 socat

```bash
sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         update

sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         install -y socat

which socat
# 期望：/usr/bin/socat
socat -V | head -2
```

如果 apt update 报代理错，回去 Mac mini 上的 Shadowrocket 确认 **「允许来自局域网的连接」** 真的打开了。

---

## 2. 部署自适应方案

### 2.1 编写智能隧道脚本

> 设计简化：用 "家庭 vs 非家庭" 二分（非家庭网关默认按公司处理），**这样回公司后零修改即可生效**，不需要预先知道公司网关。

```bash
sudo tee /usr/local/bin/surge-tunnel-adaptive.sh >/dev/null <<'EOF'
#!/bin/bash
# 自适应隧道：本地 6152 根据网络环境映射到不同后端
#   家庭（gw=192.168.123.1）        → socat 转发到家里 Mac Surge
#   其他网络（默认按公司处理）         → autossh 隧道到公司 Mac
#   完全无网络                      → 退出

set -u

HOME_GW="192.168.123.1"
HOME_PROXY="192.168.123.225:6152"
OFFICE_TUNNEL="zhangjianbo@10.167.68.126"
LOCAL_PORT=6152

# 等待网关就绪（systemd 启动时网络可能还没好）
GW=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  GW=$(ip route | awk '/^default/ {print $3; exit}')
  [ -n "$GW" ] && break
  sleep 1
done

logger -t surge-tunnel "gateway=${GW:-none}"

if [ -z "$GW" ]; then
  logger -t surge-tunnel "no network, exit"
  exit 0
fi

if [ "$GW" = "$HOME_GW" ]; then
  logger -t surge-tunnel "HOME mode: socat 127.0.0.1:$LOCAL_PORT -> $HOME_PROXY"
  exec /usr/bin/socat \
      TCP-LISTEN:$LOCAL_PORT,bind=127.0.0.1,reuseaddr,fork \
      TCP:$HOME_PROXY
else
  logger -t surge-tunnel "OFFICE mode (gw=$GW): autossh -L $LOCAL_PORT -> $OFFICE_TUNNEL"
  export AUTOSSH_GATETIME=0
  exec /usr/bin/autossh -M 0 \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -o ExitOnForwardFailure=yes \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=accept-new \
      -N -L $LOCAL_PORT:127.0.0.1:6152 $OFFICE_TUNNEL
fi
EOF
sudo chmod +x /usr/local/bin/surge-tunnel-adaptive.sh

# 自检脚本能否找到二进制
ls -l /usr/bin/socat /usr/bin/autossh
```

### 2.2 改造 surge-tunnel.service

先备份：

```bash
sudo cp /etc/systemd/system/surge-tunnel.service \
        /etc/systemd/system/surge-tunnel.service.bak.$(date +%Y%m%d)
```

直接覆盖写新版（保持 User=zhang 不变，**注意 Restart=on-failure**：脚本主动 exit 0 时不会乱重启）：

```bash
sudo tee /etc/systemd/system/surge-tunnel.service >/dev/null <<'EOF'
[Unit]
Description=Adaptive SSH/socat tunnel to Surge proxy (home or office)
After=network-online.target NetworkManager.service
Wants=network-online.target

[Service]
Type=simple
User=zhang
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/surge-tunnel-adaptive.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart surge-tunnel.service
sudo systemctl status surge-tunnel.service --no-pager
```

### 2.3 安装 NetworkManager 切网钩子

```bash
sudo tee /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh >/dev/null <<'EOF'
#!/bin/bash
# 网络 up/down/vpn 变化时重启隧道，触发脚本重新判断
case "$2" in
  up|down|vpn-up|vpn-down)
    logger -t surge-tunnel-hook "NM event: iface=$1 event=$2"
    /usr/bin/systemctl restart surge-tunnel.service
    ;;
esac
EOF
sudo chmod 755 /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh
sudo chown root:root /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh
```

---

## 3. 家里立刻验证

```bash
# 1. 服务状态（应 active running，且不在 Restarting）
systemctl status surge-tunnel.service --no-pager

# 2. 看判断日志（重点）
journalctl -t surge-tunnel -n 10 --no-pager
# 期望：HOME mode: socat 127.0.0.1:6152 -> 192.168.123.225:6152

# 3. 端口已监听 + socat 是主进程
ss -tlnp | grep :6152
# 期望：127.0.0.1:6152 LISTEN ... users:(("socat",pid=...,...))

# 4. 走代理实测
curl -x http://127.0.0.1:6152 -sI https://www.baidu.com | head -1
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1
curl -sI https://www.baidu.com | head -1   # 用 .bashrc 里的环境变量

# 5. 浏览器打开 google.com 确认 GUI 也通
```

---

## 4. 切网模拟（验证 dispatcher）

```bash
# 当前连接名
nmcli -t -f NAME,DEVICE,STATE c show --active

# 模拟断网→重连
NAME=$(nmcli -t -f NAME,STATE c show --active | awk -F: '$2=="activated"{print $1; exit}')
sudo nmcli c down "$NAME" && sleep 2 && sudo nmcli c up "$NAME"

# 看钩子和重启日志
journalctl -t surge-tunnel-hook -t surge-tunnel --since "1 minute ago" --no-pager
# 期望：NM event: ... up，紧跟 HOME mode: socat ...
```

---

## 5. 回公司后

### 5.1 切到公司 WiFi 应自动起隧道

```bash
journalctl -t surge-tunnel --since "5 minutes ago" --no-pager
# 期望：OFFICE mode (gw=...): autossh -L 6152 -> zhangjianbo@10.167.68.126
ps -ef | grep autossh | grep -v grep
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1
```

### 5.2 记录公司网关，可选写入脚本作为更严格的二分

```bash
ip route | awk '/^default/ {print $3}' > /tmp/office-gw.txt
cat /tmp/office-gw.txt
# 假设输出 10.x.y.1，可编辑脚本把 OFFICE 分支也加 case 严格匹配（可选优化）
```

如想严格匹配公司网关（避免咖啡馆/酒店 WiFi 也误起公司隧道），编辑 `/usr/local/bin/surge-tunnel-adaptive.sh`，把 `else` 分支改成：

```bash
elif [ "$GW" = "10.x.y.1" ]; then   # ← 填回填的公司网关
  ...office 分支...
else
  logger -t surge-tunnel "unknown network (gw=$GW), no tunnel"
  exit 0
fi
```

---

## 6. 回滚方案

```bash
sudo systemctl stop surge-tunnel.service
sudo cp /etc/systemd/system/surge-tunnel.service.bak.* \
        /etc/systemd/system/surge-tunnel.service
sudo rm -f /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh
sudo systemctl daemon-reload
sudo systemctl restart surge-tunnel.service
```

---

## 7. 测试结果回填

### 7.1 Bootstrap (apt 装 socat)

```
sudo systemctl stop ...        : 
apt update with -o proxy       : 
apt install -y socat           : 
which socat                    : 
```

### 7.2 家里部署后

```
systemctl status surge-tunnel  : 
journalctl -t surge-tunnel     : 
ss -tlnp | grep :6152          : 
curl baidu                     : 
curl google                    : 
浏览器访问 google.com           : 
```

### 7.3 切网模拟

```
nmcli down + up                : 
journalctl 钩子日志             : 
```

### 7.4 公司测试（日期：____）

```
公司网关                       : 
OFFICE mode 日志                : 
ps -ef | grep autossh          : 
curl google                    : 
```

---

## 8. 常见问题

| 现象 | 排查 |
|---|---|
| `socat: command not found` | Bootstrap §1.2 没成功，回看 apt 输出错误 |
| service Restarting 不停 | 看 `journalctl -u surge-tunnel -n 50`；多半是 socat/autossh 二进制路径不对，或 home 模式下家里 Mac 没开 Allow LAN |
| 切网后没切隧道 | 看 `/var/log/syslog` 里 `surge-tunnel-hook` 日志；确认 dispatcher 脚本权限是 `755 root:root` |
| 6152 端口被占 | `sudo lsof -i :6152` 看谁占的；多半是旧 autossh 没干净杀掉 |
| 公司环境 ssh 提示首次连接 | 已加 `StrictHostKeyChecking=accept-new`，第一次会自动接受 |

---

## 9. 命令一键执行版（家里执行，先确认 Mac mini Surge Allow LAN 已开）

> 整理成"复制粘贴"流程；按顺序执行，每段独立验证。

```bash
# === Phase 1: Bootstrap ===
sudo systemctl stop surge-tunnel.service
sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         update
sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         install -y socat
which socat || { echo "socat 安装失败，中止"; exit 1; }

# === Phase 2: 部署脚本和服务（见 §2.1 / §2.2 / §2.3 整段复制） ===

# === Phase 3: 验证 ===
sudo systemctl restart surge-tunnel.service
sleep 2
journalctl -t surge-tunnel -n 5 --no-pager
ss -tlnp | grep :6152
curl -x http://127.0.0.1:6152 -sI https://www.baidu.com | head -1
```

---

*创建：2026-05-16 | 接续 proxy-auto-switch-implementation.md*
