@description('Azure region for PostgreSQL Flexible Server.')
param location string

@description('PostgreSQL Flexible Server name.')
param serverName string

@description('PostgreSQL administrator login name.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password.')
param administratorLoginPassword string

@description('Whether PostgreSQL public network access is enabled.')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

@description('Whether to add the Azure-services firewall rule.')
param allowAllAzureServices bool = true

@description('Explicit IPv4 ranges to add as PostgreSQL firewall rules.')
param allowedIpRanges array = []

@description('PostgreSQL Flexible Server SKU tier.')
param serverEdition string = 'Burstable'

@description('PostgreSQL Flexible Server SKU name.')
param dbInstanceType string = 'Standard_B1ms'

@description('PostgreSQL storage size in GB.')
param storageSizeGB int = 32

@description('PostgreSQL major version.')
param postgresVersion string = '16'

@description('LiteLLM database name.')
param databaseName string = 'litellm'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: dbInstanceType
    tier: serverEdition
  }
  properties: {
    version: postgresVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    network: {
      publicNetworkAccess: publicNetworkAccess
    }
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource pgvectorExt 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresServer
  name: 'azure.extensions'
  properties: {
    value: 'VECTOR'
    source: 'user-override'
  }
}

resource dbLitellm 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: databaseName
  dependsOn: [pgvectorExt]
}

resource dbOpenWebUI 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: 'openwebui'
  dependsOn: [dbLitellm]
}

resource fwAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (allowAllAzureServices) {
  parent: postgresServer
  name: 'allow-azure-services'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [dbOpenWebUI]
}

resource fwAllowed 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [for (range, i) in allowedIpRanges: {
  parent: postgresServer
  name: 'allow-${i}'
  properties: {
    startIpAddress: range.start
    endIpAddress: range.end
  }
  dependsOn: allowAllAzureServices ? [fwAllowAzure] : [dbOpenWebUI]
}]

output postgresHost string = '${serverName}.postgres.database.azure.com'
output postgresFqdn string = postgresServer.properties.fullyQualifiedDomainName
output litellmDatabaseName string = dbLitellm.name
output openWebUIDatabaseName string = dbOpenWebUI.name