#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_config_geral.sh"
command -v az >/dev/null || { echo 'Instale Azure CLI.' >&2; exit 1; }
az account show >/dev/null || { echo 'Execute az login.' >&2; exit 1; }
for provider in Microsoft.Web Microsoft.Sql Microsoft.OperationalInsights Microsoft.Insights; do
    az provider register --namespace "$provider" --wait --output none
done
retry() {
    local count=0
    until "$@"; do
        count=$((count + 1))
        if (( count >= 5 )); then echo 'Falha ao criar recurso; revise quota, região e nomes.' >&2; return 1; fi
        sleep 20
    done
}
az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1 || retry az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none
az appservice plan show -g "$RESOURCE_GROUP" -n "$PLAN_NAME" >/dev/null 2>&1 || retry az appservice plan create -g "$RESOURCE_GROUP" -n "$PLAN_NAME" -l "$LOCATION" --is-linux --sku B1 -o none
az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null 2>&1 || retry az webapp create -g "$RESOURCE_GROUP" -p "$PLAN_NAME" -n "$WEBAPP_NAME" --runtime 'DOTNETCORE|10.0' -o none
az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" >/dev/null 2>&1 || retry az sql server create -g "$RESOURCE_GROUP" -l "$LOCATION" -n "$SQL_SERVER_NAME" -u "$SQL_ADMIN_USER" -p "$SQL_ADMIN_PASSWORD" -o none
# Para assinaturas elegíveis, pode-se ajustar este comando para --use-free-limit.
az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DB_NAME" >/dev/null 2>&1 || retry az sql db create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DB_NAME" --service-objective Basic -o none
az sql server firewall-rule show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n AllowAzureServices >/dev/null 2>&1 || az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE_NAME" >/dev/null 2>&1 || retry az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$WORKSPACE_NAME" -l "$LOCATION" -o none
workspace_id="$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE_NAME" --query id -o tsv)"
az monitor app-insights component show -g "$RESOURCE_GROUP" -a "$INSIGHTS_NAME" >/dev/null 2>&1 || retry az monitor app-insights component create -g "$RESOURCE_GROUP" -l "$LOCATION" -a "$INSIGHTS_NAME" --application-type web --kind web --workspace "$workspace_id" -o none
echo 'Recursos criados. Execute o DDL e depois 02_build_deploy.sh.'
