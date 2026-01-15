# syntax=docker/dockerfile:1

FROM python:3.12-slim

# Global env vars (safe defaults)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/home/appuser/venv \
    PATH="/home/appuser/venv/bin:$PATH"

# Create non-root user
RUN useradd --create-home --shell /usr/sbin/nologin appuser

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
COPY --chown=appuser:appuser app.py .

# Run app
CMD ["python", "app.py"]