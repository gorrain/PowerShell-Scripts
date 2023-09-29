
$Name_of_shortcut = "Shortcut on Desktop.url"
$URL_PATH = "https://www.google.com"

$wshShell = New-Object -ComObject "WScript.Shell"
$urlShortcut = $wshShell.CreateShortcut(
  (Join-Path $wshShell.SpecialFolders.Item("AllUsersDesktop") $Name_of_shortcut)
)
$urlShortcut.TargetPath = $URL_PATH
$urlShortcut.Save()