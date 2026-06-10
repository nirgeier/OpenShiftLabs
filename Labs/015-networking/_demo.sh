#!/usr/bin/env bash
# 015-Networking — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="015-Networking"
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

  info "Checking Network Policies support"
  oc api-resources | grep -q networkpolicies && info "NetworkPolicies: supported" || warn "NetworkPolicies: not found"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
