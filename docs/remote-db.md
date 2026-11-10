# Databases that are not in this Docker host

Two situations, both end with MySQL seeing the client as `127.0.0.1` so `root` (localhost-only) works.

| | Where MySQL runs | Where the client runs | Use |
|---|---|---|---|
| **A** | **Windows 10 itself** (installer / XAMPP / Laragon) | **PHP apps in Docker inside WSL2** | [below](#a-mysql-on-the-windows-10-host-apps-in-docker-inside-wsl2) |
| **B** | a VPS (`stacks/databases/*`) | dev PC (Docker or native Windows tools) | [further down](#b-databases-on-a-vps-from-your-dev-pc) |

## A. MySQL on the Windows 10 host, apps in Docker inside WSL2

### Why it needs a bridge
On Windows 10, WSL2 runs in NAT mode: `127.0.0.1` inside WSL/containers is *not* Windows' `127.0.0.1`
(the "mirrored" mode that merges them needs Windows 11 22H2+). WSL can only reach Windows through the IP of the
`vEthernet (WSL)` adapter, and MySQL then sees the client as `172.x.x.x`, not localhost. So the connection is re-made on the Windows side:

```
PHP container ──> windows-mysql:3309 (docker host gateway)
   └─> [stack "remote" / service windows, host network of WSL]  detects the Windows IP at every start
         └─> <Windows WSL-IP>:13306
               └─> netsh portproxy (windows\6-wsl-mysql-bridge-start.bat) opens its own connection ──> 127.0.0.1:3306
                                                                                     MySQL sees 127.0.0.1  => root works
```

### Setup (once)
1. **Windows, double-click `windows\6-wsl-mysql-bridge-start.bat`** (UAC). Makes a portproxy `<WSL IP>:13306 -> 127.0.0.1:3306`
   and a firewall rule that only admits the WSL network. MySQL itself needs no change (no `bind-address`, no new users).
   The WSL IP changes after a reboot or `wsl --shutdown`: run it again, or double-click `8-wsl-mysql-bridge-autostart.bat` once
   to re-create the bridge at every logon (it also wakes WSL). `8b-...-status.bat` shows what is in place; `7-...-stop.bat` removes it.
   Different MySQL port? `powershell -File windows\wsl-mysql-bridge.ps1 -MysqlPort 3307`.
2. **WSL:**
   ```bash
   bin/platform init dev                    # creates stacks/databases/remote/.env (COMPOSE_PROFILES=windows)
   bin/platform up remote                   # builds local/db-forwarder once, then starts remote-windows
   bin/platform logs remote                 # "Windows host detected: 172.x.x.1"
   ```
3. **App** (`htdocs/<app>/.env`): `DB_HOST=windows-mysql`, `DB_PORT=3309`, `DB_USERNAME=root`, your Windows MySQL password.

Docker engine must be installed **inside WSL** (as in this project). With Docker Desktop use `host.docker.internal` instead of this stack.

### Code with `127.0.0.1:3306` hard-coded (legacy PHP)
Enable the in-app proxy: in `stacks/apps/<app>/.env` add
```env
COMPOSE_PROFILES=localdb
DB_UPSTREAM_HOST=windows-mysql
DB_UPSTREAM_PORT=3309
```
then `bin/platform up <app>`. Inside that app's containers `127.0.0.1:3306` now reaches Windows MySQL (the sidecar shares php's network namespace).
Use `127.0.0.1` / `DB_HOST=127.0.0.1` (TCP). A host of `localhost` makes PHP use a unix socket, which does not exist.

### Other ways (`WINDOWS_MODE` / `WINDOWS_PORT` in the remote `.env`)
| Method | Settings | MySQL sees | Needs |
|---|---|---|---|
| **Bridge** (default) | `direct`, `WINDOWS_PORT=13306` | `127.0.0.1` | `6-wsl-mysql-bridge-start.bat` |
| **SSH tunnel** | `ssh`, `WINDOWS_PORT=3306`, `WINDOWS_SSH_USER`, key in `data/ssh/` | `127.0.0.1` (sshd connects locally) | Windows *OpenSSH Server* feature: `Start-Service sshd; Set-Service sshd -StartupType Automatic`; put the public key in `%USERPROFILE%\.ssh\authorized_keys` (administrators: `C:\ProgramData\ssh\administrators_authorized_keys`); allow port 22 from the WSL network only |
| **Plain direct** | `direct`, `WINDOWS_PORT=3306` | the WSL IP | MySQL listening beyond loopback **and** an account allowed from that IP (not `root@localhost`), plus a firewall rule |

### Troubleshooting (A)
| Symptom | Check |
|---|---|
| `Host '172.x.x.x' is not allowed to connect` | not going through the bridge: `WINDOWS_PORT` must be `13306`; bridge started? (`8b-...status.bat`) |
| connection timeout from the container | bridge missing after a reboot (new WSL IP) - run `6-...start.bat`; Windows firewall rule `platform WSL MySQL bridge` present? |
| `remote-windows` log: "cannot detect the Windows host IP" | WSL has no default route; set `WINDOWS_HOST=<ip>` |
| `Access denied for user 'root'@'localhost'` | the bridge works; password/auth plugin issue on the Windows MySQL |
| port 3309 busy | `WINDOWS_LOCAL_PORT`, and the app's `DB_PORT` / `DB_UPSTREAM_PORT` |
| Windows 11 22H2+ | alternative: `.wslconfig` `[wsl2] networkingMode=mirrored` makes WSL's `127.0.0.1` equal Windows', no bridge needed for `network_mode: host` containers |

## B. Databases on a VPS from your dev PC

### Why it is root@127.0.0.1 in both transports
The VPS databases (`stacks/databases/*`) already sit behind a socat proxy that owns the network namespace, and mysqld listens on `127.0.0.1` only.
Whatever reaches the proxy - an SSH tunnel ending on the VPS loopback, or a direct TCP connection to the published port - is re-connected by socat
from inside that namespace. So the server-side rule is the same for both:

| Transport | VPS setting (`stacks/databases/mysql56/.env`) | Security |
|---|---|---|
| **SSH tunnel** (recommended) | `MYSQL56_BIND=127.0.0.1` (default); nothing exposed | encrypted, key auth |
| **Direct** | `MYSQL56_BIND=0.0.0.0` + firewall allow-list ([databases.md](databases.md)) | plaintext on the wire, root exposed to whoever the firewall admits |

(Postgres has no localhost trick: it always asks for a password, in both transports.)
Depending on name resolution the server shows the account as `root@localhost` (mysql56) or `root@127.0.0.1` (mariadb has `skip-name-resolve`).
If a root login is refused on mariadb, create the missing account once: `CREATE USER 'root'@'127.0.0.1' IDENTIFIED BY '...'; GRANT ALL ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;`.

### One-time: SSH key (tunnel mode)
On the dev PC, in the repo root (PowerShell or WSL):
```powershell
ssh-keygen -t ed25519 -N "" -f data\ssh\id_ed25519          # dedicated key; data\ is git-ignored
type data\ssh\id_ed25519.pub | ssh ubuntu@vps.example.com "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```
Optional hardening on the VPS: prefix that line in `~/.ssh/authorized_keys` with
`restrict,port-forwarding,permitopen="127.0.0.1:3306",permitopen="127.0.0.1:3307" ` so the key can only open those database ports (no shell).
The key has no passphrase because the tunnel runs unattended; keep it dedicated and out of git.

### Configure once
`bin/platform init dev` creates `stacks/databases/remote/.env` from `.env.dev.example`. Set `COMPOSE_PROFILES` (e.g. `mysql56`, without `windows`) and edit:

| Variable | Meaning |
|---|---|
| `COMPOSE_PROFILES` | engines to forward: `mysql56,mysql84,mariadb,postgres` |
| `REMOTE_MODE` | `ssh` or `direct` |
| `REMOTE_HOST` | VPS name or IP |
| `REMOTE_SSH_USER`, `REMOTE_SSH_PORT`, `REMOTE_SSH_KEY` | tunnel login; key file inside `data/ssh/` |
| `REMOTE_SSH_TARGET_HOST` | DB address as seen from the VPS (`127.0.0.1` unless the VPS binds the DB elsewhere) |
| `REMOTE_<ENGINE>_PORT` | port the DB publishes on the VPS (3306 / 3307 / 3308 / 5432) |
| `REMOTE_<ENGINE>_LOCAL_PORT` | port on this PC (same defaults) |
| `REMOTE_<ENGINE>_ALIAS` | Docker name of the forwarder (default `remote-<engine>`) |

### B1 - Docker forwarder (apps in containers *and* Windows tools)
```bash
bin/platform up remote          # builds local/db-forwarder once, starts the engines in COMPOSE_PROFILES
bin/platform logs remote
```
* **Windows tools / host:** `127.0.0.1:3306`, user `root` (WSL forwards the published loopback port to Windows).
* **App containers:** `DB_HOST=remote-mysql56` (port 3306; postgres 5432).
* **Zero-change switch:** set `REMOTE_MYSQL56_ALIAS=mysql56`, then `bin/platform down mysql56 && bin/platform up remote`. Apps keep `DB_HOST=mysql56`
  but now talk to the VPS. Switch back: `bin/platform down remote && bin/platform up mysql56`. Never run the local stack and the forwarder of the same engine together (same alias, same port).
* The container reconnects by itself if the tunnel drops.

### B2 - native Windows 10 tunnel, no Docker (dev tools, `php.exe`, XAMPP/Laragon apps)
Same `.env`. Double-click:

| File | Does |
|---|---|
| `windows\4-remote-db-start.bat` | tunnel in a console window (close it / Ctrl+C to stop) |
| `windows\4b-remote-db-start-hidden.bat` | same, hidden in the background |
| `windows\5-remote-db-stop.bat` | stop it |
| `powershell -File windows\remote-db.ps1 -Action status` | shows which local ports answer |

`ssh` mode uses Windows' built-in `ssh.exe` (Settings > Apps > Optional features > **OpenSSH Client**), binds `127.0.0.1` only, auto-reconnects, and
copies the key to `%USERPROFILE%\.ssh\platform-remote-db` with a locked-down ACL (ssh.exe rejects keys others can read).
`direct` mode sets `netsh interface portproxy` rules `127.0.0.1:<port> -> REMOTE_HOST:<port>` (Administrator prompt; rules persist until you stop them; unencrypted).

Connect HeidiSQL/DBeaver/Navicat or `mysql -h 127.0.0.1 -P 3306 -u root -p`; Laravel on Windows: `DB_HOST=127.0.0.1`.

**B1 or B2, not both** on the same local port; to run both give one different `REMOTE_*_LOCAL_PORT` values. Docker apps should use B1 (a Windows loopback tunnel is not visible to WSL2 in NAT mode).

### Troubleshooting
| Symptom | Check |
|---|---|
| `bin/platform logs remote`: "private key ... not found" | file must be `data/ssh/<REMOTE_SSH_KEY>` |
| `Permission denied (publickey)` | public key in `~/.ssh/authorized_keys` of `REMOTE_SSH_USER`; right user/port |
| tunnel up, `Lost connection` / refused | DB stack running on the VPS? `REMOTE_*_PORT`/`REMOTE_SSH_TARGET_HOST` match its published port/bind |
| `Host '...' is not allowed to connect` | you are not going through the VPS socat proxy (e.g. pointing at a different MySQL) |
| port already in use | local MySQL/XAMPP on 3306 -> change `REMOTE_*_LOCAL_PORT` |
| host key changed warning | VPS reinstalled: remove its line from `%USERPROFILE%\.ssh\known_hosts` / `docker volume rm remote-db_ssh-state` |
