
<#	
	.NOTES
	===========================================================================
	 Updated on:   	9/29/23
	 Created by:    @gorrain
	===========================================================================
	
	.
    
	.DESCRIPTION
		Script to take two different exported lists, UKG_csv and OL_csv and combine them based on a common field (email address in this case)
#> 

$UKG_csv = Import-Csv -path "C:\Temp\UKGallusers.csv" -Header 'UKGname','UKGempnum','UKGemail','UKGstatus','UKGjob','UKGloc','UKGdivision','UKGdept','UKGcompany'

$OL_csv = Import-Csv -path "C:\Temp\OLallusers.csv" -Header 'OLemail','OLfn','OLln','OLtitle','OLdept','OLmanager','OLcreated','OLstatus','OLempnum','OLcompany','OLll'

<#
    Combining the common field (email) into a single field and ensuring only one shows up
#>
$listOfEmails = $UKG_csv.UKGemail + $OL_csv.OLemail | Sort-Object -Unique


<#
    Creating a custom object to export to CSV.

    Iterates through each email and matches the objects based on said email
    Then will create a custom object for each user with the combined values
#>
$combinedUsers = Foreach ($email in $listofEmails){
    $UKGValues = $UKG_csv | Where-Object {$_.UKGemail -eq $email} | Select-Object UKGname,UKGempnum,UKGstatus,UKGjob,UKGloc,UKGdivision,UKGdept,UKGcompany
    $OLValues = $OL_csv | WHere-Object {$_.OLemail -eq $email} | Select-Object OLfn,OLln,OLtitle,OLdept,OLmanager,OLcreated,OLstatus,OLempnum,OLcompany,OLll
    [PSCustomObject]@{
        Email = $email
        UKGName = $UKGValues.UKGname
        UKGempnum = $UKGValues.UKGempnum
        UKGstatus = $UKGValues.UKGstatus
        UKGjob = $UKGValues.UKGjob
        UKGloc = $UKGValues.UKGloc
        UKGdivision = $UKGValues.UKGdivision
        UKGdept = $UKGValues.UKGdept
        UKGcompany = $UKGValues.UKGcompany
        OLfn = $OLValues.OLfn
        OLln = $OLValues.OLln
        OLtitle = $OLValues.OLtitle
        OLdept = $OLValues.OLdept
        OLmanager = $OLValues.OLmanager
        OLcreated = $OLValues.OLcreated
        OLstatus = $OLValues.OLstatus
        OLempnum = $OLValues.OLempnum
        OLcompany = $OLValues.OLcompany
        OLll = $OLValues.OLll
    }
}

$combinedUsers | Export-Csv -Path C:\Temp\combinedOutput.csv

