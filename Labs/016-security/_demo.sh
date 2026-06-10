#!/usr/bin/env bash
# 016-Security — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="016-Security"
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

  info "Checking SCC availability"
  oc get scc --no-headers 2>/dev/null | wc -l | xargs -I{} info "SCCs found: {}" || warn "Cannot list SCCs"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
