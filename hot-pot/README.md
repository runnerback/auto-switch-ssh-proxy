# Proxy Hotspot (代理热点)

> **版本**: v1.3
> **更新时间**: 2026-05-20
> **状态**: 已部署运行

让 Ubuntu 开一个 WiFi 热点，**所有接入设备的 TCP 流量透明转发到 `127.0.0.1:6152`**（即 [auto-switch-ssh-proxy](../README.md) 的 surge 隧道入口），最终走家里/办公 Mac 的 Surge 出口。

手机/平板/其他笔记本 **连上就能用，无需在客户端配代理**，并且**能正常翻墙**（详见 §1.1 为什么必须用 xray）。

---

## 1. 架构

```
┌─────────────┐
│ 手机/平板    │  连 WiFi "JuGuang-13F-D"
└──────┬──────┘
       │ TCP (HTTP / HTTPS / SSH …)
       ▼
┌──────────────────────────── Ubuntu ─────────────────────────────┐
│                                                                  │
│  wlp0s20f3 (10.42.0.1, AP 模式, NM "shared" → 自带 dnsmasq+NAT)  │
│       │                                                          │
│       │ ① nft: prerouting REDIRECT tcp → :12345                  │
│       ▼                                                          │
│  xray dokodemo-door (0.0.0.0:12345, sniffing=on)                 │
│       │  ② 从 TLS ClientHello 嗅探 SNI / HTTP Host               │
│       │     用「域名」覆盖掉被污染的目标 IP                       │
│       ▼                                                          │
│  xray http outbound ── CONNECT 真实域名:port ──┐                 │
│                                                ▼                 │
│  127.0.0.1:6152 ──── 现有 surge-tunnel (autossh / socat)         │
│                                                                  │
└──────────┬──────────────────────────────────────────────────────┘
           ▼
     家里/公司 Mac 的 Surge → 公网 (按 Mac 上的 Surge 规则分流)
```

### 1.1 为什么必须用 xray，而不是 redsocks？

最初用 redsocks，结果**客户端只能上国内、上不了翻墙网**。根因是 **DNS 污染 + redsocks 只转发 IP**：

1. 手机解析 `www.google.com` → 走办公室/国内 DNS → GFW 返回**污染 IP**（实测返回的是 Facebook 的 IP）
2. 手机连这个污染 IP:443
3. redsocks 是「IP 级」透明代理，只能从 `SO_ORIGINAL_DST` 拿到**IP**，拿不到域名
4. redsocks 把 `CONNECT 污染IP:443` 发给 Surge
5. Surge 老实连那个污染 IP → 证书不匹配 → 失败

国内网站能通，是因为国内 DNS 不污染国内域名，IP 正确，Surge 直连成功。

**xray 的解法**：`dokodemo-door` 入站开 `sniffing` —— 读 TLS ClientHello 里的 **SNI**（或 HTTP `Host` 头），拿到真实域名，**丢弃污染 IP**，把 `CONNECT 真实域名:443` 发给 Surge。Surge 用自己的干净 DNS 重新解析 → 正确出口。

这样 DNS 污染**完全失效**，且 Surge 能套用全部域名规则。这是所有「透明网关翻墙」（OpenWrt 软路由等）的标准做法，redsocks 本身做不到 SNI 嗅探。

### 1.2 UDP 怎么办？

HTTP CONNECT 代理 **不支持 UDP**。所以方案是：
- **DNS (UDP 53)**：让 NetworkManager 自带的 dnsmasq 处理。客户端拿到的 IP 可能被污染，但**无所谓** —— xray 会用 SNI 嗅探纠正，污染 IP 用不上。
- **QUIC (UDP 443/80)**：nft `reject`，让浏览器/App 回退到 TCP TLS。否则 Chrome 会用 QUIC 绕过代理（而且 QUIC 没 TCP，xray 透明入站也接不了）。
- **其他 UDP**（WebRTC、游戏）：会被 NAT 直连出去，**不走代理**。这是 HTTP 代理的固有局限。

---

## 2. 文件清单

部署后:

| 路径 | 作用 |
|---|---|
| `/usr/local/bin/xray` | xray 二进制 |
| `/usr/local/etc/xray/config.json` | xray 配置（透明入站 + http 出站） |
| `/etc/systemd/system/xray.service` | xray systemd unit |
| `/etc/nftables.d/hotspot-proxy.nft` | 流量劫持规则 |
| `/usr/local/bin/hotspot-up.sh` | 一键开 |
| `/usr/local/bin/hotspot-down.sh` | 一键关 |
| `/etc/systemd/system/surge-hotspot.service` | 开机自启 unit |
| NM connection profile `ProxyHotspot` | 热点 SSID/密码/AP 配置 |

项目目录:

| 路径 | 作用 |
|---|---|
| `xray-config.json` | xray 配置模板 |
| `xray.service` | xray systemd unit 源 |
| `hotspot-proxy.nft` | nftables 规则模板 |
| `hotspot-up.sh` | 一键开热点脚本源 |
| `hotspot-down.sh` | 一键关热点脚本源 |
| `surge-hotspot.service` | 开机自启 unit 源 |
| `README.md` | 本文档 |

---

## 3. 一次性部署

### 3.1 装 xray

apt 仓库没有 xray，从 GitHub 下二进制：

```bash
TMP=$(mktemp -d); cd "$TMP"
curl -fL -o xray.zip \
  https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -oq xray.zip
sudo install -m 0755 xray /usr/local/bin/xray
sudo mkdir -p /usr/local/share/xray /usr/local/etc/xray
sudo install -m 0644 geoip.dat geosite.dat /usr/local/share/xray/
cd / && rm -rf "$TMP"
xray version
```

### 3.2 配置 xray

```bash
cd ~/Projects/auto-switch-ssh-proxy/hot-pot
sudo install -m 0644 xray-config.json /usr/local/etc/xray/config.json
sudo install -m 0644 xray.service /etc/systemd/system/xray.service
sudo systemctl daemon-reload

# 校验配置 + 启动
xray run -test -config /usr/local/etc/xray/config.json
sudo systemctl enable --now xray
ss -tlnp | grep 12345     # 应看到 xray 监听 *:12345 (0.0.0.0)
```

> ⚠️ xray 必须监听 `0.0.0.0`（配置里 `"listen": "0.0.0.0"`）。nft `redirect to :12345`
> 会把目标 IP 改成入站接口的 IP (10.42.0.1)，只听 loopback 会收不到。

### 3.3 配置 nftables 劫持规则

```bash
sudo mkdir -p /etc/nftables.d
sudo install -m 0644 hotspot-proxy.nft /etc/nftables.d/hotspot-proxy.nft
sudo bash -c 'grep -q hotspot-proxy /etc/nftables.conf || \
    echo "include \"/etc/nftables.d/hotspot-proxy.nft\"" >> /etc/nftables.conf'
```

### 3.4 安装脚本 + 开机自启

```bash
sudo install -m 0755 hotspot-up.sh   /usr/local/bin/
sudo install -m 0755 hotspot-down.sh /usr/local/bin/
sudo install -m 0644 surge-hotspot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now surge-hotspot.service
```

### 3.5 起热点

`surge-hotspot.service` 已 enable，开机自动起。手动起停：

```bash
sudo systemctl start  surge-hotspot
sudo systemctl stop   surge-hotspot
```

`hotspot-up.sh` 会：① 等 surge-tunnel 在跑 → ② 启动 xray → ③ 加载 nft 规则 →
④ 开 WiFi radio + 断开占用 WiFi 卡的 STA 连接 → ⑤ 起 `ProxyHotspot` 热点（首次自动创建）。

**改 SSID/密码**：编辑 `hotspot-up.sh` 顶部的 `HOTSPOT_SSID` / `HOTSPOT_PASS`，重装脚本后重启服务。或直接：

```bash
nmcli connection modify ProxyHotspot 802-11-wireless.ssid "新SSID"
nmcli connection modify ProxyHotspot wifi-sec.psk "新密码"
nmcli connection up ProxyHotspot
```

---

## 4. 验证

```bash
# 1. 服务都在
systemctl is-active surge-tunnel xray surge-hotspot
nmcli -t -f NAME,STATE connection show --active | grep ProxyHotspot

# 2. nft 表 + 计数
sudo nft list table inet hotspot_proxy

# 3. 热点接口
ip addr show wlp0s20f3 | grep "inet 10.42"

# 4. 看谁连上了
sudo iw dev wlp0s20f3 station dump | grep Station

# 5. 客户端访问 https://ipinfo.io —— 出口应是 Surge 节点 IP，且能打开 google
```

### 验证 xray SNI 嗅探（核心功能）

模拟手机的情形：连一个被污染的 IP，但 TLS SNI 是真实域名，看 xray 能否纠正：

```bash
# 临时把本机发往某污染 IP 的流量也 redirect 到 xray
sudo nft -f - <<'EOF'
table inet xray_test {
    chain output {
        type nat hook output priority dstnat - 5; policy accept;
        meta l4proto tcp ip daddr 157.240.7.20 tcp dport 443 redirect to :12345
    }
}
EOF

# 连污染 IP 157.240.7.20（Facebook 的 IP），但 SNI=www.google.com
curl -k -sI -m 15 --resolve www.google.com:443:157.240.7.20 https://www.google.com | head -3
# 期望: HTTP/2 200 —— 说明 xray 嗅探出 google 域名并正确转发

sudo nft destroy table inet xray_test     # 清理
```

xray 日志能看到嗅探+转发的连接：

```bash
sudo journalctl -u xray -f
# from 10.42.0.x:port accepted tcp:IP:443 [transparent >> proxy]
```

---

## 5. 日常使用

```bash
# 开 / 关 / 重启
sudo systemctl start   surge-hotspot
sudo systemctl stop    surge-hotspot
sudo systemctl restart surge-hotspot

# 看谁连上了热点
sudo iw dev wlp0s20f3 station dump | grep Station
ip neigh show dev wlp0s20f3

# 实时监控 nft 命中数
watch -n 1 'sudo nft list table inet hotspot_proxy | grep counter'

# 实时看 xray 转发
sudo journalctl -u xray -f
```

### 改频段

```bash
nmcli connection modify ProxyHotspot 802-11-wireless.band a    # 5GHz 更快
nmcli connection modify ProxyHotspot 802-11-wireless.band bg   # 2.4GHz 兼容好
nmcli connection up ProxyHotspot
```

---

## 6. 故障排查

| 症状 | 排查 |
|---|---|
| 客户端连不上 WiFi | `journalctl -u NetworkManager -n 50`; 网卡可能不支持当前频段，换 `band bg` |
| 连上 WiFi 没网 | 看 xray / surge-tunnel 是否健康 (`curl -x http://127.0.0.1:6152 -sI https://www.google.com`) |
| **只能上国内，翻墙网打不开** | xray sniffing 没生效。见 §6.4 |
| 客户端慢得离谱 | Surge 节点慢，或 6152 隧道延迟高。`mtr` 看 Mac 上游 |
| Chrome 还在用 QUIC 绕代理 | nft forward 链 reject UDP 443 没生效，`nft list ruleset \| grep 443` |
| `Connection 'ProxyHotspot' is not available on device wlp0s20f3` | WiFi 卡在连别的 WiFi。`nmcli device disconnect wlp0s20f3` |
| nft 报 `File exists` | 表已存在，先 `nft destroy table inet hotspot_proxy` |

### 6.1 客户端连了热点但完全无网络

```bash
ip addr show wlp0s20f3       # 必须有 10.42.0.1
ps -ef | grep dnsmasq | grep -i nm        # NM shared 的 dnsmasq 在跑吗
sudo nft list ruleset | grep -i masq      # masquerade 规则在吗
# 手机连 WiFi 后 ping 10.42.0.1 —— 能 ping 通但不能上网 → 看 xray / nft
```

### 6.2 流量没经过 xray (走了 NAT 直连)

```bash
sudo nft list table inet hotspot_proxy
# prerouting 链 'redirect to :12345' 计数一直 0 → 规则没匹配到
# 常见原因: iifname 写错 / 优先级被抢 / 客户端拿网关前的流量
```

### 6.3 ⚠️ 流量 REDIRECT 进 nft 但客户端连不上 (监听地址错)

**症状**: `redirect to :12345` 计数狂涨，但 `ss -tnp` 看不到 ESTABLISHED 连接。

**根因**: nft `redirect to :12345` 把目标 IP 改成入站接口 IP (10.42.0.1)，
不是 loopback。监听 `127.0.0.1:12345` 会收不到。

**修复**: xray 配置里 `"listen": "0.0.0.0"`（本仓库模板已是对的）。
验证: `ss -tlnp | grep 12345` 应显示 `*:12345`。
nft `chain input` 限制 :12345 仅 `wlp0s20f3 + lo`，防办公网白嫖。

### 6.4 ⚠️ 只能上国内，翻墙网打不开 (xray sniffing 问题)

**根因**: DNS 污染 + 代理只拿到 IP 没拿到域名。详见 §1.1。

**检查**:
```bash
# xray 配置里 sniffing 必须 enabled
grep -A4 sniffing /usr/local/etc/xray/config.json
# "enabled": true, "destOverride": ["http","tls"]

# 用 §4 的 xray_test 方法验证嗅探是否生效
```

**修复**: 确保 `xray-config.json` 的 inbound 里有：
```json
"sniffing": { "enabled": true, "destOverride": ["http", "tls"], "routeOnly": false }
```
`routeOnly` 必须 `false` —— true 只用域名做路由判断、实际连接仍用污染 IP。

---

## 7. 进阶 (可选)

### 7.1 客户端限速

```bash
sudo tc qdisc add dev wlp0s20f3 root tbf rate 20mbit burst 32kbit latency 50ms
sudo tc qdisc del dev wlp0s20f3 root     # 撤销
```

### 7.2 开机自启设计要点

⚠️ `surge-hotspot.service` 用 `Wants=`（不是 `Requires=`）依赖 surge-tunnel / xray。
否则 NM dispatcher 在热点 up 时重启 surge-tunnel，会通过 Requires 反向把
surge-hotspot 也 TERM 掉，ExecStart 半路阵亡。

⚠️ 同一张 WiFi 卡不能同时做 STA + AP。脚本第 4 步会断开占用 wlp0s20f3 的
客户端连接，再起 AP。

### 7.3 配合 auto-switch-ssh-proxy 切网

`surge-tunnel.service` 切后端时 `127.0.0.1:6152` 监听者会换（socat ↔ autossh）。
xray 连的是 `127.0.0.1:6152`，与具体后端解耦，新连接自动用新后端，无需干预。

### 7.4 客户端绕过本机 / 本网

让热点客户端访问 Ubuntu 自身或局域网不走代理 —— 在 `hotspot-proxy.nft`
的 prerouting 链 redirect 之前加：

```nft
ip daddr 10.167.68.0/23 return
```

---

## 8. 安全注意事项

1. **WPA2-PSK 密码**：当前 SSID `JuGuang-13F-D`，密码见 `hotspot-up.sh`。换密码见 §3.5。
2. **xray :12345 暴露面**：监听 `0.0.0.0` 但 nft `input` 链只放行 `wlp0s20f3 + lo`，办公网其他主机连不进来。
3. **nft 优先级**：`dstnat - 5` 比 NM 自动加的规则更前，确保 REDIRECT 先生效；NM masquerade 仍兜底未劫持的流量。
4. **不要在不可信网络下开热点**：热点客户端拿到的是 Surge 出口，等于免费给别人翻墙。用足够长的密码。
5. **流量审计**：所有客户端的 HTTPS 连接元数据（域名/端口）在 Mac 的 Surge 处可见。

---

## 9. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-19 | 初版：设计文档 + 配置模板 + 一键脚本 |
| v1.1 | 2026-05-19 | 实测部署修复：redsocks.conf 改 C 风格注释；hotspot-up.sh 加 STA 断开 + WiFi radio 自动开；surge-hotspot.service 用 Wants= 避免被 surge-tunnel 重启连坐 |
| v1.2 | 2026-05-19 | 关键修复：透明代理必须 bind `0.0.0.0`（nft REDIRECT 改目标 IP 为入站接口 IP）；加 nft input 链限制 :12345 仅 wlp0s20f3+lo |
| v1.3 | 2026-05-20 | **redsocks → xray**：redsocks 只转发 IP，遇 DNS 污染无法翻墙（只能上国内）。换 xray dokodemo-door + sniffing，从 TLS SNI 嗅探真实域名转给 Surge，DNS 污染失效 |
