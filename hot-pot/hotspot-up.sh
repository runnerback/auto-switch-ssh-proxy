#!/usr/bin/env bash
# 一键开启 "代理热点"
#
# 1. 启动 redsocks
# 2. 加载 nftables 劫持规则
# 3. 用 nmcli 起 WiFi 热点（"shared" 模式自动 NAT + dnsmasq）
#
# 用法: sudo ./hotspot-up.sh

set -euo pipefail

HOTSPOT_NAME="${HOTSPOT_NAME:-ProxyHotspot}"
HOTSPOT_SSID="${HOTSPOT_SSID:-JuGuang-13F-D}"
HOTSPOT_PASS="${HOTSPOT_PASS:-123581321}"
HOTSPOT_IFACE="${HOTSPOT_IFACE:-wlp0s20f3}"
HOTSPOT_BAND="${HOTSPOT_BAND:-bg}"    # bg=2.4G(兼容好), a=5G(快但部分老设备不支持)

if [[ $EUID -ne 0 ]]; then
    echo "需要 root，请用 sudo" >&2; exit 1
fi

echo "[1/5] 确认 surge-tunnel 在跑 ..."
# 给 surge-tunnel 最多 30s 上线（开机时 autossh 可能还在握手）
for i in $(seq 1 30); do
    ss -tln | grep -q '127.0.0.1:6152' && break
    sleep 1
done
if ! ss -tln | grep -q '127.0.0.1:6152'; then
    echo "  ❌ 127.0.0.1:6152 没监听（等了 30s），先修好 surge-tunnel 再来" >&2
    exit 1
fi
echo "  ✓ surge-tunnel OK"

echo "[2/5] 启动 xray (SNI 嗅探透明代理) ..."
systemctl enable --now xray
sleep 1
if ! ss -tln | grep -q ':12345'; then
    echo "  ❌ xray:12345 没监听，看 journalctl -u xray -n 30" >&2
    exit 1
fi
echo "  ✓ xray OK"

echo "[3/5] 加载 nftables 劫持规则 ..."
nft -f /etc/nftables.d/hotspot-proxy.nft
echo "  ✓ nft table inet hotspot_proxy 已加载"

echo "[4/5] 打开 WiFi radio + 确保接口空闲 ..."
rfkill unblock wifi
nmcli radio wifi on
# 给 NM 一点时间识别设备
for i in $(seq 1 10); do
    state=$(nmcli -t -f GENERAL.STATE device show "$HOTSPOT_IFACE" 2>/dev/null | cut -d: -f2)
    case "$state" in
        *unavailable*) sleep 1 ;;
        *) break ;;
    esac
done
# 如果 NM 自动接入了别的 WiFi（STA 模式），先断开 —— 同张卡不能 STA+AP 共存
active_conn=$(nmcli -t -f GENERAL.CONNECTION device show "$HOTSPOT_IFACE" 2>/dev/null | cut -d: -f2)
if [[ -n "$active_conn" && "$active_conn" != "$HOTSPOT_NAME" && "$active_conn" != "--" ]]; then
    echo "  ⚠ 当前 $HOTSPOT_IFACE 被 \"$active_conn\" 占用，断开"
    nmcli device disconnect "$HOTSPOT_IFACE" || true
    sleep 1
fi
echo "  ✓ $HOTSPOT_IFACE 可用"

echo "[5/5] 启动 WiFi 热点 \"$HOTSPOT_SSID\" ..."
# 若 profile 不存在，先创建
if ! nmcli -t connection show | grep -q "^${HOTSPOT_NAME}:"; then
    nmcli connection add type wifi ifname "$HOTSPOT_IFACE" \
        con-name "$HOTSPOT_NAME" autoconnect no ssid "$HOTSPOT_SSID"
    nmcli connection modify "$HOTSPOT_NAME" \
        802-11-wireless.mode ap \
        802-11-wireless.band "$HOTSPOT_BAND" \
        ipv4.method shared \
        ipv6.method ignore \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$HOTSPOT_PASS"
fi
nmcli connection up "$HOTSPOT_NAME"

echo ""
echo "✅ 热点已开:"
echo "   SSID:    $HOTSPOT_SSID"
echo "   密码:    $HOTSPOT_PASS"
echo "   网段:    10.42.0.0/24 (网关 10.42.0.1)"
echo ""
echo "在手机/平板上连这个 WiFi，所有 TCP 流量自动走 surge-tunnel"
echo "关闭: sudo ./hotspot-down.sh"
