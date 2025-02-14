<#
.SYNOPSIS
    

.DESCRIPTION
    This script connects to an Azure tenant and subscription, creates CSV exports of
    Azure VMs and Disks, and then archives data about VMs and disks based on customizable functions.
    Modify the functions (e.g., Get-AzVM, Get-AzDisk) as needed to suit your environment.

.PARAMETER TenantId
    The Tenant ID for your Azure account.

.PARAMETER SubscriptionId
    The Subscription ID for your Azure account.

.EXAMPLE
    PS> .\Archive-AZdisk.ps1 -TenantId "<your-tenant-id>" -SubscriptionId "<your-subscription-id>"
    Runs the script using the default parameters as defined in the script. Ensure you update the 
    TenantId and SubscriptionId variables before running.

.NOTES
    Author: @gorrain
    Date: 2025-02-13
    Version: 1.0
    This script requires the Az PowerShell module.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId
)

# Connect to Azure using the provided Tenant and Subscription IDs.
Connect-AzAccount -Tenant $TenantId -SubscriptionId $SubscriptionId

<#
	Creates CSVs of Azure VMs for saving
	and Azure Disks for archiving
	
	Edit the Get-AzVM and Get-AzDisk functions to your specifications
#>
function New-VM-Disk-CSVs {
	$VMList = Get-AZVM
	$VMList | Export-CSV -Path ".\offlineVMs.CSV" -NoTypeInformation
	
	$DiskList = Get-AzDisk
	$DiskList | Export-CSV -Path ".\Azuredisks.csv" -NoTypeInformation
	
}

# Store Data About VM Disks
function Export-VM-Disk-Information {
	$VM_CSV = Import-CSV -Path ".\offlineVMs.CSV"
	
	foreach ($row in $VM_CSV)
	{
		$vmName = $row.Name
		$vmRG = $row.ResourceGroupName
		Write-Host "Exporting disk information for $vmName inside $vmRG"
		$AzVM = Get-AzVM -ResourceGroupName $vmRG -Name $vmName

		$results = "VM Information`n"
		$results += "Resource Group: $($AzVM.ResourceGroupName)`n"
		$results += "Name: $($AzVM.Name)`n"
		$results += "Size: $($AzVM.HardwareProfile.VmSize)`n"
		
		$results += "`nOS Disk`n"
		$results += "--------------------------------------------------"

		
		$osDisk = (($AzVM).StorageProfile).OSDisk
		foreach ($disk in $osDisk)
		{
			$c = Get-AzDisk -ResourceGroupName $vmRG -DiskName $($disk.Name)
			$results += (Out-String -InputObject $c -Width 300)
		}

		$results += "`nData Disks`n"
		$results += "--------------------------------------------------"
		$dataDisks = ((Get-AzVM -ResourceGroupName $vmRG -Name $vmName).StorageProfile).DataDisks
		foreach ($disk in $dataDisks)
		{
			$c = Get-AzDisk -ResourceGroupName $vmRG -DiskName $($disk.Name)
			$results += (Out-String -InputObject $c -Width 300)
		}

		$results | Out-File ".\$vmName-Disks.txt"

	}
}

function Archive-Disks {
	$disk_CSV = Import-CSV -Path ".\Azuredisks.csv"
	$archiveContainerName = "archiveblobs"
	$pageContainerName = "pageblobs"
	$sasExpiryDuration = "10800"

	foreach ($row in $disk_CSV)
	{
		$diskName = $row.Name
		$diskRG = $row.ResourceGroupName

		# Ensuring the storage account name stays within 24 characters
		$rgStorageAccount = $("$diskRG-archivesa".ToLower()).Replace('-','').Replace('.','')
		if ($rgStorageAccount.Length -gt 24) {
			$rgStorageAccount = $rgStorageAccount.Substring(0,15) + "archivesa"
		}

		Write-Host "Checking for existence of $rgStorageAccount inside $diskRG"
		$noStorageAccountYet = $true
		$s = Get-AzStorageAccount -ResourceGroupName $diskRG -Name $rgStorageAccount
		if ($s.Length -gt 0) {
			Write-Host "$rgStorageAccount exists already, skipping creation"
			$noStorageAccountYet = $false
		}
		if ($noStorageAccountYet) {
			Write-Host "$rgStorageAccount does not exist, creating it now."
			New-AzStorageAccount -ResourceGroupName $diskRG -Name $rgStorageAccount -Location centralus -SkuName Standard_LRS -Kind StorageV2 -AccessTier Hot

			$key = Get-AzStorageAccountKey -ResourceGroupName $diskRG -Name $rgStorageAccount
			$storageAccountKey = $key.Value[0]
			$destinationContext = New-AzStorageContext -StorageAccountName $rgStorageAccount -StorageAccountKey $storageAccountKey

			Write-Host "Creating $archiveContainerName and $pageContainerName inside $rgStorageAccount"
			New-AzStorageContainer -Name $archiveContainerName -Context $destinationContext
			New-AzStorageContainer -Name $pageContainerName -Context $destinationContext
		}
		else {
			$key = Get-AzStorageAccountKey -ResourceGroupName $diskRG -Name $rgStorageAccount
			$storageAccountKey = $key.Value[0]
			$destinationContext = New-AzStorageContext -StorageAccountName $rgStorageAccount -StorageAccountKey $storageAccountKey
		}

		$containerSASURI = New-AzStorageContainerSASToken -Context $destinationContext -ExpiryTime(get-date).AddSeconds($sasExpiryDuration) -FullUri -Name $archiveContainerName -Permission rwdl

		$containerURI,$containerToken = $containerSASURI.split('?')
		$fullURI = "$($containerURI)/$($diskName).vhd?$($containerToken)"

		Write-Host "Now copying disk $diskName with URI $fullURI"
		$sas = Grant-AzDiskAccess -ResourceGroupName $diskRG -DiskName $diskName -DurationInSecond $sasExpiryDuration -Access Read
		# Copying directly to archive tier
		azcopy copy $sas.AccessSAS $fullURI --blob-type=blockblob --block-blob-tier "Archive" --cap-mbps 1000
		Write-Host "Copy of $diskName to storage account completed"
	}
}

New-VM-Disk-CSVs
Export-VM-Disk-Information
Archive-Disks