# Self-hosted Commet web client for Unraid and Docker

Docker image that serves the **official** [Commet](https://github.com/commetchat/commet) Matrix **web client** from upstream release artifacts. The full Flutter app (JavaScript, WASM, E2EE) runs in your browser; this container only hosts static files—it does **not** proxy traffic to commet.chat.

This project is **not** affiliated with commetchat. It is **not** [CometChat](https://www.cometchat.com/) (a different product). Commet is licensed under **AGPL-3.0**; see [commetchat/commet](https://github.com/commetchat/commet) for source and releases.

## What you get

- Matrix **client** only—you sign in to **external** homeservers (for example matrix.org or your own Synapse elsewhere).
- **Subdomain at `/`** hosting (for example `https://commet.example.com/`). Subpath installs (for example `/commet/`) are not supported with the upstream web build.
- Release tarballs are **PGP-verified** at image build time using the key published in the [Commet README](https://github.com/commetchat/commet).

## Session and encryption data

Web logins and E2EE keys are stored in **your browser** (IndexedDB / localStorage), not in Docker volumes. Updating or recreating the container does not log you out. Clearing site data for this host does.

No app-data volume is required for login state. Optional: mount **`/etc/nginx/ssl`** to persist TLS certificates (see below).

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEFAULT_HOMESERVER` | (upstream `matrix.org` in bundle) | Hostname written to Commet `global_config.json` at start (for example `matrix.example.com`). Also accepts `default_homeserver`. |
| `TLS_SELF_SIGNED` | `false` | If `true`, generate a self-signed cert on first start when no cert/key files exist |
| `TLS_HOSTNAME` | `commet.local` | Certificate CN/SAN when generating self-signed (use the hostname or LAN IP you open in the browser) |
| `TLS_CERT_FILE` | `/etc/nginx/ssl/cert.pem` | TLS certificate path |
| `TLS_KEY_FILE` | `/etc/nginx/ssl/key.pem` | TLS private key path |
| `TLS_PUBLIC_PORT` | `443` | Port in HTTP→HTTPS redirects; set to your **host** HTTPS port (for example `8443` on Unraid) |
| `HTTPS_PORT` | `443` | Port nginx listens on **inside** the container (usually leave at `443`) |

## HTTPS and why it matters

Commet Web uses **WASM crypto (E2EE)** in the browser. Browsers only treat origins as [**secure contexts**](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts) on **HTTPS** or `http://localhost` — not on `http://192.168.x.x`. If the UI hangs on “Connecting to homeserver” with no failed requests, try **HTTPS** first.

### Option A — TLS in this container (Unraid template defaults)

1. Set **TLS_SELF_SIGNED** to `true` (template default) or mount your own `cert.pem` / `key.pem` under **`/etc/nginx/ssl`**.
2. Set **TLS_HOSTNAME** to the name or LAN IP you use in the browser (for example `192.168.1.17` or `commet.home.example`).
3. Map **Web UI SSL Port** (host `8443` → container `443`) and set **TLS_PUBLIC_PORT** to the same host port (`8443`).
4. Open **`https://<host>:8443/`** and accept the self-signed warning once (LAN only), or use a real cert from Let’s Encrypt copied into the ssl volume.

HTTP on port 8080 redirects to HTTPS when TLS is enabled.

### Option B — Reverse proxy TLS (NPM / Traefik / Swag)

Leave **TLS_SELF_SIGNED** `false` and terminate TLS on the proxy. Forward to the container HTTP port. The browser must still see **HTTPS** on the public URL.

## Quick start (Docker Compose)

Replace `GITHUB_OWNER` with your GitHub username or org in **lowercase** (GHCR image names must be lowercase; for example `codyfraker`).

```bash
export GITHUB_OWNER=codyfraker
export COMMET_VERSION=v0.5.1
export HOST_PORT=8080
export HOST_HTTPS_PORT=8443
export TLS_SELF_SIGNED=true
export TLS_HOSTNAME=192.168.1.17
export TLS_PUBLIC_PORT=8443
export DEFAULT_HOMESERVER=matrix.org

docker compose up -d --build
```

Open `https://localhost:8443/` (accept self-signed cert if prompted).

## Pull from GHCR

Images are published to:

```text
ghcr.io/<github-owner-lowercase>/commet-unraid:<tag>
ghcr.io/<github-owner-lowercase>/commet-unraid:latest
```

Example:

```bash
docker pull ghcr.io/codyfraker/commet-unraid:latest
docker run -d --name commet -p 8080:80 --restart unless-stopped \
  ghcr.io/codyfraker/commet-unraid:latest
```

### GHCR visibility

Packages are **private by default**. Either:

- Set the package **public** under GitHub → Packages → commet-unraid → Package settings, or
- Log in on Unraid with a GitHub PAT that has `read:packages`.

## Unraid

1. Copy or link the template from [`unraid/commet-unraid.xml`](unraid/commet-unraid.xml).
2. Use a **lowercase** GHCR path in `Repository` (for example `ghcr.io/codyfraker/commet-unraid`).
3. In the Unraid UI: **Docker** → **Add Container** → **Template URL** (raw GitHub URL to your fork’s XML) or paste XML via **User Templates**.
4. Map **Web UI SSL Port** and optional **Web Port**; set **TLS_PUBLIC_PORT** to match the SSL host port.
5. Set **DEFAULT_HOMESERVER** if you want a default other than `matrix.org`.
6. Apply and open the **WebUI** link (`https://…` when TLS is enabled).

Pin a specific tag in the template (for example `v0.5.1`) or use `latest` to track upstream releases built by CI.

## Reverse proxy (optional)

Terminate TLS on NPM, Traefik, Swag, or similar and forward to the container HTTP port. Use a **dedicated hostname** with path `/`.

Example nginx-style upstream (your proxy may differ):

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Matrix sync uses **WebSockets from the browser to your homeserver**, not through this container. No extra WebSocket rules are required on the Commet vhost for typical setups.

After upgrading the image, if the UI looks stale, hard-refresh or clear site data once (Flutter service worker).

## Updates

GitHub Actions builds and pushes on **push to `main`** (when packaging files change), **daily schedule**, and **manual dispatch**. When a new upstream Commet release tag appears on schedule, CI builds, verifies, and pushes:

- `ghcr.io/<owner>/commet-unraid:<tag>`
- `ghcr.io/<owner>/commet-unraid:latest`

On Unraid, pull the new image and recreate the container (or use a tool such as Watchtower if you choose).

The repo [`VERSION`](VERSION) file records the last packaged upstream tag.

## Build locally

```bash
docker build --build-arg COMMET_VERSION=v0.5.1 -t commet-unraid:local .
```

## First-time CI setup

1. Create a GitHub repository and push this project.
2. **Settings → Actions → General → Workflow permissions**: allow read and write, and allow GitHub Actions to create and approve pull requests if you use branch protection (optional).
3. Run **Build and publish** workflow manually (**Actions** → **Build and publish** → **Run workflow**).
4. Make the GHCR package public or configure registry auth on Unraid.
5. Set the lowercase GHCR image name in the Unraid template if your GitHub username differs.

Push triggers (paths): `Dockerfile`, `nginx/**`, `scripts/**`, `commet-signing-key.asc`, and `.github/workflows/build-and-publish.yml`. Commits that only bump [`VERSION`](VERSION) or the Unraid template do not retrigger a build.

Workflow inputs (manual run only):

- **commet_version** — optional; build a specific upstream tag (for example `v0.5.1`). Defaults to the latest upstream release.
- **force_rebuild** — reserved for future use; **Run workflow** always builds and pushes. Scheduled runs skip when [`VERSION`](VERSION) already matches the latest upstream tag.

## PGP verification

Builds download `commet-web.tar.gz` and `.asc` from the upstream release and verify with the commet.chat signing key shipped as [`commet-signing-key.asc`](commet-signing-key.asc) (from the [Commet README](https://github.com/commetchat/commet)). Primary key fingerprint: `0AF0 C676 4319 21C2 B6F0 7787 01BE AC37 68B4 1195`. If upstream rotates the key, update that file and rebuild.

## Attribution

- **Commet** — Copyright commetchat / contributors, [AGPL-3.0](https://github.com/commetchat/commet/blob/main/LICENSE).
- **This repository** — packaging (Dockerfile, nginx, CI, Unraid template) only; Commet binaries are unmodified upstream release artifacts.

## License

This packaging repository is under [AGPL-3.0](LICENSE). Commet itself remains under AGPL-3.0 from its authors.
