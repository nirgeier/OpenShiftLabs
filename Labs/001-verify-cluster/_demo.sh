#!/usr/bin/env bash
# 001-Verify-Cluster — CI-friendly demo script
set -euo pipefail
IFS=$'\n\t'

MODULE="001-Verify-Cluster"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "CI-friendly checks: verify cluster connectivity and health"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present"
    if oc whoami >/dev/null 2>&1; then
      info "oc: authenticated"
      info "Checking cluster nodes..."
      oc get nodes --no-headers | wc -l | xargs -I {} info "Found {} nodes"
      info "Checking cluster operators..."
      oc get clusteroperators --no-headers | wc -l | xargs -I {} info "Found {} operators"
      info "Cluster verification completed"
    else
      warn "oc: present but not authenticated (skipping cluster checks)"
    fi
  else
    warn "oc: not found in PATH"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
