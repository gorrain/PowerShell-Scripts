# Location for offlilne dictionary
$CSV_DICTIONARY = '.\CSV\name2email.csv'



Function Get-Email-From-Name {
    param (
        [Parameter(Mandatory=$true)]
        [string]$displayName,
        [Parameter(Mandatory=$true)]
        [hashtable]$dict
    )
    
    if ($dict.ContainsKey($displayName)) {
        return $dict[$displayName]
    }

    #If it errors out, we just put unassigned
    try {
        $user = Get-AzureADUser -Filter "DisplayName eq '$displayName'"
    }
    catch {
        Write-Host "ERROR for $displayName"
        $user = "Unassigned"
    }

    #getting the correct name if it still comes back with nothing
    if ($user.count -eq 0) {
        $manualEmail = Read-Host "$displayName not recognized, provide email "
        return $manualEmail
    }

    #making sure we are only using empowerme email
    $email = $user.userprincipalname
    if ($email.length -gt 1){
        foreach ($e in $email) {
            if ($e.EndsWith('@empowerme.com')) {
                $email = $e
                break
            }
        }
    }

    #hash for faster lookups
    return $email
}

Function Save-To-Dictionary {

    param (
        [Parameter(Mandatory=$true)]
        [string]$displayName,
        [Parameter(Mandatory=$true)]
        [hashtable]$dict
    )

    $correctedName = $displayName.replace("'","''")
    $correctedName = $correctedName.Trim()
    $userEmail = Get-Email-From-Name $correctedName $dict | Out-String
    $userEmail = $userEmail.Trim()
    $userEmail = [string]::join("",($userEmail.Split("`n")))
    Write-Host "$correctedName : $userEmail"
    if (-not($dict.ContainsKey($correctedName))) {
        $dict.Add($correctedName, $userEmail)
        $data = [PSCustomObject]@{
            name = $correctedName
            email = $userEmail
        }
        $data | Export-Csv -Path $CSV_DICTIONARY -Append -NoTypeInformation -Force
    }

    return $userEmail
}


Connect-ExchangeOnline
Connect-AzureAD

$nameToEmail = Import-Csv -Path $CSV_DICTIONARY
$dN2E = [hashtable]@{}

#Build dictionary from namesToEmails CSV
foreach ($n2e in $nameToEmail) {
    $name = $n2e.name
    $email = $n2e.email
    $dN2E.Add($name,$email)
}