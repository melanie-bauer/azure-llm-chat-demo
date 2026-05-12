@description('Container Apps managed environment name.')
param envName string

@description('Azure region for the managed environment.')
param location string

@description('Log Analytics workspace customer ID.')
param logsCustomerId string

@secure()
@description('Log Analytics shared key.')
param logsKey string

@description('Storage account name that hosts config file shares.')
param storageAccountName string

@secure()
@description('Storage account key for mounting Azure Files into Container Apps.')
param storageAccountKey string

@description('Azure Files share name for LiteLLM config.')
param litellmShareName string

@description('Azure Files share name for LibreChat config.')
param librechatShareName string = ''

@description('Whether to mount the LibreChat config share.')
param deployLibreChat bool = false

resource containerEnv 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logsCustomerId
        sharedKey: logsKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    zoneRedundant: false
  }
}

resource envStorageLiteLLM 'Microsoft.App/managedEnvironments/storages@2024-10-02-preview' = {
  parent: containerEnv
  name: 'litellm-config'
  properties: {
    azureFile: {
      accountName: storageAccountName
      shareName: litellmShareName
      accountKey: storageAccountKey
      accessMode: 'ReadOnly'
    }
  }
}

resource envStorageLibreChat 'Microsoft.App/managedEnvironments/storages@2024-10-02-preview' = if (deployLibreChat) {
  parent: containerEnv
  name: 'librechat-config'
  properties: {
    azureFile: {
      accountName: storageAccountName
      shareName: librechatShareName
      accountKey: storageAccountKey
      accessMode: 'ReadOnly'
    }
  }
}

output environmentId string = containerEnv.id
output defaultDomain string = containerEnv.properties.defaultDomain
output staticIp string = containerEnv.properties.staticIp
