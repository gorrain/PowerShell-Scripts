<#	
	.NOTES
	===========================================================================
	 Updated on:   	9/29/23
	 Created by:    @gorrain
	===========================================================================
	
	.
    
	.DESCRIPTION
		Simple script to add users from CSV_path to the Distribution list DL_name
#> 

#CONSTANTS
$csvPath = "C:\Temp\emails.csv"
$DL_name = "Contoso Users"

<#
    CSV should contain
    email, name
    test@contoso.com, John Doe
#>
$emails = Import-Csv -Path $csvPath

foreach($line in $emails) {
    $email = $line.email
    Add-DistributionGroupMember -Identity $DL_name -Member $email
    Write-Host -ForegroundColor Green "Added $email"
}