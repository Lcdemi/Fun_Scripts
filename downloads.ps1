param (
    [string]$Path = $(throw "-Path is required.")
)

$InputPath = $Path
Set-Location -Path $InputPath | Out-Null

# Create directories
New-Item -Path $InputPath -Name "scripts" -ItemType "directory" | Out-Null
New-Item -Path $InputPath -Name "installers" -ItemType "directory" | Out-Null
New-Item -Path $InputPath -Name "tools" -ItemType "directory" | Out-Null
New-Item -Path $InputPath -Name "zipped" -ItemType "directory" | Out-Null
$ScriptPath = Join-Path -Path $InputPath -ChildPath "scripts"
$SetupPath = Join-Path -Path $InputPath -ChildPath "installers"
$ToolsPath = Join-Path -Path $InputPath -ChildPath "tools"
$ZippedPath = Join-Path -Path $InputPath -ChildPath "zipped"

# Create subdirectories
New-Item -Path $ToolsPath -Name "sys" -ItemType "directory" | Out-Null
New-Item -Path $ToolsPath -Name "antipwny" -ItemType "directory" | Out-Null
$SysPath = Join-Path -Path $ToolsPath -ChildPath "sys"
$antipwnyPath = Join-Path -Path $ToolsPath -ChildPath "antipwny"

# Downloading Windows Defender and Bitlocker
if ((Get-CimInstance -Class Win32_OperatingSystem).Caption -match "Windows Server") {
    Install-WindowsFeature -Name Bitlocker | Out-Null

    # Check the Windows Server version and install the appropriate Windows Defender features
    if (([version](Get-CimInstance -Class Win32_OperatingSystem).Version) -ge [version]"10.0") {
        # Windows Server 2016 or newer
        Install-WindowsFeature -Name Windows-Defender | Out-Null
        Install-WindowsFeature -Name Windows-Defender-GUI -ErrorAction SilentlyContinue | Out-Null
    } elseif (([version](Get-CimInstance -Class Win32_OperatingSystem).Version) -ge [version]"6.3") {
        # Windows Server 2012 R2
        Install-WindowsFeature -Name Windows-Defender | Out-Null
    }

    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Bitlocker and Windows Defender installed" -ForegroundColor white
} else {
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "ERROR" -ForegroundColor red -NoNewLine; Write-Host "] This script is only for Windows Server" -ForegroundColor white
}

# Downloading scripts
(New-Object System.Net.WebClient).DownloadFile("", (Join-Path -Path $ScriptPath -ChildPath "backup.ps1"))
(New-Object System.Net.WebClient).DownloadFile("", (Join-Path -Path $ScriptPath -ChildPath "firewall.ps1"))
(New-Object System.Net.WebClient).DownloadFile("", (Join-Path -Path $ScriptPath -ChildPath "usermgmt.ps1"))
(New-Object System.Net.WebClient).DownloadFile("", (Join-Path -Path $ScriptPath -ChildPath "iis.ps1"))
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/itm4n/PrivescCheck/master/PrivescCheck.ps1", (Join-Path -Path $ScriptPath -ChildPath "PrivescCheck.ps1"))

# Downloading Firewall Control and .NET 4.8
$net48path = Join-Path -Path $SetupPath -ChildPath "net_installer.exe"
(New-Object System.Net.WebClient).DownloadFile("https://www.binisoft.org/download/wfc6setup.exe", (Join-Path -Path $SetupPath -ChildPath "wfcsetup.exe"))
(New-Object System.Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?LinkId=2088631", $net48path)
Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Windows Firewall Control and .NET 4.8 installers downloaded" -ForegroundColor white
## silently installing .NET 4.8 library
& $net48path /passive /norestart

# Downloading Wireshark
(New-Object System.Net.WebClient).DownloadFile("https://1.na.dl.wireshark.org/win64/Wireshark-latest-x64.exe", (Join-Path -Path $SetupPath -ChildPath "wsinstall.exe"))

# Downloading Sysinternals Suite
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Autoruns.zip", (Join-Path -Path $InputPath -ChildPath "ar.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/ListDlls.zip", (Join-Path -Path $InputPath -ChildPath "dll.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/ProcessExplorer.zip", (Join-Path -Path $InputPath -ChildPath "pe.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/ProcessMonitor.zip", (Join-Path -Path $InputPath -ChildPath "pm.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Sigcheck.zip", (Join-Path -Path $InputPath -ChildPath "sc.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/TCPView.zip", (Join-Path -Path $InputPath -ChildPath "tv.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Streams.zip", (Join-Path -Path $InputPath -ChildPath "stm.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Sysmon.zip", (Join-Path -Path $InputPath -ChildPath "sm.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/AccessChk.zip", (Join-Path -Path $InputPath -ChildPath "ac.zip"))
(New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Strings.zip", (Join-Path -Path $InputPath -ChildPath "str.zip"))

# Downloading Antipwny
(New-Object System.Net.WebClient).DownloadFile("https://github.com/rvazarkar/antipwny/raw/refs/heads/master/exe/x86/AntiPwny.exe", (Join-Path -Path $antipwnyPath -ChildPath "AntiPwny.exe"))
(New-Object System.Net.WebClient).DownloadFile("https://github.com/rvazarkar/antipwny/raw/refs/heads/master/exe/x86/ObjectListView.dll", (Join-Path -Path $antipwnyPath -ChildPath "ObjectListView.dll"))

# Unzipping
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "ar.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "ar")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "dll.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "dll")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "pe.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "pe")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "pm.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "pm")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "sc.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "sc")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "tv.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "tv")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "stm.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "stm")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "sm.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "sm")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "ac.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "ac")
Expand-Archive -LiteralPath (Join-Path -Path $InputPath -ChildPath "str.zip") -DestinationPath (Join-Path -Path $SysPath -ChildPath "str")

foreach($file in (Get-childItem -Path $InputPath)){
    if($file.name -match ".zip"){
        Move-item -path (Join-Path -path $InputPath -ChildPath $file.name) -Destination $zippedPath
    }
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Downloads Script" -ForegroundColor white