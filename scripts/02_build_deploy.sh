#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config_geral.sh"

echo "=========================================="
echo "ARGOS CP5 - BUILD E DEPLOY NO APP SERVICE"
echo "=========================================="

# ---------------------------------------------------------
# Ferramentas, autenticação e credenciais
# ---------------------------------------------------------
for command_name in az dotnet curl; do
    command -v "$command_name" &>/dev/null || { echo "ERRO: instale $command_name." >&2; exit 1; }
done

if ! command -v zip &>/dev/null && ! command -v powershell.exe &>/dev/null; then
    echo 'ERRO: é necessário zip (Linux/WSL) ou powershell.exe (Git Bash no Windows).' >&2
    exit 1
fi

if [[ "${SKIP_DDL:-0}" != 1 ]]; then
    command -v sqlcmd &>/dev/null || {
        echo 'ERRO: instale sqlcmd para aplicar o DDL automaticamente ou use SKIP_DDL=1 após executá-lo manualmente.' >&2
        exit 1
    }
fi

az account show &>/dev/null || { echo "ERRO: execute az login." >&2; exit 1; }
[[ -n "$SQL_ADMIN_USER" ]] || { echo "ERRO: defina SQL_ADMIN_USER no .env ou no ambiente." >&2; exit 1; }

if [[ -z "${SQL_ADMIN_PASSWORD:-}" ]]; then
    [[ -t 0 ]] || { echo "ERRO: defina SQL_ADMIN_PASSWORD ou execute em terminal interativo." >&2; exit 1; }
    read -rsp 'Senha do administrador Azure SQL: ' SQL_ADMIN_PASSWORD
    echo
    [[ -n "$SQL_ADMIN_PASSWORD" ]] || { echo 'ERRO: senha vazia.' >&2; exit 1; }
fi

# ---------------------------------------------------------
# Libera apenas o IP atual e aplica o DDL no Azure SQL
# ---------------------------------------------------------
if [[ "${SKIP_DDL:-0}" == 1 ]]; then
    echo 'DDL manual indicado por SKIP_DDL=1; seguindo para build e deploy.'
else

echo "Verificando acesso local ao Azure SQL..."

if [[ -n "${SQL_CLIENT_IP:-}" ]]; then
    client_ip="$SQL_CLIENT_IP"
else
    client_ip="$(curl -4fsS --max-time 15 https://api.ipify.org)" || {
        echo 'ERRO: não foi possível detectar o IP público. Defina SQL_CLIENT_IP no .env.' >&2
        exit 1
    }
fi

if [[ ! "$client_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo 'ERRO: IP público inválido. Defina SQL_CLIENT_IP no .env.' >&2
    exit 1
fi

IFS=. read -r ip1 ip2 ip3 ip4 <<< "$client_ip"

for octet in "$ip1" "$ip2" "$ip3" "$ip4"; do
    if (( 10#$octet > 255 )); then
        echo 'ERRO: IP público inválido. Defina SQL_CLIENT_IP no .env.' >&2
        exit 1
    fi
done

firewall_rule="ArgosDeploy${client_ip//./_}"

if ! az sql server firewall-rule show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" \
    -n "$firewall_rule" &>/dev/null; then

    echo "Liberando o IP $client_ip no firewall do Azure SQL..."

    az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" \
        -n "$firewall_rule" --start-ip-address "$client_ip" \
        --end-ip-address "$client_ip" -o none
fi

ddl_path="$SCRIPT_DIR/ddl.sql"

# sqlcmd.exe no Git Bash precisa receber o arquivo em formato de caminho Windows.
if [[ -n "${MSYSTEM:-}" ]] && command -v cygpath &>/dev/null; then
    ddl_path="$(cygpath -w "$ddl_path")"
fi

echo "Aplicando scripts/ddl.sql no banco Azure SQL '$SQL_DB_NAME'..."

ddl_ok=0

for attempt in 1 2 3 4 5 6; do
    if MSYS2_ENV_CONV_EXCL=SQLCMDPASSWORD SQLCMDPASSWORD="$SQL_ADMIN_PASSWORD" \
        sqlcmd -S "${SQL_SERVER_NAME}.database.windows.net" -d "$SQL_DB_NAME" \
            -U "$SQL_ADMIN_USER" -b -l 15 -i "$ddl_path"; then
        ddl_ok=1
        break
    fi
    if (( attempt < 6 )); then
        echo "Conexão/DDL falhou (tentativa $attempt/6); aguardando propagação do firewall..." >&2
        sleep 10
    fi
done

[[ "$ddl_ok" == 1 ]] || { echo 'ERRO: DDL não aplicado; verifique senha, firewall e saída do sqlcmd.' >&2; exit 1; }
echo 'DDL aplicado com sucesso (tabelas ZONAS_RISCO e ALERTAS).'
fi

# ---------------------------------------------------------
# Publicação .NET e pacote ZIP
# ---------------------------------------------------------
mkdir -p "$ROOT_DIR/.publish"

rm -rf "$ROOT_DIR/.publish/app" "$ROOT_DIR/.publish/argos.zip"

dotnet publish "$ROOT_DIR/src/Argos.Api/Argos.Api.csproj" -c Release -o "$ROOT_DIR/.publish/app"

echo 'Compactando a publicação...'

if command -v zip &>/dev/null; then
    (cd "$ROOT_DIR/.publish/app" && zip -qr ../argos.zip .)
else
    command -v cygpath &>/dev/null || { echo 'ERRO: cygpath não encontrado no Git Bash.' >&2; exit 1; }
    ARGOS_PUBLISH_DIR="$(cygpath -w "$ROOT_DIR/.publish/app")" \
    ARGOS_ZIP_PATH="$(cygpath -w "$ROOT_DIR/.publish/argos.zip")" \
    MSYS2_ENV_CONV_EXCL='ARGOS_PUBLISH_DIR;ARGOS_ZIP_PATH' \
        powershell.exe -NoProfile -NonInteractive -Command \
        '$ErrorActionPreference = "Stop";
         Add-Type -AssemblyName System.IO.Compression;
         Add-Type -AssemblyName System.IO.Compression.FileSystem;
         $root = [System.IO.Path]::GetFullPath($env:ARGOS_PUBLISH_DIR);
         if (-not $root.EndsWith([string][System.IO.Path]::DirectorySeparatorChar)) { $root += [System.IO.Path]::DirectorySeparatorChar }
         $archive = [System.IO.Compression.ZipFile]::Open($env:ARGOS_ZIP_PATH, [System.IO.Compression.ZipArchiveMode]::Create);

         try {
             foreach ($file in [System.IO.Directory]::EnumerateFiles($root, "*", [System.IO.SearchOption]::AllDirectories)) {
                 $entry = $file.Substring($root.Length).Replace([char]92, [char]47);
                 [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null;
             }
         } finally { $archive.Dispose() }
         $check = [System.IO.Compression.ZipFile]::OpenRead($env:ARGOS_ZIP_PATH);

         try {
             if ($null -eq $check.GetEntry("Argos.Api.dll") -or $null -eq $check.GetEntry("wwwroot/index.html")) {
                 throw "ZIP inválido: arquivos da aplicação ausentes na raiz esperada."
             }
             foreach ($item in $check.Entries) {
                 if ($item.FullName.IndexOf([char]92) -ge 0) { throw "ZIP inválido: caminho com barra invertida: $($item.FullName)" }
             }
         } finally { $check.Dispose() }'
fi

[[ -s "$ROOT_DIR/.publish/argos.zip" ]] || { echo 'ERRO: ZIP de publicação não foi criado.' >&2; exit 1; }

# ---------------------------------------------------------
# Configuração do App Service e deploy
# ---------------------------------------------------------
insights_connection="$(az monitor app-insights component show -g "$RESOURCE_GROUP" -a "$INSIGHTS_NAME" --query connectionString -o tsv)"

[[ -n "$insights_connection" ]] || { echo 'Application Insights sem connection string.' >&2; exit 1; }

sql_connection="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DB_NAME};Persist Security Info=False;User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Impede que shell com set -x imprima credenciais ao configurar a aplicação.
set +x

az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings ASPNETCORE_ENVIRONMENT=Production "ConnectionStrings__ArgosSql=$sql_connection" "APPLICATIONINSIGHTS_CONNECTION_STRING=$insights_connection" -o none

unset sql_connection insights_connection

unset SQL_ADMIN_PASSWORD

if ! az webapp deploy -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
    --src-path "$ROOT_DIR/.publish/argos.zip" --type zip --clean true -o none; then
    echo 'ERRO: o App Service recusou o pacote. Logs da implantação mais recente:' >&2
    az webapp log deployment show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" -o jsonc >&2 || \
        echo 'Não foi possível consultar os logs via Azure CLI; abra o details_url da etapa que falhou no Kudu.' >&2
    echo 'Se os logs exibirem apenas "Running deployment command...", abra o details_url dessa linha no Kudu para ver a causa interna.' >&2
    exit 1
fi

# ---------------------------------------------------------
# Aguarda o endpoint de saúde
# ---------------------------------------------------------
url="https://$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)"

for i in {1..30}; do
    if [[ "$(curl -sSL -o /dev/null -w '%{http_code}' --max-time 10 "$url/health" || true)" == 200 ]]; then echo "Aplicação disponível: $url"; exit 0; fi
    sleep 10
done

echo "Deploy enviado, porém $url/health não respondeu HTTP 200. Veja os logs do App Service." >&2

exit 1
