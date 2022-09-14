targetScope = 'resourceGroup'

param location string = 'westeurope'

param uniqueName string = uniqueString(resourceGroup().id)

param iothubName string = 'iothub${uniqueName}'
param iothubSkuCapacity int = 1
param iothubSkuName string = 'F1'

param datalakeName string = 'datalake${uniqueName}'
param datalakeSkuName string = 'Standard_RAGRS'

param funcName string = 'func${uniqueName}'
param funcStorageName string = 'funcstrg${uniqueName}'
param funcHostingName string = 'funchosting${uniqueName}'

param appinsightsName string = 'appinsights${uniqueName}'

param synapseName string = 'synapse${uniqueName}'
param synapseManagedName string = 'managed${uniqueName}'
param synapseAdminUsername string = 'synapseadmin'
@secure()
param synapseAdminPassword string

param keyvaultName string = 'keyvault${uniqueName}'

resource iothub 'Microsoft.Devices/IotHubs@2021-07-01' = {
  name: iothubName
  location: location
  tags: {    
  }
  sku: {
    capacity: iothubSkuCapacity
    name: iothubSkuName
  }  
  properties: {   
    messagingEndpoints: {}    
    
    routing: {
      endpoints: {
        
        storageContainers: [
          {
            authenticationType: 'keyBased'
            batchFrequencyInSeconds: 100
            connectionString: 'DefaultEndpointsProtocol=https;AccountName=${telemetrydatalake.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(telemetrydatalake.id, telemetrydatalake.apiVersion).keys[0].value}'
            containerName: 'telemetry-rawdata'
            encoding: 'JSON'            
            fileNameFormat: 'year={YYYY}/month={YYYY}{MM}/date={YYYY}{MM}{DD}/{iothub}_{partition}_{YYYY}{MM}{DD}{HH}{mm}.json'            
            maxChunkSizeInBytes: 104857600
            name: 'telemetry-rawdata'
            resourceGroup: resourceGroup().name            
          }
        ]
      }      
      routes: [
        {
           condition: 'true'
           endpointNames: [ 
             'telemetry-rawdata' 
           ]
           isEnabled: true
           name: 'telemetry-rawdata-route'
           source: 'DeviceMessages'
        }
      ]
    }      
  }   
  dependsOn: [
    telemetrydatalake        
  ]
} 

resource telemetrydatalake 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: datalakeName
  location: location
  tags: {    
  }
  sku: {
    name: datalakeSkuName
  }
  kind: 'StorageV2'  
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true            
    isHnsEnabled: true    
    minimumTlsVersion: 'TLS1_2'
  }  

  resource blobSvc 'blobServices' = {
    name: 'default'   // Always has value 'default'
    resource rawdataContainer 'containers@2021-04-01' = {    
      name: 'telemetry-rawdata'   
      properties:{
        publicAccess: 'Container'
      }   
    }   
    resource parquetstorageContainer 'containers@2021-04-01' = {    
      name: 'parquet-contents'      
      properties:{
        publicAccess: 'Container'
      }   
    }      
  }  
}

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: funcStorageName
  location: location
  tags: {    
  }
  sku: {
    name: 'Standard_RAGRS'
  }
  kind: 'StorageV2'  
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true            
    isHnsEnabled: true    
    minimumTlsVersion: 'TLS1_2'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appinsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
    // 'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
}

resource functionAppHostingPlan 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: funcHostingName
  location: location
  sku: {
    name: 'Y1' 
    tier: 'Dynamic'
  }
  properties:{
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: funcName
  location: location  
  kind: 'functionapp,linux'  
  identity: {
    type: 'SystemAssigned'    
  }
  properties: {      
    httpsOnly: true    
    serverFarmId: functionAppHostingPlan.id
    siteConfig: {      
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionAppStorageAccount.id, functionAppStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }   
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }     
        {
          name: 'SettingsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionAppStorageAccount.id, functionAppStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'RawTelemetryConnectionString'
          value: 'Data Source=${synapse.properties.connectivityEndpoints.sqlOnDemand},1433;Initial Catalog=db1'
        }
        {
          name: 'ParquetStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${telemetrydatalake.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(telemetrydatalake.id, telemetrydatalake.apiVersion).keys[0].value}'
        }
      ]
      autoHealEnabled: false     
      }    
  }
  dependsOn: [
    functionAppStorageAccount
    functionAppHostingPlan
    appInsights
    synapse
  ]
}

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01-preview' = {
  name: synapseName
  location: location  
  identity: {
    type: 'SystemAssigned'    
  }
  properties: {
    connectivityEndpoints: {}    
    defaultDataLakeStorage: {
      accountUrl: telemetrydatalake.properties.primaryEndpoints.dfs
      filesystem: 'filesystem'
    }
    encryption: {      
    }
    managedResourceGroupName: synapseManagedName    
    sqlAdministratorLogin: synapseAdminUsername
    sqlAdministratorLoginPassword: synapseAdminPassword
  }
  dependsOn: [
    telemetrydatalake
  ]
}

resource synapseFirewallRuleAllowAll 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01-preview' = {
  name: '${synapse.name}/allowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyvaultName
  location: location
  tags: {    
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }    
    enableSoftDelete: false
    accessPolicies: []
    tenantId: subscription().tenantId
  }

  resource synapseAdminPasswordResource 'secrets@2021-06-01-preview' = {
    name: 'SynapseAdminPassword'
    tags: {    
    }
    properties: {
      attributes: {
        enabled: true      
      }
      contentType: 'string'
      value: synapseAdminPassword
    }
  }
}

var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource functionAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(telemetrydatalake.id, functionApp.id, storageBlobDataContributorRoleID)
  scope: telemetrydatalake
  properties: {      
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
  dependsOn:[
    functionApp
    telemetrydatalake
  ]
}
