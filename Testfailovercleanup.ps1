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

#region TestFailoverCleanUp function
Function Invoke-TestFailoverCleanUp($csvItem)
{
  try{
        
        If([string]::IsNullOrEmpty($csvItem.SOURCE_MACHINE_NAME)){
           Write-Error "SOURCE_MACHINE_NAME is Empty!" -TargetObject $_}
        Else{$VMName=$csvItem.SOURCE_MACHINE_NAME}

        If([string]::IsNullOrEmpty($csvItem.VM_LOCATION)){
             Write-Error "VM_LOCATION is Empty!" -TargetObject $_}
        Else{$vmLocation=$csvItem.VM_LOCATION}
        
         If([string]::IsNullOrEmpty($csvItem.CONFIGURATION_SERVER)){
             Write-Error "CONFIGURATION_SERVER is Empty!" -TargetObject $_}
         Else{$ConfigServer=$csvItem.CONFIGURATION_SERVER}
        
        If([string]::IsNullOrEmpty($csvItem.VAULT_SUBSCRIPTION_ID)){
            Write-Error "VAULT_SUBSCRIPTION_ID is Empty!" -TargetObject $_}
        Else{$VaultSubscription=$csvItem.VAULT_SUBSCRIPTION_ID}
        
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
        $ASRFabrics = Get-AzRecoveryServicesAsrFabric -FriendlyName $ConfigServer -ErrorAction SilentlyContinue

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
            Write-Host "ASR Fabrics doesn't exist for configuration Server '$ConfigServer'." -ForegroundColor red
        }

        #Get the protection container corresponding to the Configuration Server
        $ProtectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $ASRFabrics[0]
        $replicatedVM = Get-AzRecoveryServicesAsrReplicationProtectedItem -FriendlyName $VMName -ProtectionContainer $ProtectionContainer

        If(-not($replicatedVM)) {
            Write-Host "VM '$VMName' is not protected" -ForegroundColor red
        }
        else{
             Write-Host "VM '$VMName' is protected" 
        }

        If($replicatedVM.LastSuccessfulTestFailoverTime -eq $null){
            Write-Host "Test failover is not successful yet"
        }
        Else{
            Write-Host "Test failover is successful"
        }

        #Start the test failover cleanup operation
        $Job_TFOCleanup = Start-AzRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $replicatedVM
        do {
            $Job_TFOCleanup = Get-ASRJob -Job $Job_TFOCleanup;
            sleep 60;
        } while (($Job_TFOCleanup.State -eq "InProgress") -or ($Job_TFOCleanup.State -eq "NotStarted"))
        $Job_TFOCleanup.State
  }catch
	{
		LogError "Exception in Test Failover Clean Up"
        $exceptionMessage = $_ | Out-String
	}
}
#endregion

ForEach ($csvItem in $csvObj){
Invoke-TestFailoverCleanUp -csvItem $csvItem
}  