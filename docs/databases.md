# Databases

| Stack | Image | Host alias (inside Docker) | Published port (host) | Data dir |
|---|---|---|---|---|
| `mysql56` | mysql:5.6.43 | `mysql56` (+ `mysql56-shared`, old name) | 3306 | `data/mysql56` (unchanged) |
| `mysql84` | mysql:8.4 LTS | `mysql84` | 3307 | `data/mysql84` |
| `mariadb` | mariadb:11.4 LTS | `mariadb` | 3308 | `data/mariadb` |
| `postgres` | postgres:17-alpine | `postgres` | 5432 | `data/postgres17` |

Apps always use the alias and the **in-container port** (3306, or 5432 for postgres), e.g. `DB_HOST=mysql84`, `DB_PORT=3306`.
Remote PCs use the **published** port (3307 for mysql84 ...).

## The socat pattern (MySQL, MariaDB)

```
remote PC ──> VPS:3306 ──> [socat container :3306] ──> 127.0.0.1:33060 ──> mysqld
                           └── owns the network namespace; mysqld joins it (network_mode: service:proxy)
```
mysqld binds `127.0.0.1` only, so nothing can reach it except through socat, and because socat connects from inside
the same namespace, mysqld sees every client as `127.0.0.1`. That is why `root@127.0.0.1` works for remote PCs.
Internal ports: mysql56 `33060`, mysql84/mariadb `13306` (MySQL 8 would otherwise clash with its X-plugin port).

If socat is **recreated** (not merely restarted), recreate the DB container too: `bin/platform up mysql56 -- --force-recreate`.

## PostgreSQL is different on purpose
The official image trusts `127.0.0.1` without a password. Routing remote clients through localhost would hand them a
passwordless superuser, so the postgres stack puts socat in front over the normal network (`tcp-connect:db:5432`).
Remote clients must authenticate (scram-sha-256).

## Remote access: choose how exposed you want to be

`root` reachable through socat means **anyone who can reach the published port gets a root login attempt**. Options, safest first:

1. **SSH tunnel (default, `*_BIND=127.0.0.1`)** — nothing is exposed.
   `ssh -L 3306:127.0.0.1:3306 user@vps`, then connect to `127.0.0.1:3306` on your PC (HeidiSQL/DBeaver have a built-in SSH tunnel tab).
2. **VPN IP (WireGuard/Tailscale)**: `MYSQL56_BIND=<vpn ip of the VPS>`.
3. **Public + firewall allow-list**: `MYSQL56_BIND=0.0.0.0`, a strong root password (set `MYSQL56_ROOT_PASSWORD` before the *first*
   start, or `ALTER USER` later) and a rule that only lets your office/home IP reach the published port. Docker bypasses
   `ufw`, so use the `DOCKER-USER` chain (example for published port 3306, public interface `eth0`, allowed IP `203.0.113.7`):
   ```bash
   sudo iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctorigdstport 3306 ! -s 203.0.113.7 -j DROP
   ```
   (Persist it with `iptables-persistent`/your provider's cloud firewall. Adapt interface and port; test from another network.)
   Do not try to allow-list inside socat: your own apps reach the database through socat too.

## Per-app users (recommended instead of root)
```bash
bin/platform exec mysql56 db mysql -uroot -p -e "CREATE DATABASE bengkel; CREATE USER 'bengkel'@'%' IDENTIFIED BY 'secret'; GRANT ALL ON bengkel.* TO 'bengkel'@'%'; FLUSH PRIVILEGES;"
bin/platform exec postgres db psql -U postgres -c "CREATE ROLE bengkel LOGIN PASSWORD 'secret'" -c "CREATE DATABASE bengkel OWNER bengkel"
```
(`bengkel@%` from a php container works because the client address is the socat/docker address, not localhost.)

## Legacy PHP vs MySQL 8.4
PHP 5.6 / 7.2 clients cannot use `caching_sha2_password`. `mysql84/conf/base.cnf` therefore enables `mysql_native_password=ON`
(disabled by default in 8.4). Create app users with `IDENTIFIED WITH mysql_native_password BY '...'`.
PHP 7.4+ can use the default plugin; remove the line if you only run those.

## Memory profiles
`*_CNF=low-memory|production` picks `conf/<name>.cnf`; `*_MEM_LIMIT=2g` caps the container (`0` = unlimited).

## Backup / restore
```bash
bin/platform exec mysql56 db sh -c 'mysqldump -h127.0.0.1 -P33060 -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases' > backup.sql
bin/platform exec postgres db pg_dumpall -U postgres > backup.sql
```

## Adding another engine (Redis, MongoDB ...)
Copy `stacks/databases/postgres/`, change image / alias / ports / data dir / variable prefix, `bin/platform up <name>`.
Anything that needs "connect from localhost" semantics uses the mysql56 pattern; anything with its own auth uses the postgres pattern.
