#!/usr/bin/env bash

set -Eeuo pipefail

log() {
  printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    log "Missing required file: ${path}"
    exit 1
  fi
}

run_with_retries() {
  local max_attempts="$1"
  local sleep_seconds="$2"
  shift 2

  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi

    if (( attempt >= max_attempts )); then
      log "Command failed after ${attempt} attempt(s): $*"
      return 1
    fi

    log "Command failed on attempt ${attempt}; retrying in ${sleep_seconds}s: $*"
    sleep "${sleep_seconds}"
    attempt=$((attempt + 1))
  done
}

checkpoint_done() {
  local checkpoint_file="$1"
  local step_name="$2"
  grep -Fxq "${step_name}" "${checkpoint_file}" 2>/dev/null
}

mark_checkpoint() {
  local checkpoint_file="$1"
  local step_name="$2"
  local temp_file

  mkdir -p "$(dirname "${checkpoint_file}")"
  temp_file="$(mktemp "$(dirname "${checkpoint_file}")/checkpoint.XXXXXX")"

  if [[ -f "${checkpoint_file}" ]]; then
    cat "${checkpoint_file}" > "${temp_file}"
  fi

  if ! grep -Fxq "${step_name}" "${temp_file}" 2>/dev/null; then
    printf '%s\n' "${step_name}" >> "${temp_file}"
  fi

  mv "${temp_file}" "${checkpoint_file}"
}
