#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

MODULE="016-Templates"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "CI-friendly checks: Templates"
  if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
    info "Checking available templates..."
    oc get templates -n openshift --no-headers 2>/dev/null | head -5 || warn "No templates found"
    info "Template verification completed"
  else
    warn "oc: not available or not authenticated"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
