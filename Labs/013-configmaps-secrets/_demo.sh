#!/usr/bin/env bash
# 013-ConfigMaps & Secrets — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="013-ConfigMaps-Secrets"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Verifying oc CLI availability"
  if command -v oc >/dev/null 2>&1; then
    info "oc: present ($(oc version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' || echo 'unknown'))"
  else
    warn "oc not found; skipping"
    return
  fi

  info "Creating test ConfigMap and Secret"
  oc create configmap demo-config --from-literal=KEY=value --dry-run=client -o yaml
  oc create secret generic demo-secret --from-literal=PASS=demo --dry-run=client -o yaml
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
