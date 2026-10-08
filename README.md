# DevOps Interview Task (Part 1): Containerize

**This is a take-home task.** Please submit by the date given when the task was
issued.

## Submission details

-   **Repository:** <https://github.com/chiranjib-iag/greeting-container>
-   **Container image (public):** `ghcr.io/chiranjib-iag/sample-app:v1`
-   **Registry:** GitHub Container Registry (`ghcr.io`)

Pull the image without credentials:

```bash
docker pull ghcr.io/chiranjib-iag/sample-app:v1
```

## Overview

You are given a small web application (`app/`). A working `Dockerfile` is
provided, but it was written quickly and does **not** follow container best
practices. Your job is to refactor it into a production-quality image and push
it to a container registry.

You do **not** need to modify the application code.

## What we provide

Clone this repository into your local account.

> **Do Not** fork this repository. Clone it and re-push it into your local account.

The following is provided as part of this repository:

```text
Dockerfile            # a working but non-production Dockerfile — improve it
app/
  app.py              # a minimal Python Flask web app (do not modify)
  requirements.txt    # the app's dependencies (do not modify)
```

The application:

-   Listens on the port given by the `PORT` environment variable (default `8080`).
-   Reads a `GREETING` environment variable used in its response.
-   Exposes `GET /`, `GET /healthz`, and `GET /info`.

## Container image

The image is published to the GitHub Container Registry:

```text
ghcr.io/chiranjib-iag/sample-app:v1
```

### Dockerfile design

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

## Build and run locally

> **Note:** The published image is built and pushed by the GitHub Actions
> workflow (see [Continuous delivery](#continuous-delivery)), not from a local
> machine. The commands in this section and the next are provided for reference
> and local development.

Build the image and tag it for GHCR (use a real version tag, not `:latest`):

```bash
docker build -t ghcr.io/chiranjib-iag/sample-app:v1 .
```

Run the container and exercise the endpoints:

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

## Publishing manually

The image is normally published by CI (see below), but it can also be pushed by
hand. Log in once with a GitHub Personal Access Token that has the
`write:packages` scope, then push the tagged image:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u chiranjib-iag --password-stdin

docker build -t ghcr.io/chiranjib-iag/sample-app:v1 .
docker push ghcr.io/chiranjib-iag/sample-app:v1
```

After the first push, set the package visibility to public so it can be pulled
without credentials: **GitHub → your profile → Packages → `sample-app` →
Package settings → Change visibility → Public**.

## Continuous delivery

A GitHub Actions workflow at `.github/workflows/docker-publish.yml` builds the
image, verifies that the container answers on `/healthz` and runs as a non-root
user, and then pushes it to GHCR. It runs on every push to `main`, on `v*` tags,
and on manual dispatch. Publishing uses the built-in `GITHUB_TOKEN`, so no
personal access token is required.

## Pulling the published image

Once the package visibility is set to public, the image can be pulled without
credentials:

```bash
docker pull ghcr.io/chiranjib-iag/sample-app:v1
```
