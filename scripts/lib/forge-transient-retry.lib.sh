#!/usr/bin/env bash
# forge-transient-retry.lib.sh — Retry forge CLI/API calls on 5xx/timeouts.
#
# Usage:
#   forge_retry_transient cmd [args...]
#
# On success, prints the command's stdout. On failure, prints the command's
# combined output to stderr so callers (and workflow logs) can diagnose.
# Retries only when the output looks like a transient 5xx or timeout.
#
# Environment:
#   FORGE_TRANSIENT_RETRY_ATTEMPTS   — default 3
#   FORGE_TRANSIENT_RETRY_BASE_DELAY — default 2 (seconds; doubles each retry)

# shellcheck shell=bash

[[ -n "${FORGE_TRANSIENT_RETRY_SH_LOADED:-}" ]] && return 0
FORGE_TRANSIENT_RETRY_SH_LOADED=1

forge_is_transient_error() {
  local text="$1"
  local lower
  lower=$(printf '%s' "${text}" | tr '[:upper:]' '[:lower:]')

  if echo "${lower}" | grep -qE \
    'http[[:space:]]*5[0-9][0-9]|status([:]|[[:space:]]+code)[[:space:]]*5[0-9][0-9]|error:[[:space:]]*5[0-9][0-9]|\(http 5[0-9][0-9]\)'; then
    return 0
  fi
  if echo "${lower}" | grep -qE \
    'internal server error|service unavailable|bad gateway|gateway timeout'; then
    return 0
  fi
  if echo "${lower}" | grep -qE \
    'context deadline exceeded|connection reset|i/o timeout|operation timed out|timed out|timeout'; then
    return 0
  fi
  return 1
}

_forge_retry_notice() {
  local msg="$1"
  # Always stderr so success stdout (e.g. a PR URL) stays clean.
  if declare -F gha_echo >/dev/null 2>&1; then
    gha_echo warning "${msg}" >&2
  else
    echo "${msg}" >&2
  fi
}

# Run a command, retrying transient 5xx/timeout failures with exponential
# backoff (2s, 4s, 8s by default). Non-transient failures return immediately.
forge_retry_transient() {
  local max_attempts="${FORGE_TRANSIENT_RETRY_ATTEMPTS:-3}"
  local delay="${FORGE_TRANSIENT_RETRY_BASE_DELAY:-2}"
  local attempt=1
  local outfile errfile rc combined

  outfile=$(mktemp)
  errfile=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '${outfile}' '${errfile}'" RETURN

  while [ "${attempt}" -le "${max_attempts}" ]; do
    : >"${outfile}"
    : >"${errfile}"
    rc=0
    "$@" >"${outfile}" 2>"${errfile}" || rc=$?

    if [ "${rc}" -eq 0 ]; then
      cat "${outfile}"
      return 0
    fi

    combined=$(cat "${outfile}" "${errfile}")
    if [ "${attempt}" -lt "${max_attempts}" ] && forge_is_transient_error "${combined}"; then
      _forge_retry_notice \
        "Transient forge error (attempt ${attempt}/${max_attempts}); retrying in ${delay}s..."
      sleep "${delay}"
      delay=$((delay * 2))
      attempt=$((attempt + 1))
      continue
    fi

    printf '%s' "${combined}" >&2
    if [ -n "${combined}" ]; then
      printf '\n' >&2
    fi
    return "${rc}"
  done

  return 1
}
