# Production (VPS)

```bash
sudo ln -s /home/ubuntu/app /app && cd /app
bin/platform init prod
```
Edit the generated `.env` files (they are git-ignored; only `*.example` are committed):

| File | Set |
|---|---|
| `stacks/core/traefik/.env` | `ACME_EMAIL`, `CERT_NAMES=<server ip>[,...]`, `TRAEFIK_IP_BIND=0.0.0.0` |
| `stacks/core/portainer/.env` | `PORTAINER_HOST_PROD`+`ACME_RESOLVER=le` and/or `PORTAINER_IP_HOST`+`PORTAINER_IP_EP=ip-8443` |
| `stacks/databases/*/.env` | root passwords (first start), `*_BIND` |
| `stacks/apps/<app>/.env` | see below |

```bash
bin/platform build php72
bin/platform up traefik portainer mysql56 bengkel
```
Open ports 80, 443 (domains) and 8443-8450 (IP mode) in the VPS firewall. Keep 3306/3307/3308/5432 closed unless you chose the firewall allow-list option in [databases.md](databases.md).

## The three app modes (`stacks/apps/<app>/.env`)

**Domain + Let's Encrypt**
```env
APP_HOST_PROD=bengkel.example.com
APP_HOST_PROD_ALT=www.bengkel.example.com   # optional
ACME_RESOLVER=le
```
DNS A record -> VPS IP, port 80 reachable (http-01). Certificates are stored in `data/traefik/letsencrypt/acme.json`.
While testing, set `ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory` in the Traefik `.env` to avoid rate limits (then delete `acme.json`).

**IP + custom port + self-signed**
```env
APP_IP_HOST=203.0.113.10
APP_IP_EP=ip-8444                           # -> https://203.0.113.10:8444
```
The certificate is the Traefik default (`certs/default.pem`, made for `CERT_NAMES`) signed by *your own* CA (mkcert). Browsers warn until
`certs/rootCA.crt` is trusted on the client, or you click through once. A public CA cannot issue certificates for a bare IP with Let's Encrypt's standard flow, so this is the right tool for IP access.

**Both:** set all of the above. The same container answers on `https://bengkel.example.com` and `https://203.0.113.10:8444`.
Remove a mode by deleting its lines; its router then sits on `disabled.invalid` and does nothing.

Pre-declared IP ports: `ip-8443` (Portainer by convention) ... `ip-8450`. `platform new-app` picks the next free one.

### Need more than 8 IP ports?
In `stacks/core/traefik/compose.yml` add two flags (`--entrypoints.ip-8451.address=:8451`, `--entrypoints.ip-8451.http.tls=true`) and widen the range in
`ports:` (`8443-8451:8443-8451`), then `bin/platform up traefik`.

### Changing the server IP / names
Edit `CERT_NAMES`, run `bin/platform certs` (regenerates and restarts Traefik). The CA stays the same, so clients that trust it keep working.

## Traefik dashboard
Published on `127.0.0.1:8080` only: `ssh -L 8080:127.0.0.1:8080 user@vps` then `http://localhost:8080`.

## Updating
```bash
bin/platform pull traefik portainer && bin/platform up traefik portainer
bin/platform build php72 && bin/platform up bengkel -- --force-recreate
```
