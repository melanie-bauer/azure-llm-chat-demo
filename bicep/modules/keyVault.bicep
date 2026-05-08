// Azure Key Vault with RBAC authorization (no access policies).
// Roles assigned:
//   - Managed Identity of Container Apps -> Key Vault Secrets User (read)
//   - Admin user/group                   -> Key Vault Secrets User (read)
//   - Admin user/group (optional)        -> Key Vault Secrets Officer (write)
// Built-in role IDs:
//   Key Vault Secrets User    = 4633458b-17de-408a-b874-0445c86b69e6
//   Key Vault Secrets Officer = b86a8fe4-44ce-4948-aee5-eccb2c155cd7

param keyVaultName string
param location string

@description('Object ID of the admin user or group in Entra ID.')
param adminObjectId string

@description('Principal ID of the user-assigned managed identity used by Container Apps.')
param managedIdentityPrincipalId string

@description('If true, admin also receives Secrets Officer (write/rotate).')
param grantAdminSecretsOfficer bool = true

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

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

var roleIdSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'
var roleIdSecretsOfficer = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource raManagedIdentitySecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, managedIdentityPrincipalId, roleIdSecretsUser)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdSecretsUser)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource raAdminSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, adminObjectId, roleIdSecretsUser)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdSecretsUser)
    principalId: adminObjectId
    principalType: 'User'
  }
}

resource raAdminSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (grantAdminSecretsOfficer) {
  name: guid(vault.id, adminObjectId, roleIdSecretsOfficer)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdSecretsOfficer)
    principalId: adminObjectId
    principalType: 'User'
  }
}

// Secrets are written by the deployment principal; that principal must
// hold Secrets Officer at scope. enabledForTemplateDeployment lets ARM
// itself populate values during template execution.

resource secLitellmMasterKey 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'LiteLLMMasterKey'
  properties: { value: litellmMasterKeyValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLitellmDbUrl 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'LiteLLMDatabaseUrl'
  properties: { value: litellmDatabaseUrlValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOpenWebUIDbUrl 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'OpenWebUIDatabaseUrl'
  properties: { value: openWebUIDatabaseUrlValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOpenWebUISecretKey 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'WebUISecretKey'
  properties: { value: openWebUISecretKeyValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secRedisUrl 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'RedisUrl'
  properties: { value: redisUrlValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secPostgresUsername 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'PostgresUsername'
  properties: { value: postgresUsernameValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secPostgresPassword 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'PostgresPassword'
  properties: { value: postgresPasswordValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOidcOpenWebUIClientId 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'OpenWebUIOidcClientId'
  properties: { value: oidcOpenWebUIClientId }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOidcOpenWebUIClientSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'OpenWebUIOidcClientSecret'
  properties: { value: oidcOpenWebUIClientSecret }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOidcLibreChatClientId 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(oidcLibreChatClientId)) {
  parent: vault
  name: 'LibreChatOidcClientId'
  properties: { value: oidcLibreChatClientId }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secOidcLibreChatClientSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(oidcLibreChatClientSecret)) {
  parent: vault
  name: 'LibreChatOidcClientSecret'
  properties: { value: oidcLibreChatClientSecret }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLibreChatJwt 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(librechatJwtSecretValue)) {
  parent: vault
  name: 'LibreChatJwtSecret'
  properties: { value: librechatJwtSecretValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLibreChatJwtRefresh 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(librechatJwtRefreshSecretValue)) {
  parent: vault
  name: 'LibreChatJwtRefreshSecret'
  properties: { value: librechatJwtRefreshSecretValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLibreChatMongoUri 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(librechatMongoUriValue)) {
  parent: vault
  name: 'LibreChatMongoUri'
  properties: { value: librechatMongoUriValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLibreChatOidcSession 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(librechatOidcSessionSecretValue)) {
  parent: vault
  name: 'LibreChatOidcSessionSecret'
  properties: { value: librechatOidcSessionSecretValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secLitellmServiceKey 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: vault
  name: 'LiteLLMServiceKey'
  properties: { value: litellmServiceKeyValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

resource secAzureOpenAIKey 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(azureOpenAIKeyValue)) {
  parent: vault
  name: 'AzureOpenAIKey'
  properties: { value: azureOpenAIKeyValue }
  dependsOn: [ raAdminSecretsOfficer ]
}

output vaultUri string = vault.properties.vaultUri
output vaultName string = vault.name
output vaultId string = vault.id
