#!/usr/bin/env bash
# 002-New User — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="002-New User"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check for oc and ability to list roles (skip if missing or unauthenticated)"
  if ! command -v oc >/dev/null 2>&1; then
    warn "oc: not found"
    return 0
  fi
  if ! oc whoami >/dev/null 2>&1; then
    warn "oc: present but not logged in"
    return 0
  fi
  oc get clusterroles --no-headers -o custom-columns=NAME:.metadata.name || true
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac

