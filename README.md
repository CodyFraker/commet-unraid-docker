# Self-hosted Commet web client for Unraid and Docker

Docker image that serves the **official** [Commet](https://github.com/commetchat/commet) Matrix **web client** from upstream release artifacts. The full Flutter app (JavaScript, WASM, E2EE) runs in your browser; this container only hosts static files—it does **not** proxy traffic to commet.chat.

This project is **not** affiliated with commetchat. It is **not** [CometChat](https://www.cometchat.com/) (a different product). Commet is licensed under **AGPL-3.0**; see [commetchat/commet](https://github.com/commetchat/commet) for source and releases.

## What you get

- Matrix **client** only—you sign in to **external** homeservers (for example matrix.org or your own Synapse elsewhere).
- **Subdomain at `/`** hosting (for example `https://commet.example.com/`). Subpath installs (for example `/commet/`) are not supported with the upstream web build.
- Release tarballs are **PGP-verified** at image build time using the key published in the [Commet README](https://github.com/commetchat/commet).

## Session and encryption data

Web logins and E2EE keys are stored in **your browser** (IndexedDB / localStorage), not in Docker volumes. Updating or recreating the container does not log you out. Clearing site data for this host does.

No config volume is required for normal use.

## Quick start (Docker Compose)

Replace `GITHUB_OWNER` with your GitHub username or org in **lowercase** (GHCR image names must be lowercase; for example `codyfraker`).

```bash
export GITHUB_OWNER=codyfraker
export COMMET_VERSION=v0.5.1   # optional; default in compose build args
export HOST_PORT=8080

docker compose up -d --build
```

Open `http://localhost:8080/`.

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
4. Map **Web Port** (default host `8080` → container `80`).
5. Apply and open the **WebUI** link.

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

GitHub Actions checks [commetchat/commet releases](https://github.com/commetchat/commet/releases) daily and on manual dispatch. When a new release tag appears, CI builds, verifies, and pushes:

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

Workflow inputs:

- **commet_version** — optional; build a specific upstream tag (for example `v0.5.1`). Defaults to the latest upstream release.
- **force_rebuild** — reserved for future use; **Run workflow** always builds and pushes. Scheduled runs skip when [`VERSION`](VERSION) already matches the latest upstream tag.

## PGP verification

Builds download `commet-web.tar.gz` and `.asc` from the upstream release and verify with the commet.chat signing key shipped as [`commet-signing-key.asc`](commet-signing-key.asc) (from the [Commet README](https://github.com/commetchat/commet)). Primary key fingerprint: `0AF0 C676 4319 21C2 B6F0 7787 01BE AC37 68B4 1195`. If upstream rotates the key, update that file and rebuild.

## Attribution

- **Commet** — Copyright commetchat / contributors, [AGPL-3.0](https://github.com/commetchat/commet/blob/main/LICENSE).
- **This repository** — packaging (Dockerfile, nginx, CI, Unraid template) only; Commet binaries are unmodified upstream release artifacts.

## License

This packaging repository is under [AGPL-3.0](LICENSE). Commet itself remains under AGPL-3.0 from its authors.
