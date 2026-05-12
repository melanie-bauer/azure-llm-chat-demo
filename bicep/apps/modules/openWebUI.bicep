@description('Container App name for Open WebUI.')
param openWebUIName string

@description('Open WebUI container image.')
param openWebUIImage string

@description('Azure region for the Container App.')
param location string

@description('Resource ID of the Container Apps managed environment.')
param envId string

@description('Resource ID of the user-assigned managed identity used to read Key Vault secrets.')
param userIdentityResourceId string

@description('Key Vault name containing Open WebUI runtime secrets.')
param keyVaultName string

@description('Public URL of Open WebUI, e.g. https://chat.example.com.')
param openWebUiUrl string

@description('LiteLLM OpenAI-compatible base URL including /v1.')
param litellmBaseUrl string

@description('OIDC issuer well-known URL.')
param oidcProviderUrl string

@description('Full OIDC redirect URI, e.g. https://chat.example.com/oauth/oidc/callback.')
param oidcRedirectUri string

@description('Display name shown on the OWUI sign-in button.')
param oidcProviderName string = 'Entra ID'

@description('OIDC scopes requested by Open WebUI.')
param oidcScopes string = 'openid email profile'

@description('Enable role mapping from OIDC roles claim.')
param enableOidcRoleMapping bool = true

@description('Enable group sync from OIDC groups claim.')
param enableOidcGroupManagement bool = true

@description('Comma-separated allowed roles in OWUI.')
param oidcAllowedRoles string = 'user,admin'

@description('Comma-separated admin roles in OWUI.')
param oidcAdminRoles string = 'admin'

@minValue(1)
@description('Minimum number of Open WebUI replicas.')
param minReplicas int = 1

@minValue(1)
@description('Maximum number of Open WebUI replicas.')
param maxReplicas int = 1

@description('CPU cores per replica.')
param cpu string = '1.0'

@description('Memory per replica.')
param memory string = '2Gi'

var keyVaultBase = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets'

var secrets = [
  {
    name: 'webui-secret-key'
    keyVaultUrl: '${keyVaultBase}/WebUISecretKey'
    identity: userIdentityResourceId
  }
  {
    name: 'webui-database-url'
    keyVaultUrl: '${keyVaultBase}/OpenWebUIDatabaseUrl'
    identity: userIdentityResourceId
  }
  {
    name: 'oidc-client-id'
    keyVaultUrl: '${keyVaultBase}/OpenWebUIOidcClientId'
    identity: userIdentityResourceId
  }
  {
    name: 'oidc-client-secret'
    keyVaultUrl: '${keyVaultBase}/OpenWebUIOidcClientSecret'
    identity: userIdentityResourceId
  }
  {
    name: 'redis-url'
    keyVaultUrl: '${keyVaultBase}/RedisUrl'
    identity: userIdentityResourceId
  }
  {
    name: 'litellm-service-key'
    keyVaultUrl: '${keyVaultBase}/LiteLLMServiceKey'
    identity: userIdentityResourceId
  }
]

var coreEnv = [
  { name: 'WEBUI_URL', value: openWebUiUrl }
  { name: 'WEBUI_SECRET_KEY', secretRef: 'webui-secret-key' }
  { name: 'ENABLE_PERSISTENT_CONFIG', value: 'False' }
  { name: 'ENABLE_OAUTH_PERSISTENT_CONFIG', value: 'False' }

  { name: 'DATABASE_URL', secretRef: 'webui-database-url' }
  { name: 'VECTOR_DB', value: 'pgvector' }
  { name: 'PGVECTOR_DB_URL', secretRef: 'webui-database-url' }

  { name: 'REDIS_URL', secretRef: 'redis-url' }
  { name: 'WEBUI_SESSION_REDIS_URL', secretRef: 'redis-url' }
  { name: 'WEBSOCKET_MANAGER', value: 'redis' }
  { name: 'WEBSOCKET_REDIS_URL', secretRef: 'redis-url' }
  { name: 'ENABLE_WEBSOCKET_SUPPORT', value: 'true' }

  { name: 'OPENAI_API_BASE_URL', value: litellmBaseUrl }
  { name: 'OPENAI_API_KEY', secretRef: 'litellm-service-key' }
  { name: 'ENABLE_FORWARD_USER_INFO_HEADERS', value: 'True' }
  { name: 'FORWARD_USER_INFO_HEADER_USER_ID', value: 'X-LiteLLM-User-Id' }
  { name: 'FORWARD_USER_INFO_HEADER_USER_EMAIL', value: 'X-LiteLLM-User-Email' }
  { name: 'FORWARD_USER_INFO_HEADER_USER_NAME', value: 'X-LiteLLM-User-Name' }

  { name: 'ENABLE_SIGNUP', value: 'False' }
  { name: 'ENABLE_LOGIN_FORM', value: 'False' }
  { name: 'ENABLE_OAUTH_SIGNUP', value: 'True' }

  { name: 'OPENID_PROVIDER_URL', value: oidcProviderUrl }
  { name: 'OAUTH_CLIENT_ID', secretRef: 'oidc-client-id' }
  { name: 'OAUTH_CLIENT_SECRET', secretRef: 'oidc-client-secret' }
  { name: 'OPENID_REDIRECT_URI', value: oidcRedirectUri }
  { name: 'OAUTH_PROVIDER_NAME', value: oidcProviderName }
  { name: 'OAUTH_SCOPES', value: oidcScopes }
  { name: 'OAUTH_SUB_CLAIM', value: 'oid' }
  { name: 'OAUTH_USERNAME_CLAIM', value: 'name' }
  { name: 'OAUTH_EMAIL_CLAIM', value: 'preferred_username' }

  { name: 'WEBUI_SESSION_COOKIE_SECURE', value: 'true' }
  { name: 'WEBUI_AUTH_COOKIE_SECURE', value: 'true' }
  { name: 'WEBUI_AUTH_COOKIE_SAME_SITE', value: 'lax' }
]

var roleEnv = enableOidcRoleMapping ? [
  { name: 'ENABLE_OAUTH_ROLE_MANAGEMENT', value: 'true' }
  { name: 'OAUTH_ROLES_CLAIM', value: 'roles' }
  { name: 'OAUTH_ALLOWED_ROLES', value: oidcAllowedRoles }
  { name: 'OAUTH_ADMIN_ROLES', value: oidcAdminRoles }
] : []

var groupEnv = enableOidcGroupManagement ? [
  { name: 'ENABLE_OAUTH_GROUP_MANAGEMENT', value: 'true' }
  { name: 'OAUTH_GROUP_CLAIM', value: 'groups' }
] : []

var envVars = concat(coreEnv, roleEnv, groupEnv)

resource openWebUIApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: openWebUIName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: envId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: 'openwebui'
          image: openWebUIImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: envVars
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 15
              periodSeconds: 10
              failureThreshold: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 60
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = openWebUIApp.properties.configuration.ingress.fqdn
output publicUrl string = 'https://${openWebUIApp.properties.configuration.ingress.fqdn}'
