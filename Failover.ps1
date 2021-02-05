[CmdletBinding()]
Param ( 
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

$resolvedCsvPath = Resolve-Path -LiteralPath $CsvFilePath
$csvObj = Import-Csv $resolvedCsvPath -Delimiter ','

#region Failover function
Function Invoke-Failover($csvItem)
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
        $ASRFabrics = Get-AzRecoveryServicesAsrFabric -FriendlyName $ConfigServer

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
        $ProtectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $ASRFabrics[0] -ErrorAction SilentlyContinue

        If (-not($ProtectionContainer)) {
            Write-Host "Proection Container doesn't exist for Configuration Server" -ForegroundColor red  
        }
        else {
            Write-Host "Proection Container already exists for Configuration Server".        
        }

        $replicatedVM = Get-AzRecoveryServicesAsrReplicationProtectedItem -FriendlyName "$VMName" -ProtectionContainer $ProtectionContainer

        If (-not($replicatedVM)) {
            Write-Host "VM '$VMName' is not protected" -ForegroundColor red   
        }
        else {
            Write-Host "VM '$VMName' is protected"         
        }

        # Get the list of available recovery points for Win2K12VM1
        $RecoveryPoints = Get-AzRecoveryServicesAsrRecoveryPoint -ReplicationProtectedItem $replicatedVM
        "{0} {1}" -f $RecoveryPoints[0].RecoveryPointType, $RecoveryPoints[0].RecoveryPointTime

        #Start the failover job
        Write-Host "Failover of VM '$VMName' is started."   
        $Job_Failover = Start-AzRecoveryServicesAsrUnplannedFailoverJob -ReplicationProtectedItem $replicatedVM -Direction PrimaryToRecovery -RecoveryPoint $RecoveryPoints[0]
        do {
            $Job_Failover = Get-ASRJob -Job $Job_Failover;
            sleep 60;
        } while (($Job_Failover.State -eq "InProgress") -or ($JobFailover.State -eq "NotStarted"))
        $Job_Failover.State
  }catch
	{
	  LogError "Exception in Failover"
        $exceptionMessage = $_ | Out-String
	}
}
#endregion

ForEach ($csvItem in $csvObj){
Invoke-Failover -csvItem $csvItem
}  