#!/usr/bin/env bash
# 017-Helm — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="017-Helm"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Verifying Helm CLI availability"
  if command -v helm >/dev/null 2>&1; then
    info "helm: present ($(helm version --short 2>/dev/null || echo 'unknown'))"
  else
    warn "helm not found; skipping"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
