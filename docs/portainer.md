# Portainer *and* the command line on the same stacks

The goal: manage stacks in Portainer (start/stop, logs, container console, stats, even edit) **and** still run
`docker compose` yourself, without the two fighting. Four conventions make that work; they are already built in.

1. **Absolute paths** (`${APP_ROOT:-/app}/...`). Portainer runs compose from inside its own container, so relative paths such as
   `./nginx.conf` would resolve to a directory on the host that does not exist. `/app` is identical on the host and in the file.
2. **Project name = stack name.** Compose files carry `name:` and `platform` never passes a different `-p`. In Portainer, name the stack exactly like the
   folder (`bengkel`, `mysql56` ...). Same name => same project => the same containers, whichever tool touched them last.
3. **Portainer's data is a host bind mount** (`/app/data/portainer`), so the compose files Portainer stores for its own stacks are visible
   on the host and can be used from a shell.
4. **Variables, not edited files.** All environment differences are `.env` variables; Portainer's "Environment variables -> Load variables from .env file"
   takes the same `.env` the CLI uses.

## Day-to-day workflows

### A. Files are the source of truth (default; recommended for core + databases)
```bash
bin/platform up bengkel            # = docker compose --env-file ... -f stacks/apps/bengkel/compose.yml up -d
bin/platform logs bengkel web
bin/platform dc bengkel ps
```
Portainer shows the containers and you can use logs, stats, restart and the **Console** (exec) on them. Portainer lists stacks that were
not created in it as externally created: you control the containers, but you edit the file in the repo, not in the UI.

### B. Portainer owns the stack (edit in the UI, still usable from the CLI)
1. Portainer -> Stacks -> Add stack -> *Web editor*, name = folder name, paste `compose.yml`, *Load variables from .env file* -> `.env`, Deploy.
   Or let the wrapper do it through the API (experimental, check the result in the UI):
   `PORTAINER_TOKEN` in `.env` (Portainer: *My account -> Access tokens*), then `bin/platform portainer-import bengkel`.
2. Portainer saves the stack on the host: `ls /app/data/portainer/compose/` (one numbered folder per stack, containing the compose file and its env file).
3. CLI on a Portainer-owned stack:
   ```bash
   cd /app/data/portainer/compose/<id>
   docker compose -p bengkel --env-file stack.env -f docker-compose.yml ps    # file names: use what `ls` shows
   docker compose -p bengkel --env-file stack.env -f docker-compose.yml exec php composer install
   ```
   Day-to-day `docker exec`/`docker logs`/`docker compose -p bengkel exec ...` work from anywhere because the containers carry the project labels.

Pick one owner per stack. If you edit a stack in Portainer, copy the change back into the repo file (or keep that stack in workflow A), otherwise the repo and Portainer drift apart.

## Things to know
* Networks `edge` and `data` are `external`. They are created by `bin/platform init`; if you only use Portainer, create them under *Networks* first.
* Portainer-only users also need the host folders from `platform init` (`/app/data/...`, `/app/certs`) and the PHP images (`bin/platform build`).
* Portainer's stack environment is the *only* place variables come from in that tool; the global `.env` that `platform` adds (`TZ`, ...) is not read, so every stack `.env` repeats `APP_ROOT` and the needed values.
* Mounting `/var/run/docker.sock` makes Portainer root-equivalent on the host. It is only reachable through Traefik (TLS) and `127.0.0.1:9443`. Create the admin account right after the first start (Portainer locks itself after a few minutes; `bin/platform restart portainer` reopens the window).
* The first deployment of the Portainer stack itself is always from the CLI (`bin/platform up portainer`), obviously.
