@description('Key Vault name.')
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Resource tags applied to the vault.')
param tags object = {}

@description('Object ID (principal ID) of the admin user/group/service principal in Entra ID.')
param adminPrincipalId string

@description('Principal type for the admin principal.')
@allowed([ 'User', 'Group', 'ServicePrincipal' ])
param adminPrincipalType string = 'User'

@description('Principal ID of the user-assigned managed identity used by Container Apps.')
param managedIdentityPrincipalId string

@allowed([ 'Enabled', 'Disabled' ])
@description('Whether Key Vault public network access is enabled.')
param publicNetworkAccess string = 'Enabled'

@description('Enable purge protection. Once enabled it cannot be disabled.')
param enablePurgeProtection bool = false

@minValue(7)
@maxValue(90)
@description('Soft-delete retention period in days.')
param softDeleteRetentionInDays int = 7

@secure()
@description('Secret value for LiteLLM master key.')
param litellmMasterKeyValue string

@secure()
@description('Secret value for PostgreSQL administrator username.')
param postgresUsernameValue string

@secure()
@description('Secret value for PostgreSQL administrator password.')
param postgresPasswordValue string

@secure()
@description('Secret value for LiteLLM PostgreSQL connection string.')
param litellmDatabaseUrlValue string

@secure()
@description('Secret value for Open WebUI PostgreSQL connection string.')
param openWebUIDatabaseUrlValue string

@secure()
@description('Secret value for Open WebUI signing secret.')
param openWebUISecretKeyValue string

@secure()
@description('Secret value for Redis connection string.')
param redisUrlValue string

@secure()
@description('Secret value for Open WebUI OIDC client ID.')
param oidcOpenWebUIClientId string

@secure()
@description('Secret value for Open WebUI OIDC client secret.')
param oidcOpenWebUIClientSecret string

@secure()
@description('Secret value for LibreChat OIDC client ID.')
param oidcLibreChatClientId string = ''

@secure()
@description('Secret value for LibreChat OIDC client secret.')
param oidcLibreChatClientSecret string = ''

@secure()
@description('Secret value for Azure OpenAI API key.')
param azureOpenAIKeyValue string = ''

@secure()
@description('Secret value for LibreChat JWT signing secret.')
param librechatJwtSecretValue string = ''

@secure()
@description('Secret value for LibreChat refresh-token signing secret.')
param librechatJwtRefreshSecretValue string = ''

@secure()
@description('Secret value for LibreChat MongoDB connection string.')
param librechatMongoUriValue string = ''

@secure()
@description('Secret value for LibreChat OpenID session secret.')
param librechatOidcSessionSecretValue string = ''

@secure()
@description('Secret value for LibreChat Admin Panel session secret.')
param librechatAdminSessionSecretValue string = ''

@secure()
@description('Secret value for the LiteLLM virtual key used by frontends.')
param litellmServiceKeyValue string

var roles = loadJsonContent('../../azure-roles.json')

var requiredSecrets = [
  { name: 'LiteLLMMasterKey',          value: litellmMasterKeyValue }
  { name: 'LiteLLMDatabaseUrl',        value: litellmDatabaseUrlValue }
  { name: 'OpenWebUIDatabaseUrl',      value: openWebUIDatabaseUrlValue }
  { name: 'WebUISecretKey',            value: openWebUISecretKeyValue }
  { name: 'RedisUrl',                  value: redisUrlValue }
  { name: 'PostgresUsername',          value: postgresUsernameValue }
  { name: 'PostgresPassword',          value: postgresPasswordValue }
  { name: 'OpenWebUIOidcClientId',     value: oidcOpenWebUIClientId }
  { name: 'OpenWebUIOidcClientSecret', value: oidcOpenWebUIClientSecret }
  { name: 'LiteLLMServiceKey',         value: litellmServiceKeyValue }
]

var optionalSecrets = filter([
  { name: 'LibreChatOidcClientId',      value: oidcLibreChatClientId }
  { name: 'LibreChatOidcClientSecret',  value: oidcLibreChatClientSecret }
  { name: 'LibreChatJwtSecret',         value: librechatJwtSecretValue }
  { name: 'LibreChatJwtRefreshSecret',  value: librechatJwtRefreshSecretValue }
  { name: 'LibreChatMongoUri',           value: librechatMongoUriValue }
  { name: 'LibreChatOidcSessionSecret',  value: librechatOidcSessionSecretValue }
  { name: 'LibreChatAdminSessionSecret', value: librechatAdminSessionSecretValue }
  { name: 'AzureOpenAIKey',              value: azureOpenAIKeyValue }
], s => !empty(s.value))

var allSecrets = concat(requiredSecrets, optionalSecrets)

module vault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'kv-${keyVaultName}'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    sku: 'standard'
    enableRbacAuthorization: true
    enableVaultForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    roleAssignments: [
      {
        name: guid(keyVaultName, managedIdentityPrincipalId, roles.KeyVaultSecretsUser)
        principalId: managedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: roles.KeyVaultSecretsUser
      }
      {
        name: guid(keyVaultName, adminPrincipalId, roles.KeyVaultSecretsOfficer)
        principalId: adminPrincipalId
        principalType: adminPrincipalType
        roleDefinitionIdOrName: roles.KeyVaultSecretsOfficer
      }
    ]
    secrets: allSecrets
  }
}

output vaultName string = vault.outputs.name
output vaultUri string = vault.outputs.uri
output vaultId string = vault.outputs.resourceId
