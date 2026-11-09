#!/bin/sh
# Creates the Traefik default certificate with mkcert (private local CA).
#   dev : CERT_NAMES=mysite.test,*.mysite.test,localhost,127.0.0.1,::1
#   prod: CERT_NAMES=203.0.113.10          (IP:port access, "self signed" = signed by your own CA)
# The CA lives in /certs/mkcert (rootCA.pem). Trust it once per client PC; every cert
# issued later (new names / new IP) is then trusted automatically.
set -eu
set -f                                   # '*.mysite.test' must not be glob-expanded

CERT_DIR=/certs
NAMES=$(printf '%s' "${CERT_NAMES:?CERT_NAMES is empty}" | tr ',' ' ')
export CAROOT="$CERT_DIR/mkcert"
mkdir -p "$CAROOT"
cd "$CERT_DIR"

if [ "${CERT_FORCE:-0}" != "1" ] \
   && [ -s default.pem ] && [ -s default-key.pem ] && [ -f default.names ] \
   && [ "$(cat default.names)" = "$NAMES" ] \
   && [ -z "$(find default.pem -mtime +700 2>/dev/null)" ]; then
  echo "[certs] up to date for: $NAMES"
  exit 0
fi

echo "[certs] generating certificate for: $NAMES"
# shellcheck disable=SC2086
mkcert -cert-file default.pem -key-file default-key.pem $NAMES
printf '%s' "$NAMES" > default.names
cp "$CAROOT/rootCA.pem" "$CERT_DIR/rootCA.crt"     # handy copy to import on other PCs/phones
chmod 600 default-key.pem "$CAROOT/rootCA-key.pem" 2>/dev/null || true
echo "[certs] done. Trust $CERT_DIR/rootCA.crt on client machines (windows/1-install-cert.bat)."
