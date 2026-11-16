# Memory limits

Every container has a memory cap (`mem_limit`). If a container exceeds it, Docker kills only that
container (OOM) instead of the whole server swapping to death. All caps are variables in the stack's
`.env`; **`0` = unlimited**. Defaults apply when the variable is unset.

## Suggested defaults

| Stack / container | Variable | Default | Prod example | Why |
|---|---|---|---|---|
| traefik | `TRAEFIK_MEM_LIMIT` | 256m | | uses ~50-100 MB |
| portainer | `PORTAINER_MEM_LIMIT` | 256m | | ~100-200 MB |
| dev dns (dnsmasq) | `DNS_MEM_LIMIT` | 64m | | tiny |
| mysql56 | `MYSQL56_MEM_LIMIT` | 512m | 2g | default `low-memory` cnf; `production` cnf has a 1G buffer pool |
| mysql84 | `MYSQL84_MEM_LIMIT` | 768m | 2g | 8.4 needs more baseline than 5.6 |
| mariadb | `MARIADB_MEM_LIMIT` | 512m | 2g | same as above |
| postgres | `POSTGRES_MEM_LIMIT` | 512m | 2g | `shared_buffers` 128MB default, 512MB in prod example |
| db socat proxies | `<DB>_PROXY_MEM_LIMIT` | 32m | | socat only |
| remote forwarders | `REMOTE_MEM_LIMIT` | 64m | | ssh/socat |
| app php-fpm | `PHP_MEM_LIMIT` | 512m | per app | 3 children x 128M + ~100m |
| app nginx | `WEB_MEM_LIMIT` | 128m | | static + proxy only |
| app dbproxy sidecar | `DBPROXY_MEM_LIMIT` | 32m | | socat only |

## Sizing rules

- **Databases:** cap ≈ 2x the buffer pool (`innodb_buffer_pool_size` / `shared_buffers`), plus ~10 MB per
  connection. When you switch `*_CNF=production` (1G pool), set the cap to 2g. Raise both together.
  A cap below the buffer pool gets the database OOM-killed under load.
- **PHP apps:** `PHP_MEM_LIMIT >= PHP_FPM_MAX_CHILDREN x PHP_MEMORY_LIMIT + ~100m`.
  - `PHP_MEMORY_LIMIT` = php.ini `memory_limit` per request (default 128M).
  - `PHP_FPM_MAX_CHILDREN` = simultaneous PHP requests (default 3).
  - `PHP_FPM_PM` = `ondemand` (default), `dynamic` or `static`. With `ondemand`, workers start with the first
    request and exit after `PHP_FPM_PROCESS_IDLE_TIMEOUT` (default 10s), so an idle app holds almost no worker
    memory. The cost is a few milliseconds on the first request after idle. Use `dynamic`/`static` only for
    the few busiest apps.
  - Example for an export-heavy app: `PHP_MEMORY_LIMIT=256M`, `PHP_FPM_MAX_CHILDREN=8`, `PHP_MEM_LIMIT=2300m`.
  - These PHP settings need the PHP image rebuilt once (`platform build`) because they are applied by `start.sh`.
- **Budget the whole server:** sum of caps can exceed RAM (not every container peaks together), but the
  *typical* sum should fit. Keep ~15% for the OS and page cache.

## Many apps on a small server (e.g. 20 Laravel apps on 4 GB)

A cap is a ceiling, not a reservation: 20 x 512m caps do **not** need 10 GB. What counts is real use:
an idle app costs ~50-80 MB (php-fpm master + OPcache + nginx), so 20 idle apps are ~1-1.5 GB, plus the
database and core stacks. Workers only add memory while requests are running.

1. Keep the defaults (`ondemand`, 3 children, 512m). Give only busy apps more.
2. Keep the *typical* total under ~80% of RAM and the sum of caps under ~2x RAM.
3. Add a small swap file (1-2 GB) as a safety net against short spikes, not 20 GB: swap is disk, and a
   server that really needs it becomes extremely slow instead of failing cleanly.
4. Watch it with `bin/platform mem` after a normal day, then tune. If idle use alone is near RAM, the
   server is too small: move to 8 GB rather than adding swap.

Swap file on Ubuntu:
```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
sysctl vm.swappiness=10 && echo 'vm.swappiness=10' > /etc/sysctl.d/99-swap.conf
```

## Example budgets (prod, caps only)

| Server RAM | Core | 1 database (prod cnf) | Apps |
|---|---|---|---|
| 2 GB | traefik 256m + portainer 256m | 512m (`low-memory` cnf) | 2 small apps x ~384m |
| 4 GB | 512m | 2g | 4-8 apps at defaults (512m each); or ~20 quiet apps with `ondemand` |
| 8 GB | 512m | 2g (+ second DB 2g) | 10-15 apps at defaults; 20 quiet apps |

## Checking

```bash
bin/platform mem        # grouped: CORE, DATABASES, APPS - one row per stack, with a total per group
bin/platform mem -v     # same, plus every container under its stack
```
Output looks like (used / cap):
```
APPS
  bengkel          2 ctr      54 MiB / 640 MiB
  shop             2 ctr    1.10 GiB / unlimited*
  TOTAL apps                1.16 GiB / 768 MiB + unlimited*
ALL CONTAINERS              1.72 GiB  caps 2.03 GiB + unlimited*   host RAM 3.82 GiB, containers use 45%
```
Groups come from where each stack lives (`stacks/core`, `stacks/databases`, `stacks/apps`); anything else
is listed as OTHER. Compare the **used** total with host RAM, not the caps. `unlimited*` means no cap is set (`0`). Apply a changed cap with
`bin/platform up <stack> -- --force-recreate`. For existing apps run `bin/platform sync-apps --up` once to
pick up the new template (it adds the `mem_limit` lines).

## Windows dev (WSL2)

All containers share the memory of the WSL2 VM, which defaults to 50% of Windows RAM. To change it,
create `%UserProfile%\.wslconfig`:
```
[wsl2]
memory=6GB
swap=2GB
```
then `wsl --shutdown`. Container caps are upper bounds inside that VM; for dev the defaults are
deliberately small.
