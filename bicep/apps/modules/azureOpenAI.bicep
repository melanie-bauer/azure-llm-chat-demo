// References an existing Azure OpenAI account and exposes its endpoint + key
// to the rest of the platform. The account itself (and its model deployments)
// is provisioned by the standalone bicep/azureOpenAI.bicep, which must be
// deployed BEFORE main.bicep runs.

param openAIName string

resource openAI 'Microsoft.CognitiveServices/accounts@2025-09-01' existing = {
  name: openAIName
}

output azureOpenAIName string = openAIName
output azureOpenAIEndpoint string = openAI.properties.endpoint
output azureOpenAIResourceId string = openAI.id

@secure()
output azureOpenAIKey string = openAI.listKeys().key1
