# 05 - Deployment

Deploy the platform in two stages: the infra layer first, then the application layer.

## Deploy Infra First

Deploy `bicep/infra/main.bicep` manually before the GitHub Actions pipeline deploys apps. This layer creates the user-assigned managed identity and Azure OpenAI resources. The apps layer later grants that identity Key Vault access, so the identity must already exist.

```bash
az login
az account set --subscription "<subscription-id>"
az group create --name "<resource-group>" --location "<region>"

az deployment group create \
  --resource-group "<resource-group>" \
  --name "infra" \
  --template-file "bicep/infra/main.bicep" \
  --parameters projectName="llmchat"
```

Use the same `projectName` for infra and apps. The naming convention depends on it.

## Deploy Apps With GitHub Actions

After `docs/04-deployment-setup.md` is complete, run `.github/workflows/deploy.yaml` manually or push to `main`.

The workflow:

1. Logs into Azure with the GitHub deploy app registration.
2. Builds the Bicep template.
3. Runs `what-if`.
4. Deploys `bicep/apps/main.bicep`.

The first deployment can use placeholder values for `LITELLM_SERVICE_KEY` and `LIBRECHAT_ADMIN_URL`. You will replace those after LiteLLM and the generated URLs exist.

## Local Deployment

Copy the local parameter template:

```bash
cp bicep/apps/parameters.local.example.json bicep/apps/parameters.local.json
```

Fill in local secrets, then deploy:

```bash
az deployment group create \
  --resource-group "<resource-group>" \
  --template-file "bicep/apps/main.bicep" \
  --parameters @bicep/apps/dev.parameters.json @bicep/apps/parameters.local.json
```

## Deployment Helper Script

`bicep/deployment.sh` is an interactive local helper. It can:

- remove deployed resources while preserving Key Vault and Azure OpenAI,
- deploy the infra layer,
- deploy the apps layer.

Run it from the repo root or directly from `bicep`:

```bash
bash bicep/deployment.sh
```

Read the prompts carefully. The delete step is intentionally interactive.

## First Output Check

After deployment, read outputs:

```bash
az deployment group show \
  --resource-group "<resource-group>" \
  --name "main" \
  --query properties.outputs
```

Use those outputs to update Entra redirect URIs:

- `openWebUIRedirectUri`
- `libreChatRedirectUri`
- `libreChatAdminOauthRedirectUri`
- `libreChatAdminUrl` plus `/auth/openid/callback`

Then continue with `docs/06-after-deployment.md`.
