#!/bin/sh
# Applies the timeout settings from the environment, then runs php-fpm in the foreground.
#   PHP_MAX_EXECUTION_TIME          php.ini max_execution_time   (seconds, 0 = unlimited; CPU time on Linux)
#   PHP_REQUEST_TERMINATE_TIMEOUT   php-fpm pool request_terminate_timeout (wall clock; 0 = unlimited)
# Keep nginx FASTCGI_READ_TIMEOUT >= these, otherwise nginx answers 504 first.
#   PHP_MEMORY_LIMIT                php.ini memory_limit per request (default 128M, -1 = unlimited)
#   PHP_FPM_PM                      ondemand (default: workers start on demand, exit when idle) | dynamic | static
#   PHP_FPM_MAX_CHILDREN            most simultaneous PHP requests (default 3)
#   PHP_FPM_PROCESS_IDLE_TIMEOUT    ondemand only: idle worker lifetime (default 10s)
# Container cap (compose PHP_MEM_LIMIT) should be >= max_children x memory_limit + ~100m.
set -eu
V="${PHP_VERSION:?}"
MEM="${PHP_MEMORY_LIMIT:-128M}"
PM="${PHP_FPM_PM:-ondemand}"
CHILD="${PHP_FPM_MAX_CHILDREN:-3}"
case "$PM" in ondemand|dynamic|static) ;; *) echo "PHP_FPM_PM must be ondemand|dynamic|static" >&2; exit 1;; esac
[ "$CHILD" -ge 1 ] 2>/dev/null || CHILD=3
IDLE="${PHP_FPM_PROCESS_IDLE_TIMEOUT:-10s}"
MET="${PHP_MAX_EXECUTION_TIME:-300}"
RTT="${PHP_REQUEST_TERMINATE_TIMEOUT:-300}"
POOL="/etc/php/$V/fpm/pool.d/www.conf"

printf 'max_execution_time = %s\nmemory_limit = %s\n' "$MET" "$MEM" > "/etc/php/$V/fpm/conf.d/99-platform-timeouts.ini"
setpool() {            # setpool key value : set or append a pool directive
  if grep -q "^;\{0,1\}$1 *=" "$POOL"; then sed -i "s|^;\{0,1\}$1 *=.*|$1 = $2|" "$POOL"; else printf '%s = %s\n' "$1" "$2" >> "$POOL"; fi
}
setpool pm "$PM"
setpool pm.max_children "$CHILD"
if [ "$PM" = ondemand ]; then setpool pm.process_idle_timeout "$IDLE"; fi
if [ "$PM" = dynamic ]; then   # spare/start values must not exceed max_children
  S=2; [ "$CHILD" -ge "$S" ] || S=$CHILD
  M=3; [ "$CHILD" -ge "$M" ] || M=$CHILD
  setpool pm.start_servers "$S"; setpool pm.min_spare_servers 1; setpool pm.max_spare_servers "$M"
fi
if grep -q '^;\{0,1\}request_terminate_timeout' "$POOL"; then
  sed -i "s|^;\{0,1\}request_terminate_timeout.*|request_terminate_timeout = $RTT|" "$POOL"
else
  printf 'request_terminate_timeout = %s\n' "$RTT" >> "$POOL"
fi
exec "php-fpm$V" -F
