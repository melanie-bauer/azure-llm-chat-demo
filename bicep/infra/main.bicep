targetScope = 'resourceGroup'

@description('Project short-name. Used to derive deterministic resource names.')
param projectName string = 'llmchat'

@description('Tags applied to every resource provisioned by infra.')
param tags object = {}

@description('Azure region for infra resources.')
param location string = resourceGroup().location

var abbrs = loadJsonContent('../abbreviations.json')

var userIdentityName = '${abbrs.ManagedIdentity}-${projectName}'
var azureOpenAIName = '${abbrs.AzureOpenAIService}-${projectName}'

@description('Whether Azure OpenAI public network access is enabled.')
@allowed([ 'Enabled', 'Disabled' ])
param azureOpenAIPublicNetworkAccess string = 'Enabled'

module mi './managedIdentity.bicep' = {
  name: 'managedIdentity'
  params: {
    name: userIdentityName
    location: location
    tags: tags
  }
}

module aoai './azureOpenAI.bicep' = {
  name: 'aoai'
  params: {
    openAIName: azureOpenAIName
    location: location
    publicNetworkAccess: azureOpenAIPublicNetworkAccess
  }
}

output managedIdName string = mi.outputs.managedIdName
output managedIdResourceId string = mi.outputs.managedIdResourceId
output managedIdPrincipalId string = mi.outputs.managedIdPrincipalId
output managedIdClientId string = mi.outputs.managedIdClientId

output azureOpenAIName string = aoai.outputs.azureOpenAIName
output azureOpenAIEndpoint string = aoai.outputs.azureOpenAIEndpoint
output azureOpenAIResourceId string = aoai.outputs.azureOpenAIResourceId
