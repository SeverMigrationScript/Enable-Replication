[CmdletBinding()]
Param ( 
    [parameter(Mandatory=$true)]
    $CsvFilePath
)
$resolvedCsvPath = Resolve-Path -LiteralPath $CsvFilePath
$csvObj = Import-Csv $resolvedCsvPath -Delimiter ','

Function LogError([string] $Message)
{
    $logDate = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
    $logMessage = [string]::Concat($logDate, "[ERROR]-", $Message)
    Write-Output $logMessage
    Write-Host $logMessage
}

#region TestFailover function
Function Invoke-TestFailover($csvItem)
{
try
{         
          If([string]::IsNullOrEmpty($csvItem.SOURCE_MACHINE_NAME)){
             Write-Error "SOURCE_MACHINE_NAME is Empty!" -TargetObject $_}
          Else{$VMName=$csvItem.SOURCE_MACHINE_NAME}

          If([string]::IsNullOrEmpty($csvItem.RESOURCE_SUBSCRIPTION_ID)){
          Write-Error "RESOURCE_SUBSCRIPTION_ID is Empty!" -TargetObject $_}
          Else{$ResourceSubscription=$csvItem.RESOURCE_SUBSCRIPTION_ID}

          If([string]::IsNullOrEmpty($csvItem.VAULT_SUBSCRIPTION_ID)){
          Write-Error "VAULT_SUBSCRIPTION_ID is Empty!" -TargetObject $_}
          Else{$VaultSubscription=$csvItem.VAULT_SUBSCRIPTION_ID}

          If([string]::IsNullOrEmpty($csvItem.TARGET_VM_SIZE)){
             Write-Error "TARGET_VM_SIZE is Empty!" -TargetObject $_}
          Else{$TargetVMSize=$csvItem.TARGET_VM_SIZE}
          
          If([string]::IsNullOrEmpty($csvItem.TESTFAILOVER_VNET_NAME)){
             Write-Error "TESTFAILOVER_VNET_NAME is Empty!" -TargetObject $_}
          Else{$TestFailoverVnetName=$csvItem.TESTFAILOVER_VNET_NAME}

          If([string]::IsNullOrEmpty($csvItem.TESTFAILOVER_VNET_RG)){
             Write-Error "TESTFAILOVER_VNET_RG is Empty!" -TargetObject $_}
          Else{$TestFailoverVnetRG=$csvItem.TESTFAILOVER_VNET_RG}
          
          If([string]::IsNullOrEmpty($csvItem.VM_LOCATION)){
             Write-Error "VM_LOCATION is Empty!" -TargetObject $_}
          Else{$vmLocation=$csvItem.VM_LOCATION} 
          
          If([string]::IsNullOrEmpty($csvItem.CONFIGURATION_SERVER)){
             Write-Error "CONFIGURATION_SERVER is Empty!" -TargetObject $_}
          Else{$ConfigServer=$csvItem.CONFIGURATION_SERVER}  
           
          If([string]::IsNullOrEmpty($csvItem.VAULT_NAME)){
             Write-Error "VAULT_NAME is Empty!" -TargetObject $_}
          Else{$RecoveryVaultName=$csvItem.VAULT_NAME}
           
          

            Select-AzSubscription -Subscription $VaultSubscription

            #Setting the Recovery vault context
            $vault = Get-AzRecoveryServicesVault -Name $RecoveryVaultName
            If (-not($vault)) {
                Write-Host "Recovery Vault does not exist" -ForegroundColor red
            }    
            Set-ASRVaultContext -Vault $vault

            # Verify that the Configuration server is successfully registered to the vault
            $ASRFabrics = Get-AzRecoveryServicesAsrFabric -FriendlyName $ConfigServer -ErrorAction Stop

            If ($ASRFabrics) {
                Write-Host "ASR Fabrics exists for configuration Server '$ConfigServer'."
                $ProcessServers = $ASRFabrics[0].FabricSpecificDetails.ProcessServers
                for ($i = 0; $i -lt $ProcessServers.count; $i++) {
                    "{0,-5} {1}" -f $i, $ProcessServers[$i].FriendlyName
                }

                $AccountHandles = $ASRFabrics[0].FabricSpecificDetails.RunAsAccounts
   
                Foreach ($AccountHandle in $AccountHandles) {
                    If ($AccountHandle.AccountName -eq $ReplicationAccountName) {
                        $ReplicationAccount = $AccountHandle
                        Write-Host "Account '$ReplicationAccountName' is configured in '$ConfigServer'."
                    }
                }
            }
            Else {
                Write-Host "ASR Fabrics doesn't exist for configuration Server '$ConfigServer'."
            }

            #Get the protection container corresponding to the Configuration Server
            $ProtectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $ASRFabrics[0] -ErrorAction Stop

            $replicatedVM = Get-AzRecoveryServicesAsrReplicationProtectedItem -FriendlyName $VMName -ProtectionContainer $ProtectionContainer -ErrorAction Stop

            If(-not($replicatedVM)) {
                Write-Host "VM '$VMName' is not protected"   
            }
            else{
                 Write-Host "VM '$VMName' is protected"         
            }
            $TargetVm
            $replicatedVM.RecoveryAzureVMSize =$TargetVMSize 
            write-Host $TargetVMSize
            #$TargetVMSize ="Standard_DS1_v2"

            $tempASRJob = Set-AzRecoveryServicesAsrReplicationProtectedItem -InputObject $replicatedVM -Size $TargetVMSize -UseManagedDisk True -LicenseType NoLicenseType -ErrorAction Stop

            do {
                $tempASRJob = Get-ASRJob -Job $tempASRJob;
                sleep 30;
            } while (($tempASRJob.State -eq "InProgress") -or ($tempASRJob.State -eq "NotStarted"))
            $tempASRJob.State

            #Test failover of VM to the test virtual network

            Select-AzSubscription -Subscription $ResourceSubscription

            #Get details of the test failover virtual network to be used
            $testFailoverVnet = Get-AzVirtualNetwork -Name $TestFailoverVnetName -ResourceGroupName $TestFailoverVnetRG -ErrorAction SilentlyContinue

            If(-not($testFailoverVnet)){
                Write-Host "Test failover Network '$TestFailoverVnetName' doesnot exist. " -ForegroundColor red      
            }
            Else{
                Write-Host "Test failover Network '$TestFailoverVnetName' exists."    
            }  

            Select-AzSubscription -Subscription $VaultSubscription

            #Start the test failover operation
            $TFOJob = Start-AzRecoveryServicesAsrTestFailoverJob -ReplicationProtectedItem $replicatedVM -AzureVMNetworkId $testFailoverVnet.Id -Direction PrimaryToRecovery

            do {
                $TFOJob = Get-ASRJob -Job $TFOJob;
                sleep 60;
            } while (($TFOJob.State -eq "InProgress") -or ($TFOJob.State -eq "NotStarted"))
            $TFOJob.State
}catch
	{
        $MessageTxt = "Invoke-AgentlessMonitorReplication() $($psitem.Exception.Message)"
            $paramWriteLogEntry = @{
                logMessage   = "$MessageTxt : At Line: $($psitem.InvocationInfo.ScriptLineNumber) Char: $($psitem.InvocationInfo.OffsetInLine)"
                logComponent = "Invoke-AgentlessMonitorReplication"
                logSeverity  = 3
            }
            Write-Output @paramWriteLogEntry
		
	}
}
#endregion

ForEach ($csvItem in $csvObj){
Invoke-TestFailover -csvItem $csvItem
}       