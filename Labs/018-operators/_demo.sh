#!/usr/bin/env bash
# 018-Operators — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="018-Operators"
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

  info "Checking OLM (Operator Lifecycle Manager)"
  oc get csv -A --no-headers 2>/dev/null | wc -l | xargs -I{} info "Installed Operators (CSVs): {}" || warn "Cannot list CSVs"
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
