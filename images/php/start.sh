#!/bin/sh
# Applies the timeout settings from the environment, then runs php-fpm in the foreground.
#   PHP_MAX_EXECUTION_TIME          php.ini max_execution_time   (seconds, 0 = unlimited; CPU time on Linux)
#   PHP_REQUEST_TERMINATE_TIMEOUT   php-fpm pool request_terminate_timeout (wall clock; 0 = unlimited)
# Keep nginx FASTCGI_READ_TIMEOUT >= these, otherwise nginx answers 504 first.
set -eu
V="${PHP_VERSION:?}"
MET="${PHP_MAX_EXECUTION_TIME:-300}"
RTT="${PHP_REQUEST_TERMINATE_TIMEOUT:-300}"
POOL="/etc/php/$V/fpm/pool.d/www.conf"

printf 'max_execution_time = %s\n' "$MET" > "/etc/php/$V/fpm/conf.d/99-platform-timeouts.ini"
if grep -q '^;\{0,1\}request_terminate_timeout' "$POOL"; then
  sed -i "s|^;\{0,1\}request_terminate_timeout.*|request_terminate_timeout = $RTT|" "$POOL"
else
  printf 'request_terminate_timeout = %s\n' "$RTT" >> "$POOL"
fi
exec "php-fpm$V" -F
