#!/usr/bin/env bash
# 021-MicroShift — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="021-MicroShift"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Verifying oc CLI availability"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present"
  else
    warn "oc not found; skipping"
    return
  fi

  info "Checking for MicroShift"
  if command -v microshift >/dev/null 2>&1; then
    info "microshift: present ($(microshift version 2>/dev/null || echo 'unknown'))"
  else
    warn "microshift not found; this lab requires a MicroShift installation"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
