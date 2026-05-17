#!/bin/bash
# 自适应隧道:本地 6152 端口根据当前默认网关查 /etc/surge-tunnel/networks.conf,
# 第一条命中的规则决定走 socat (LAN 代理) 还是 autossh (SSH 隧道)。
# 无匹配或无网络 → exit 0,服务静默退出 (Restart=on-failure 不会拉起)。

set -u

CONFIG_FILE="/etc/surge-tunnel/networks.conf"
LOCAL_PORT=6152

# 等默认网关就绪 (systemd 启动时网络可能还没好)
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

if [ ! -r "$CONFIG_FILE" ]; then
  logger -t surge-tunnel "config $CONFIG_FILE not readable, exit"
  exit 1
fi

mode=""; target=""
while IFS='|' read -r p m t _; do
  [[ -z "$p" || "$p" == \#* ]] && continue
  # shellcheck disable=SC2053
  if [[ "$GW" == $p ]]; then
    mode="$m"; target="$t"
    logger -t surge-tunnel "match: gw=$GW rule=$p mode=$m target=$t"
    break
  fi
done < "$CONFIG_FILE"

if [ -z "$mode" ]; then
  logger -t surge-tunnel "no rule matched gw=$GW, exit"
  exit 0
fi

case "$mode" in
  socat)
    exec /usr/bin/socat \
        TCP-LISTEN:$LOCAL_PORT,bind=127.0.0.1,reuseaddr,fork \
        "TCP:$target"
    ;;
  ssh)
    host="${target%:*}"
    rport="${target##*:}"
    export AUTOSSH_GATETIME=0
    exec /usr/bin/autossh -M 0 \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -N -L "$LOCAL_PORT:127.0.0.1:$rport" "$host"
    ;;
  *)
    logger -t surge-tunnel "unknown mode: $mode, exit"
    exit 1
    ;;
esac
