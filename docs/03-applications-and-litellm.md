# 03 - Applications and LiteLLM

This document explains how Open WebUI, LibreChat, the LibreChat Admin Panel, and LiteLLM work together. It intentionally only lists the variables and behavior users usually need to understand.

## Open WebUI

Open WebUI is the primary chat frontend. Bicep configures:

- Entra ID login.
- PostgreSQL for application state.
- Redis for session and websocket behavior.
- LiteLLM as the OpenAI-compatible backend.
- Forwarded user headers for LiteLLM spend attribution.

Important runtime settings:

- `WEBUI_URL` is the public Open WebUI URL.
- `OPENID_PROVIDER_URL` points to Entra’s OIDC metadata endpoint.
- `OPENID_REDIRECT_URI` must match the Open WebUI redirect URI in Entra.
- `OPENAI_API_BASE_URL` points to LiteLLM with `/v1`.
- `OPENAI_API_KEY` is the LiteLLM virtual key used by the frontend.
- `ENABLE_FORWARD_USER_INFO_HEADERS=True` makes Open WebUI send user identity headers to LiteLLM.

Open WebUI forwards:

- `X-LiteLLM-User-Id`
- `X-LiteLLM-User-Email`
- `X-LiteLLM-User-Name`

## LibreChat

LibreChat is an optional second chat frontend. It uses:

- Entra ID login.
- Cosmos DB for MongoDB API for LibreChat data.
- Redis for runtime state.
- LiteLLM as its custom model endpoint.
- `librechat.yaml` from the Azure Files config share.

LibreChat forwards the same LiteLLM header names as Open WebUI:

- `X-LiteLLM-User-Id`
- `X-LiteLLM-User-Email`
- `X-LiteLLM-User-Name`
- `X-LiteLLM-Source-App=librechat`

The important part is that both frontends send `X-LiteLLM-User-Email`. LiteLLM uses that as the customer identifier.

## LibreChat Admin Panel

The admin panel is a separate Container App, but it does not own users or settings itself. It calls LibreChat `/api/admin/*` endpoints.

Important runtime settings:

- `VITE_API_BASE_URL` points to the public LibreChat API URL.
- `API_SERVER_URL` also points to LibreChat unless you have an internal-only service URL.
- `SESSION_SECRET` protects the admin panel session cookie.
- `ADMIN_SSO_ONLY=true` hides the local admin login form.

Admin login works like this:

1. The user opens the admin panel.
2. The admin panel starts SSO through LibreChat `/api/admin/oauth/*`.
3. Entra authenticates the user.
4. LibreChat verifies admin access.
5. The admin panel calls LibreChat `/api/admin/*` APIs.

A LibreChat admin user needs one of:

- Entra app role value `admin` mapped into LibreChat.
- `role: "ADMIN"` in the LibreChat Mongo user document.
- `access:admin` grant.

## LiteLLM

LiteLLM is the central gateway. Open WebUI and LibreChat never call Azure OpenAI directly. They call LiteLLM with a shared virtual key, and LiteLLM applies routing, spend logging, and budget rules.

Important keys:

- `LITELLM_MASTER_KEY` is for `/ui` administration.
- `LITELLM_SERVICE_KEY` is the virtual key used by Open WebUI and LibreChat at runtime.

Important config:

- `model_list` defines the Azure OpenAI deployments exposed to the frontends.
- `max_end_user_budget_id: demo-budget` tells LiteLLM to use the named budget for customers without an explicit budget.
- `user_header_mappings` maps incoming frontend headers into LiteLLM user roles.

Current attribution model:

```yaml
user_header_mappings:
  - header_name: x-litellm-user-email
    litellm_user_role: customer
  - header_name: x-litellm-user-id
    litellm_user_role: internal_user
```

This means the LiteLLM “Spend per customer” view should use email addresses for new requests. Old spend rows can still show the previous IDs because they were logged before the mapping changed.

## Why Customers, Not Internal Users

The frontend service key is shared by the apps. If LiteLLM only tracked the key owner, all usage would look like one internal service. Mapping `x-litellm-user-email` to `customer` lets LiteLLM attribute usage to the real end user while still using a shared backend key.

This is also why Open WebUI and LibreChat must agree on the same canonical user value. In this repo, email is the customer identifier because Open WebUI and LibreChat can both forward it.

## Changing Models

Change models in `bicep/apps/litellm_config.yaml`, redeploy the apps layer so the config share is updated, and restart or roll the LiteLLM revision if needed. Frontends can then refresh the model list from LiteLLM.
