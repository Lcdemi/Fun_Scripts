param(
    [Parameter(Mandatory=$false)]
    [Array]$extraDirs
)

[string]$path = ($MyInvocation.MyCommand.Path).substring(0,($MyInvocation.MyCommand.Path).indexOf("scripts\backup.ps1"))

if (!(Test-Path -Path (Join-Path $path "backup"))) {
    New-Item -Path $path -Name "backup" -ItemType "directory" | Out-Null
}
[string]$backupParentPath = (Join-Path $path "backup")
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
[string]$backupPath = (Join-Path $backupParentpath $dateTime)

if (Get-Service -Name W3SVC 2>$null) {
    xcopy /E /I C:\inetpub (Join-Path -Path $backupPath -childPath "iis_backup") | Out-Null
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] IIS folder backed up" -ForegroundColor white
} else {
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "ERROR" -ForegroundColor red -NoNewLine; Write-Host "] IIS is not installed" -ForegroundColor white
}

if (Get-Service -Name WinRM 2>$null) {
    New-Item -Path $backupPath -Name "winrm" -ItemType "directory" | Out-Null
    $winrmConfigBackupPath = Join-Path -Path $backupPath -childPath "winrm\winrm_config_backup.txt"
    winrm get winrm/config > $winrmConfigBackupPath
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] WinRM configuration backed up" -ForegroundColor white
}

# Back up Extra Directories
foreach ($dir in $extraDirs){
    # xcopy doesn't work with a triling '\'
    if ($dir[$dir.Length - 1] -eq "\"){
        $dir = $dir.substring(0, $dir.Length - 1)
    }
    # Get the Last directory, because that is going to be the name of the directory within the backup
    $dirs = $dir -split "\\"
    $lastDir = $dirs[$dirs.Length - 1]
    
    # Copy over the directory
    xcopy $dir (Join-Path -Path $backupPath -ChildPath $lastDir) /H /I /K /S /X | Out-Null

    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] $($lastDir) folder backed up" -ForegroundColor white
}