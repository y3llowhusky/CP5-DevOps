#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_config_geral.sh"
for command_name in az dotnet zip curl; do command -v "$command_name" >/dev/null || { echo "Instale $command_name." >&2; exit 1; }; done
mkdir -p "$ROOT_DIR/.publish"
rm -rf "$ROOT_DIR/.publish/app" "$ROOT_DIR/.publish/argos.zip"
dotnet publish "$ROOT_DIR/src/Argos.Api/Argos.Api.csproj" -c Release -o "$ROOT_DIR/.publish/app"
(cd "$ROOT_DIR/.publish/app" && zip -qr ../argos.zip .)
insights_connection="$(az monitor app-insights component show -g "$RESOURCE_GROUP" -a "$INSIGHTS_NAME" --query connectionString -o tsv)"
[[ -n "$insights_connection" ]] || { echo 'Application Insights sem connection string.' >&2; exit 1; }
sql_connection="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DB_NAME};Persist Security Info=False;User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
# Impede que shell com set -x imprima credenciais ao configurar a aplicação.
set +x
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings ASPNETCORE_ENVIRONMENT=Production "ConnectionStrings__ArgosSql=$sql_connection" "APPLICATIONINSIGHTS_CONNECTION_STRING=$insights_connection" -o none
unset sql_connection insights_connection
az webapp deploy -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --src-path "$ROOT_DIR/.publish/argos.zip" --type zip --clean true -o none
url="https://$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)"
for i in {1..30}; do
    if [[ "$(curl -sSL -o /dev/null -w '%{http_code}' --max-time 10 "$url/health" || true)" == 200 ]]; then echo "Aplicação disponível: $url"; exit 0; fi
    sleep 10
done
echo "Deploy enviado, porém $url/health não respondeu HTTP 200. Veja os logs do App Service." >&2
exit 1
