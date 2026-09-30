#!/usr/bin/env bash
set -euo pipefail
REQUIRE_SQL_PASSWORD=0 source "$(dirname "${BASH_SOURCE[0]}")/00_config_geral.sh"
read -rp "Digite o nome do grupo de recursos ($RESOURCE_GROUP) para confirmar a exclusão: " confirm
[[ "$confirm" == "$RESOURCE_GROUP" ]] || { echo 'Cancelado.'; exit 1; }
az group delete -n "$RESOURCE_GROUP" --yes --no-wait
az group wait -n "$RESOURCE_GROUP" --deleted
echo 'Grupo removido.'
