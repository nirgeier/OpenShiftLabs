#!/usr/bin/env bash
# 005-Docker Pipeline — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="005-Docker Pipeline"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check for oc and pipeline tooling availability (jq optional)"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present"
  else
    warn "oc: missing"
  fi
  if command -v jq >/dev/null 2>&1; then
    info "jq: present"
  else
    warn "jq: missing (used for JSON parsing in demos)"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac

