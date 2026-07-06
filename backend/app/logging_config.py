"""Structured JSON logging configuration with log rotation and request/response middleware."""

import logging
import os
import sys
import time
import uuid
from logging.handlers import RotatingFileHandler
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

# ─── Configuration ───────────────────────────────────────────────
LOG_DIR = os.getenv("LOG_DIR", "/var/log/astronova")
LOG_FILE = os.path.join(LOG_DIR, "app.log")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_MAX_BYTES = int(os.getenv("LOG_MAX_BYTES", 10 * 1024 * 1024))   # 10 MB per file
LOG_BACKUP_COUNT = int(os.getenv("LOG_BACKUP_COUNT", 5))            # Keep 5 rotated files


def setup_logging() -> logging.Logger:
    """Configure structured JSON logging with stdout + rotating file output.

    Log rotation policy (file handler):
      - Max file size: 10 MB (configurable via LOG_MAX_BYTES)
      - Rotated backups: 5 (configurable via LOG_BACKUP_COUNT)
      - Rotation produces: app.log, app.log.1, app.log.2, ..., app.log.5
      - Total max disk usage: ~60 MB

    Returns a logger instance that outputs JSON-formatted log entries.
    """
    logger = logging.getLogger("astronova")
    logger.setLevel(getattr(logging, LOG_LEVEL.upper(), logging.INFO))

    # Prevent duplicate handlers on reload
    if logger.handlers:
        return logger

    formatter = logging.Formatter(
        '{"timestamp": "%(asctime)s", "level": "%(levelname)s", '
        '"logger": "%(name)s", "message": "%(message)s"}',
        datefmt="%Y-%m-%dT%H:%M:%S%z",
    )

    # ── stdout handler (for kubectl logs / journalctl) ───────────
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setLevel(logging.INFO)
    stdout_handler.setFormatter(formatter)
    logger.addHandler(stdout_handler)

    # ── Rotating file handler ────────────────────────────────────
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        file_handler = RotatingFileHandler(
            LOG_FILE,
            maxBytes=LOG_MAX_BYTES,
            backupCount=LOG_BACKUP_COUNT,
            encoding="utf-8",
        )
        file_handler.setLevel(logging.INFO)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        logger.info(f"File logging enabled: {LOG_FILE} (max {LOG_MAX_BYTES // (1024*1024)}MB × {LOG_BACKUP_COUNT} backups)")
    except (PermissionError, OSError) as e:
        logger.warning(f"File logging disabled — could not create {LOG_DIR}: {e}")

    return logger


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware that logs every HTTP request and response with timing."""

    def __init__(self, app):
        super().__init__(app)
        self.logger = logging.getLogger("astronova.http")

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        request_id = str(uuid.uuid4())[:8]
        start_time = time.time()

        # Log incoming request
        self.logger.info(
            f"request_id={request_id} method={request.method} "
            f"path={request.url.path} client={request.client.host if request.client else 'unknown'}"
        )

        response = await call_next(request)

        # Calculate duration
        duration_ms = round((time.time() - start_time) * 1000, 2)

        # Log response
        self.logger.info(
            f"request_id={request_id} method={request.method} "
            f"path={request.url.path} status={response.status_code} "
            f"duration_ms={duration_ms}"
        )

        # Add request ID header for tracing
        response.headers["X-Request-ID"] = request_id
        return response
