# Auto-Switch SSH Proxy

Ubuntu 上的自适应代理隧道:本机 `127.0.0.1:6152` 是上层应用统一入口,根据当前网络环境自动切换后端 —— 家里走 socat 直连 Mac 上的 Surge,公司走 autossh 隧道,其他环境按 `networks.conf` 规则匹配。NetworkManager 切网时自动重启服务,无需手工干预。

部署过程见 [proxy-auto-switch-execute.md](./proxy-auto-switch-execute.md)。

---

## 1. 常用命令

### 1.1 启停 / 状态

```bash
# 开启 (本次)
sudo systemctl start surge-tunnel.service

# 关闭 (本次,但切网时 NM 钩子仍会拉起 —— 见 §1.5)
sudo systemctl stop surge-tunnel.service

# 重启 (改完配置后用这个)
sudo systemctl restart surge-tunnel.service

# 看状态
systemctl status surge-tunnel.service --no-pager

# 开机自启 / 取消
sudo systemctl enable surge-tunnel.service
sudo systemctl disable surge-tunnel.service
```

### 1.2 看日志 / 确认当前模式

```bash
# 最近 20 行 (能看到匹配了哪条规则、走 socat 还是 ssh)
journalctl -t surge-tunnel -n 20 --no-pager

# 实时跟随
journalctl -t surge-tunnel -f

# 切网钩子日志 (NM 触发记录)
journalctl -t surge-tunnel-hook -n 20 --no-pager

# 完整服务日志 (含 autossh/socat 的 stderr)
journalctl -u surge-tunnel.service -n 50 --no-pager
```

期望日志样例:
```
surge-tunnel: gateway=192.168.123.1
surge-tunnel: match: gw=192.168.123.1 rule=192.168.123.1 mode=socat target=192.168.123.225:6152
```

### 1.3 验证代理可用

```bash
# 端口被谁监听 (socat 还是 ssh)
ss -tlnp | grep :6152

# 走代理访问外网
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1
curl -x http://127.0.0.1:6152 -sI https://www.baidu.com | head -1

# 当前默认网关 (用来跟 networks.conf 里的 pattern 对照)
ip route | awk '/^default/ {print $3}'
```

### 1.4 配置文件

```bash
# 编辑规则
sudo nano /etc/surge-tunnel/networks.conf

# 改完必须重启服务
sudo systemctl restart surge-tunnel.service
journalctl -t surge-tunnel -n 5 --no-pager   # 确认走了预期模式
```

### 1.5 彻底关闭 (临时调试)

`systemctl stop` 不够 —— 切网时 NM 钩子会把服务重新拉起。要让它真正不起来:

```bash
# 方案 A: mask (推荐,可逆)
sudo systemctl mask surge-tunnel.service
# 恢复
sudo systemctl unmask surge-tunnel.service && sudo systemctl start surge-tunnel.service

# 方案 B: 摘掉切网钩子
sudo chmod -x /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh
# 恢复
sudo chmod +x /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh
```

关掉代理后,记得把 shell 里的 `http_proxy / https_proxy` 环境变量也 `unset` 一下,否则 curl/apt 还会尝试连不存在的代理。

---

## 2. 接入新环境 (核心功能)

到了新地方 —— 朋友家、咖啡馆、酒店、新办公室 —— 只需追加一行规则。

### 2.1 三步走

```bash
# Step 1: 看当前默认网关
ip route | awk '/^default/ {print $3}'
# 假设输出: 192.168.31.1

# Step 2: 追加规则到 /etc/surge-tunnel/networks.conf
#   格式: gateway_pattern|mode|target
sudo nano /etc/surge-tunnel/networks.conf

# Step 3: 重启服务并确认
sudo systemctl restart surge-tunnel.service
journalctl -t surge-tunnel -n 5 --no-pager
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1
```

### 2.2 该填什么

新环境有两种典型形态,挑一个:

**形态 A — 同 LAN 内有现成代理 (Mac/手机/路由器跑 Surge/Clash)**
- 让那台机器开启 "允许局域网连接"
- 在 `networks.conf` 追加: `gateway_ip|socat|代理机IP:代理端口`
- 例: `192.168.31.1|socat|192.168.31.50:7890`

**形态 B — 没有 LAN 代理,但能 SSH 到一台有代理的远端机器**
- 远端机器自己上 :6152 (或别的) 有可用代理
- 在 `networks.conf` 追加: `gateway_ip|ssh|user@remote_host:remote_port`
- 例: `10.20.30.1|ssh|alice@10.20.30.5:6152`
- 前提:本机能免密 SSH 到 `user@remote_host` (一次性: `ssh-copy-id user@remote_host`)

### 2.3 gateway_pattern 写法

| 写法 | 含义 |
|---|---|
| `192.168.123.1` | 精确匹配 |
| `10.167.68.*` | 整个 /24 段 |
| `10.*` | 整个 10.x 大段 (公司多个子网时用) |
| `*` | 兜底 (必须放**最后**一行,前面所有没命中的都走这条) |

匹配顺序从上到下,第一条命中即生效 —— 把精确规则放上面,通配规则放下面。

### 2.4 不想自动接管时

如果你到了某个不信任的网络 (公共 WiFi 等),不希望服务尝试任何隧道:
- 不在 `networks.conf` 里加这个网关的规则
- 也不要加 `*` 兜底
- 服务会日志一行 `no rule matched gw=...` 然后 exit 0,本地 6152 不监听,上层应用应用绕过代理

---

## 3. 升级到配置驱动版 (一次性)

老的脚本把 home/office 硬编码了。下面的步骤把它升级成读 `networks.conf`。**只需做一次**。

```bash
# 1. 备份现役脚本
sudo cp /usr/local/bin/surge-tunnel-adaptive.sh \
        /usr/local/bin/surge-tunnel-adaptive.sh.bak.$(date +%Y%m%d)

# 2. 部署新脚本 (从项目目录复制)
cd ~/Projects/auto-switch-ssh-proxy
sudo install -m 0755 surge-tunnel-adaptive.sh /usr/local/bin/surge-tunnel-adaptive.sh

# 3. 创建配置目录,放置初始规则
sudo mkdir -p /etc/surge-tunnel
sudo install -m 0644 networks.conf.example /etc/surge-tunnel/networks.conf
# 检查内容是否正确反映你的实际网关/代理
sudo nano /etc/surge-tunnel/networks.conf

# 4. 重启服务,确认日志
sudo systemctl restart surge-tunnel.service
journalctl -t surge-tunnel -n 10 --no-pager
ss -tlnp | grep :6152
curl -x http://127.0.0.1:6152 -sI https://www.google.com | head -1
```

回滚:

```bash
sudo cp /usr/local/bin/surge-tunnel-adaptive.sh.bak.* \
        /usr/local/bin/surge-tunnel-adaptive.sh
sudo systemctl restart surge-tunnel.service
```

---

## 4. 故障排查速查

| 症状 | 怎么查 |
|---|---|
| 服务 active 但 curl 不通 | `journalctl -t surge-tunnel -n 5` 看走的什么模式,对照 `networks.conf` |
| 端口没监听 | `journalctl -u surge-tunnel.service -n 30`,常见:autossh 公钥认证失败 / socat 目标拒绝连接 / `no rule matched gw=...` |
| 切网后没自动切 | `journalctl -t surge-tunnel-hook --since "5 min ago"`;若无输出 → dispatcher 脚本权限错;若有输出但服务没重启 → 看 service 日志 |
| 6152 被占 | `sudo lsof -i :6152` 看 PID,常见是旧 autossh 没退干净 |
| home/office 走错了 | `ip route` 看实际网关,跟 `networks.conf` 第一条命中的 pattern 对照 |
| 改完 conf 没生效 | 忘了 `sudo systemctl restart surge-tunnel.service` |
| autossh 一直重连 | 公司侧 sshd 限速 / 公钥未上对端,试 `ssh -v user@host` 手动连一次看错误 |

---

## 5. 文件清单

部署到系统后:

| 路径 | 作用 |
|---|---|
| `/usr/local/bin/surge-tunnel-adaptive.sh` | 主脚本 |
| `/etc/surge-tunnel/networks.conf` | 网络规则表 (改这里加新环境) |
| `/etc/systemd/system/surge-tunnel.service` | systemd 服务定义 |
| `/etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh` | NM 切网钩子 |

项目目录:

| 路径 | 作用 |
|---|---|
| `proxy-auto-switch-execute.md` | 首次部署文档 (历史记录) |
| `surge-tunnel-adaptive.sh` | 新版主脚本 (配置驱动) |
| `networks.conf.example` | 配置模板 |
| `README.md` | 本文档 |
