// Azure Cache for Redis. Used by Open WebUI for token revocation and
// websocket fan-out, and optionally by LibreChat (USE_REDIS=true).

param redisName string
param location string

@allowed([ 'Basic', 'Standard', 'Premium' ])
param skuName string = 'Basic'

@allowed([ 'C', 'P' ])
param skuFamily string = 'C'

@minValue(0)
param skuCapacity int = 0

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
