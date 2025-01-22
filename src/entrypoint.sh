#!/bin/bash

set -euo pipefail
trap 'echo "Error on line $LINENO"' ERR

: "${CONTAINER_PORT:=8000}"
: "${CONTAINER_MANUAL_SETUP:=}"
: "${CONTAINER_MODE:=app}"
: "${CONTAINER_WORKER_DELAY:=10}"
: "${CONTAINER_WORKER_SLEEP:=5}"
: "${CONTAINER_WORKER_TIMEOUT:=300}"
: "${CONTAINER_WORKER_TRIES:=3}"
: "${TEST_CONNECTION_TIMEOUT:=10}"

: "${APP_ENV:=production}"
: "${APP_DEBUG:=false}"

ARTISAN="php -d variables_order=EGPCS /laravel/artisan"

_test_connection() {
  local count=0
  local type="${1}"
  local status

  echo "🧪 Testing ${type} connection..."

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
  declare -A connections=(
    [database]="${TEST_DB_CONNECTION:-true}"
    [cache]="${TEST_CACHE_CONNECTION:-true}"
    [s3]="${TEST_S3_CONNECTION:-false}"
    [smtp]="${TEST_SMTP_CONNECTION:-false}"
  )

  for service in "${!connections[@]}"; do
    if [ "${connections[$service]}" != "true" ]; then
      echo "⏭ Skipping $service connection test..."
    else
      _test_connection "$service"
    fi
  done
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
    echo "🗂️ Linking the storage..."
    ${ARTISAN} storage:link
  fi

  echo "⚙️ Creating config cache..."
  ${ARTISAN} config:cache

  echo "🃏 Creating event cache..."
  ${ARTISAN} event:cache

  echo "🚏 Creating route cache..."
  ${ARTISAN} route:cache

  echo "🖼️ Creating view cache..."
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
      echo "🌤️ Running horizon..."
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
