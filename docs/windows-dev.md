# Windows dev PC (WSL Debian + Docker)

## 0. One-time WSL setup
```bash
sudo ln -s /mnt/d/app /app        # same paths as the VPS
cd /app && bin/platform init dev && bin/platform build && bin/platform up
```
Keep the repo's line endings LF (`.gitattributes` does this). CRLF in `*.cnf` or `*.sh` breaks them inside Linux containers.
Speed tips for `/mnt/d`: [faster-on-windows.md](faster-on-windows.md), [fast-copy.md](fast-copy.md).

## 1. Trust the certificate (once per Windows PC)
`bin/platform up traefik` creates `certs/mkcert/rootCA.pem` (and `certs/rootCA.crt`). Double-click **`windows\1-install-cert.bat`**
(UAC prompt). It imports the CA into *Local Machine -> Trusted Root*, skipping if already present.
Restart Chrome/Edge. Firefox: `about:config` -> `security.enterprise_roots.enabled = true`.
The certificate covers `mysite.test`, `*.mysite.test`, `localhost`, `127.0.0.1`. Change the names with `CERT_NAMES` in
`stacks/core/traefik/.env`, then `bin/platform certs --force`.
Another PC/phone: copy `certs/rootCA.crt` and trust it there (never share `rootCA-key.pem`).

## 2. Hostnames: pick ONE

### A. Wildcard DNS (recommended, zero maintenance)
```bash
bin/platform up dns                    # dnsmasq answering *.mysite.test -> 127.0.0.1
```
Windows: double-click **`windows\2-setup-dns.bat`**. It adds an NRPT rule (`.mysite.test` -> `127.0.0.1`) and tests a lookup.
From then on every new app works instantly, nothing to edit. Undo: `setup-dns.ps1 -Remove`.

Caveat: this needs UDP/53 on Windows' `127.0.0.1` to reach the container. Docker Desktop does that. With the Docker engine
*inside* WSL2 in the default NAT mode, UDP localhost forwarding may not work. The script tells you when the test lookup fails; then
either use WSL `networkingMode=mirrored` in `%UserProfile%\.wslconfig` or use option B.

### B. Hosts file (works everywhere)
Double-click **`windows\3-update-hosts.bat`**. It scans `stacks/**/.env` for `*_HOST_DEV=` and rewrites a single managed
block in `C:\Windows\System32\drivers\etc\hosts`. Re-run after `new-app`. (A hosts file cannot do wildcards, which is why A exists.)

## 3. Open
`https://portainer.mysite.test` (set `PORTAINER_HOST_DEV` in `stacks/core/portainer/.env`), `https://bengkel.mysite.test`.
Traefik dashboard: `http://localhost:8080`.

## Databases from Windows tools (HeidiSQL, DBeaver)
`127.0.0.1:3306` (mysql56), `:3307` (mysql84), `:3308` (mariadb), `:5432` (postgres), user `root` / `postgres`.

## Troubleshooting
| Symptom | Check |
|---|---|
| Browser shows "not secure" | Restart the browser; `certs/mkcert/rootCA.pem` must be the one installed (re-run script after `rm -r certs/*` since a new CA is made) |
| `NET::ERR_CERT_AUTHORITY_INVALID` after regenerating certs | You deleted `certs/mkcert`, creating a new CA. Run `1-install-cert.bat` again |
| 404 from Traefik | `bin/platform logs traefik`; is the app up and `APP_HOST_DEV` correct? `bin/platform config <app> \| grep rule` |
| `.test` name does not resolve | DNS option: `nslookup x.mysite.test 127.0.0.1`; hosts option: re-run `3-update-hosts.bat` |
| Port 80/443 already used | Stop IIS/World Wide Web Publishing, or Skype/other; `netstat -ano \| findstr :443` |
