#!/usr/bin/env bash
# 关闭代理热点 (反向操作 hotspot-up.sh)
# 用法: sudo ./hotspot-down.sh

set -euo pipefail
HOTSPOT_NAME="${HOTSPOT_NAME:-ProxyHotspot}"

if [[ $EUID -ne 0 ]]; then
    echo "需要 root" >&2; exit 1
fi

echo "[1/3] 停热点 ..."
nmcli connection down "$HOTSPOT_NAME" 2>/dev/null || true

echo "[2/3] 卸 nft 表 ..."
nft destroy table inet hotspot_proxy 2>/dev/null || true

echo "[3/3] 停 redsocks ..."
systemctl stop redsocks

echo "✅ 已关闭"
