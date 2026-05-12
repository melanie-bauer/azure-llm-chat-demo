@description('Container App name for LiteLLM.')
param liteLLMName string

@description('LiteLLM container image.')
param liteLLMImage string

@description('Azure region for the Container App.')
param location string

@description('Resource ID of the Container Apps managed environment.')
param envId string

@description('Resource ID of the user-assigned managed identity used to read Key Vault secrets.')
param userIdentityResourceId string

@description('Key Vault name containing LiteLLM runtime secrets.')
param keyVaultName string

@description('Azure OpenAI endpoint injected as AZURE_API_BASE. Leave empty to omit the variable.')
param azureOpenAIBaseUrl string = ''

@description('Azure OpenAI API version injected as AZURE_API_VERSION.')
param azureOpenAIApiVersion string = ''

@description('Whether LiteLLM should read AzureOpenAIKey from Key Vault.')
param useAzureOpenAIKey bool = false

@minValue(1)
@description('Minimum number of LiteLLM replicas.')
param minReplicas int = 1

@minValue(1)
@description('Maximum number of LiteLLM replicas.')
param maxReplicas int = 1

@description('CPU cores per replica.')
param cpu string = '1.0'

@description('Memory per replica.')
param memory string = '2Gi'

var keyVaultBase = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets'

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
              type: 'Startup'
              httpGet: {
                path: '/health/liveliness'
                port: 4000
              }
              initialDelaySeconds: 15
              periodSeconds: 10
              failureThreshold: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/liveliness'
                port: 4000
              }
              initialDelaySeconds: 60
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
