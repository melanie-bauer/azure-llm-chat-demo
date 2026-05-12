# 06 - After Deployment

After the first deployment, finish the runtime setup in LiteLLM and update the values that depend on generated URLs.

## Update Entra Redirect URIs

Read the deployment outputs and update the Entra app registrations:

- Open WebUI app: `openWebUIRedirectUri`
- LibreChat app: `libreChatRedirectUri`
- LibreChat app: `libreChatAdminOauthRedirectUri`

Do this before testing user login.

## Create the LiteLLM Virtual Key

1. Open:

   ```text
   https://<litellm-url>/ui
   ```

2. Sign in with `LITELLM_MASTER_KEY`.
3. Create a virtual key for the frontends.
4. Allow the models exposed by `litellm_config.yaml`.
5. Copy the generated `sk-...` key.
6. Store it as GitHub secret `LITELLM_SERVICE_KEY`.

This key is the runtime key used by Open WebUI and LibreChat. Do not use the master key in the frontends.

## Create the Default Customer Budget

LiteLLM config references `demo-budget`:

```yaml
max_end_user_budget_id: demo-budget
```

Create a budget with that ID in the LiteLLM UI:

1. Open LiteLLM `/ui`.
2. Go to Budgets.
3. Create a budget with ID `demo-budget`.
4. Set the desired max budget and reset window.

Customers without an explicit budget will use this default budget.

## Set the LibreChat Admin URL

After the first deployment, copy output `libreChatAdminUrl` and set GitHub variable:

```text
LIBRECHAT_ADMIN_URL=https://<librechat-admin-host>
```

LibreChat uses this value as `ADMIN_PANEL_URL`, so links between LibreChat and its admin panel point to the correct host.

## Redeploy Once More

Run the GitHub Actions deployment again after setting:

- `LITELLM_SERVICE_KEY`
- `LIBRECHAT_ADMIN_URL`

This redeployment updates the Key Vault service key and the LibreChat admin panel URL wiring. After this redeploy, Open WebUI and LibreChat should both be able to call LiteLLM with the real virtual key.

## Quick Verification

Check the app URLs from deployment outputs:

- `openWebUIUrl`
- `litellmUrl`
- `libreChatUrl`
- `libreChatAdminUrl`

Then verify:

- LiteLLM `/ui` accepts the master key.
- Open WebUI can list and call LiteLLM models.
- LibreChat can list and call LiteLLM models.
- LiteLLM Spend per customer shows new requests under the forwarded email value.
