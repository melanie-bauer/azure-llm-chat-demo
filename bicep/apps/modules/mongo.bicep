// Azure Cosmos DB for MongoDB (serverless) used by LibreChat.
// Serverless billing is per-request, the cheapest option for low-traffic
// demos. LibreChat treats this as a standard MongoDB endpoint.

param accountName string
param location string
param databaseName string = 'LibreChat'

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    apiProperties: {
      serverVersion: '7.0'
    }
    capabilities: [
      { name: 'EnableServerless' }
      { name: 'EnableMongo' }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    publicNetworkAccess: publicNetworkAccess
    minimalTlsVersion: 'Tls12'
    disableLocalAuth: false
  }
}

resource db 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-11-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

output mongoHost string = '${account.name}.mongo.cosmos.azure.com'
output databaseName string = db.name

@secure()
output mongoConnectionString string = account.listConnectionStrings().connectionStrings[0].connectionString
