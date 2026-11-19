#!/usr/bin/env bash
# =============================================================================
# Refugio 360 - Provisionamento da infraestrutura na Azure (Azure CLI)
# Global Solution 2026/2 - DevOps Tools & Cloud Computing - GS The Last Dance
#
# Cria, nesta ordem:
#   1. Resource Group
#   2. Azure SQL Server (logical server) + regras de firewall
#   3. Azure SQL Database "refugio360" (PaaS)
#   4. App Service Plan Linux
#   5. Web App Linux Java 21 (onde a Release publica a API)
#
# O schema do banco NAO e criado aqui: a pipeline de Release executa
# scripts/script-bd.sql no Azure SQL antes de cada deploy.
# As credenciais sensiveis (senha do banco, JWT, gestor) tambem nao ficam no Web
# App por este script: a Release as aplica a partir de variaveis secretas.
#
# Uso (Azure Cloud Shell ou maquina com "az login"):
#   export SQL_ADMIN_PASSWORD='<senha forte>'    # nunca versionar
#   bash scripts/provisionar-azure.sh
# =============================================================================
set -euo pipefail

RM="${RM:-rm562917}"
# Regioes liberadas na assinatura Azure for Students: mexicocentral, chilecentral,
# eastus, southcentralus, northcentralus.
LOCATION="${LOCATION:-mexicocentral}"

RESOURCE_GROUP="rg-refugio360-${RM}"
SQL_SERVER="sql-refugio360-${RM}"
SQL_DATABASE="refugio360"
SQL_ADMIN_USER="${SQL_ADMIN_USER:-refugioadmin}"
SQL_ADMIN_PASSWORD="${SQL_ADMIN_PASSWORD:?Defina SQL_ADMIN_PASSWORD antes de rodar (export SQL_ADMIN_PASSWORD=...)}"
APP_SERVICE_PLAN="plan-refugio360-${RM}"
WEBAPP="refugio360-api-${RM}"
RUNTIME="JAVA:21-java21"

echo ">> 1/5 Resource Group: ${RESOURCE_GROUP} (${LOCATION})"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" \
  --query "{nome:name, regiao:location, estado:properties.provisioningState}" --output table

echo ">> 2/5 Azure SQL Server: ${SQL_SERVER}"
if ! az sql server show --resource-group "$RESOURCE_GROUP" --name "$SQL_SERVER" --output none 2>/dev/null; then
  az sql server create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SQL_SERVER" \
    --location "$LOCATION" \
    --admin-user "$SQL_ADMIN_USER" \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --minimal-tls-version 1.2 \
    --query "{nome:name, host:fullyQualifiedDomainName, estado:state}" --output table
fi

# 0.0.0.0 - 0.0.0.0 = "permitir servicos do Azure": o Web App e o agente da Release.
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER" \
  --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 \
  --query "{regra:name, de:startIpAddress, ate:endIpAddress}" --output table

# IP de quem roda o script: permite consultar o banco (SELECT) no video.
MEU_IP="$(curl -s https://api.ipify.org || true)"
if [[ -n "$MEU_IP" ]]; then
  az sql server firewall-rule create \
    --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER" \
    --name AllowOperador --start-ip-address "$MEU_IP" --end-ip-address "$MEU_IP" \
    --query "{regra:name, de:startIpAddress, ate:endIpAddress}" --output table
fi

echo ">> 3/5 Azure SQL Database: ${SQL_DATABASE} (Basic, 2 GB)"
az sql db create \
  --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER" --name "$SQL_DATABASE" \
  --edition Basic --capacity 5 --max-size 2GB --backup-storage-redundancy Local \
  --query "{banco:name, edicao:edition, estado:status}" --output table

echo ">> 4/5 App Service Plan (Linux B1): ${APP_SERVICE_PLAN}"
az appservice plan create \
  --resource-group "$RESOURCE_GROUP" --name "$APP_SERVICE_PLAN" --location "$LOCATION" \
  --sku B1 --is-linux \
  --query "{nome:name, sku:sku.name, estado:status}" --output table

echo ">> 5/5 Web App (Java 21): ${WEBAPP}"
az webapp create \
  --resource-group "$RESOURCE_GROUP" --plan "$APP_SERVICE_PLAN" --name "$WEBAPP" \
  --runtime "$RUNTIME" \
  --query "{nome:name, host:defaultHostName, estado:state}" --output table

# Configuracao NAO sensivel; os segredos sao aplicados pela pipeline de Release.
az webapp config set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP" \
  --always-on true --http20-enabled true --min-tls-version 1.2 --output none
az webapp update --resource-group "$RESOURCE_GROUP" --name "$WEBAPP" --https-only true --output none
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP" \
  --settings SPRING_PROFILES_ACTIVE=cloud SERVER_PORT=8080 WEBSITES_PORT=8080 --output none

DATABASE_URL="jdbc:sqlserver://${SQL_SERVER}.database.windows.net:1433;database=${SQL_DATABASE};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"

echo
echo "================================================================"
az resource list --resource-group "$RESOURCE_GROUP" \
  --query "[].{Nome:name, Tipo:type, Regiao:location}" --output table
echo
echo " API (apos a primeira Release): https://${WEBAPP}.azurewebsites.net/swagger-ui/index.html"
echo " Servidor SQL:                  ${SQL_SERVER}.database.windows.net"
echo
echo " Variaveis para o Variable Group 'refugio360-cloud' no Azure DevOps:"
echo "   DATABASE_URL      = ${DATABASE_URL}"
echo "   DATABASE_USERNAME = ${SQL_ADMIN_USER}        (secret)"
echo "   DATABASE_PASSWORD = a senha exportada acima  (secret)"
echo "================================================================"
