$buildInfo = Get-Content -Path "$PSScriptRoot\buildinfo.json" -Raw | ConvertFrom-Json

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/eiedouno/PowerServer/main/installer/bin/initiate.ps1" -OutFile "$PSScriptRoot\initiate-update.ps1"

Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-File", "$PSScriptRoot\initiate-update.ps1",
    "-Path $($buildInfo.Path)",
    "-Version $($buildInfo.Version)",
    "-License", "true",
    "-Start", "true"
    "-Autokill", "true"
) 
Stop-Process -Id $PID