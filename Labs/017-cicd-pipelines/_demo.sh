#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

MODULE="017-CICD-Pipelines"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "CI-friendly checks: CI/CD Pipelines"
  if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
    info "Checking BuildConfigs..."
    oc get bc --no-headers 2>/dev/null || info "No BuildConfigs found"
    info "CI/CD verification completed"
  else
    warn "oc: not available or not authenticated"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
