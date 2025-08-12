param (
    [Alias("p")]
    [string]$Path = "HELPMSG",

    [Alias("Pt")]
    [int]$Port = 8080,

    [switch]$NoLog,

    [ValidateSet("Allow", "Deny", "Password")]
    [string]$FileUploadPolicy = "Deny",

    [switch]$SetDefault,
    [switch]$Default,
    [switch]$Help
)

if (($Path -eq "HELPMSG") -or ($Path -eq "/?") -or ($Help) -and -not $SetDefault -and -not ($Default)) {
    Write-Host "PowerServer v0.1`nCreated by eiedouno (https://github.com/eiedouno)`n`nCreates a webserver on LAN.
    
PWServer[.ps1] [-Path <string>]
    [-Port <int>] [-NoLog] [-FileUploadPolicy <FileUploadPolicy>]
    [-SetDefault] [-Default] [-Help]
    
PWServer[.ps1] -Help | -? | /?

-Path, -P
    Sets the file path for the webserver.
    Example: `"C:\Users\Administrator\Webserver`"
        Important: Values with a whitespace-character (spaces) are currently unsupported.
    
-Port, -Pt
    Sets the desired port. Valid Values are 4-digit integers.
    Examples: `"3002`", `"4030`", `"1001`"
    The default value is 8080.

-NoLog
    Hides the connection log.

-FileUploadPolicy
    Controls whether or not connections are allowed to make edits to files. Valid Values are:
    `"Deny`" - Disallow file changes. (Default)
    `"Allow`" - Allow file changes.
    `"Password`" - Require a password for file changes.
        Passwords are loaded into RAM as plaintext and are not saved between sessions.

-SetDefault
    Set the values for the default preset.
    
-Default
    Loads the default preset.
    
-Help, -?, /?
    Shows this message.

EXAMPLES
    PWServer.ps1 -Path C:\ -Port 8080 -FileUploadPolicy Allow
    PWServer -P C:\ -Pt 8080 -NoLog -FileUploadPolicy Deny
    PWServer C:\ 8080 Allow`n"
    exit
}

if ($SetDefault) {
    if (-not (Test-Path "$PSScriptRoot\default.txt")) {
        New-Item -Path $PSScriptRoot -ItemType File -Name default.txt
    }
    Start-Process $PSScriptRoot\default.txt
    exit
}

if ($Default) {
    $paramArray = Get-Content $PSSCriptRoot\default.txt | ConvertFrom-JSON
    $Path = $paramArray.Path
    $Port = $paramArray.Port
    if ($paramArray.NoLog) {
        $NoLog = $paramArray.NoLog
    }
    $FileUploadPolicy = $paramArray.FileUploadPolicy
    $Password = $paramArray.Password
}

if ($FileUploadPolicy -eq "Password" -and -not $Password) {
    Write-Host "This password isn't saved. You will have to input it again."
    $Password = Read-Host "Enter upload password"
    [console]::SetCursorPosition(0, [console]::CursorTop - 1)
    Write-Host "`rPassword Set                                                                                           "
}

# Normalize path
$Path = (Resolve-Path $Path).Path
if (-not (Test-Path $Path -PathType Container)) {
    Write-Error "Invalid path: $Path"
    exit 1
}

$argList = @(
    "-File", "`"$PSScriptRoot\bin\server.ps1`"",
    "-Path", "$Path",
    "-Port", "$Port",
    "-NoLog", "$NoLog",
    "-FileUploadPolicy", "$FileUploadPolicy"
)

if ($FileUploadPolicy -eq "Password") {
    $argList += @("-Pd", "`"$Password`"")
}

Start-Process powershell -ArgumentList $argList