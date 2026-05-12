# 04 - Deployment Setup

This page lists the inputs needed before CI/CD can deploy the application stack.

## GitHub Environment

The workflow uses the GitHub environment `dev`. Create it in GitHub repository settings and add the variables and secrets below.

GitHub variables:

- `RG_NAME`: target resource group name.
- `LOCATION`: Azure region.
- `OPEN_WEBUI_URL`: optional custom Open WebUI URL. Leave empty to use the Container Apps generated URL.
- `LIBRECHAT_URL`: optional custom LibreChat URL. Leave empty to use the generated URL.
- `LIBRECHAT_ADMIN_URL`: optional custom LibreChat Admin Panel URL. Leave empty to use the generated URL.

GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ADMIN_OBJECT_ID`
- `POSTGRES_ADMIN_LOGIN`
- `POSTGRES_ADMIN_PASSWORD`
- `LITELLM_MASTER_KEY`
- `LITELLM_SERVICE_KEY`
- `OPEN_WEBUI_SECRET_KEY`
- `OIDC_PROVIDER_URL`
- `OIDC_OPENWEBUI_CLIENT_ID`
- `OIDC_OPENWEBUI_CLIENT_SECRET`
- `OIDC_LIBRECHAT_CLIENT_ID`
- `OIDC_LIBRECHAT_CLIENT_SECRET`
- `LIBRECHAT_JWT_SECRET`
- `LIBRECHAT_JWT_REFRESH_SECRET`
- `LIBRECHAT_OIDC_SESSION_SECRET`
- `LIBRECHAT_ADMIN_SESSION_SECRET`
- `AZURE_OPENAI_KEY_OVERRIDE` (optional; leave empty unless you want to override the key Bicep reads from Azure OpenAI)

`LITELLM_SERVICE_KEY` can be a placeholder for the first apps deployment. After LiteLLM is running, replace it with a real virtual key created in the LiteLLM UI and redeploy.

## Generate Secrets

Use OpenSSL or an equivalent secret generator:

```bash
openssl rand -hex 32      # LITELLM_MASTER_KEY suffix or app secrets
openssl rand -base64 48   # OPEN_WEBUI_SECRET_KEY
openssl rand -base64 48   # LIBRECHAT_JWT_SECRET
openssl rand -base64 48   # LIBRECHAT_JWT_REFRESH_SECRET
openssl rand -base64 48   # LIBRECHAT_OIDC_SESSION_SECRET
openssl rand -base64 48   # LIBRECHAT_ADMIN_SESSION_SECRET
```

LiteLLM keys conventionally start with `sk-`, for example:

```bash
echo "sk-$(openssl rand -hex 32)"
```

## GitHub Deploy Identity

Create a separate Entra app registration for GitHub Actions. This is not the Open WebUI or LibreChat login app. It is only for CI/CD deployment.

```bash
az login
az account set --subscription "<subscription-id>"

TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
APP_CLIENT_ID=$(az ad app create --display-name "github-deploy-llmchat" --query appId -o tsv)

echo "AZURE_CLIENT_ID=$APP_CLIENT_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

Add a federated credential for the repository and `dev` environment:

Create the service principal and grant access on the resource group.

`Owner` is the simplest option for this demo because the deployment creates role assignments. If your organization does not allow `Owner`, use `Contributor` plus `User Access Administrator` on the resource group.

## Admin Object ID

`ADMIN_OBJECT_ID` is the object ID that receives Key Vault secret management permissions. Use a security group when possible:

```bash
az ad group show --group "<group-name>" --query id -o tsv
```

For a single user:

```bash
az ad signed-in-user show --query id -o tsv
```
