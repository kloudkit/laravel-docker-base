#!/bin/bash

set -e

: "${CONTAINER_MODE:=app}"
: "${CONTAINER_PORT:=8000}"
: "${CONTAINER_WORKER_DELAY:=10}"
: "${CONTAINER_WORKER_SLEEP:=5}"
: "${CONTAINER_WORKER_TIMEOUT:=300}"
: "${CONTAINER_WORKER_TRIES:=3}"
: "${CONTAINER_SCHEDULER_INTERVAL:=60}"
: "${APP_ENV:=production}"

ARTISAN="php -d variables_order=EGPCS /app/artisan"

_setup() {
  if [ -n "${CONTAINER_MANUAL_SETUP}" ]; then
    echo DEBUG: Skipping setup...

    return
  fi

  echo DEBUG: Preparing application...

  ${ARTISAN} storage:link || true

  ${ARTISAN} optimize  || true
  ${ARTISAN} config:cache || true
  ${ARTISAN} route:cache || true
  ${ARTISAN} view:cache || true
  ${ARTISAN} events:cache || true

  ${ARTISAN} migrate --force || true
}

_run() {
  case "${CONTAINER_MODE}" in
    app)
      echo INFO: Running octane...
      exec "${ARTISAN}" octane:frankenphp --host=0.0.0.0 --port="${CONTAINER_PORT}"
      ;;
    worker)
      echo INFO: Running the queue...
      exec "${ARTISAN}" queue:work -vv \
        --no-interaction \
        --tries="${CONTAINER_WORKER_TRIES}" \
        --sleep="${CONTAINER_WORKER_SLEEP}" \
        --timeout="${CONTAINER_WORKER_TIMEOUT}" \
        --delay="${CONTAINER_WORKER_DELAY}"
      ;;
    horizon)
      echo INFO: Running horizon...
      exec "${ARTISAN}" horizon
      ;;
    scheduler)
      while true; do
        echo "INFO: Running scheduled tasks."
        "${ARTISAN}" schedule:run --verbose --no-interaction &
        sleep "${CONTAINER_SCHEDULER_INTERVAL}s"
      done
      ;;
    *)
      echo "Could not match the container mode [${CONTAINER_MODE}]"
      exit 1
      ;;
  esac
}

_setup
_run
