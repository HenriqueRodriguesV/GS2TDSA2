#!/usr/bin/env bash
# Remove TODOS os recursos criados por provisionar-azure.sh (apagando o Resource
# Group inteiro). Rodar somente depois da avaliacao da GS.
set -euo pipefail
RM="${RM:-rm562917}"
RESOURCE_GROUP="rg-refugio360-${RM}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Exclusao do Resource Group '${RESOURCE_GROUP}' disparada."
echo "Acompanhe com: az group exists --name ${RESOURCE_GROUP}"
