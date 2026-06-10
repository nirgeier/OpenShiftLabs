#!/usr/bin/env bash
# 019-Pipelines — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="019-Pipelines"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Verifying oc and tkn CLI availability"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present"
  else
    warn "oc not found"
  fi
  if command -v tkn >/dev/null 2>&1; then
    info "tkn: present ($(tkn version --component client 2>/dev/null || echo 'unknown'))"
  else
    warn "tkn not found; install with 'brew install tektoncd-cli'"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
