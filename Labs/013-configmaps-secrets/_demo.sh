#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

MODULE="013-ConfigMaps-Secrets"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "CI-friendly checks: ConfigMaps and Secrets"
  if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
    info "Creating ConfigMap..."
    oc create configmap test-config --from-literal=key=value --dry-run=client -o yaml | oc apply -f -
    info "Creating Secret..."
    oc create secret generic test-secret --from-literal=password=test123 --dry-run=client -o yaml | oc apply -f -
    info "ConfigMap and Secret created successfully"
    oc delete configmap test-config --ignore-not-found
    oc delete secret test-secret --ignore-not-found
  else
    warn "oc: not available or not authenticated"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac
