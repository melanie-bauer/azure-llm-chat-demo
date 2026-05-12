@description('Log Analytics workspace name.')
param workspaceName string

@description('Azure region for the workspace.')
param location string = resourceGroup().location

@description('Log Analytics retention period in days.')
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
