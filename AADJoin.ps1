<#	
	.NOTES
	===========================================================================
	 Updated on:   	9/29/23
	 Created by:    @gorrain
	===========================================================================
	
	.
    Download the latest SetupRST Driver from https://www.intel.com/content/www/us/en/download-center/home.html

    Create your provisioning package here https://learn.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-create-package

    WARNING: Will wipe the PC entirely when run, ensure data has been backed up before proceeding.
    
	.DESCRIPTION
		This script was used to migrate remote PCs from On-prem Active Directory to our Azure Active Directory.

        1. Will check for Temp folder to ensure files can be downloaded to it
        2. Checks the processor information. Intel CPUs 11+ will require SETUPRST.exe installed before resetting will work.
        3. Downloads and installs the PPKG file.
#>  



#CONSTANTS
$SETUP_RST_PATH = "C:\Temp\SetupRST.exe"
$SETUP_RST_URL = "<url pointing to this file>"

$PPKG_INSTALL_PATH = "C:\Temp\FS3.ppkg"
$PPKG_URL = "<url pointing to this file>"


Function Get-Temp-Files {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileURL,
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    Invoke-WebRequest -Uri $FileURL -OutFile (New-Item -Path $FilePath -Force)
}

Function Invoke-PPKG_Install {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileURL,
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    Write-Host 'Downloading ppkg file.'
    Invoke-WebRequest -Uri $FileURL -OutFile (New-Item -Path $FilePath -Force)

    Write-Host 'Pushing PPKG Package'
    Install-ProvisioningPackage -PackagePath $PPKGdest -QuietInstall -ForceInstall #use the PackagePath accordingly

    #PC should restart automatically

}

Function Get-ProcessorInformation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileURL,
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    <#
        Checking to see if processor information has been run already
        If not, will use DXDIAG to get the the generation of the processor
    #>
    $logFile = "C:\Temp\diaglog.xml"
    if (!(Test-Path -Path $logFile -PathType Leaf)) {
        C:\Windows\System32\dxdiag.exe /whql:off /dontskip /x $logFile | Out-Null
    }

    <#
        Parsing the XML output from DXDIAG run. If it is 11-13th generation, we will need to ensure
        the proper intel RST driver is installed to ensure it will reset itself correctly.
    #>
    [xml]$dxDiagLog = Get-Content $logFile
    $processor = $dxDiagLog.DxDiag.SystemInformation.Processor
    Write-Host $processor
    if ($processor.StartsWith('11') -or $processor.StartsWith('12') -or $processor.StartsWith('13')){
        $rstDrivers = Get-WmiObject Win32_PnPSignedDriver| Select-Object DeviceName,DriverVersion |Where-Object {($_.DeviceName -like "*RST*")}
        # Testing to see if there are no drivers or the driver version is less than the downloaded version as of this date
        if ($null -eq $rstDrivers -or $rstDrivers.DriverVersion -ne "19.5.2.1049") {
            Get-Temp-Files $FileURL $FilePath | Out-Null
            C:\Temp\SetupRST.exe -s -onlydriver -accepteula | Out-Null
            Write-Host "SETUPRST COMPLETE"
        }
        
    }

}

Set-TempFolder {
    #Ensuring Temp Folder directory is here
    $FolderPath = "C:\Temp"
    if (!(Test-Path $FolderPath)) {
        New-Item -ItemType Directory -Force -Path $FolderPath
    }
}

# | Out-null ensures it will complete its task before moving to the next
Set-TempFolder | Out-Null
Get-ProcessorInformation $SETUP_RST_URL $SETUP_RST_PATH | Out-Null
Invoke-PPKG_Install $PPKG_URL $PPKG_INSTALL_PATH