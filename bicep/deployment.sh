#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RG="llm-platform-dev"
APPS_DIR="$SCRIPT_DIR/apps"
INFRA_DIR="$SCRIPT_DIR/infra"
BICEP_FILE="$APPS_DIR/main.bicep"
INFRA_BICEP="$INFRA_DIR/main.bicep"
PARAM_DEV="$APPS_DIR/dev.parameters.json"
PARAM_LOCAL="$APPS_DIR/parameters.local.json"

echo "==> Collecting resources to preserve (all Key Vaults + Azure OpenAI):"
readarray -t VAULT_IDS < <(az keyvault list -g "$RG" --query "[].id" -o tsv 2>/dev/null || true)
readarray -t OPENAI_IDS < <(az resource list -g "$RG" --resource-type "Microsoft.CognitiveServices/accounts" --query "[?kind=='OpenAI'].id" -o tsv)

echo
echo "==> Preserved resources:"
if ((${#VAULT_IDS[@]})); then
  for vid in "${VAULT_IDS[@]}"; do
    VNAME=$(az resource show --ids "$vid" --query name -o tsv 2>/dev/null || echo "(unknown)")
    printf "   - Vault: %s\n" "$VNAME"
  done
else
  echo "   - Vault: (none found)"
fi
if ((${#OPENAI_IDS[@]})); then
  for oid in "${OPENAI_IDS[@]}"; do
    ONAME=$(az resource show --ids "$oid" --query name -o tsv 2>/dev/null || echo "(unknown)")
    printf "   - OpenAI: %s\n" "$ONAME"
  done
else
  echo "   - OpenAI: (none found)"
fi
echo

is_excluded() {
  local id="$1"
  [[ -z "${id}" ]] && return 1
  for vid in "${VAULT_IDS[@]:-}"; do
    [[ "$id" == "$vid" ]] && return 0
  done
  for oid in "${OPENAI_IDS[@]:-}"; do
    [[ "$id" == "$oid" ]] && return 0
  done
  return 1
}

is_affirmative() {
  local a
  a=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
  case "$a" in
    (yes | y | ja) return 0 ;;
    (*) return 1 ;;
  esac
}

echo "==> Resources that would be deleted (everything except Key Vaults + OpenAI):"
az resource list -g "$RG" --query "[?type != 'Microsoft.KeyVault/vaults' && kind != 'OpenAI'].{name:name,type:type,id:id}" -o table || true

echo
read -p "Proceed and delete EVERYTHING except Key Vaults + OpenAI? (yes/no) " CONFIRM_DELETE

if is_affirmative "$CONFIRM_DELETE"; then
  echo "==> Cancel and remove stale deployments:"
    readarray -t DEPS < <(az deployment group list -g "$RG" --query "[].name" -o tsv)
    for dep in "${DEPS[@]:-}"; do
    state=$(az deployment group show -g "$RG" -n "$dep" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "")
    if [[ "$state" == "Running" || "$state" == "Accepted" || "$state" == "Creating" || "$state" == "InProgress" ]]; then
        echo "   -> Cancel $dep (state: $state)"
        az deployment group cancel -g "$RG" -n "$dep" || true
        for i in {1..18}; do
        newstate=$(az deployment group show -g "$RG" -n "$dep" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "")
        [[ "$newstate" == "Canceled" || "$newstate" == "Failed" || -z "$newstate" ]] && break
        sleep 5
        done
    fi
    echo "   -> Delete $dep"
    az deployment group delete -g "$RG" -n "$dep" || true
    done

  echo "==> Delete Container Apps, environments, private endpoints/DNS first:"
  WAVE1_TYPES=(
    "Microsoft.App/containerApps"
    "Microsoft.App/managedEnvironments"
    "Microsoft.Network/privateEndpoints"
    "Microsoft.Network/privateDnsZones"
  )
  for t in "${WAVE1_TYPES[@]}"; do
    readarray -t IDS < <(az resource list -g "$RG" --resource-type "$t" --query "[].id" -o tsv)
    if ((${#IDS[@]})); then
      for id in "${IDS[@]}"; do
        if ! is_excluded "$id"; then
          echo "   -> Deleting $id"
          az resource delete --ids "$id" || true
        fi
      done
    else
      echo "   -> No resources of type $t found."
    fi
  done

  echo "==> Wait until managed environments are gone (if any):"
  readarray -t ENV_IDS < <(az resource list -g "$RG" --resource-type "Microsoft.App/managedEnvironments" --query "[].id" -o tsv)
  for env_id in "${ENV_IDS[@]:-}"; do
    echo "   -> Waiting for: $env_id"
    for i in {1..18}; do
      if ! az resource show --ids "$env_id" &>/dev/null; then
        echo "      OK: removed"
        break
      fi
      sleep 10
    done
  done

  echo "==> Delete virtual networks explicitly:"
  readarray -t VNETS < <(az network vnet list -g "$RG" --query "[].name" -o tsv)
  if ((${#VNETS[@]})); then
    for vnet in "${VNETS[@]}"; do
      VNET_ID=$(az network vnet show -g "$RG" -n "$vnet" --query id -o tsv)
      if ! is_excluded "$VNET_ID"; then
        echo "   -> Deleting VNet $vnet"
        az network vnet delete -g "$RG" -n "$vnet" || true
      fi
    done
  else
    echo "   -> No VNets found."
  fi

  echo "==> Delete remaining resources (except Key Vaults + OpenAI):"
  readarray -t ALL_IDS < <(az resource list -g "$RG" --query "[].id" -o tsv)
  if ((${#ALL_IDS[@]})); then
    for id in "${ALL_IDS[@]}"; do
      if ! is_excluded "$id"; then
        echo "   -> Deleting $id"
        az resource delete --ids "$id" || true
      fi
    done
  else
    echo "   -> No further resources found."
  fi
else
  echo "==> Deletion skipped (answer was not yes)."
fi

echo
echo "==> Remaining resources in the resource group (after optional deletion):"
az resource list -g "$RG" -o table

echo
read -p "Deploy infra layer (managed identity + Azure OpenAI)? (yes/no) " CONFIRM_INFRA
if is_affirmative "$CONFIRM_INFRA"; then
  echo "==> Deploy infra layer:"
  az deployment group create --resource-group "$RG" --template-file "$INFRA_BICEP" --name "infra-$(date +%s)" --output none
  echo "==> Infra deployment finished."
else
  echo "==> Infra deployment skipped."
fi

echo
read -p "Deploy apps layer (Container Apps, Postgres, Key Vault, etc.)? (yes/no) " CONFIRM_APPS
if is_affirmative "$CONFIRM_APPS"; then
  echo "==> Starting apps deployment:"
  az deployment group create --resource-group "$RG" --template-file "$BICEP_FILE" --parameters @"$PARAM_DEV" @"$PARAM_LOCAL"
  echo "==> Apps deployment finished."
else
  echo "==> Apps deployment skipped."
fi
