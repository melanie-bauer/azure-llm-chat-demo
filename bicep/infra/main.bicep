targetScope = 'resourceGroup'

// =====================================================================
// Infra layer: stable, slow-changing resources that the application
// stack (bicep/apps) consumes by name.
//
//   - User-assigned managed identity (used by every Container App)
//   - Azure OpenAI account + model deployments
//
// Deploy this BEFORE bicep/apps/main.bicep. Use the same `projectName` as the
// apps deployment so abbreviation-based names align.
// =====================================================================

@description('Project short-name. Used to derive deterministic resource names.')
param projectName string = 'llmchat'

@description('Tags applied to every resource provisioned by infra.')
param tags object = {}

param location string = resourceGroup().location

var abbrs = loadJsonContent('../abbreviations.json')

var userIdentityName = '${abbrs.ManagedIdentity}-${projectName}'
var azureOpenAIName = '${abbrs.AzureOpenAIService}-${projectName}'

// -------- managed identity --------
// -------- Azure OpenAI --------
@allowed([ 'Enabled', 'Disabled' ])
param azureOpenAIPublicNetworkAccess string = 'Enabled'

// =====================================================================
// modules
// =====================================================================

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

// =====================================================================
// outputs (consumed by bicep/apps/main.bicep)
// =====================================================================

output managedIdName string = mi.outputs.managedIdName
output managedIdResourceId string = mi.outputs.managedIdResourceId
output managedIdPrincipalId string = mi.outputs.managedIdPrincipalId
output managedIdClientId string = mi.outputs.managedIdClientId

output azureOpenAIName string = aoai.outputs.azureOpenAIName
output azureOpenAIEndpoint string = aoai.outputs.azureOpenAIEndpoint
output azureOpenAIResourceId string = aoai.outputs.azureOpenAIResourceId
