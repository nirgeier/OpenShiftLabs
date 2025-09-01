#!/usr/bin/env bash
# 012-Scaling — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="012-Scaling"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check for oc and HPA capabilities"
  if ! command -v oc >/dev/null 2>&1; then
    warn "oc: not found"
    return 0
  fi
  if ! oc whoami >/dev/null 2>&1; then
    warn "oc present but not logged in"
    return 0
  fi
  info "Checking metrics-server availability..."
  oc get apiservice v1beta1.metrics.k8s.io --no-headers || warn "metrics-server may not be available"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
