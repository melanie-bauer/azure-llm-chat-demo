# 02 - Entra ID Setup

This project uses Entra ID as the identity provider for Open WebUI and, when enabled, LibreChat. Create the app registrations before deploying the application stack, then update the redirect URIs after the first deployment outputs the real Container App URLs.

## Get the Provider URL

Run:

```bash
az account show --query tenantId -o tsv
```

Use the tenant ID to build:

```text
https://login.microsoftonline.com/<tenant-id>/v2.0/.well-known/openid-configuration
```

Store this value as `OIDC_PROVIDER_URL`.

## Open WebUI App Registration

1. Open Azure Portal → Microsoft Entra ID → App registrations → New registration.
2. Name it `OpenWebUI`.
3. Select single-tenant unless your scenario needs multi-tenant login.
4. Add a temporary Web redirect URI:

   ```text
   https://placeholder.example.com/oauth/oidc/callback
   ```

5. Create a client secret in Certificates & secrets. Copy the secret **Value**, not the secret ID.
6. Save these values for deployment:
   - `OIDC_OPENWEBUI_CLIENT_ID`: Application (client) ID.
   - `OIDC_OPENWEBUI_CLIENT_SECRET`: client secret value.
7. In Token configuration, add the ID token claims your app expects:
   - `email`
   - `preferred_username`
   - `name`
   - `groups` if you want group-based Open WebUI access.
8. Add app roles with values `admin` and `user`.
9. Open Enterprise applications → OpenWebUI → Users and groups and assign users or groups to the roles.

After first deploy, replace the placeholder redirect URI with deployment output `openWebUIRedirectUri`.

## LibreChat App Registration

Create this only when `deployLibreChat` is enabled.

1. Create another app registration named `LibreChat`.
2. Add temporary Web redirect URIs:

   ```text
   https://placeholder-librechat.example.com/oauth/openid/callback
   https://placeholder-librechat.example.com/api/admin/oauth/openid/callback
   ```

3. Create a client secret and save:
   - `OIDC_LIBRECHAT_CLIENT_ID`
   - `OIDC_LIBRECHAT_CLIENT_SECRET`
4. Add app role value `admin`.
5. Assign every LibreChat administrator to that role in Enterprise applications → LibreChat → Users and groups.

After first deploy, replace the placeholders with the exact deployment outputs:

- `libreChatRedirectUri`
- `libreChatAdminOauthRedirectUri`

The admin panel starts its login through LibreChat, but the browser returns to the admin panel at `/auth/openid/callback`. Entra redirect URIs must match exactly, including host and path.

## GitHub Deploy App Registration

GitHub Actions also needs its own Entra app registration. This app is not used for end-user login; it lets the workflow deploy Bicep with federated credentials.

The setup is documented in `docs/04-deployment-setup.md`. The important point is that this app registration must receive permissions on the target resource group through Access control (IAM), usually `Owner` for this demo or `Contributor` plus `User Access Administrator`.

## Common Mistakes

- Using a secret ID instead of the secret value.
- Forgetting to assign app roles after creating them.
- Registering the admin panel callback on the wrong host.
- Leaving placeholder redirect URIs after the first deployment.
- Adding a trailing slash that is not present in the app’s redirect URI.

## References

- [Microsoft identity platform OIDC](https://learn.microsoft.com/entra/identity-platform/v2-protocols-oidc)
- [Add redirect URI](https://learn.microsoft.com/entra/identity-platform/how-to-add-redirect-uri)
- [Redirect URI restrictions](https://learn.microsoft.com/entra/identity-platform/reply-url)
