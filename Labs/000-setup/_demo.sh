#!/usr/bin/env bash
# 000-Setup — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="000-Setup"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '[%s] %s\n' "$MODULE" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks() {
  info "CI-friendly checks: verify common CLIs and auth, skip if missing"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present"
    if oc whoami >/dev/null 2>&1; then
      info "oc: authenticated"
    else
      warn "oc: present but not authenticated (skipping cluster checks)"
    fi
  else
    warn "oc: not found in PATH"
  fi
  if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
    info "container tooling: present"
  else
    warn "container tooling: not found (docker/podman)"
  fi
}

case "${1:-}" in
demo) ci_checks ;;
*)
  printf 'Usage: %s demo\n' "$0"
  exit 1
  ;;
esac
