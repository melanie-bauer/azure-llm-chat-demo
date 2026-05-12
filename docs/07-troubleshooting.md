# 07 - Troubleshooting

Use this page to isolate the most common deployment and runtime issues.

## First Commands

```bash
az containerapp list -g <resource-group> -o table
az containerapp logs show -g <resource-group> -n openwebui --follow
az containerapp logs show -g <resource-group> -n litellm --follow
az containerapp logs show -g <resource-group> -n librechat --follow
az containerapp logs show -g <resource-group> -n librechat-admin --follow
```

For deployment failures:

```bash
az deployment operation group list \
  --resource-group <resource-group> \
  --name main \
  --query "[?properties.provisioningState=='Failed']"
```

## Entra Login Fails

Check the exact `redirect_uri` in the browser or Entra error message. It must be registered exactly in the matching app registration.

Open WebUI uses:

```text
https://<openwebui-host>/oauth/oidc/callback
```

LibreChat uses:

```text
https://<librechat-host>/oauth/openid/callback
https://<librechat-host>/api/admin/oauth/openid/callback
```

If login works but the user has no admin rights, check the Entra app role assignment and the claim value. This repo expects role value `admin`.

## LibreChat Admin SSO Returns 401 Before Microsoft Login

If the failed request is:

```text
GET /api/admin/oauth/openid?...code_challenge=...
```

then LibreChat is rejecting the admin OAuth start. Known causes:

- LibreChat image does not include the PKCE fix from `danny-avila/LibreChat#12534`.
- Admin OpenID environment variables are missing or not loaded.
- The LibreChat app registration is missing the admin redirect URI.

Your Mongo user being `role: "ADMIN"` matters after the OAuth flow. A 401 on the first admin OAuth URL usually happens before that user record is checked.

## LiteLLM Shows IDs Instead of Emails

Check `bicep/apps/litellm_config.yaml`:

```yaml
user_header_mappings:
  - header_name: x-litellm-user-email
    litellm_user_role: customer
```

Then confirm the frontend sends `X-LiteLLM-User-Email`. Old spend rows keep the identifier that was logged at the time; make new requests after redeploying to validate the current mapping.

## LiteLLM Models Are Missing

Check:

- `LITELLM_SERVICE_KEY` is a real LiteLLM virtual key, not the master key.
- `bicep/apps/litellm_config.yaml` contains the model name.
- Open WebUI or LibreChat points at LiteLLM with `/v1`.
- LiteLLM can reach Azure OpenAI and has the provider key from Key Vault.

## Key Vault Secrets Do Not Load

Check:

- The user-assigned managed identity exists.
- Key Vault uses RBAC mode.
- The managed identity has `Key Vault Secrets User`.
- The deployment principal can write secrets, normally via `Key Vault Secrets Officer`.

## PostgreSQL Server Is Busy

Azure PostgreSQL Flexible Server can reject parallel control-plane updates with `ServerIsBusy`. Wait a few minutes and redeploy. The Bicep module serializes the extension, database, and firewall updates to reduce this, but the service can still be busy immediately after creation.

## Fast Recovery

1. Read the failing Container App logs.
2. Fix the secret, redirect URI, or image tag.
3. Redeploy the apps layer.
4. Retry one login and one LiteLLM model request.
