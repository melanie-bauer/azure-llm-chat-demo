// Azure Key Vault deployed via AVM.
// This module creates:
// - the Key Vault
// - role assignments for app identity and admin principal
// - all required secrets
//
// NOTE: No explicit `dependsOn` to role assignments is required here.
// AVM handles resource ordering internally.

param keyVaultName string
param location string = resourceGroup().location

@description('Resource tags applied to the vault.')
param tags object = {}

@description('Object ID (principal ID) of the admin user/group/service principal in Entra ID.')
param adminPrincipalId string

@description('Principal type for admin principal.')
@allowed([ 'User', 'Group', 'ServicePrincipal' ])
param adminPrincipalType string = 'User'

@description('Principal ID of the user-assigned managed identity used by Container Apps.')
param managedIdentityPrincipalId string

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

@description('Enable purge protection. Once enabled it cannot be disabled.')
param enablePurgeProtection bool = false

@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

@secure()
param litellmMasterKeyValue string

@secure()
param postgresUsernameValue string

@secure()
param postgresPasswordValue string

@secure()
param litellmDatabaseUrlValue string

@secure()
param openWebUIDatabaseUrlValue string

@secure()
param openWebUISecretKeyValue string

@secure()
param redisUrlValue string

@secure()
param oidcOpenWebUIClientId string

@secure()
param oidcOpenWebUIClientSecret string

@secure()
param oidcLibreChatClientId string = ''

@secure()
param oidcLibreChatClientSecret string = ''

@secure()
param azureOpenAIKeyValue string = ''

@secure()
param librechatJwtSecretValue string = ''

@secure()
param librechatJwtRefreshSecretValue string = ''

@secure()
param librechatMongoUriValue string = ''

@secure()
param librechatOidcSessionSecretValue string = ''

@secure()
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
  { name: 'LibreChatMongoUri',          value: librechatMongoUriValue }
  { name: 'LibreChatOidcSessionSecret', value: librechatOidcSessionSecretValue }
  { name: 'AzureOpenAIKey',             value: azureOpenAIKeyValue }
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
