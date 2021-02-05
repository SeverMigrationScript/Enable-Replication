#Introduction 
Purpose of this project is to migrate On-prem physical server to azure using PowerShell script. 
Objectives: Discover physical servers within the network, Enable replication for all the discovered servers, perform test failover and then final migration. 
Motivation: Automation reduces the migration time, it lowers the migration cost and also minimizes business disruptions. 

#Pre-requisites
Before you get started, you need to do the following:
Ensure that the Site Recovery vault is created in your Azure subscription
Ensure that the Configuration Server and Process Server are installed in the source environment and the vault is able to discover the environment
Ensure that a Replication Policy is created and associated with the Configuration Server
Ensure that you have added the VM admin account to the config server (that will be used to replicate the on-prem VMs)
Ensure that the target artifacts in Azure are created
Target Resource Group
Target Storage Account (and its Resource Group) - Create a premium storage account if you plan to migrate to premium disks
Target Cache Storage Account (and its Resource Group) - Create a standard storage account in the same region as the vault
Target Virtual Network for failover (and its Resource Group)
Target Subnet
Target Virtual Network for Test failover (and its Resource Group)
Availability Set (if needed)
Target Network Security Group and its Resource Group
Ensure that you have decided on the properties of the target VM
Target VM name
Target VM size in Azure (can be decided using Azure Migrate assessment)
Private IP Address of the primary NIC in the VM

#CSV input file
Once you have all the pre-requisites completed, you need to create a CSV file which has data for each source machine that you want to migrate. The input CSV must have a header line with the input details and a row with details for each machine that needs to be migrated. All the scripts are designed to work on the same CSV file.


#Keyword 	                    Description
VAULT_SUBSCRIPTION_ID	        Subscription id where Site Recovery vault has been created. 
RESOURCE_SUBSCRIPTION_ID	
VAULT_NAME	                    Site Recovery vault name.
SOURCE_MACHINE_NAME	            Server name that needs to migrate 
PRIVATE_IP	                    Private IP of the servers that needs to migrate 
SOURCE_OS	                    Source Machine OS type like windows /Linux 
TARGET_MACHINE_NAME	            Source machine corresponding name in azure (friendly name)
TARGET_VM_IP	                Migrated VM IP address
CONFIGURATION_SERVER	        Configuration Server name
PROCESS_SERVER	                Process Server name
TARGET_RESOURCE_GROUP	        Target RG name (Target artefacts in azure )
TARGET_STORAGE_ACCOUNT	        Target storage account name
TARGET_STORAGE_ACCOUNT_RG       RG name of the Target storage account 
TARGET_VNET	Target              VNET name
TARGET_VNET_RG	                RG group name of the target VNET
TARGET_SUBNET	                Target Subnet name
REPLICATION_POLICY	            Replication policy name I.e. associated with Configuration Server
ACCOUNT_NAME	
TARGET_VM_SIZE	                Target VM sizes corresponding to Source
TESTFAILOVER_VNET_NAME	        VNET name for test failover 
TESTFAILOVER_VNET_RG	        RG group name of the test failover virtual network 
VM_LOCATION	                    Region of target VM
DIAGNOSTIC_STORAGE_RG	        RG name of the diagnostic account 
DIAGNOSTIC_STORAGE	            Storage Account name for diagnostic. 

