#!/bin/bash

# =========================================================
# CONFIGURAÇÕES GERAIS - ARGOS CP5 APP SERVICE + AZURE SQL
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
set +x  # Não imprima credenciais carregadas do .env nem passadas ao Azure CLI.

# Copie .env.example para .env. O arquivo .env não deve ser enviado ao Git.
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

: "${RM:?Defina RM no .env ou no ambiente (ex.: rm123456)}"
[[ "$RM" =~ ^rm[0-9]{6}$ ]] || { echo "ERRO: substitua RM por rm{SEU_RM} no .env." >&2; exit 1; }

LOCATION="${LOCATION:-southafricanorth}"

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-${RM}-argos-cp5}"

# Azure App Service (Linux)
APP_SERVICE_PLAN="${APP_SERVICE_PLAN:-${RM}-argos-plan}"
WEBAPP_NAME="${WEBAPP_NAME:-${RM}-argos-api}"
APP_RUNTIME="${APP_RUNTIME:-DOTNETCORE|10.0}"
APP_PLAN_SKU="${APP_PLAN_SKU:-B1}"

# Azure SQL Database; usuário e senha somente via .env/ambiente/prompt.
SQL_SERVER_NAME="${SQL_SERVER_NAME:-${RM}-argos-sql}"
SQL_DB_NAME="${SQL_DB_NAME:-Argos}"
SQL_DB_SKU="${SQL_DB_SKU:-Basic}"
SQL_ADMIN_USER="${SQL_ADMIN_USER:-}"

# Azure Monitor / Application Insights
WORKSPACE_NAME="${WORKSPACE_NAME:-${RM}-argos-logs}"
INSIGHTS_NAME="${INSIGHTS_NAME:-${RM}-argos-insights}"
