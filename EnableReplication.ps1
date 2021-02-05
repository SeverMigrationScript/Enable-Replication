
Param(
    [parameter(Mandatory=$true)]
    $CsvFilePath
)

Function LogError([string] $Message)
{
    $logDate = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
    $logMessage = [string]::Concat($logDate, "[ERROR]-", $Message)
    Write-Output $logMessage
    Write-Host $logMessage
}

Function LogErrorAndThrow([string] $Message)
{
    $logDate = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
    $logMessage = [string]::Concat($logDate, "[ERROR]-", $Message)
    Write-Output $logMessage
    Write-Error $logMessage
}

Function LogTrace([string] $Message)
{
    $logDate = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
    $logMessage = [string]::Concat($logDate, "[LOG]-", $Message)
    Write-Output $logMessage
    Write-Host $logMessage
}

LogTrace "[START]-Starting Asr Replication"
LogTrace "File: $CsvFilePath"

$resolvedCsvPath = Resolve-Path -LiteralPath $CsvFilePath
$csvObj = Import-Csv $resolvedCsvPath -Delimiter ','



class ReplicationInformation
{
    [string]$Machine
    [string]$ProtectableStatus
    [string]$ProtectionState
    [string]$ProtectionStateDescription
    [string]$Exception
    [string]$ReplicationJobId
}

class DiscoveryInformation
{
    [string]$Machine
    [string]$discoveryStatus
    [string]$discoverystate
    [string]$ProtectionStateDescription
    [string]$Exception
    [string]$ReplicationJobId
}


$protectedItemStatusArray = New-Object System.Collections.Generic.List[System.Object]

$discoveryitemArray = New-Object System.Collections.Generic.List[System.Object]


Function vmdiscovery($csvItem)
{

    $vaultName = $csvItem.VAULT_NAME
    $sourceMachineName = $csvItem.SOURCE_MACHINE_NAME
    $PrivateIP = $csvItem.PRIVATE_IP
    $sourceConfigurationServer = $csvItem.CONFIGURATION_SERVER
    $VaultSubscription=$csvItem.VAULT_SUBSCRIPTION_ID
    $SourceOS=$csvItem.SOURCE_OS
    $discoverystatusItemInfo = [discoveryInformation]::new()
    $discoverystatusItemInfo.Machine = $sourceMachineName

    Select-AzSubscription -Subscription $VaultSubscription

    $targetVault = Get-AzRecoveryServicesVault -Name $vaultName 
    if ($targetVault -eq $null)
    {
        LogErrorAndThrow "Unable to find Vault with name '$($vaultName)'"
    }

    Set-AzRecoveryServicesAsrVaultContext -Vault $targetVault

  

     $fabricServer = Get-AzRecoveryServicesAsrFabric -FriendlyName $sourceConfigurationServer
    $protectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabricServer

    
   
    try {
     $protectableVM=Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $protectionContainer -FriendlyName $sourceMachineName -ErrorAction Stop
     }
     catch 
     {
     Write-Output "stop"
     $Error[0].Exception
     }  

    if ($protectableVM -eq $null)
    {
      LogTrace "Starting Discovery Job for source '$($sourceMachineName)'"
     $discoveryjob = New-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $protectionContainer -FriendlyName $sourceMachineName -IPAddress  $PrivateIP -OSType $SourceOS
     
      Write-Host "." -NoNewline 
            
        if ($discoveryjob.State -eq 'InProgress')
        {
            sleep 30
            $asrjob = Get-AzRecoveryServicesAsrJob -Name $discoveryjob.Name
            Write-Output "$($asrjob)"
            while ($asrjob.StateDescription -ne 'Completed')
            {
                 $asrjob = Get-AzRecoveryServicesAsrJob -Name $discoveryjob.Name
                 Write-Output "Discovery $($asrjob.StateDescription)"
            }
           LogTrace "Discovery Done for VM $($sourceMachineName)" 
         
        } 
        else {
      
        LogTrace " VM $($sourceMachineName) already discovered" 
              }
        $protectedItem = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $protectionContainer -FriendlyName  $sourceMachineName
        $discoverystatusItemInfo.discoverystate = $protectedItem.ProtectionState
        $discoverystatusItemInfo.ProtectionStateDescription = $protectedItem.ProtectionStateDescription
    }
    $discoveryitemArray.Add($discoverystatusItemInfo)

}





Function StartReplicationJobItem($csvItem)
{
   
    $vaultName = $csvItem.VAULT_NAME
    $sourceAccountName = $csvItem.ACCOUNT_NAME
    $sourceProcessServer = $csvItem.PROCESS_SERVER
    $sourceConfigurationServer = $csvItem.CONFIGURATION_SERVER
    $targetPostFailoverResourceGroup = $csvItem.TARGET_RESOURCE_GROUP
    $targetPostFailoverStorageAccountName = $csvItem.TARGET_STORAGE_ACCOUNT
    $targetPostFailoverVNET = $csvItem.TARGET_VNET
    $targetPostFailoverSubnet = $csvItem.TARGET_SUBNET
    $sourceMachineName = $csvItem.SOURCE_MACHINE_NAME
    $replicationPolicy = $csvItem.REPLICATION_POLICY
    $PrivateIP = $csvItem.PRIVATE_IP
    $targetMachineSize = $csvItem.TARGET_VM_SIZE
    $targetMachineName = $csvItem.TARGET_MACHINE_NAME
    $targetStorageAccountRG = $csvItem.TARGET_STORAGE_ACCOUNT_RG
    $targetVNETRG = $csvItem.TARGET_VNET_RG
    $VaultSubscription=$csvItem.VAULT_SUBSCRIPTION_ID
    $ResourceSubscription=$csvItem.RESOURCE_SUBSCRIPTION_ID
    #Print replication settings
    Write-Host "[REPLICATIONJOB SETTINGS]-$($sourceMachineName)" -BackgroundColor Green
  
    $statusItemInfo = [ReplicationInformation]::new()
    $statusItemInfo.Machine = $sourceMachineName

    $targetVault = Get-AzRecoveryServicesVault -Name $vaultName
    if ($targetVault -eq $null)
    {
        LogErrorAndThrow "Unable to find Vault with name '$($vaultName)'"
    }

    Set-AzRecoveryServicesAsrVaultContext -Vault $targetVault

    $fabricServer = Get-AzRecoveryServicesAsrFabric -FriendlyName $sourceConfigurationServer
    $protectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabricServer
    #$replicationPolicyObj = Get-AzRecoveryServicesAsrPolicy -Name $replicationPolicy
    Write-Output $ResourceSubsriptionName

    Select-AzSubscription -Subscription $ResourceSubscription

    #Assumption storage are already created
    $targetPostFailoverStorageAccount = Get-AzStorageAccount `
        -Name $targetPostFailoverStorageAccountName `
        -ResourceGroupName $targetStorageAccountRG

    $targetResourceGroupObj = Get-AzResourceGroup -Name $targetPostFailoverResourceGroup
    $targetVnetObj = Get-AzVirtualNetwork `
        -Name $targetPostFailoverVNET `
        -ResourceGroupName $targetVNETRG 
        
    Select-AzSubscription -Subscription $VaultSubscription
    
    $targetPolicyMap  =  Get-AzRecoveryServicesAsrProtectionContainerMapping `
        -ProtectionContainer $protectionContainer | Where-Object { $_.PolicyFriendlyName -eq $replicationPolicy }
    if ($targetPolicyMap -eq $null)
    {
        LogErrorAndThrow "Policy map '$($replicationPolicy)' was not found"
    }
    $protectableVM = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $protectionContainer -FriendlyName $sourceMachineName
    $statusItemInfo.ProtectableStatus = $protectableVM.ProtectionStatus

    if ($protectableVM.ReplicationProtectedItemId -eq $null)
   {
        $sourceProcessServerObj = $fabricServer.FabricSpecificDetails.ProcessServers | Where-Object { $_.FriendlyName -eq $sourceProcessServer }
        if ($sourceProcessServerObj -eq $null)
        {
            LogErrorAndThrow "Process server with name '$($sourceProcessServer)' was not found"
        }
        $sourceAccountObj = $fabricServer.FabricSpecificDetails.RunAsAccounts | Where-Object { $_.AccountName -eq $sourceAccountName }
        if ($sourceAccountObj -eq $null)
        {
            LogErrorAndThrow "Account name '$($sourceAccountName)' was not found"
        }

     
        LogTrace "Starting replication Job for source '$($sourceMachineName)'"
    


        $replicationJob = New-AzRecoveryServicesAsrReplicationProtectedItem `
            -VMwareToAzure `
            -ProtectableItem $protectableVM `
            -Name (New-Guid).Guid `
            -ProtectionContainerMapping $targetPolicyMap `
            -logStorageAccountId $targetPostFailoverStorageAccount.Id `
            -ProcessServer $sourceProcessServerObj `
            -Account $sourceAccountObj `
            -RecoveryResourceGroupId $targetResourceGroupObj.ResourceId `
            -RecoveryAzureNetworkId $targetVnetObj.Id `
            -RecoveryAzureSubnetName $targetPostFailoverSubnet `
            -RecoveryVmName $targetMachineName
            
        $replicationJobObj = Get-AzRecoveryServicesAsrJob -Name $replicationJob.Name
        while ($replicationJobObj.State -eq 'NotStarted') {
            Write-Host "." -NoNewline 
            $replicationJobObj = Get-AzRecoveryServicesAsrJob -Name $replicationJob.Name
        }
        $statusItemInfo.ReplicationJobId = $replicationJob.Name

        if ($replicationJobObj.State -eq 'Failed')
        {
            LogError "Error starting replication job"
            foreach ($replicationJobError in $replicationJobObj.Errors)
            {
                LogError $replicationJobError.ServiceErrorDetails.Message
                LogError $replicationJobError.ServiceErrorDetails.PossibleCauses
            }
        } else {
            LogTrace "ReplicationJob initiated"        
        }
    } else {
        $protectedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem `
            -ProtectionContainer $protectionContainer `
            -FriendlyName $sourceMachineName
        $statusItemInfo.ProtectionState = $protectedItem.ProtectionState
        $statusItemInfo.ProtectionStateDescription = $protectedItem.ProtectionStateDescription
    }
    $protectedItemStatusArray.Add($statusItemInfo)
}


foreach ($csvItem in $csvObj)
{
    try { 
        vmdiscovery -csvItem $csvItem
        StartReplicationJobItem -csvItem $csvItem
    } catch {
        LogError "Exception creating replication job"
        $exceptionMessage = $_ | Out-String

        $statusItemInfo = [ReplicationInformation]::new()
        $statusItemInfo.Machine = $csvItem.SOURCE_MACHINE_NAME
        $statusItemInfo.Exception = "ERROR PROCESSING ITEM" 
        $protectedItemStatusArray.Add($statusItemInfo)

        LogError $exceptionMessage
    }
}


 




