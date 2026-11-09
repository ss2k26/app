# Migrating from the old layout

## What maps to what

| Old | New |
|---|---|
| `stacks/shared-services/proxy-traefik/docker-compose-{dev,prod,ip}.yml` | `stacks/core/traefik/compose.yml` + `.env` |
| `.../dashboard-portainer/docker-compose-{dev,prod,ip}.yml` | `stacks/core/portainer/compose.yml` + `.env` |
| `.../mysql56/docker-compose-{dev,prod}.yml`, `*.cnf` | `stacks/databases/mysql56/compose.yml`, `conf/` (`MYSQL56_CNF=low-memory|production`) |
| `.../base-images/php56-debian13`, `php72-debian13` | `images/php/` -> `local/php:5.6`, `local/php:7.2` |
| `stacks/laravel-apps/*`, `stacks/php-apps/*` | `stacks/apps/<name>/` (+ `_shared/nginx.conf.template`) |
| network `shared-db-network` | `edge` (Traefik/web) and `data` (php/databases) |
| `run-cert-install.bat`, `run-host-update.bat`, `*.ps1` | `windows/1-install-cert.bat`, `2-setup-dns.bat`, `3-update-hosts.bat` |
| `fast-copy.md`, `faster-on-windows.md` | `docs/` |
| DB host `mysql56-shared` | still works (alias kept); new name `mysql56` |
| Traefik dashboard `:8082` on all interfaces | `http://localhost:8080` (loopback) |

## Steps (dev machine; the VPS is the same with `prod`)

1. **Back up** `data/mysql56` (copy the folder) and commit/stash your repo.
2. **Stop the old stacks** from their old folders: `docker compose -f docker-compose-dev.yml down` for apps, mysql56, portainer, traefik.
3. **Overlay the new tree** on the repo. Keep `data/` and `htdocs/`; the old `stacks/shared-services|laravel-apps|php-apps` and root scripts are replaced.
4. **Keep your trusted certificate (avoids re-installing the CA on Windows).** Before the first start copy the old mkcert CA:
   ```bash
   mkdir -p certs/mkcert
   cp stacks/shared-services/proxy-traefik/dev/rootCA.pem stacks/shared-services/proxy-traefik/dev/rootCA-key.pem certs/mkcert/
   ```
   (Do this before deleting the old folder. If you skip it, a new CA is created and you run `1-install-cert.bat` once more.)
5. `bin/platform init dev`, review the `.env` files, `bin/platform build`.
6. `bin/platform up` then `bin/platform up bengkel panglima-kediri`.
   The existing MySQL 5.6 data directory is reused as-is; the root-password variables only apply to an empty data directory.
7. Windows: `1-install-cert.bat` (if the CA changed) and `2-setup-dns.bat` or `3-update-hosts.bat`.
8. When nothing uses it any more: `docker network rm shared-db-network`; `docker image rm local/php72-debian13:latest local/php56-debian13:latest`.

## Things that behave differently
* `docker compose exec bengkel-app ...` becomes `bin/platform exec bengkel php ...` (services are `php` / `web`; containers are named by Compose).
* `down -v` on an app also removes its `vendor` volume (as before); run `composer install` again.
* The IP-mode entrypoints are no longer one per app in Traefik's file; they come from the `ip-8443..8450` pool.
* mysql56 is bound to `127.0.0.1` only by default (unchanged); remote access options are in [databases.md](databases.md).
* Compose-level `container_name` is gone for app containers; use `platform ps/logs/exec`.
