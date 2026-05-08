// LiteLLM proxy as a Container App.
// Public ingress on port 4000. Auth is enforced by LITELLM_MASTER_KEY
// and per-virtual-key access controls inside the proxy itself.
// Secrets are pulled from Key Vault via the user-assigned managed identity.

param liteLLMName string
param liteLLMImage string
param location string
param envId string
param userIdentityResourceId string
param keyVaultName string

@description('Optional Azure OpenAI endpoint to inject as AZURE_API_BASE.')
param azureOpenAIBaseUrl string = ''

@description('Optional Azure OpenAI api-version.')
param azureOpenAIApiVersion string = ''

@description('Set true if Azure OpenAI is reached via key (secret AzureOpenAIKey in KV).')
param useAzureOpenAIKey bool = false

@minValue(1)
param minReplicas int = 1

@minValue(1)
param maxReplicas int = 1

@description('CPU cores per replica.')
param cpu string = '0.5'

@description('Memory per replica.')
param memory string = '1Gi'

var keyVaultBase = 'https://${keyVaultName}.vault.azure.net/secrets'

var baseSecrets = [
  {
    name: 'litellm-master-key'
    keyVaultUrl: '${keyVaultBase}/LiteLLMMasterKey'
    identity: userIdentityResourceId
  }
  {
    name: 'litellm-database-url'
    keyVaultUrl: '${keyVaultBase}/LiteLLMDatabaseUrl'
    identity: userIdentityResourceId
  }
]

var azureOpenAIKeySecret = [
  {
    name: 'azure-openai-key'
    keyVaultUrl: '${keyVaultBase}/AzureOpenAIKey'
    identity: userIdentityResourceId
  }
]

var allSecrets = useAzureOpenAIKey ? concat(baseSecrets, azureOpenAIKeySecret) : baseSecrets

var baseEnv = [
  { name: 'LITELLM_MASTER_KEY', secretRef: 'litellm-master-key' }
  { name: 'DATABASE_URL', secretRef: 'litellm-database-url' }
  { name: 'STORE_MODEL_IN_DB', value: 'True' }
  { name: 'CONFIG_FILE_PATH', value: '/app/config/litellm_config.yaml' }
  { name: 'LITELLM_LOG', value: 'INFO' }
]

var azureEnv = empty(azureOpenAIBaseUrl) ? [] : [
  { name: 'AZURE_API_BASE', value: azureOpenAIBaseUrl }
  { name: 'AZURE_API_VERSION', value: azureOpenAIApiVersion }
]

var azureKeyEnv = useAzureOpenAIKey ? [
  { name: 'AZURE_API_KEY', secretRef: 'azure-openai-key' }
] : []

var envVars = concat(baseEnv, azureEnv, azureKeyEnv)

resource liteLLMApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: liteLLMName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: envId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 4000
        transport: 'auto'
        allowInsecure: false
      }
      secrets: allSecrets
    }
    template: {
      containers: [
        {
          name: 'litellm'
          image: liteLLMImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: envVars
          volumeMounts: [
            {
              volumeName: 'litellm-config'
              mountPath: '/app/config'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/liveliness'
                port: 4000
              }
              initialDelaySeconds: 30
              periodSeconds: 30
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'litellm-config'
          storageType: 'AzureFile'
          storageName: 'litellm-config'
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = liteLLMApp.properties.configuration.ingress.fqdn
output internalUrl string = 'http://${liteLLMName}'
output publicUrl string = 'https://${liteLLMApp.properties.configuration.ingress.fqdn}'
