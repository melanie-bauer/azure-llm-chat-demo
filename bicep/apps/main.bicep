targetScope = 'resourceGroup'

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

@description('Azure region for app-layer resources.')
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

@description('PostgreSQL administrator login name.')
param postgresAdminLogin string
@secure()
@description('PostgreSQL administrator password.')
param postgresAdminPassword string

@description('Whether PostgreSQL public network access is enabled.')
@allowed([ 'Enabled', 'Disabled' ])
param postgresPublicNetworkAccess string = 'Enabled'

@description('Azure OpenAI API version used by LiteLLM.')
param azureOpenAIApiVersion string = '2024-12-01-preview'

@secure()
@description('Optional Azure OpenAI key override. Leave empty to read the key from the existing Azure OpenAI account.')
param azureOpenAIKeyOverride string = ''

@description('Open WebUI container image.')
param openWebUIImage string = 'ghcr.io/open-webui/open-webui:v0.9.2'

@description('LiteLLM container image.')
param litellmImage string = 'docker.litellm.ai/berriai/litellm:main-v1.83.10-stable'

@secure()
@description('LiteLLM master key used for proxy administration and /ui login.')
param litellmMasterKey string

@secure()
@description('LiteLLM virtual key used by Open WebUI and LibreChat.')
param litellmServiceKey string

@secure()
@description('Random secret used by Open WebUI for cookies and JWT signing.')
param openWebUISecretKey string

@description('Optional custom URL of Open WebUI. Leave empty to auto-derive from the Container Apps environment default domain.')
param openWebUiUrl string = ''

@description('OIDC well-known URL (e.g. https://login.microsoftonline.com/<tenant>/v2.0/.well-known/openid-configuration).')
param oidcProviderUrl string

@secure()
@description('Open WebUI Entra application client ID.')
param oidcOpenWebUIClientId string

@secure()
@description('Open WebUI Entra application client secret.')
param oidcOpenWebUIClientSecret string

@description('Deploy LibreChat and LibreChat Admin Panel in addition to Open WebUI.')
param deployLibreChat bool = false

@description('LibreChat container image.')
param libreChatImage string = 'librechat/librechat:v0.8.5'

@description('Optional custom URL of LibreChat. Leave empty to auto-derive from the Container Apps environment default domain.')
param libreChatUrl string = ''

@secure()
@description('LibreChat Entra application client ID.')
param oidcLibreChatClientId string = ''

@secure()
@description('LibreChat Entra application client secret.')
param oidcLibreChatClientSecret string = ''

@secure()
@description('LibreChat JWT signing secret.')
param librechatJwtSecret string = ''

@secure()
@description('LibreChat refresh-token signing secret.')
param librechatJwtRefreshSecret string = ''

@secure()
@description('LibreChat OpenID session secret.')
param librechatOidcSessionSecret string = ''

@description('LibreChat Admin Panel container image.')
param libreChatAdminImage string = 'ghcr.io/clickhouse/librechat-admin-panel:latest'

@description('Optional custom URL of the LibreChat Admin Panel. Leave empty to auto-derive from the Container Apps environment default domain.')
param libreChatAdminUrl string = ''

@secure()
@description('Random secret used to encrypt LibreChat Admin Panel sessions.')
param librechatAdminSessionSecret string = ''

var litellmDatabaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServerName}.postgres.database.azure.com:5432/litellm?sslmode=require'
var openWebUIDatabaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServerName}.postgres.database.azure.com:5432/openwebui?sslmode=require'

var openWebUiEffectiveUrl = !empty(openWebUiUrl) ? openWebUiUrl : 'https://${openWebUIName}.${containerEnv.outputs.defaultDomain}'
var libreChatEffectiveUrl = !empty(libreChatUrl) ? libreChatUrl : 'https://${libreChatName}.${containerEnv.outputs.defaultDomain}'
var libreChatAdminEffectiveUrl = !empty(libreChatAdminUrl) ? libreChatAdminUrl : 'https://${libreChatAdminName}.${containerEnv.outputs.defaultDomain}'
var oidcOpenWebUIRedirectUri = '${openWebUiEffectiveUrl}/oauth/oidc/callback'

var azureOpenAIEffectiveKey = !empty(azureOpenAIKeyOverride) ? azureOpenAIKeyOverride : aoai.outputs.azureOpenAIKey

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
    adminPanelUrl: libreChatAdminEffectiveUrl
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
  }
  dependsOn: [
    keyVault
    librechat
  ]
}

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
