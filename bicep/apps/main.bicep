// Main composition for the Azure LLM Chat demo (application stack).
// Resource-group scope. Open WebUI + LiteLLM is the default stack;
// LibreChat is optional via deployLibreChat=true.
//
// PREREQUISITE: infra/main.bicep must have been deployed first. It creates
//   - the user-assigned managed identity (referenced here as 'existing')
//   - the Azure OpenAI account + model deployments
//
// The deployment principal (CI service principal or local user) needs:
//   - Contributor at the RG scope (create resources)
//   - Role Based Access Control Administrator OR Owner (create RBAC bindings
//     inside the Key Vault module)
//   - Key Vault Secrets Officer (write secret values)

targetScope = 'resourceGroup'

// -------- deterministic naming (abbreviation + projectName; matches bicep/infra/main.bicep) --------
var abbrs = loadJsonContent('../abbreviations.json')

@description('Short project label. Must match `projectName` in bicep/infra/main.bicep for identity and Azure OpenAI names.')
param projectName string = 'llmchat'

var storageAccountName = '${abbrs.StorageAccount}${projectName}'
var workspaceName = '${abbrs.LogAnalyticsWorkspace}-${projectName}'
var userIdentityName = '${abbrs.ManagedIdentity}-${projectName}'
var keyVaultName = '${abbrs.KeyVault}-${projectName}'
var envName = '${abbrs.ContainerAppsEnvironment}-${projectName}'
var postgresServerName = '${abbrs.PostgreSQLDatabase}-${projectName}'
var redisName = '${abbrs.AzureCacheForRedisInstance}-${projectName}'
var azureOpenAIName = '${abbrs.AzureOpenAIService}-${projectName}'
var mongoAccountName = '${abbrs.AzureCosmosDBForMongoDBAccount}-${projectName}'
var openWebUIName = 'openwebui'
var litellmName = 'litellm'
var libreChatName = 'librechat'
var libreChatAdminName = 'librechat-admin'

param location string = resourceGroup().location

@description('Object ID (principal ID) of the admin principal in Entra ID. Receives Key Vault Secrets Officer at deploy time so secret values can be written.')
param adminPrincipalId string

@description('Principal type for `adminPrincipalId`. Use `Group` (recommended) when adminPrincipalId points at a security group, or `User` for a single human.')
@allowed([ 'User', 'Group', 'ServicePrincipal' ])
param adminPrincipalType string = 'User'

@description('Optional override for the managed identity principal ID. Leave empty to read principalId from the existing user-assigned identity (same name as infra).')
param managedIdentityPrincipalId string = ''

@description('Tags applied to apps-layer resources that accept tags (currently the Key Vault).')
param tags object = {}

// -------- postgres --------
param postgresAdminLogin string
@secure()
param postgresAdminPassword string
@allowed([ 'Enabled', 'Disabled' ])
param postgresPublicNetworkAccess string = 'Enabled'

// -------- azure openai --------
// Account + model deployments are provisioned by bicep/infra/main.bicep first (same derived name as `azureOpenAIName`).
param azureOpenAIApiVersion string = '2024-12-01-preview'

@secure()
@description('Optional override. Leave empty to let Bicep grab the key from the existing AOAI account.')
param azureOpenAIKeyOverride string = ''

// -------- core demo apps --------
param openWebUIImage string = 'ghcr.io/open-webui/open-webui:v0.9.2'

param litellmImage string = 'docker.litellm.ai/berriai/litellm:main-v1.83.10-stable'

@secure()
param litellmMasterKey string

@secure()
@description('LiteLLM virtual key used by Open WebUI / LibreChat as Bearer.')
param litellmServiceKey string

@secure()
@description('Random >= 32 byte secret used by Open WebUI for cookies/JWT.')
param openWebUISecretKey string

// -------- public hostnames --------
@description('Optional custom URL of Open WebUI. Leave empty to auto-derive from the Container Apps environment default domain.')
param openWebUiUrl string = ''

// -------- OIDC: Open WebUI --------
@description('OIDC well-known URL (e.g. https://login.microsoftonline.com/<tenant>/v2.0/.well-known/openid-configuration).')
param oidcProviderUrl string

@secure()
param oidcOpenWebUIClientId string

@secure()
param oidcOpenWebUIClientSecret string

// -------- LibreChat (optional) --------
param deployLibreChat bool = false
param libreChatImage string = 'ghcr.io/danny-avila/librechat:v0.8.5'
@description('Optional custom URL of LibreChat. Leave empty to auto-derive from the Container Apps environment default domain.')
param libreChatUrl string = ''
@secure()
param oidcLibreChatClientId string = ''

@secure()
param oidcLibreChatClientSecret string = ''

@secure()
param librechatJwtSecret string = ''

@secure()
param librechatJwtRefreshSecret string = ''

@secure()
param librechatOidcSessionSecret string = ''

// -------- LibreChat Admin Panel (deployed when deployLibreChat = true) --------
@description('LibreChat Admin Panel image. The project has no tagged releases yet; pin a digest in production.')
param libreChatAdminImage string = 'ghcr.io/clickhouse/librechat-admin-panel:latest'

@description('Optional custom URL of the LibreChat Admin Panel. Leave empty to auto-derive from the Container Apps environment default domain.')
param libreChatAdminUrl string = ''

@description('Force SSO-only login on the admin panel (hide email/password form).')
param libreChatAdminSsoOnly bool = true

@secure()
@description('>= 32 chars random secret used to encrypt admin-panel sessions. Required when deployLibreChat = true.')
param librechatAdminSessionSecret string = ''

// -------- derived values --------
var litellmDatabaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServerName}.postgres.database.azure.com:5432/litellm?sslmode=require'
var openWebUIDatabaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServerName}.postgres.database.azure.com:5432/openwebui?sslmode=require'

// Auto-derive public URLs from ACA environment default domain unless overridden.
var openWebUiEffectiveUrl = !empty(openWebUiUrl) ? openWebUiUrl : 'https://${openWebUIName}.${containerEnv.outputs.defaultDomain}'
var libreChatEffectiveUrl = !empty(libreChatUrl) ? libreChatUrl : 'https://${libreChatName}.${containerEnv.outputs.defaultDomain}'
var libreChatAdminEffectiveUrl = !empty(libreChatAdminUrl) ? libreChatAdminUrl : 'https://${libreChatAdminName}.${containerEnv.outputs.defaultDomain}'
var oidcOpenWebUIRedirectUri = '${openWebUiEffectiveUrl}/oauth/oidc/callback'

// Auto-grab AOAI key unless an explicit override is provided.
var azureOpenAIEffectiveKey = !empty(azureOpenAIKeyOverride) ? azureOpenAIKeyOverride : aoai.outputs.azureOpenAIKey

// =====================================================================
// modules
// =====================================================================

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: userIdentityName
}

module logs './modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    workspaceName: workspaceName
    location: location
  }
}

module postgres './modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    location: location
    serverName: postgresServerName
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    publicNetworkAccess: postgresPublicNetworkAccess
  }
}

module redis './modules/redis.bicep' = {
  name: 'redis'
  params: {
    redisName: redisName
    location: location
  }
}

module mongo './modules/mongo.bicep' = if (deployLibreChat) {
  name: 'mongo'
  params: {
    accountName: mongoAccountName
    location: location
  }
}

module aoai './modules/azureOpenAI.bicep' = {
  name: 'aoai'
  params: {
    openAIName: azureOpenAIName
  }
}

module keyVault './modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    adminPrincipalId: adminPrincipalId
    adminPrincipalType: adminPrincipalType
    managedIdentityPrincipalId: !empty(managedIdentityPrincipalId) ? managedIdentityPrincipalId : userIdentity.properties.principalId
    litellmMasterKeyValue: litellmMasterKey
    postgresUsernameValue: postgresAdminLogin
    postgresPasswordValue: postgresAdminPassword
    litellmDatabaseUrlValue: litellmDatabaseUrl
    openWebUIDatabaseUrlValue: openWebUIDatabaseUrl
    openWebUISecretKeyValue: openWebUISecretKey
    redisUrlValue: redis.outputs.redisUrl
    oidcOpenWebUIClientId: oidcOpenWebUIClientId
    oidcOpenWebUIClientSecret: oidcOpenWebUIClientSecret
    oidcLibreChatClientId: oidcLibreChatClientId
    oidcLibreChatClientSecret: oidcLibreChatClientSecret
    azureOpenAIKeyValue: azureOpenAIEffectiveKey
    librechatJwtSecretValue: librechatJwtSecret
    librechatJwtRefreshSecretValue: librechatJwtRefreshSecret
    librechatMongoUriValue: mongo.?outputs.mongoConnectionString ?? ''
    librechatOidcSessionSecretValue: librechatOidcSessionSecret
    librechatAdminSessionSecretValue: librechatAdminSessionSecret
    litellmServiceKeyValue: litellmServiceKey
  }
}

module storage './modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    deployLibreChat: deployLibreChat
  }
}

module containerEnv './modules/containerEnv.bicep' = {
  name: 'containerEnv'
  params: {
    envName: envName
    location: location
    logsCustomerId: logs.outputs.workspaceId
    logsKey: logs.outputs.workspaceKey
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    litellmShareName: storage.outputs.litellmShareName
    librechatShareName: storage.outputs.librechatShareName
    deployLibreChat: deployLibreChat
  }
}

module litellm './modules/litellm.bicep' = {
  name: 'litellm'
  params: {
    liteLLMName: litellmName
    liteLLMImage: litellmImage
    location: location
    envId: containerEnv.outputs.environmentId
    userIdentityResourceId: userIdentity.id
    keyVaultName: keyVaultName
    azureOpenAIBaseUrl: aoai.outputs.azureOpenAIEndpoint
    azureOpenAIApiVersion: azureOpenAIApiVersion
    useAzureOpenAIKey: true
  }
  dependsOn: [
    keyVault
  ]
}

module openWebUI './modules/openWebUI.bicep' = {
  name: 'openWebUI'
  params: {
    openWebUIName: openWebUIName
    openWebUIImage: openWebUIImage
    location: location
    envId: containerEnv.outputs.environmentId
    userIdentityResourceId: userIdentity.id
    keyVaultName: keyVaultName
    openWebUiUrl: openWebUiEffectiveUrl
    litellmBaseUrl: '${litellm.outputs.publicUrl}/v1'
    oidcProviderUrl: oidcProviderUrl
    oidcRedirectUri: oidcOpenWebUIRedirectUri
  }
  dependsOn: [
    keyVault
  ]
}

module librechat './modules/librechat.bicep' = if (deployLibreChat) {
  name: 'librechat'
  params: {
    libreChatName: libreChatName
    libreChatImage: libreChatImage
    location: location
    envId: containerEnv.outputs.environmentId
    userIdentityResourceId: userIdentity.id
    keyVaultName: keyVaultName
    libreChatUrl: libreChatEffectiveUrl
    litellmBaseUrl: '${litellm.outputs.publicUrl}/v1'
    oidcIssuer: replace(oidcProviderUrl, '/.well-known/openid-configuration', '')
  }
  dependsOn: [
    keyVault
  ]
}

module librechatAdmin './modules/librechatAdmin.bicep' = if (deployLibreChat) {
  name: 'librechatAdmin'
  params: {
    libreChatAdminName: libreChatAdminName
    libreChatAdminImage: libreChatAdminImage
    location: location
    envId: containerEnv.outputs.environmentId
    userIdentityResourceId: userIdentity.id
    keyVaultName: keyVaultName
    libreChatUrl: libreChatEffectiveUrl
    libreChatAdminUrl: libreChatAdminEffectiveUrl
    adminSsoOnly: libreChatAdminSsoOnly
  }
  dependsOn: [
    keyVault
    librechat
  ]
}

// =====================================================================
// outputs
// =====================================================================
output openWebUIUrl string = openWebUiEffectiveUrl
output openWebUIRedirectUri string = oidcOpenWebUIRedirectUri
output litellmUrl string = litellm.outputs.publicUrl
output libreChatUrl string = deployLibreChat ? libreChatEffectiveUrl : ''
output libreChatRedirectUri string = deployLibreChat ? '${libreChatEffectiveUrl}/oauth/openid/callback' : ''
output libreChatAdminOauthRedirectUri string = deployLibreChat ? '${libreChatEffectiveUrl}/api/admin/oauth/openid/callback' : ''
output libreChatAdminUrl string = deployLibreChat ? libreChatAdminEffectiveUrl : ''
output keyVaultUri string = keyVault.outputs.vaultUri
output managedIdentityClientId string = userIdentity.properties.clientId
output managedIdentityPrincipalId string = userIdentity.properties.principalId
output containerAppNameOpenWebUI string = openWebUIName
output containerAppNameLiteLLM string = litellmName
output containerAppNameLibreChat string = libreChatName
output containerAppNameLibreChatAdmin string = libreChatAdminName
output userAssignedIdentityName string = userIdentityName
output keyVaultNameOut string = keyVaultName
