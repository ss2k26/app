#!/bin/sh
# Local end of a remote-database link. Listens on $LISTEN_PORT inside the container and forwards to the
# database published on the VPS ($REMOTE_PORT), either
#   ssh    : through an SSH tunnel (the VPS sees a connection from 127.0.0.1)  <- recommended
#   direct : plain TCP via socat to $REMOTE_HOST:$REMOTE_PORT (VPS port must be reachable)
# Either way the VPS-side socat proxy (see mysql56/compose.yml) makes mysqld see root@127.0.0.1.
set -eu

fail() { echo "[remote-db] $*" >&2; sleep 30; exit 1; }     # sleep: avoid a tight restart loop

: "${LISTEN_PORT:?}" "${REMOTE_PORT:?}"
[ -n "${REMOTE_HOST:-}" ] || fail "REMOTE_HOST is empty - set it in stacks/databases/remote/.env"

# REMOTE_HOST=windows: the Windows 10 host that runs WSL2 (NAT mode). Only valid for a container in the
# host network namespace (compose service "windows"): there the default gateway IS the Windows host.
if [ "$REMOTE_HOST" = "windows" ]; then
  REMOTE_HOST=$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')
  [ -n "$REMOTE_HOST" ] || fail "cannot detect the Windows host IP (no default route) - set WINDOWS_HOST to its IP"
  echo "[remote-db] Windows host detected: $REMOTE_HOST"
fi

case "${REMOTE_MODE:-ssh}" in
  direct)
    echo "[remote-db] direct :$LISTEN_PORT -> $REMOTE_HOST:$REMOTE_PORT"
    exec socat "tcp-listen:${LISTEN_PORT},fork,reuseaddr,max-children=200" "tcp-connect:${REMOTE_HOST}:${REMOTE_PORT}"
    ;;
  ssh)
    [ -n "${REMOTE_SSH_USER:-}" ] || fail "REMOTE_SSH_USER is empty"
    KEY="/ssh/${REMOTE_SSH_KEY:-id_ed25519}"
    [ -f "$KEY" ] || fail "private key $KEY not found - put it in data/ssh/ (see docs/remote-db.md)"
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    tr -d '\r' < "$KEY" > /root/.ssh/id && chmod 600 /root/.ssh/id      # Windows keys may be CRLF / 0777
    echo "[remote-db] ssh :$LISTEN_PORT -> ${REMOTE_SSH_USER}@${REMOTE_HOST}:${REMOTE_SSH_PORT:-22} -> ${REMOTE_SSH_TARGET_HOST:-127.0.0.1}:$REMOTE_PORT"
    while :; do
      ssh -N \
        -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=15 \
        -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
        -o StrictHostKeyChecking=accept-new \
        -i /root/.ssh/id -p "${REMOTE_SSH_PORT:-22}" \
        -L "0.0.0.0:${LISTEN_PORT}:${REMOTE_SSH_TARGET_HOST:-127.0.0.1}:${REMOTE_PORT}" \
        "${REMOTE_SSH_USER}@${REMOTE_HOST}" || true
      echo "[remote-db] tunnel closed, reconnecting in 5s" >&2
      sleep 5
    done
    ;;
  *) fail "REMOTE_MODE must be 'ssh' or 'direct'" ;;
esac
