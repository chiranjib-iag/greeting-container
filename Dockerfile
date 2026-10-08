# syntax=docker/dockerfile:1

############################
# Stage 1: builder
# Installs Python dependencies into an isolated virtual environment.
# Kept separate so build tools never end up in the final runtime image.
############################
FROM python:3.12-slim-bookworm AS builder

# Fail fast and keep Python from writing .pyc files / buffering stdout.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Create an isolated virtual environment we can copy wholesale to the runtime stage.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy only the dependency manifest first so this layer is cached and only
# re-runs when requirements.txt actually changes (not on every app code edit).
COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

############################
# Stage 2: runtime
# Minimal image containing only the venv and the application code.
############################
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8080

# Create a dedicated non-root user and group to run the app.
RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# Bring in the pre-built virtual environment from the builder stage.
COPY --from=builder /opt/venv /opt/venv

# Copy only the application package (not the whole repo context).
COPY --chown=appuser:appgroup app/ ./app/

# Drop root privileges.
USER appuser

EXPOSE 8080

# Container-level healthcheck hitting the app's own probe endpoint.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8080') + '/healthz').read()" || exit 1

# Start the app with gunicorn (unchanged default command).
# The app package lives at /app/app, so --chdir app + app:app resolves to app/app.py:app.
CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
