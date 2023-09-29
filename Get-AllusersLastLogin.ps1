function Get-MBusers {
    Param (
        $Group,
        $adserver
    )
    
    $users=@()    
    
    $members = Get-Adgroup -Identity $Group -Server $adserver -Properties members | Select-Object -ExpandProperty Members | Where-Object {$_ -notmatch "ForeignSecurityPrincipals"}  | ForEach-Object {Get-ADObject $_ -Server $adserver}
    foreach ($member in $members) {
        Write-Debug "$($member.Name)"
    
        $type = Get-ADObject $member -server $ADServer -Properties samAccountname
    
        if ($type.ObjectClass -eq 'user') {
            $users += Get-Aduser $type.samaccountname -Server $ADServer
        }
    
        # If it's a group
        if ($type.ObjectClass -eq 'group') {
            Write-Debug "Breaking out group $($type.Name)"
            $users += Get-MBUsers $member $adserver
        }
    
    }    
    
    return $users
    
}



Get-ADUser -Filter * -SearchBase "dc=contoso,DC=com" | Select-Object -ExpandProperty UserPrinciPalName | Out-File "Alluseremails.csv"

#make our own header "email" to reference in $_.email
$employee_list = Import-Csv -Path ".\Alluseremails.csv" -Header email

$total = 0
$users_logged_in = 0
$users_not_logged_in = 0
$date = Get-Date -f yyyy-MM-dd

foreach ($employee in $employee_list.email){
    $total += 1
    $username = $employee
    $userlog = Get-AzureADAuditSignInLogs -Filter "userPrincipalName eq '$username'" | Select-Object -Property createddatetime
    #if the user has not logged in (in 30 days)
    if($null -eq $userlog){
        $users_not_logged_in += 1
        Out-File "ALLuserlogins$date.txt" -Append -InputObject "$username, NA"
        Out-File "ALLproblemChildren$date.txt" -Append -InputObject "$username"
    }else{
        $users_logged_in += 1
        $time = $userlog[0].createddatetime
        Out-File "ALLuserlogins$date.txt" -Append -InputObject "$username, $time"
        #Creating a "history" for logged in users
        #Out-File "AllLoggedInTherapists.txt" -Append -InputObject "$username"
        }
    Start-Sleep -s 5
}

Write-Output "Total: $total"
Write-Output "Logged In: $users_logged_in"
Write-Output "Not logged in: $users_not_logged_in"
$fraction = ($users_logged_in/$total)*100
Write-Output "Adoption percentage: $fraction"
