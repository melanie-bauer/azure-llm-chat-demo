@description('Name of the user-assigned managed identity. Must match `userIdentityName` in bicep/apps/main.bicep.')
param name string

@description('Azure region for the managed identity.')
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
