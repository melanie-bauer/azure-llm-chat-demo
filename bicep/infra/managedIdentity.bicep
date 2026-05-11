// User-assigned managed identity for the application stack.
// The identity is created here (infra layer) so the Key Vault module in
// bicep/apps can reference it by name and grant it Key Vault Secrets User
// at deploy time. Role assignments to the vault deliberately live with the
// vault (apps layer), not here, because the vault is created later.

@description('Name of the user-assigned managed identity. Must match `userIdentityName` in bicep/apps/main.bicep.')
param name string

param location string = resourceGroup().location

@description('Tags applied to the identity.')
param tags object = {}

module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  params: {
    name: name
    location: location
    tags: tags
  }
}

output managedIdName string = identity.outputs.name
output managedIdResourceId string = identity.outputs.resourceId
output managedIdPrincipalId string = identity.outputs.principalId
output managedIdClientId string = identity.outputs.clientId
