# azure-llm-chat-demo

Azure reference architecture for a self-hosted LLM chat platform with:

- `Open WebUI` as the main user interface
- `LiteLLM` as the centralized model gateway
- `LibreChat` as an optional second frontend
- `Microsoft Entra ID (OIDC)` for SSO
- `Azure Container Apps`, `Key Vault (RBAC)`, `PostgreSQL`, `Redis`, and optional `Cosmos DB (Mongo API)`

The repo is designed for demos and workshops while keeping the deployment model close to what a production platform needs: central model governance, Entra ID, managed secrets, and repeatable infrastructure.

## Who This Is For

Use this repository if you are new to this stack and want:

- a guided first deployment
- a clean secrets strategy
- a practical OIDC setup
- one place to control model routing, logging, and budget enforcement

## Quick Start

1. Read `docs/01-architecture.md` to understand the platform.
2. Create Entra app registrations with `docs/02-entra-id-setup.md`.
3. Prepare GitHub secrets and variables with `docs/04-deployment-setup.md`.
4. Deploy `bicep/infra/main.bicep` manually.
5. Run the GitHub Actions deployment for the apps layer.
6. Complete the LiteLLM and redirect URI steps in `docs/06-after-deployment.md`.

If this is your first time, follow the docs in order.

## Repository Structure

```text
.
├── bicep/
│   ├── infra/                       # Managed identity + Azure OpenAI
│   ├── apps/                        # Container Apps, data stores, Key Vault
│   │   ├── main.bicep
│   │   ├── dev.parameters.json
│   │   ├── litellm_config.yaml
│   │   ├── librechat.yaml
│   │   └── modules/
│   └── deployment.sh                # Local cleanup/deploy helper
├── docs/
│   ├── 01-architecture.md
│   ├── 02-entra-id-setup.md
│   ├── 03-applications-and-litellm.md
│   ├── 04-deployment-setup.md
│   ├── 05-deployment.md
│   ├── 06-after-deployment.md
│   └── 07-troubleshooting.md
└── .github/workflows/
    └── deploy.yaml
```

## Security and Secrets Model

This repo intentionally separates inputs into two groups:

- `bicep/apps/dev.parameters.json`: safe-to-commit, non-sensitive defaults
- GitHub Secrets (or local `bicep/apps/parameters.local.json`): passwords, keys, client secrets, identity IDs

Do not commit local secret files.

## Common First-Time Questions

- **Do I need to know OpenWebUI URL before first deploy?** No. It can be auto-derived from the Container Apps environment domain.
- **Do I need to provide `AZURE_OPENAI_KEY` upfront?** Usually no. Bicep can retrieve it from the Azure OpenAI account and store it in Key Vault.
- **Do I still need redirect URIs in Entra?** Yes. You set placeholder first, then update to the output URI after first deploy.

## Pinned Container Images

- Open WebUI: `ghcr.io/open-webui/open-webui:v0.9.2`
- LiteLLM: `docker.litellm.ai/berriai/litellm:main-v1.83.10-stable`
- LibreChat: `librechat/librechat:v0.8.5` (Docker Hub mirror; pin digest for production)

Avoid floating tags (`latest`, `main`, `-rc`) for reliable demos.

## Documentation Guide

1. `docs/01-architecture.md` - What gets deployed and why
2. `docs/02-entra-id-setup.md` - End-user and deployment app registrations
3. `docs/03-applications-and-litellm.md` - Open WebUI, LibreChat, admin panel, and LiteLLM behavior
4. `docs/04-deployment-setup.md` - GitHub secrets, variables, and deployment identity
5. `docs/05-deployment.md` - Infra and apps deployment
6. `docs/06-after-deployment.md` - LiteLLM virtual key, budget, final redeploy
7. `docs/07-troubleshooting.md` - Fast issue diagnosis

## References

- [Microsoft identity platform OIDC](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc)
- [Add redirect URI in Entra app registration](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-redirect-uri)
- [Redirect URI best practices](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [Key Vault RBAC guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide?tabs=azure-cli)
- [Azure Container Apps ingress](https://learn.microsoft.com/en-us/azure/container-apps/ingress-overview?tabs=bash)
