<#	
	.NOTES
	===========================================================================
	 Updated on:   	9/29/23
	 Created by:    @gorrain
	===========================================================================
	
	.
    
	.DESCRIPTION
		Script used to offboard our On premise AD users.
		1. Starts a loop to get the alias of the user in question
		2. If confirmed correct user, moves them into a disabled users OUs
			,removes all AD memberships, and disables their account
#> 


$DisabledUsersOU = "OU=Disabled Accounts,DC=contoso,DC=com"

#loop for disabling multiple users at a time
$answer = "Y"
while ($answer -eq "Y"){
    #getting the username from host input
    Write-Host "Username?" -ForegroundColor Green
    $username = Read-Host
	try {
		$obj = Get-ADUser $username
	}
	catch {
		Write-Output "$username is not in AD, try again"
		continue
	}
    #confirm this is the right person we are disabling
	Write-Output ($obj | Format-List | Out-String)
	Write-Host "Are you sure you want to disable this user? (Y/N)" -ForegroundColor Red
	$sure = Read-Host
	if ($sure -ne "Y"){
		break
	}
	try {
        #diable the AD account, move to Disabled accounts OU, remove all memberships	
		Disable-ADAccount -Identity $username
		Get-ADUser $username | Move-ADObject -TargetPath $DisabledUsersOU
		$ADGroups = Get-ADPrincipalGroupMembership -Identity  $username | Where-Object {$_.Name -ne “Domain Users”}
		Remove-ADPrincipalGroupMembership -Identity  $username -MemberOf $ADGroups -Confirm:$false
	}
	catch {
		Write-Warning $Error[0]
		continue
	}
    Write-Output "$username account has been disabled, removed from all AD memberships and sent to Disabled Accounts OU"
    Write-Host "Continue?(Y/N)" -ForegroundColor Green
    $answer = Read-Host
}
