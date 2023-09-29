$content = Get-Content listOfUsers.txt
$ex1 = "4b9405b0-7788-4568-add1-99614e613b69"
$ex2 = "19ec0d23-8335-4cbd-94ac-6050e30712fa"

ForEach($user in $content){

Set-MgUserLicense -UserId $user -AddLicenses @{SkuId = $ex2} -RemoveLicenses @($ex1)

}