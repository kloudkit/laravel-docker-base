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

ARTISAN="php -d variables_order=EGPCS /laravel/artisan"

_migrate() {
  local count=0
  local timeout=20

  while [ $count -lt "${timeout}" ]; do
    php -f /common/test_db_connection.php > /dev/null 2>&1

    status=$?

    if [ $status -eq 0 ]; then
      echo "✅ Database connection successful."
      break
    fi

    echo "⏱ Waiting on database connection, retrying... $((timeout - count)) seconds left"
    count=$((count + 1))
    sleep 1
  done

  if [ $count -eq "${timeout}" ]; then
    echo "⛔ Database connection failed after multiple attempts."
    exit 1
  fi

  echo "🚀 Running migrations..."
  ${ARTISAN} migrate --force --isolated
}

_setup() {
  if [ -n "${CONTAINER_MANUAL_SETUP}" ]; then
    echo "⏭: Skipping setup..."

    return
  fi

  _migrate

  if [ -d "/laravel/app/public/storage" ]; then
    echo "✅ Storage already linked..."
  else
    echo "🔐 Linking the storage..."
    ${ARTISAN} storage:link
  fi

  ${ARTISAN} config:cache
  ${ARTISAN} events:cache
  ${ARTISAN} route:cache
  ${ARTISAN} view:cache
}

_run() {
  case "${CONTAINER_MODE}" in
    app)
      echo "🚀 Running octane..."
      exec "${ARTISAN}" octane:frankenphp --host=0.0.0.0 --port="${CONTAINER_PORT}"
      ;;
    worker)
      echo "⏳ Running the queue..."
      exec "${ARTISAN}" queue:work -vv \
        --no-interaction \
        --tries="${CONTAINER_WORKER_TRIES}" \
        --sleep="${CONTAINER_WORKER_SLEEP}" \
        --timeout="${CONTAINER_WORKER_TIMEOUT}" \
        --delay="${CONTAINER_WORKER_DELAY}"
      ;;
    horizon)
      echo "Running horizon..."
      exec "${ARTISAN}" horizon
      ;;
    scheduler)
      while true; do
        echo "📆 Running scheduled tasks."
        "${ARTISAN}" schedule:run --verbose --no-interaction &
        sleep "${CONTAINER_SCHEDULER_INTERVAL}s"
      done
      ;;
    *)
      echo "⛔ Could not match the container mode [${CONTAINER_MODE}]"
      exit 1
      ;;
  esac
}

_setup
_run
