# Proxy Hotspot (代理热点)

> **版本**: v1.0
> **更新时间**: 2026-05-19
> **状态**: 设计文档 + 可执行脚本，**未部署**

让 Ubuntu 开一个 WiFi 热点，**所有接入设备的 TCP 流量透明转发到 `127.0.0.1:6152`**（即 [auto-switch-ssh-proxy](../README.md) 的 surge 隧道入口），最终走家里/办公 Mac 的 Surge 出口。

手机/平板/其他笔记本 **连上就能用，无需在客户端配代理**。

---

## 1. 架构

```
┌─────────────┐
│ 手机/平板    │  连 WiFi "ZhangProxy"
└──────┬──────┘
       │ TCP (HTTP / HTTPS / SSH …)
       ▼
┌──────────────────────────── Ubuntu ─────────────────────────────┐
│                                                                  │
│  wlp0s20f3 (10.42.0.1, AP 模式, NM "shared" → 自带 dnsmasq+NAT)  │
│       │                                                          │
│       │ ① nft: prerouting REDIRECT tcp → :12345                  │
│       ▼                                                          │
│  redsocks (127.0.0.1:12345)                                      │
│       │                                                          │
│       │ ② 包装成 HTTP CONNECT host:port                          │
│       ▼                                                          │
│  127.0.0.1:6152 ──── 现有 surge-tunnel (autossh / socat)         │
│                                                                  │
└──────────┬──────────────────────────────────────────────────────┘
           ▼
     家里/公司 Mac 的 Surge → 公网 (按 Mac 上的 Surge 规则分流)
```

### 为什么需要 redsocks？

`127.0.0.1:6152` 是 HTTP 代理 —— 只接受 `CONNECT host:port HTTP/1.1` 这种握手报文。但被劫持的客户端 TCP 包是裸 TCP，没有 CONNECT 头部。`redsocks` 就是干这件事的：
1. 接管 nft REDIRECT 过来的连接
2. 从原始 socket 取出**原本要去的目标 IP:port**（`SO_ORIGINAL_DST`）
3. 主动连 `127.0.0.1:6152`，发 `CONNECT 原目标 HTTP/1.1`
4. 转换完成后双向 splice

### UDP 怎么办？

HTTP CONNECT 代理 **不支持 UDP**。所以方案是：
- **DNS (UDP 53)**：让 NetworkManager 自带的 dnsmasq 处理。dnsmasq 用系统 resolver 直接解析 —— DNS 明文经有线 `enp8s0` 出去（不走代理）。不解析私有域名，所以"分流"问题 0 影响。
- **QUIC (UDP 443/80)**：nft `reject`，让浏览器/App 回退到 TCP TLS。否则 Chrome/Instagram 会偷偷用 QUIC 绕过代理。
- **其他 UDP**（WebRTC、游戏）：会被 NAT 直连出去，**不走代理**。这是 HTTP 代理的固有局限。如果在意，下一步换 WireGuard/v2ray 隧道。

---

## 2. 文件清单

部署后:

| 路径 | 作用 |
|---|---|
| `/etc/redsocks.conf` | redsocks 主配置 |
| `/etc/nftables.d/hotspot-proxy.nft` | 流量劫持规则 |
| `/usr/local/bin/hotspot-up.sh` | 一键开 |
| `/usr/local/bin/hotspot-down.sh` | 一键关 |
| NM connection profile `ProxyHotspot` | 热点 SSID/密码/AP 配置 |

项目目录:

| 路径 | 作用 |
|---|---|
| `redsocks.conf.example` | redsocks 配置模板 |
| `hotspot-proxy.nft` | nftables 规则模板 |
| `hotspot-up.sh` | 一键开热点脚本源 |
| `hotspot-down.sh` | 一键关热点脚本源 |
| `README.md` | 本文档 |

---

## 3. 一次性部署

### 3.1 装依赖

```bash
sudo apt update
sudo apt install -y redsocks nftables
```

> 已经有 `nftables`（Ubuntu 26.04 默认），主要装的是 `redsocks`。

### 3.2 配置 redsocks

```bash
cd ~/Projects/auto-switch-ssh-proxy/hot-pot
sudo install -m 0644 redsocks.conf.example /etc/redsocks.conf

# 检查 redsocks 是否能起来
sudo systemctl restart redsocks
sudo systemctl status redsocks --no-pager
ss -tlnp | grep 12345     # 应能看到 redsocks 监听在 127.0.0.1:12345
```

如果失败：`journalctl -u redsocks -n 30 --no-pager` 看日志。

### 3.3 配置 nftables 劫持规则

```bash
sudo mkdir -p /etc/nftables.d
sudo install -m 0644 hotspot-proxy.nft /etc/nftables.d/hotspot-proxy.nft
```

让规则跟随系统启动加载（在主 `/etc/nftables.conf` 末尾追加 include）：

```bash
sudo bash -c 'grep -q hotspot-proxy /etc/nftables.conf || \
    echo "include \"/etc/nftables.d/hotspot-proxy.nft\"" >> /etc/nftables.conf'
```

> ⚠️ 但**默认 hotspot-proxy 表无害**（没流量进 wlp0s20f3 时所有规则都 return）。也可以选择不开机加载，仅在 `hotspot-up.sh` 里临时 `nft -f` 加载。

### 3.4 安装一键脚本

```bash
sudo install -m 0755 hotspot-up.sh   /usr/local/bin/
sudo install -m 0755 hotspot-down.sh /usr/local/bin/
```

### 3.5 首次起热点

```bash
sudo /usr/local/bin/hotspot-up.sh
```

脚本会：
1. 检查 surge-tunnel 在跑
2. 启动 redsocks
3. 加载 nft 规则
4. 若 `ProxyHotspot` profile 不存在，自动创建（AP 模式、shared IP、WPA2-PSK）
5. 启用热点

成功后输出 SSID 和密码，手机连上即可。

**改 SSID/密码**：直接编辑 `hotspot-up.sh` 顶部的 `HOTSPOT_SSID` / `HOTSPOT_PASS` 后重跑。或者：

```bash
nmcli connection modify ProxyHotspot 802-11-wireless.ssid "新SSID"
nmcli connection modify ProxyHotspot wifi-sec.psk "新密码"
nmcli connection up ProxyHotspot
```

---

## 4. 验证

```bash
# 1. 服务都在
systemctl is-active surge-tunnel redsocks
nmcli -t -f NAME,STATE connection show --active | grep ProxyHotspot

# 2. nft 表加载
sudo nft list table inet hotspot_proxy

# 3. 热点接口起来了
ip addr show wlp0s20f3 | grep "inet 10.42"

# 4. 手机连上后，看到客户端
ip neigh show dev wlp0s20f3

# 5. 在客户端跑：访问 https://ipinfo.io —— 出口 IP 应该是 Mac 上 Surge 选的节点的 IP
#    （不是你 Ubuntu 当前 enp8s0 的公网出口）
```

### 抓包确认流量走代理

在 Ubuntu 上观察 `redsocks` 进出连接：

```bash
sudo ss -tnp | grep redsocks
# 应看到 LISTEN 0 ... 127.0.0.1:12345 的入连接 + 到 127.0.0.1:6152 的出连接
```

观察 6152 上去往 Mac 的连接：

```bash
sudo journalctl -u surge-tunnel -f       # 看到流量在动
```

---

## 5. 日常使用

```bash
# 开 / 关
sudo hotspot-up.sh
sudo hotspot-down.sh

# 看谁连上了热点
ip neigh show dev wlp0s20f3
# 或更友好：
sudo iw dev wlp0s20f3 station dump | grep Station

# 实时监控 nft 命中数
watch -n 1 'sudo nft list table inet hotspot_proxy'

# 限速（可选，避免某客户端跑满）—— tc 见 §7
```

### 改 SSID/密码/频段

```bash
# 5GHz（更快，但有些老设备不支持）
nmcli connection modify ProxyHotspot 802-11-wireless.band a
# 2.4GHz（兼容好）
nmcli connection modify ProxyHotspot 802-11-wireless.band bg
nmcli connection up ProxyHotspot
```

---

## 6. 故障排查

| 症状 | 排查 |
|---|---|
| 客户端连不上 WiFi | `journalctl -u NetworkManager -n 50`; 网卡可能不支持当前频段，换 `band bg` |
| 连上 WiFi 没网 | 看 redsocks 是否在跑、surge-tunnel 是否健康 (`curl -x http://127.0.0.1:6152 -sI https://www.google.com`) |
| 客户端能上 HTTP，不能上 HTTPS | nft 规则没生效 / redsocks 协议类型错 (应为 `http-connect`) |
| 客户端慢得离谱 | Surge 节点慢，或 6152 隧道延迟高。`mtr` 看 Mac 上游 |
| Chrome 还在用 QUIC 绕代理 | nft forward 链 reject UDP 443 没生效，`nft list ruleset \| grep 443` |
| 手机 DNS 解析慢 | dnsmasq 上游可能在转圈，改用 `8.8.8.8`: `nmcli connection modify ProxyHotspot ipv4.dns 8.8.8.8` |
| `Error: Connection activation failed: Connection 'ProxyHotspot' is not available on device wlp0s20f3` | 你的 WiFi 卡正在连别的 WiFi。先 `nmcli device disconnect wlp0s20f3` |
| nft 报 `Error: Could not process rule: File exists` | 表已存在，先 `nft destroy table inet hotspot_proxy` |

### 6.1 客户端连了热点但完全无网络

```bash
# 1. 看热点接口的状态
ip addr show wlp0s20f3       # 必须有 10.42.0.1
ip route                     # 应看到 10.42.0.0/24 dev wlp0s20f3

# 2. NetworkManager shared 模式起 dnsmasq + masquerade 了吗
ps -ef | grep dnsmasq | grep -i nm
sudo nft list ruleset | grep -i masq

# 3. 客户端能 ping 网关吗
# 在手机连 WiFi 后，用网络诊断 ping 10.42.0.1
```

如果客户端能 ping 10.42.0.1 但不能上网 → 大概率是 redsocks 没在跑 / nft 规则没生效。

### 6.2 流量没经过 redsocks (走了 NAT 直连)

```bash
# 看 nft 计数
sudo nft list table inet hotspot_proxy
# prerouting 链每条规则后面有 packets / bytes 计数
# 如果 'redirect to :12345' 那条计数一直 0 → 规则没匹配到

# 常见原因:
# a) iifname 写错了 (确认是 wlp0s20f3 不是 wlan0)
# b) 优先级被其他表抢先 (dstnat - 5 已经比默认还前)
# c) 客户端在拿网关之前的流量
```

### 6.3 ⚠️ 流量 REDIRECT 进 nft 但客户端永远连不上 (redsocks bind 错地址)

**症状**: `meta l4proto tcp counter packets 1500+ redirect to :12345` 计数狂涨,
但 `ss -tnp` 看不到对应的 ESTABLISHED 连接,手机显示"无法联网"。

**根因**: redsocks 默认配置写 `local_ip = 127.0.0.1`,
但 nft `redirect to :12345` 会把目标 IP **改成入站接口的 IP** (即 `10.42.0.1`),
**不是** loopback。客户端 SYN 到达 `10.42.0.1:12345` → 内核找不到 listener → RST。

**验证**:
```bash
# 看 redsocks 监听哪
sudo ss -tlnp | grep redsocks
# 如果显示 127.0.0.1:12345 → 错的
# 应显示 0.0.0.0:12345 → 对

# 反向测试: 从热点网关 IP 能不能连
nc -vz 10.42.0.1 12345
# refused → bind 错了
```

**修复**: `local_ip = 0.0.0.0` (本仓库的 `redsocks.conf.example` 已经是对的)。
为了避免办公网其他主机也连进来白嫖, nft 的 `chain input` 限制 `iifname { lo, wlp0s20f3 }`。

---

## 7. 进阶 (可选)

### 7.1 客户端限速

避免某客户端跑满隧道带宽：

```bash
sudo tc qdisc add dev wlp0s20f3 root tbf rate 20mbit burst 32kbit latency 50ms
# 撤销:
# sudo tc qdisc del dev wlp0s20f3 root
```

### 7.2 开机自启 (推荐已部署)

用 `surge-hotspot.service`：

```bash
sudo install -m 0644 surge-hotspot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now surge-hotspot.service
```

⚠️ **关键设计点**: service 用 `Wants=surge-tunnel.service` 而**不是** `Requires=`。
否则 NM dispatcher 在热点 up 时重启 surge-tunnel，会通过 Requires 反向把
surge-hotspot 也 TERM 掉，导致 ExecStart 半路阵亡。

⚠️ **STA vs AP 冲突**: 同一张 WiFi 卡不能同时做客户端 (STA) 和热点 (AP)。
脚本第 4 步会检查 wlp0s20f3 是否被别的 WiFi 连接占用，是的话先 `disconnect`
再 up ProxyHotspot。否则会卡在「Geely-Group 自动重连 → AP 起不来」死循环。

按需关闭 / 重启：

```bash
sudo systemctl stop surge-hotspot.service     # 关
sudo systemctl restart surge-hotspot.service  # 改了配置后重启
sudo systemctl disable surge-hotspot.service  # 不再开机自启

### 7.3 配合 auto-switch-ssh-proxy 切网

`surge-tunnel.service` 切后端时 `127.0.0.1:6152` 监听者会换（socat ↔ autossh）。
**redsocks 连的是 `127.0.0.1:6152`，与具体后端解耦**，所以切网时只需重启 redsocks（可选）：

```bash
# 在 /etc/NetworkManager/dispatcher.d/60-surge-tunnel.sh 里加一行：
/usr/bin/systemctl restart redsocks 2>/dev/null || true
```

实际上 redsocks 是惰性连接，新连接才用新后端，所以这一步可省。

### 7.4 客户端绕过本机 / 本网

如果想让热点客户端访问 Ubuntu 自身或者 Ubuntu 局域网（10.167.68.0/23）不走代理：

```nft
# 在 prerouting 链 redirect 之前加
ip daddr 10.167.68.0/23 return
```

---

## 8. 安全注意事项

1. **WPA2-PSK 密码**：默认脚本里是 `changeme123`，**部署前必改**。
2. **SSID 不要广播敏感信息**（如 `Zhang-Office-Internal` 这种）。
3. **redsocks 暴露面**：监听 `127.0.0.1:12345`，外部不可达 ✓
4. **nft 表优先级**：`dstnat - 5` 比 NM 自动加的高，确保我们的 REDIRECT 先生效，但 NM 的 masquerade 还会兜底（这是好事 —— UDP DNS 和未被劫持的流量正常走 NAT）
5. **不要在不可信网络下开热点**：热点客户端拿到的是 Surge 出口，等于免费给别人翻墙。最好用足够长的密码，或者只在自己设备临时开。
6. **流量审计**：所有客户端的 HTTPS 在 Mac 上的 Surge 处可见连接元数据（域名/端口）。如果有隐私顾虑，知道这一层。

---

## 9. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-19 | 初版：设计文档 + 配置模板 + 一键脚本 |
| v1.1 | 2026-05-19 | 实测部署修复：redsocks.conf 改 C 风格注释；hotspot-up.sh 加 STA 断开 + WiFi radio 自动开；surge-hotspot.service 用 Wants= 避免被 surge-tunnel 重启连坐 |
| v1.2 | 2026-05-19 | **关键修复**：redsocks 必须 bind `0.0.0.0`（不能 `127.0.0.1`）—— nft REDIRECT 把目标 IP 改成入站接口 IP (10.42.0.1)，loopback 监听收不到。同步加 nft input 链限制 :12345 仅 wlp0s20f3+lo |
