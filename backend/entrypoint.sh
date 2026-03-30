#!/bin/sh
set -e

WORKERS="${WEB_CONCURRENCY:-2}"

exec gunicorn app.main:app \
    -k uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8080 \
    --workers "${WORKERS}" \
    --timeout 120 \
    --graceful-timeout 30 \
    --keep-alive 5 \
    --access-logfile - \
    --error-logfile - \
    --capture-output
