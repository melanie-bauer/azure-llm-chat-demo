@description('Azure Cache for Redis name.')
param redisName string

@description('Azure region for Redis.')
param location string

@description('Redis SKU name.')
@allowed([ 'Basic', 'Standard', 'Premium' ])
param skuName string = 'Basic'

@description('Redis SKU family.')
@allowed([ 'C', 'P' ])
param skuFamily string = 'C'

@minValue(0)
@description('Redis SKU capacity.')
param skuCapacity int = 0

@description('Whether Redis public network access is enabled.')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: skuCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisVersion: '6'
    publicNetworkAccess: publicNetworkAccess
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

output redisHost string = '${redis.name}.redis.cache.windows.net'
output redisPort int = redis.properties.sslPort

@secure()
output redisUrl string = 'rediss://:${redis.listKeys().primaryKey}@${redis.name}.redis.cache.windows.net:${redis.properties.sslPort}/0'
