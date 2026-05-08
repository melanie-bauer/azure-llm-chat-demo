// Azure OpenAI account and model deployments.
// When createAzureOpenAI=false the account is referenced as 'existing'
// and only the deployments from models.json are reconciled.

param openAIName string
param location string
param createAzureOpenAI bool = false
param createOpenAIModels bool = true

resource openAINew 'Microsoft.CognitiveServices/accounts@2025-09-01' = if (createAzureOpenAI) {
  name: openAIName
  location: location
  sku: { name: 'S0' }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Single symbolic reference used for deployments. dependsOn ensures
// the account exists before models are reconciled when createAzureOpenAI=true.
resource openAI 'Microsoft.CognitiveServices/accounts@2025-09-01' existing = {
  name: openAIName
  dependsOn: [
    openAINew
  ]
}

var models = createOpenAIModels ? loadJsonContent('../models.json').models : []

@batchSize(1)
resource openAIModels 'Microsoft.CognitiveServices/accounts/deployments@2025-09-01' = [for (model, i) in models: {
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

output azureOpenAIEndpoint string = openAI.properties.endpoint
output azureOpenAIName string = openAIName
output azureOpenAIResourceId string = openAI.id

@secure()
output azureOpenAIKey string = openAI.listKeys().key1
