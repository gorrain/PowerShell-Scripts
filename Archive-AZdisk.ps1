$tenant_id = 'Enter-Tenant-ID-Here'
$sub_id = 'Enter-Subscription-ID-Here'


Connect-AzAccount -Tenant $tenant_id -Subscriptionid $sub_id

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

# Archive Data About VMs
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
			# Write-Output $($disk.ManagedDisk)
		}

		$results += "`nData Disks`n"
		$results += "--------------------------------------------------"
		$dataDisks = ((Get-AzVM -ResourceGroupName $vmRG -Name $vmName).StorageProfile).DataDisks
		foreach ($disk in $dataDisks)
		{
			$c = Get-AzDisk -ResourceGroupName $vmRG -DiskName $($disk.Name)
			$results += (Out-String -InputObject $c -Width 300)
		}

		$results | Out-File ".\VM_reports\$vmName-Disks.txt"

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
		azcopy copy $sas.AccessSAS $fullURI --blob-type=blockblob --block-blob-tier "Archive" --cap-mbps 1000
		Write-Host "Copy of $diskName to storage account completed"
	}
}


