#!/usr/bin/env bash
# 006-Hooks Setup — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="006-Hooks Setup"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check oc and list buildconfigs triggers if authenticated (skip otherwise)"
  if ! command -v oc >/dev/null 2>&1; then
    warn "oc: not found"
    return 0
  fi
  if ! oc whoami >/dev/null 2>&1; then
    warn "oc: not logged in"
    return 0
  fi
  oc get buildconfigs --no-headers -o custom-columns=NAME:.metadata.name,TRIGGERS:.spec.triggers || true
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac

