#!/usr/bin/env bash
set -euo pipefail

RG="${RG:-arm-c2c-rg}"
SUB="${SUB:-95dd4846-e6a6-4dbf-9046-560f7c53714e}"

az account set --subscription "$SUB"
az group delete --name "$RG" --yes --no-wait
echo "Deletion of $RG initiated."
