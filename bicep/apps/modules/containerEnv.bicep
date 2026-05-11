// Container Apps managed environment + Azure Files mounts for the
// LiteLLM config (always) and the LibreChat config (when enabled).

param envName string
param location string
param logsCustomerId string

@secure()
param logsKey string

param storageAccountName string

@secure()
param storageAccountKey string

param litellmShareName string
param librechatShareName string = ''
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
