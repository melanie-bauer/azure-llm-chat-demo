// LibreChat as a Container App (optional, comparison architecture).
// Public ingress, MongoDB + Redis backed, generic OIDC against Entra ID.
// MeiliSearch is intentionally omitted for the demo to keep the surface small.

param libreChatName string
param libreChatImage string
param location string
param envId string
param userIdentityResourceId string
param keyVaultName string

@description('Public URL of LibreChat, e.g. https://librechat.example.com.')
param libreChatUrl string

@description('LiteLLM OpenAI-compatible base URL including /v1.')
param litellmBaseUrl string

@description('OIDC issuer URL (without trailing /.well-known/...).')
param oidcIssuer string

@description('OIDC callback path on the LibreChat host.')
param oidcCallbackPath string = '/oauth/openid/callback'

@description('Comma-separated allowed roles. Empty = no role gate.')
param oidcRequiredRoles string = ''

@description('Enable Microsoft Graph integration for people/group search.')
param useEntraGraph bool = false

@description('Name of the ACA managed environment storage that exposes the LibreChat config share.')
param librechatStorageName string = 'librechat-config'

@description('Path inside the container where librechat.yaml is mounted.')
param librechatConfigPath string = '/app/config/librechat.yaml'

@minValue(1)
param minReplicas int = 1

@minValue(1)
param maxReplicas int = 1

@description('CPU cores per replica.')
param cpu string = '1.0'

@description('Memory per replica. Node + LibreChat often needs >1Gi (OOM/137 at 1Gi).')
param memory string = '2Gi'

var keyVaultBase = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets'

var secrets = [
  {
    name: 'jwt-secret'
    keyVaultUrl: '${keyVaultBase}/LibreChatJwtSecret'
    identity: userIdentityResourceId
  }
  {
    name: 'jwt-refresh-secret'
    keyVaultUrl: '${keyVaultBase}/LibreChatJwtRefreshSecret'
    identity: userIdentityResourceId
  }
  {
    name: 'mongo-uri'
    keyVaultUrl: '${keyVaultBase}/LibreChatMongoUri'
    identity: userIdentityResourceId
  }
  {
    name: 'redis-url'
    keyVaultUrl: '${keyVaultBase}/RedisUrl'
    identity: userIdentityResourceId
  }
  {
    name: 'oidc-client-id'
    keyVaultUrl: '${keyVaultBase}/LibreChatOidcClientId'
    identity: userIdentityResourceId
  }
  {
    name: 'oidc-client-secret'
    keyVaultUrl: '${keyVaultBase}/LibreChatOidcClientSecret'
    identity: userIdentityResourceId
  }
  {
    name: 'oidc-session-secret'
    keyVaultUrl: '${keyVaultBase}/LibreChatOidcSessionSecret'
    identity: userIdentityResourceId
  }
  {
    name: 'litellm-service-key'
    keyVaultUrl: '${keyVaultBase}/LiteLLMServiceKey'
    identity: userIdentityResourceId
  }
]

var coreEnv = [
  { name: 'HOST', value: '0.0.0.0' }
  { name: 'PORT', value: '3080' }
  { name: 'DOMAIN_CLIENT', value: libreChatUrl }
  { name: 'DOMAIN_SERVER', value: libreChatUrl }

  { name: 'ALLOW_EMAIL_LOGIN', value: 'false' }
  { name: 'ALLOW_REGISTRATION', value: 'false' }
  { name: 'ALLOW_SOCIAL_LOGIN', value: 'true' }
  { name: 'ALLOW_SOCIAL_REGISTRATION', value: 'true' }

  { name: 'JWT_SECRET', secretRef: 'jwt-secret' }
  { name: 'JWT_REFRESH_SECRET', secretRef: 'jwt-refresh-secret' }
  { name: 'SESSION_EXPIRY', value: '900000' }
  { name: 'REFRESH_TOKEN_EXPIRY', value: '604800000' }

  { name: 'MONGO_URI', secretRef: 'mongo-uri' }
  { name: 'USE_REDIS', value: 'true' }
  { name: 'REDIS_URI', secretRef: 'redis-url' }

  { name: 'OPENID_CLIENT_ID', secretRef: 'oidc-client-id' }
  { name: 'OPENID_CLIENT_SECRET', secretRef: 'oidc-client-secret' }
  { name: 'OPENID_ISSUER', value: oidcIssuer }
  { name: 'OPENID_SESSION_SECRET', secretRef: 'oidc-session-secret' }
  { name: 'OPENID_SCOPE', value: 'openid profile email offline_access' }
  { name: 'OPENID_CALLBACK_URL', value: oidcCallbackPath }
  { name: 'OPENID_USE_END_SESSION_ENDPOINT', value: 'true' }
  { name: 'OPENID_REUSE_TOKENS', value: 'true' }

  { name: 'OPENID_ADMIN_ROLE', value: 'admin' }
  { name: 'OPENID_ADMIN_ROLE_PARAMETER_PATH', value: 'roles' }
  { name: 'OPENID_ADMIN_ROLE_TOKEN_KIND', value: 'id' }

  { name: 'LITELLM_BASE_URL', value: litellmBaseUrl }
  { name: 'LITELLM_API_KEY', secretRef: 'litellm-service-key' }

  { name: 'CONFIG_PATH', value: librechatConfigPath }
  { name: 'ADMIN_PANEL_URL', value: 'https://librechat-admin.calmglacier-bdbc6f5e.swedencentral.azurecontainerapps.io' }
]

var roleEnv = empty(oidcRequiredRoles) ? [] : [
  { name: 'OPENID_REQUIRED_ROLE_TOKEN_KIND', value: 'id' }
  { name: 'OPENID_REQUIRED_ROLE_PARAMETER_PATH', value: 'roles' }
  { name: 'OPENID_REQUIRED_ROLE', value: oidcRequiredRoles }
]

var graphEnv = useEntraGraph ? [
  { name: 'USE_ENTRA_ID_FOR_PEOPLE_SEARCH', value: 'true' }
  { name: 'ENTRA_ID_INCLUDE_OWNERS_AS_MEMBERS', value: 'true' }
  { name: 'OPENID_GRAPH_SCOPES', value: 'User.Read,People.Read,GroupMember.Read.All,User.ReadBasic.All' }
] : []

var envVars = concat(coreEnv, roleEnv, graphEnv)

resource libreChatApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: libreChatName
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
        targetPort: 3080
        transport: 'auto'
        allowInsecure: false
      }
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: 'librechat'
          image: libreChatImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: envVars
          volumeMounts: [
            {
              volumeName: 'librechat-config'
              mountPath: '/app/config'
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/'
                port: 3080
              }
              initialDelaySeconds: 15
              periodSeconds: 10
              failureThreshold: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 3080
              }
              initialDelaySeconds: 60
              periodSeconds: 30
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'librechat-config'
          storageType: 'AzureFile'
          storageName: librechatStorageName
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = libreChatApp.properties.configuration.ingress.fqdn
output publicUrl string = 'https://${libreChatApp.properties.configuration.ingress.fqdn}'
