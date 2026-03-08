#!/bin/bash

set -euo pipefail

: "${KLOUDKIT_PORT:=8000}"
: "${KLOUDKIT_MANUAL_SETUP:=}"
: "${KLOUDKIT_MODE:=app}"
: "${KLOUDKIT_WORKER_DELAY:=10}"
: "${KLOUDKIT_WORKER_SLEEP:=5}"
: "${KLOUDKIT_WORKER_TIMEOUT:=300}"
: "${KLOUDKIT_WORKER_TRIES:=3}"
: "${KLOUDKIT_WORKER_MAX_JOBS:=1000}"
: "${KLOUDKIT_WORKER_MAX_TIME:=3600}"
: "${KLOUDKIT_WORKER_QUEUE:=default}"
: "${KLOUDKIT_WORKER_CONNECTION:=}"
: "${KLOUDKIT_TEST_TIMEOUT:=10}"
: "${KLOUDKIT_LOG_COLOR:=}"
: "${KLOUDKIT_SKIP_CONFIG_WARNINGS:=}"

: "${APP_ENV:=production}"
: "${APP_DEBUG:=false}"

_log_use_color() {
  if [ "${NO_COLOR+set}" = "set" ]; then
    return 1
  fi
  if [ "$KLOUDKIT_LOG_COLOR" = "true" ]; then
    return 0
  fi
  [ -t 1 ]
}

_log() {
  local level="$1" color="$2" fd="$3"
  shift 3
  if _log_use_color; then
    printf "\033[${color}m[kloudkit] [${level}]\033[0m %s\n" "$*" >&"$fd"
  else
    printf "[kloudkit] [${level}] %s\n" "$*" >&"$fd"
  fi
}

log_info()  { _log INFO  32 1 "$@"; }
log_warn()  { _log WARN  33 1 "$@"; }
log_error() { _log ERROR 31 1 "$@"; }

log_pipe() {
  local line
  "$@" 2>&1 | while IFS= read -r line; do
    log_info "    $line"
  done
  return "${PIPESTATUS[0]}"
}

trap 'log_error "Command failed: \"$BASH_COMMAND\" (exit code $?)"' ERR

ARTISAN=(php -d variables_order=EGPCS /laravel/artisan)

_banner() {
  log_info "============================================"
  log_info "Mode:  ${KLOUDKIT_MODE}"
  log_info "Env:   ${APP_ENV}"
  log_info "Debug: ${APP_DEBUG}"
  log_info "============================================"
}

_setup() {
  if [ -n "$KLOUDKIT_MANUAL_SETUP" ]; then
    log_info "Skipping setup..."
    return
  fi

  log_info "Running migrations..."
  log_pipe "${ARTISAN[@]}" migrate --force --isolated

  if [ -L "/laravel/public/storage" ]; then
    log_info "Storage already linked."
  else
    log_info "Linking the storage..."
    log_pipe "${ARTISAN[@]}" storage:link
  fi

  log_info "Optimizing application..."
  log_pipe /helpers/artisan-optimize
}

_check_config() {
  if [ -n "$KLOUDKIT_SKIP_CONFIG_WARNINGS" ]; then
    return
  fi

  local output
  output=$(php -f /checks/check_container_config.php 2>/dev/null) || true

  if [ -n "$output" ]; then
    while IFS= read -r line; do
      log_warn "$line"
    done <<< "$output"
  fi
}

_run() {
  case "$KLOUDKIT_MODE" in
    app)
      _setup
      log_info "Starting Octane on port ${KLOUDKIT_PORT}..."
      exec "${ARTISAN[@]}" octane:frankenphp --host=0.0.0.0 --port="$KLOUDKIT_PORT"
      ;;
    worker)
      log_info "Starting queue worker..."
      log_info "  Queue:      ${KLOUDKIT_WORKER_QUEUE}"
      log_info "  Connection: ${KLOUDKIT_WORKER_CONNECTION:-default}"
      log_info "  Tries:      ${KLOUDKIT_WORKER_TRIES}"
      log_info "  Timeout:    ${KLOUDKIT_WORKER_TIMEOUT}s"
      log_info "  Sleep:      ${KLOUDKIT_WORKER_SLEEP}s"
      log_info "  Delay:      ${KLOUDKIT_WORKER_DELAY}s"
      log_info "  Max jobs:   ${KLOUDKIT_WORKER_MAX_JOBS}"
      log_info "  Max time:   ${KLOUDKIT_WORKER_MAX_TIME}s"

      WORKER_CMD=("${ARTISAN[@]}" queue:work)
      if [ -n "$KLOUDKIT_WORKER_CONNECTION" ]; then
        WORKER_CMD+=("$KLOUDKIT_WORKER_CONNECTION")
      fi
      exec "${WORKER_CMD[@]}" -vv \
        --no-interaction \
        --tries="$KLOUDKIT_WORKER_TRIES" \
        --sleep="$KLOUDKIT_WORKER_SLEEP" \
        --timeout="$KLOUDKIT_WORKER_TIMEOUT" \
        --delay="$KLOUDKIT_WORKER_DELAY" \
        --max-jobs="$KLOUDKIT_WORKER_MAX_JOBS" \
        --max-time="$KLOUDKIT_WORKER_MAX_TIME" \
        --queue="$KLOUDKIT_WORKER_QUEUE"
      ;;
    horizon)
      log_info "Starting Horizon..."
      exec "${ARTISAN[@]}" horizon
      ;;
    scheduler)
      log_info "Starting scheduler..."
      exec "${ARTISAN[@]}" schedule:work --verbose --no-interaction
      ;;
    migrate)
      _setup
      log_info "Setup complete."
      ;;
    *)
      log_error "Could not match the container mode [$KLOUDKIT_MODE]"
      exit 1
      ;;
  esac
}

_banner
# shellcheck source=/dev/null
source /helpers/test-connections
_check_config
_run
