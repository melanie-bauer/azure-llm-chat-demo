@description('Cosmos DB for MongoDB account name.')
param accountName string

@description('Azure region for Cosmos DB.')
param location string

@description('MongoDB database name used by LibreChat.')
param databaseName string = 'LibreChat'

@description('Whether Cosmos DB public network access is enabled.')
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
