#!/usr/bin/env bash
# /usr/local/bin/log-functions.sh
# Shared logging library — sourced by init and svc scripts.
# Do NOT execute directly.
#
# Usage:
#   SVC_NAME="svc-mlathub"
#   . /usr/local/bin/log-functions.sh
#   log_info  "starting up"
#   log_warn  "something off"
#   log_error "connection refused"
#   log_fatal "cannot continue"

if [[ -z "${SVC_NAME:-}" ]]; then
    echo "FATAL: SVC_NAME must be set before sourcing log-functions.sh" >&2
    exit 1
fi

_log() {
    local priority="$1" fd="$2"; shift 2
    printf '%s %s[%s]: %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "${SVC_NAME}" "${priority}" "$*" >&"${fd}"
}

log_info()  { _log info  1 "$@"; }
log_warn()  { _log warn  2 "$@"; }
log_error() { _log error 2 "$@"; }
log_fatal() { _log fatal 2 "$@"; }
