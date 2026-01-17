# syntax=docker/dockerfile:1

FROM python:3.13-slim

ARG BUILD_ENV=dev

# Global env vars (safe defaults)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/home/appuser/venv \
    PATH="/home/appuser/venv/bin:$PATH" \
    BUILD_ENV=$BUILD_ENV

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /usr/sbin/nologin appuser

COPY certificates/ /usr/local/share/ca-certificates/

RUN if ["$BUILD_ENV" == "production"] ; then \
        echo "production env" ; \
    else echo "non production env: $BUILD_ENV"; \
        update-ca-certificates; \
    fi

# Switch early to non-root
USER appuser
WORKDIR /home/appuser/app

# Create virtual environment as appuser
RUN python -m venv "$VIRTUAL_ENV"

# Copy dependency list
COPY --chown=appuser:appuser requirements.txt .

# Install deps WITHOUT root
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser src/main.py .

# Run app
CMD ["python", "main.py"]