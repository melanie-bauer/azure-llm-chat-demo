// Storage account with Azure Files shares for the LiteLLM config file
// and (optionally) the LibreChat config file. Open WebUI does not use
// Azure Files; it runs on PostgreSQL + Redis instead.

param storageAccountName string
param location string
param litellmShareName string = 'litellm-config'
param librechatShareName string = 'librechat-config'
param deployLibreChat bool = false
param fileShareQuotaGB int = 5

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource litellmConfigShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: litellmShareName
  properties: {
    shareQuota: fileShareQuotaGB
    accessTier: 'Hot'
  }
}

resource librechatConfigShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = if (deployLibreChat) {
  parent: fileService
  name: librechatShareName
  properties: {
    shareQuota: fileShareQuotaGB
    accessTier: 'Hot'
  }
}

var litellmConfig = loadTextContent('../litellm_config.yaml')
var librechatConfig = loadTextContent('../librechat.yaml')

resource uploadLitellmConfig 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'upload-litellm-config'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.61.0'
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      { name: 'AZURE_STORAGE_ACCOUNT', value: storageAccount.name }
      { name: 'AZURE_STORAGE_KEY', secureValue: storageAccount.listKeys().keys[0].value }
      { name: 'SHARE_NAME', value: litellmConfigShare.name }
      { name: 'CONTENT', value: litellmConfig }
    ]
    scriptContent: 'printf "%s" "$CONTENT" > litellm_config.yaml && az storage file upload --source litellm_config.yaml --share-name "$SHARE_NAME" --auth-mode key --only-show-errors'
  }
}

resource uploadLibrechatConfig 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (deployLibreChat) {
  name: 'upload-librechat-config'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.61.0'
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      { name: 'AZURE_STORAGE_ACCOUNT', value: storageAccount.name }
      { name: 'AZURE_STORAGE_KEY', secureValue: storageAccount.listKeys().keys[0].value }
      { name: 'SHARE_NAME', value: librechatShareName }
      { name: 'CONTENT', value: librechatConfig }
    ]
    scriptContent: 'printf "%s" "$CONTENT" > librechat.yaml && az storage file upload --source librechat.yaml --share-name "$SHARE_NAME" --auth-mode key --only-show-errors'
  }
  dependsOn: [
    librechatConfigShare
  ]
}

output storageAccountName string = storageAccount.name

@secure()
output storageAccountKey string = storageAccount.listKeys().keys[0].value

output litellmShareName string = litellmShareName
output librechatShareName string = librechatShareName
