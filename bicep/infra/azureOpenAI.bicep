targetScope = 'resourceGroup'

@description('Name of the Azure OpenAI account to create.')
param openAIName string = 'llmchat-openai'

@description('Azure region for the OpenAI account.')
param location string = resourceGroup().location

@description('Account SKU. S0 is the only generally available SKU for OpenAI.')
param skuName string = 'S0'

@allowed([ 'Enabled', 'Disabled' ])
@description('Whether Azure OpenAI public network access is enabled.')
param publicNetworkAccess string = 'Enabled'

resource openAI 'Microsoft.CognitiveServices/accounts@2025-09-01' = {
  name: openAIName
  location: location
  sku: { name: skuName }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

var models = loadJsonContent('./models.json').models

@batchSize(1)
resource openAIModels 'Microsoft.CognitiveServices/accounts/deployments@2025-09-01' = [for model in models: {
  parent: openAI
  name: model.deploymentName
  sku: {
    name: 'Standard'
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.modelName
      version: model.version
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

output azureOpenAIName string = openAI.name
output azureOpenAIEndpoint string = openAI.properties.endpoint
output azureOpenAIResourceId string = openAI.id

@secure()
output azureOpenAIKey string = openAI.listKeys().key1
