// LibreChat Admin Panel as a Container App.
// Standalone web UI that talks to the LibreChat API at /api/admin/*
// for user / role / group / config management. Requires LibreChat >= v0.8.5.
//
// Authentication is delegated to LibreChat (SSO redirects go through
// VITE_API_BASE_URL which points at the LibreChat public URL), so this
// Container App reuses the existing Entra app registration / redirect URI.

param libreChatAdminName string
param libreChatAdminImage string
param location string
param envId string
param userIdentityResourceId string
param keyVaultName string

@description('Browser-facing URL of the LibreChat API server (e.g. https://librechat.example.com). Used for OAuth/SSO redirects.')
param libreChatUrl string

@description('Public URL of the Admin Panel itself (used to compose its own outputs). Leave empty to default to the auto-derived FQDN.')
param libreChatAdminUrl string = ''

@description('Force SSO-only login (hide the local username/password form).')
param adminSsoOnly bool = true

@description('Session idle timeout in milliseconds. Default 30 minutes.')
param adminSessionIdleTimeoutMs int = 1800000

@minValue(1)
param minReplicas int = 1

@minValue(1)
param maxReplicas int = 1

param cpu string = '1.0'
param memory string = '2Gi'

var keyVaultBase = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets'

var secrets = [
  {
    name: 'admin-session-secret'
    keyVaultUrl: '${keyVaultBase}/LibreChatAdminSessionSecret'
    identity: userIdentityResourceId
  }
]


var envVars = [
  { name: 'PORT', value: '3000' }
  { name: 'SESSION_SECRET', secretRef: 'admin-session-secret' }
  { name: 'VITE_API_BASE_URL', value: libreChatUrl }
  { name: 'API_SERVER_URL', value: libreChatUrl }
  { name: 'ADMIN_SSO_ONLY', value: string(adminSsoOnly) }
  { name: 'ADMIN_SESSION_IDLE_TIMEOUT_MS', value: string(adminSessionIdleTimeoutMs) }
  { name: 'SESSION_COOKIE_SECURE', value: 'true' }
]

resource libreChatAdminApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: libreChatAdminName
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
        targetPort: 3000
        transport: 'auto'
        allowInsecure: false
      }
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: 'librechat-admin'
          image: libreChatAdminImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: envVars
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/'
                port: 3000
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 3000
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

output fqdn string = libreChatAdminApp.properties.configuration.ingress.fqdn
output publicUrl string = empty(libreChatAdminUrl) ? 'https://${libreChatAdminApp.properties.configuration.ingress.fqdn}' : libreChatAdminUrl
