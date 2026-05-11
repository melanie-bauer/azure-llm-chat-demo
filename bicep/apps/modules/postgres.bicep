// Azure Database for PostgreSQL Flexible Server.
// pgvector extension is enabled via server parameter so Open WebUI can
// use VECTOR_DB=pgvector.

param location string
param serverName string
param administratorLogin string

@secure()
param administratorLoginPassword string

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

@description('Allow other Azure services (Container Apps egress IPs are dynamic). Demo only.')
param allowAllAzureServices bool = true

@description('Optional list of explicit IPv4 ranges to whitelist (e.g. your office IP).')
param allowedIpRanges array = []

param serverEdition string = 'Burstable'
param dbInstanceType string = 'Standard_B1ms'
param storageSizeGB int = 32
param postgresVersion string = '16'
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
}

resource dbOpenWebUI 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: 'openwebui'
}

resource fwAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (allowAllAzureServices) {
  parent: postgresServer
  name: 'allow-azure-services'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource fwAllowed 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [for (range, i) in allowedIpRanges: {
  parent: postgresServer
  name: 'allow-${i}'
  properties: {
    startIpAddress: range.start
    endIpAddress: range.end
  }
}]

output postgresHost string = '${serverName}.postgres.database.azure.com'
output postgresFqdn string = postgresServer.properties.fullyQualifiedDomainName
output litellmDatabaseName string = dbLitellm.name
output openWebUIDatabaseName string = dbOpenWebUI.name