#!/bin/bash

set -e

: "${CONTAINER_MODE:=app}"
: "${CONTAINER_PORT:=8000}"
: "${CONTAINER_WORKER_DELAY:=10}"
: "${CONTAINER_WORKER_SLEEP:=5}"
: "${CONTAINER_WORKER_TIMEOUT:=300}"
: "${CONTAINER_WORKER_TRIES:=3}"

: "${TEST_DB_CONNECTION:=true}"
: "${TEST_CACHE_CONNECTION:=true}"
: "${TEST_CONNECTION_TIMEOUT:=20}"

: "${APP_ENV:=production}"
: "${APP_DEBUG:=false}"

ARTISAN="php -d variables_order=EGPCS /laravel/artisan"

_test_connection() {
  local count=0
  local type="${1}"

  while [ "$count" -lt "$TEST_CONNECTION_TIMEOUT" ]; do
    php -f "/common/test_${type}_connection.php" > /dev/null 2>&1
    status=$?

    if [ "$status" -eq 0 ]; then
      echo "✅ ${type^} connection successful."
      return 0
    fi

    echo "⏱ Waiting on $type connection, retrying... $((TEST_CONNECTION_TIMEOUT - count)) seconds left"
    count=$((count + 1))
    sleep 1
  done

  echo "⛔ ${type^} connection failed after multiple attempts."
  exit 1
}

_test_connections() {
  if [ "$TEST_DB_CONNECTION" != "true" ]; then
    echo "⏭ Skipping database connection test..."
  else
    _test_connection "db"
  fi

  if [ "$TEST_CACHE_CONNECTION" != "true" ]; then
    echo "⏭ Skipping cache connection test..."
  else
    _test_connection "cache"
  fi
}

_migrate() {
  echo "🚀 Running migrations..."
  ${ARTISAN} migrate --force --isolated
}

_setup() {
  if [ -n "$CONTAINER_MANUAL_SETUP" ]; then
    echo "⏭: Skipping setup..."
    return
  fi

  _test_connections
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
  case "$CONTAINER_MODE" in
    app)
      echo "🚀 Running octane..."
      exec ${ARTISAN} octane:frankenphp --host=0.0.0.0 --port="$CONTAINER_PORT"
      ;;
    worker)
      echo "⏳ Running the queue..."
      exec ${ARTISAN} queue:work -vv \
        --no-interaction \
        --tries="$CONTAINER_WORKER_TRIES" \
        --sleep="$CONTAINER_WORKER_SLEEP" \
        --timeout="$CONTAINER_WORKER_TIMEOUT" \
        --delay="$CONTAINER_WORKER_DELAY"
      ;;
    horizon)
      echo "Running horizon..."
      exec ${ARTISAN} horizon
      ;;
    scheduler)
      echo "📆 Running scheduled tasks..."
      exec ${ARTISAN} schedule:work --verbose --no-interaction
      ;;
    *)
      echo "⛔ Could not match the container mode [$CONTAINER_MODE]"
      exit 1
      ;;
  esac
}

_setup
_run
