#!/bin/bash
# Delegate to the shared init_site.sh vendored as the .mkdocs-shared git
# submodule. The shared location comes from this project's .env
# (MKDOCS_SHARED_DIR); the project folder is passed as the build target.
set -euo pipefail
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
MKDOCS_SHARED_DIR=".mkdocs-shared"
if [[ -f "$PROJ/.env" ]]; then set -a; . "$PROJ/.env"; set +a; fi
exec "$PROJ/${MKDOCS_SHARED_DIR}/init_site.sh" "$PROJ" "$@"
