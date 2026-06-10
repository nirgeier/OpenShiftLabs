#!/usr/bin/env bash
# 014-Persistent Storage — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="014-Persistent-Storage"
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

  info "Checking StorageClasses"
  oc get storageclass --no-headers 2>/dev/null || warn "Cannot list StorageClasses"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
