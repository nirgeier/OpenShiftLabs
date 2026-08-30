#!/usr/bin/env bash
# 009-Services & Routes — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="009-Services & Routes"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check for oc and list services/routes when available"
  if ! command -v oc >/dev/null 2>&1; then
    warn "oc: not found"
    return 0
  fi
  if ! oc whoami >/dev/null 2>&1; then
    warn "oc present but not authenticated"
    return 0
  fi
  oc get svc --no-headers -o custom-columns=NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP || true
  oc get routes --no-headers -o custom-columns=NAME:.metadata.name,HOST:.spec.host || true
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac

