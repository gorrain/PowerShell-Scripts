<#
DESCRIPTION: Takes emails from csv and hides them on Exchange Online

USAGE: Need to use Connect-ExchangeOnline in context beforehand
       Then create EMW_useremails.csv with header email with email addresses to be hidden/unhidden
       Set $hide to either $true/false, $true will hide them
       Set $csv_path to the full path of the CSV file to import
       Outputs any emails not hidden to EMW_hidefailures.txt
#>


#Set true/false for hiding/unhiding
$hide = $true

#Path of CSV to import
$csv_path = "C:\Temp\userlistToHide.csv"

$employee_list = Import-Csv $csv_path

foreach($employee in $employee_list) {
    $email = $employee.email
    try {
        #Error handling for Set-Mailbox was not written correctly...
        #https://old.reddit.com/r/PowerShell/comments/9ivhm0/comment/e6mp6zv/
        $OldPref = $global:ErrorActionPreference
        $global:ErrorActionPreference = 'Stop'
        #Set-Mailbox -Identity $email -HiddenFromAddressListsEnabled $hide
        Set-DistributionGroup -Identity $email -HiddenFromAddressListsEnabled $hide
    }
    catch {
        Out-File "C:\Temp\hidefailures.txt" -Append -InputObject $email
    }
    finally{
        $global:ErrorActionPreference = $OldPref
    }
}