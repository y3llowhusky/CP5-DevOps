#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # Arquivo local de confiança do operador; nunca copie um .env de terceiros.
    source "$ROOT_DIR/.env"
    set +a
fi
for var in RESOURCE_GROUP LOCATION PLAN_NAME WEBAPP_NAME SQL_SERVER_NAME SQL_DB_NAME WORKSPACE_NAME INSIGHTS_NAME SQL_ADMIN_USER; do
    if [[ -z "${!var:-}" ]]; then echo "Configure $var em .env ou exporte no ambiente." >&2; exit 1; fi
done
if [[ "${REQUIRE_SQL_PASSWORD:-1}" == 1 && -z "${SQL_ADMIN_PASSWORD:-}" ]]; then
    if [[ ! -t 0 ]]; then echo "Defina SQL_ADMIN_PASSWORD em ambiente seguro ou execute em terminal interativo." >&2; exit 1; fi
    read -rsp 'Senha SQL (não será exibida): ' SQL_ADMIN_PASSWORD
    echo
    export SQL_ADMIN_PASSWORD
fi
