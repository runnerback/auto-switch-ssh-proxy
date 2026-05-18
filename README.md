# Auto-Switch SSH Proxy

> **版本**: v2.0
> **更新时间**: 2026-05-18

Ubuntu 上的自适应代理隧道。本机 `127.0.0.1:6152` 是上层应用统一入口,服务根据当前网络环境自动选择后端:

```
home    : socat 直连 LAN 内 Surge / Clash    (低延迟)
office  : autossh 隧道到 Mac (走 mDNS 名)    (跨子网穿透)
其他    : 按 networks.conf 自定义匹配         (任意 LAN/远端)
无规则  : 静默退出, 6152 不监听              (不信任的网络)
```

NetworkManager 切网时自动重启服务,无需手工干预。

---

## 1. 一次性部署

### 1.1 前置:家里能用 LAN 代理装 socat (bootstrap)

家里旧隧道连不上公司 → 127.0.0.1:6152 不通 → 用 apt 临时绕过本地代理直连家里 Mac:

```bash
# 假设家里 Mac 是 192.168.123.225, Surge 在 :6152 (Allow LAN 已开)
sudo systemctl stop surge-tunnel.service 2>/dev/null

sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         update

sudo apt -o Acquire::http::proxy="http://192.168.123.225:6152" \
         -o Acquire::https::proxy="http://192.168.123.225:6152" \
         install -y socat autossh avahi-utils libnss-mdns

which socat autossh    # 应都有路径
```

> ⚠️ 公司里没 LAN 代理时,先用手机热点 + autossh 装,或者直接 USB 把 `.deb` 拷过来 `sudo apt install ./*.deb`。

### 1.2 部署脚本

```bash
cd ~/Projects/auto-switch-ssh-proxy   # 或你 clone 的位置
sudo install -m 0755 surge-tunnel-adaptive.sh /usr/local/bin/

sudo mkdir -p /etc/surge-tunnel
sudo install -m 0644 networks.conf.example /etc/surge-tunnel/networks.conf
sudo nano /etc/surge-tunnel/networks.conf    # 改成你的实际规则,见 §2
```

### 1.3 创建 systemd service

```bash
sudo tee /etc/systemd/system/surge-tunnel.service >/dev/null <<'EOF'
[Unit]
Description=Adaptive SSH/socat tunnel to Surge proxy
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
sudo systemctl enable --now surge-tunnel.service
```

### 1.4 创建 NetworkManager 切网钩子

```bash
sudo tee /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh >/dev/null <<'EOF'
#!/bin/bash
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

## 2. 配置 networks.conf

格式: `gateway_pattern|mode|target`,从上到下,第一条命中即生效。

```
192.168.123.1|socat|192.168.123.225:6152
10.167.68.*|ssh|zhangjianbo@zhangjianbos-macbook-pro.local:6152
```

| 字段 | 取值 |
|---|---|
| **gateway_pattern** | 精确 IP / glob (`10.167.68.*`, `10.*`) / 兜底 (`*`,放最后一行) |
| **mode** | `socat` (LAN 直连) 或 `ssh` (autossh 隧道) |
| **target** | `host:port` (socat) 或 `user@host:rport` (ssh) |

### 2.1 ⭐ host 字段强烈推荐用 mDNS 主机名

办公网 DHCP 反复变 IP。硬编码 IP 的后果:
1. Mac IP 变了 → autossh 连不上
2. 旧 IP 被分给陌生机器 → SSH 拿到不同 host key → `Host key verification failed`
3. 若盲目 `ssh-keygen -R` 重连 → 流量被转发到陌生机器,**HTTP 明文 Cookie/Token 被截获**

**用 mDNS 名 (`xxx.local`) 跟着 Mac 主机走,IP 怎么变都不用管**:

```bash
# 推荐 ✅
zhangjianbo@zhangjianbos-macbook-pro.local:6152

# 不推荐 ❌
zhangjianbo@10.167.68.126:6152
```

验证 mDNS 通:

```bash
avahi-resolve-host-name zhangjianbos-macbook-pro.local   # 应返回 Mac 当前 IP
ssh zhangjianbo@zhangjianbos-macbook-pro.local "echo ok"
```

> ⚠️ 极少数公司网屏蔽 mDNS 跨子网组播。`avahi-resolve` 解析失败时,要么找 IT 给 Mac MAC 做 DHCP reservation 拿固定 IP,要么退回 IP 方式并接受每次手工改的成本。

> ℹ️ 脚本已加 mDNS 解析等待(最多 10s),boot 后 avahi 未就绪不会立即失败。

### 2.2 SSH 模式前置: 免密 + 首次接受 host key

```bash
ssh-copy-id zhangjianbo@zhangjianbos-macbook-pro.local
ssh zhangjianbo@zhangjianbos-macbook-pro.local "echo ok"   # 应免密返回 ok
```

### 2.3 接入新环境(到了朋友家/咖啡馆/新办公室)

```bash
ip route | awk '/^default/ {print $3}'        # 看当前网关
sudo nano /etc/surge-tunnel/networks.conf     # 追加一行新规则
sudo systemctl restart surge-tunnel.service
journalctl -t surge-tunnel -n 5 --no-pager    # 确认匹配到新规则
```

不信任的网络 → 不要加规则,也不要加 `*` 兜底,服务会 exit 0,6152 不监听。

---

## 3. 日常使用

```bash
# 启停 / 状态
sudo systemctl restart surge-tunnel.service     # 改完配置必跑
systemctl status surge-tunnel.service --no-pager

# 看走了哪条规则 / 哪种模式
journalctl -t surge-tunnel -n 10 --no-pager
journalctl -t surge-tunnel -f                    # 实时

# 端口是谁在监听 (socat 或 ssh)
ss -tlnp | grep :6152

# 验证代理可用
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1

# 彻底关闭 (切网钩子也不再拉起)
sudo systemctl mask surge-tunnel.service
sudo systemctl unmask surge-tunnel.service && sudo systemctl start surge-tunnel.service
```

---

## 4. 故障排查

| 症状 | 检查 + 修复 |
|---|---|
| 服务 active 但 curl 不通 | `journalctl -t surge-tunnel -n 5` 对照 networks.conf 看走了什么模式 |
| 端口没监听 | `journalctl -u surge-tunnel -n 30`: autossh 公钥认证失败 / socat 拒绝连接 / `no rule matched gw=...` |
| 切网后没自动切 | 看 `journalctl -t surge-tunnel-hook`; 无输出 → dispatcher 脚本权限不对 |
| 6152 被占 | `sudo lsof -i :6152`; 多半是旧 autossh 没退干净 |
| 改完 conf 没生效 | 忘了 `sudo systemctl restart surge-tunnel.service` |
| `Host key verification failed` | DHCP 把目标 IP 分给了陌生机器, **别盲目** `ssh-keygen -R`。修复见 §4.1 |
| `waiting for *.local to resolve` 后连不上 | `sudo systemctl status avahi-daemon`; 或办公网屏蔽 mDNS 跨子网组播 |

### 4.1 `Host key verification failed` 安全修复流程

**根因**: target 还在用硬编码 IP,办公网 DHCP 把 IP 分给了陌生机器。

**修复步骤** (假设 networks.conf 里目标是 `zhangjianbo@10.167.68.126:6152`):

```bash
# 第 1 步: Mac 上确认当前真实 IP 和 SSH 指纹
# 在 Mac 上跑:
ipconfig getifaddr en8    # 假设输出 10.167.68.43 (新 IP)
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# 记下指纹,例如: SHA256:7nmVAHgoqcmcVFZbpPovEoGj8VKBv9zDy/GQUOvUpbA

# 第 2 步: Ubuntu 上清掉错的 known_hosts
ssh-keygen -R 10.167.68.126     # 旧 IP (已是别人的)
ssh-keygen -R 10.167.68.43      # 新 IP (防止之前误接受过陌生机器)

# 第 3 步: 拉新 IP 的指纹并核对
ssh-keyscan -t ed25519 10.167.68.43 2>/dev/null > /tmp/k.txt
ssh-keygen -lf /tmp/k.txt
# 指纹必须 == Mac 上的指纹! 不一致 = 还是陌生机器, 停, 不要 cat 进 known_hosts.

# 第 4 步: 一致才能写入
cat /tmp/k.txt >> ~/.ssh/known_hosts

# 第 5 步: 改 conf 改成 mDNS, 永久解决 (见 §2.1)
sudo sed -i 's|@10.167.68.126:|@zhangjianbos-macbook-pro.local:|' \
  /etc/surge-tunnel/networks.conf

sudo systemctl restart surge-tunnel.service
journalctl -t surge-tunnel -n 5 --no-pager
```

---

## 5. 文件清单

部署后:

| 路径 | 作用 |
|---|---|
| `/usr/local/bin/surge-tunnel-adaptive.sh` | 主脚本 |
| `/etc/surge-tunnel/networks.conf` | 规则表 |
| `/etc/systemd/system/surge-tunnel.service` | systemd unit |
| `/etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh` | 切网钩子 |

项目目录:

| 路径 | 作用 |
|---|---|
| `surge-tunnel-adaptive.sh` | 主脚本源 |
| `networks.conf.example` | 配置模板 |
| `README.md` | 本文档 (单文件全包含) |

---

## 6. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-16 | 初版: 配置驱动脚本 + NM 切网钩子 + bootstrap 流程 |
| v1.1 | 2026-05-18 | 脚本加 mDNS 解析等待; 推荐用 mDNS 名取代 IP |
| v2.0 | 2026-05-18 | **单文件重构**: 整合原 `proxy-auto-switch-execute.md` (bootstrap/部署) 和 `ssh-tunnel-office-network-fix.md` (host key 修复) 到本文档, 删除冗余 |
