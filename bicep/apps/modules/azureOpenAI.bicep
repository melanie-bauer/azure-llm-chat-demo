@description('Name of the existing Azure OpenAI account created by the infra layer.')
param openAIName string

resource openAI 'Microsoft.CognitiveServices/accounts@2025-09-01' existing = {
  name: openAIName
}

output azureOpenAIName string = openAIName
output azureOpenAIEndpoint string = openAI.properties.endpoint
output azureOpenAIResourceId string = openAI.id

@secure()
output azureOpenAIKey string = openAI.listKeys().key1
