// Log Analytics workspace used by the Container Apps environment.

param workspaceName string
param location string = resourceGroup().location
param retentionDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionDays
  }
}

output workspaceId string = logAnalytics.properties.customerId

@secure()
output workspaceKey string = logAnalytics.listKeys().primarySharedKey

output resourceId string = logAnalytics.id
