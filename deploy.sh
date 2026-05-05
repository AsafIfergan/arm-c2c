#!/usr/bin/env bash
set -euo pipefail

RG="${RG:-arm-c2c-rg}"
LOCATION="${LOCATION:-eastus}"
SUB="${SUB:-95dd4846-e6a6-4dbf-9046-560f7c53714e}"

cd "$(dirname "$0")"

echo "[1/4] Setting subscription -> $SUB"
az account set --subscription "$SUB"

echo "[2/4] Ensuring resource group $RG in $LOCATION"
az group create \
  --name "$RG" \
  --location "$LOCATION" \
  --tags demo=cloud2code owner=asaf.ifergan iac_source=github.com/AsafIfergan/arm-c2c \
  --output none

UNIQUE_SUFFIX="$(echo -n "${RG}-$(az account show --query id -o tsv)" | shasum | head -c 8)"
COMMON_TAGS='{"demo":"cloud2code","owner":"asaf.ifergan","iac_source":"github.com/AsafIfergan/arm-c2c"}'
echo "    uniqueSuffix=$UNIQUE_SUFFIX"

echo "[3/4] Generating SQL admin password (not persisted)"
SQL_PW="$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)Aa1!"

echo "[4/4] Deploying modules"

deploy_module() {
  local name="$1"; shift
  local file="$1"; shift
  echo "  -> $name"
  az deployment group create \
    --resource-group "$RG" \
    --name "armc2c-$name" \
    --template-file "$file" \
    --parameters location="$LOCATION" commonTags="$COMMON_TAGS" "$@" \
    --output none
}

deploy_module storage  modules/storage.json  uniqueSuffix="$UNIQUE_SUFFIX"
deploy_module nsg      modules/nsg.json
deploy_module keyvault modules/keyvault.json uniqueSuffix="$UNIQUE_SUFFIX"
deploy_module sql      modules/sql.json      uniqueSuffix="$UNIQUE_SUFFIX" sqlAdminPassword="$SQL_PW"

echo
echo "Done. Resources in $RG:"
az resource list -g "$RG" -o table
