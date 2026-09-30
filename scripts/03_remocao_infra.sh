#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config_geral.sh"

echo "=========================================="
echo "ARGOS CP5 - REMOÇÃO DA INFRAESTRUTURA"
echo "=========================================="
command -v az &>/dev/null || { echo 'ERRO: instale Azure CLI.' >&2; exit 1; }
az account show &>/dev/null || { echo 'ERRO: execute az login.' >&2; exit 1; }

# A exclusão do grupo remove também o banco de dados e seus registros.
read -rp "Digite o nome do grupo de recursos ($RESOURCE_GROUP) para confirmar a exclusão: " confirm
[[ "$confirm" == "$RESOURCE_GROUP" ]] || { echo 'Cancelado.'; exit 1; }
az group delete -n "$RESOURCE_GROUP" --yes --no-wait
az group wait -n "$RESOURCE_GROUP" --deleted
echo 'Grupo removido.'
