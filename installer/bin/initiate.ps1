param(
    [string]$Path = "ERROR: Path not set",
    [string]$Version = "ERROR: Version not set",
    [string]$License = "false",
    [string]$DS="false",
    [string]$SM="false",
    [string]$Start="false",
    [string]$autokill="false"
)

# This is the installer for PowerServer.

if ($Path -eq "ERROR: Path not set" -or $Version -eq "ERROR: Version not set") {
    Write-Host "`n[ERROR] Path or Version not set. Please check your configuration." -ForegroundColor DarkRed
    Pause
    exit 1
}

if ($License -eq "false") {
    Write-Host "`n[ERROR] Please accept the license agreement before proceeding." -ForegroundColor DarkRed
    Pause
    exit
}

# Intro
$host.UI.RawUI.WindowTitle = "PowerServer Installer"
Write-Host "`nInstalling PowerServer -$Version" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Blue
Write-Host "[INFO] Installation path: $Path" -ForegroundColor Blue
Write-Host "[INFO] Starting download and setup...`n" -ForegroundColor Blue

Start-Sleep -Seconds 1

# File list
$files = @(
    "pwserver.ps1",
    "bin/server.ps1",
    "bin/update.ps1"
)
if ($Version -eq "stable") {
    $uri = "https://raw.githubusercontent.com/eiedouno/PowerServer/main/"
} else {
    Write-Host "`n[ERROR] Invalid version specified. Please check your configuration." -ForegroundColor DarkRed
    Pause
    exit 1
}
$total = $files.Count
$count = 0
$maxLength = ($files | Measure-Object -Property Length -Maximum).Maximum

foreach ($file in $files) {
    $count++
    $localPath = Join-Path $Path $file
    $folder = Split-Path $localPath
    $paddedFile = $file.PadRight($maxLength + 2)
    $percent = [math]::Round(($count / $total) * 100)

    try {
        # Ensure directory exists
        if (!(Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        # Show live percent
        Write-Host "`r[Downloading] $paddedFile ($percent%)" -NoNewline -ForegroundColor Yellow

        # Download the file
        Invoke-WebRequest -Uri ($uri + $file) -OutFile $localPath -ErrorAction Stop

        # Overwrite with success
        Write-Host "`r[Installed  ] $paddedFile       " -ForegroundColor Green
    }
    catch {
        Write-Host "`r[Failed     ] $paddedFile       " -ForegroundColor DarkRed
    }
}



Start-Sleep -Seconds 1



# Create build info file
$buildInfoPath = Join-Path $Path "\bin\buildinfo.json"
$buildInfo = @{
    Version = $Version
    Path = $Path
} | ConvertTo-Json | Set-Content -Path $buildInfoPath -Force
Write-Host "[INFO] Build info saved to buildinfo.json" -ForegroundColor Blue

# Delete the installer
Remove-Item -Path PowerServer-Installer -Force -Recurse

# End of installation
Write-Host "`n[INFO] Installation completed." -ForegroundColor Blue
if ($autokill -eq "true") {
    Stop-Process -Id $PID
} else {
    Write-Host "[INFO] Press any key to exit." -ForegroundColor Blue
}
Pause | Out-Null
exit 1