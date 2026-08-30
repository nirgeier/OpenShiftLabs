#!/usr/bin/env bash
# 004-Docker Lifecycle — CI-friendly demo script (placeholder)
set -euo pipefail
IFS=$'\n\t'

MODULE="004-Docker Lifecycle"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf '[%s] %s\n' "$MODULE" "$*"; }
warn(){ printf '[%s] WARN: %s\n' "$MODULE" "$*" >&2; }

ci_checks(){
  info "Check for container tooling (docker/podman) presence"
  if command -v podman >/dev/null 2>&1; then
    info "podman: present"
  elif command -v docker >/dev/null 2>&1; then
    info "docker: present"
  else
    warn "Neither podman nor docker found; container-related demos will be skipped"
  fi
}

case "${1:-}" in
  demo) ci_checks ;;
  *) printf 'Usage: %s demo\n' "$0" ; exit 1 ;;
esac

