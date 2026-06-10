#!/usr/bin/env bash
# 020-Troubleshooting — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="020-Troubleshooting"
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

  info "Checking cluster connectivity for troubleshooting exercises"
  oc whoami 2>/dev/null && info "Cluster: connected" || warn "Cluster: not connected"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
