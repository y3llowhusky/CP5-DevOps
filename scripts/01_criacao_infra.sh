#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config_geral.sh"

AZ_RETRY_ATTEMPTS="${AZ_RETRY_ATTEMPTS:-12}"
AZ_RETRY_WAIT_SECONDS="${AZ_RETRY_WAIT_SECONDS:-20}"

wait_for_resource() {
    local resource_type="$1"
    local resource_name="$2"
    shift 2
    local attempt=1
    while (( attempt <= AZ_RETRY_ATTEMPTS )); do
        if "$@" &>/dev/null; then
            echo "Recurso '$resource_name' disponível."
            return 0
        fi
        echo "Aguardando $resource_type '$resource_name' (${attempt}/${AZ_RETRY_ATTEMPTS})..."
        sleep "$AZ_RETRY_WAIT_SECONDS"
        ((attempt+=1))
    done
    echo "ERRO: timeout aguardando $resource_type '$resource_name'." >&2
    return 1
}

retry_az_create() {
    local description="$1"
    local sensitive="$2"
    shift 2
    local attempt=1 output
    while (( attempt <= AZ_RETRY_ATTEMPTS )); do
        if output=$("$@" 2>&1); then
            return 0
        fi
        echo "Tentativa ${attempt}/${AZ_RETRY_ATTEMPTS} para $description falhou." >&2
        if [[ "$sensitive" == 0 ]]; then
            echo "$output" >&2
        else
            echo "Detalhes da criação do servidor SQL ocultos para proteger as credenciais." >&2
        fi
        if grep -Eqi "exclusive lock|retry the request later|operation is in progress|temporarily unavailable|another operation is|throttl" <<< "$output"; then
            echo "Azure ocupada; aguardando para tentar novamente..."
            sleep "$AZ_RETRY_WAIT_SECONDS"
            ((attempt+=1))
            continue
        fi
        echo "ERRO: falha em $description. Verifique nomes, permissões, região e cotas." >&2
        return 1
    done
    echo "ERRO: excedeu o número de tentativas para $description." >&2
    return 1
}

echo "=========================================="
echo "ARGOS CP5 - CRIAÇÃO DA INFRAESTRUTURA AZURE"
echo "=========================================="

# ---------------------------------------------------------
# Verifica ferramentas e autenticação Azure
# ---------------------------------------------------------
command -v az &>/dev/null || { echo "ERRO: instale Azure CLI." >&2; exit 1; }
az account show &>/dev/null || { echo "ERRO: execute az login e selecione sua assinatura." >&2; exit 1; }

# A primeira chamada a 'az monitor app-insights' pode instalar uma extensão
# automaticamente. Faça isso aqui, com saída visível, antes de criar recursos.
if ! az extension show --name application-insights --query name --output tsv &>/dev/null; then
    echo "Instalando extensão Azure CLI 'application-insights'..."
    az extension add --name application-insights
fi

if [[ -z "$SQL_ADMIN_USER" ]]; then
    echo "ERRO: defina SQL_ADMIN_USER no .env ou no ambiente." >&2
    exit 1
fi
if [[ -z "${SQL_ADMIN_PASSWORD:-}" ]]; then
    [[ -t 0 ]] || { echo "ERRO: defina SQL_ADMIN_PASSWORD ou execute em terminal interativo." >&2; exit 1; }
    read -rsp "Senha do administrador Azure SQL: " SQL_ADMIN_PASSWORD
    echo
    [[ -n "$SQL_ADMIN_PASSWORD" ]] || { echo "ERRO: senha vazia." >&2; exit 1; }
fi

# ---------------------------------------------------------
# Providers utilizados pelo projeto
# ---------------------------------------------------------
echo "Registrando providers..."
for provider in Microsoft.Web Microsoft.Sql Microsoft.OperationalInsights Microsoft.Insights; do
    az provider register --namespace "$provider" --wait --output none
done

# ---------------------------------------------------------
# Resource Group
# ---------------------------------------------------------
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Criando Resource Group '$RESOURCE_GROUP'..."
    retry_az_create "criação do Resource Group" 0 az group create \
        --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    wait_for_resource "Resource Group" "$RESOURCE_GROUP" az group show --name "$RESOURCE_GROUP"
else
    echo "Resource Group '$RESOURCE_GROUP' já existe."
fi

# ---------------------------------------------------------
# App Service Plan + Web App
# ---------------------------------------------------------
if ! az appservice plan show --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Criando App Service Plan '$APP_SERVICE_PLAN'..."
    retry_az_create "criação do App Service Plan" 0 az appservice plan create \
        --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" --is-linux --sku "$APP_PLAN_SKU" --output none
    wait_for_resource "App Service Plan" "$APP_SERVICE_PLAN" az appservice plan show \
        --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP"
else
    echo "App Service Plan '$APP_SERVICE_PLAN' já existe."
fi

if ! az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Criando Web App '$WEBAPP_NAME'..."
    retry_az_create "criação do Web App" 0 az webapp create \
        --resource-group "$RESOURCE_GROUP" --plan "$APP_SERVICE_PLAN" \
        --name "$WEBAPP_NAME" --runtime "$APP_RUNTIME" --output none
    wait_for_resource "Web App" "$WEBAPP_NAME" az webapp show \
        --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP"
else
    echo "Web App '$WEBAPP_NAME' já existe."
fi

# ---------------------------------------------------------
# Azure SQL Server + Azure SQL Database
# ---------------------------------------------------------
if ! az sql server show --resource-group "$RESOURCE_GROUP" --name "$SQL_SERVER_NAME" &>/dev/null; then
    echo "Criando servidor Azure SQL '$SQL_SERVER_NAME'..."
    set +x
    retry_az_create "criação do servidor Azure SQL" 1 az sql server create \
        --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
        --name "$SQL_SERVER_NAME" --admin-user "$SQL_ADMIN_USER" \
        --admin-password "$SQL_ADMIN_PASSWORD" --output none
    wait_for_resource "servidor Azure SQL" "$SQL_SERVER_NAME" az sql server show \
        --resource-group "$RESOURCE_GROUP" --name "$SQL_SERVER_NAME"
else
    echo "Servidor Azure SQL '$SQL_SERVER_NAME' já existe."
fi

if ! az sql db show --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" --name "$SQL_DB_NAME" &>/dev/null; then
    echo "Criando banco '$SQL_DB_NAME'..."
    retry_az_create "criação do banco Azure SQL" 0 az sql db create \
        --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" \
        --name "$SQL_DB_NAME" --service-objective "$SQL_DB_SKU" --output none
    wait_for_resource "banco Azure SQL" "$SQL_DB_NAME" az sql db show \
        --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" --name "$SQL_DB_NAME"
else
    echo "Banco '$SQL_DB_NAME' já existe."
fi

if ! az sql server firewall-rule show --resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER_NAME" --name AllowAzureServices &>/dev/null; then
    echo "Configurando regra de firewall para serviços Azure..."
    retry_az_create "regra AllowAzureServices" 0 az sql server firewall-rule create \
        --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" \
        --name AllowAzureServices --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0 --output none
    wait_for_resource "regra SQL" AllowAzureServices az sql server firewall-rule show \
        --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" --name AllowAzureServices
else
    echo "Regra AllowAzureServices já existe."
fi

# ---------------------------------------------------------
# Log Analytics Workspace + Application Insights
# ---------------------------------------------------------
if ! az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" &>/dev/null; then
    echo "Criando Log Analytics Workspace '$WORKSPACE_NAME'..."
    retry_az_create "criação do Log Analytics Workspace" 0 az monitor log-analytics workspace create \
        --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" \
        --location "$LOCATION" --output none
    wait_for_resource "Log Analytics Workspace" "$WORKSPACE_NAME" az monitor log-analytics workspace show \
        --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME"
else
    echo "Log Analytics Workspace '$WORKSPACE_NAME' já existe."
fi

echo "Verificando Application Insights '$INSIGHTS_NAME'..."
if ! az monitor app-insights component show --resource-group "$RESOURCE_GROUP" \
    --app "$INSIGHTS_NAME" &>/dev/null; then
    echo "Criando Application Insights '$INSIGHTS_NAME'..."
    retry_az_create "criação do Application Insights" 0 az monitor app-insights component create \
        --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
        --app "$INSIGHTS_NAME" --application-type web --kind web \
        --workspace "$WORKSPACE_NAME" --output none
    wait_for_resource "Application Insights" "$INSIGHTS_NAME" az monitor app-insights component show \
        --resource-group "$RESOURCE_GROUP" --app "$INSIGHTS_NAME"
else
    echo "Application Insights '$INSIGHTS_NAME' já existe."
fi

unset SQL_ADMIN_PASSWORD
echo
echo "=========================================="
echo "INFRAESTRUTURA BASE CRIADA COM SUCESSO"
echo "=========================================="
az resource list --resource-group "$RESOURCE_GROUP" --output table
echo "Execute scripts/ddl.sql no Azure SQL e depois scripts/02_build_deploy.sh."
