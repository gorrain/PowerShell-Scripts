$dist_list = Import-Csv "C:\Users\grainwater\OneDrive - EmpowerMe Wellness\Documents\ONRcommunitydistlists.csv"

$start_date = "03/22/2023"
$end_date = Get-Date

$combined_emails = Foreach ($dist in $dist_list) {
    $primary = $dist.email
    $new = $dist.newemail
    $old = $dist.oldemail
    $sum = 0
    $sum += $(Get-MessageTrace -RecipientAddress $primary -Startdate $start_date -EndDate $end_date).count
    $sum += $(Get-MessageTrace -RecipientAddress $new -Startdate $start_date -EndDate $end_date).count
    $sum += $(Get-MessageTrace -RecipientAddress $old -Startdate $start_date -EndDate $end_date).count
    [PSCustomObject]@{
        Email = $new
        Total = $sum
    }
    
}

$combined_emails | Export-Csv -Path C:\Temp\emailsbysum.csv