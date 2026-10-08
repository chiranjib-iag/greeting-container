# Greeting Container

A small Flask web application, containerised into a production-quality image and
published to the GitHub Container Registry. This repository is my solution to
the DevOps containerisation task: the provided `Dockerfile` has been refactored
to follow container best practices, and the image is built and published
automatically by a GitHub Actions workflow.

The application code under `app/` is unchanged from the original.

## Submission details

-   **Repository:** <https://github.com/chiranjib-iag/greeting-container>
-   **Container image (public):** `ghcr.io/chiranjib-iag/sample-app:v1`
-   **Registry:** GitHub Container Registry (`ghcr.io`)

Pull the image without credentials:

```bash
docker pull ghcr.io/chiranjib-iag/sample-app:v1
```

## The application

The app is a minimal Flask service served by `gunicorn`:

-   Listens on the port given by the `PORT` environment variable (default `8080`).
-   Reads a `GREETING` environment variable used in its response.
-   Exposes `GET /`, `GET /healthz`, and `GET /info`.

```text
Dockerfile            # production-quality multi-stage build
.dockerignore         # trims the build context
app/
  app.py              # Flask application (unmodified)
  requirements.txt    # pinned dependencies (unmodified)
.github/workflows/
  docker-publish.yml  # CI that builds, verifies, and publishes the image
```

## Dockerfile design

The `Dockerfile` uses a multi-stage build that follows container best practices:

-   **Multi-stage build** — a `builder` stage installs the Python dependencies
    into an isolated virtual environment (`/opt/venv`), and a separate `runtime`
    stage copies only that environment plus the application code. Build tooling
    never ships in the final image.
-   **Slim base image** — `python:3.12-slim-bookworm` keeps the image small and
    reduces the attack surface compared with the full Python image.
-   **No unnecessary packages** — the image installs no compilers or editors; the
    application's wheels install without a build toolchain.
-   **Layer caching** — `requirements.txt` is copied and installed before the
    application code, so editing the app does not invalidate the dependency layer.
-   **Non-root runtime** — the container runs as a dedicated unprivileged
    `appuser`, not root.
-   **Pinned dependencies** — reproducible installs via the versions pinned in
    `app/requirements.txt`.
-   **Health check** — a `HEALTHCHECK` probes the app's `/healthz` endpoint using
    the Python standard library (no extra runtime dependency).
-   **`.dockerignore`** — keeps the build context small by excluding `.git`,
    documentation, and local caches.

The container start command is unchanged and still serves the app with
`gunicorn`.

## How the image is published

The image is built and pushed automatically by a GitHub Actions workflow at
`.github/workflows/docker-publish.yml`. On every push to `main`, on `v*` tags,
and on manual dispatch, the workflow:

1.  Builds the image from the `Dockerfile`.
2.  Runs the container and verifies it answers on `/healthz` and runs as the
    non-root `appuser`.
3.  Pushes the image to GHCR tagged `v1` (plus a short-SHA tag).

Publishing uses the built-in `GITHUB_TOKEN`, so no personal access token is
required. After the first successful publish, the package visibility was set to
**public** so the image can be pulled without credentials.

## Running the image locally

The commands below are for local development and verification; the published
image itself is produced by CI (above), not from a local machine.

Run the published image and exercise the endpoints:

```bash
docker run --rm -p 8080:8080 ghcr.io/chiranjib-iag/sample-app:v1

curl http://localhost:8080/healthz   # {"status":"ok"}
curl http://localhost:8080/
curl http://localhost:8080/info
```

Override configuration via environment variables:

```bash
docker run --rm -p 9000:9000 -e PORT=9000 -e GREETING="Hi there" \
    ghcr.io/chiranjib-iag/sample-app:v1
```

Build the image yourself from source (use a real version tag, not `:latest`):

```bash
docker build -t ghcr.io/chiranjib-iag/sample-app:v1 .
```

## Publishing manually (alternative to CI)

Publishing is normally handled by the CI workflow, but the image can also be
pushed by hand. Log in once with a GitHub Personal Access Token that has the
`write:packages` scope, then build and push:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u chiranjib-iag --password-stdin

docker build -t ghcr.io/chiranjib-iag/sample-app:v1 .
docker push ghcr.io/chiranjib-iag/sample-app:v1
```

Then set the package visibility to public: **GitHub → your profile → Packages →
`sample-app` → Package settings → Change visibility → Public**.
