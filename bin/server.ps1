param(
    [string]$Path,
    [int]$Port,
    [string]$NoLog,
    [string]$FileUploadPolicy,
    [string]$Pd
)
$PasswordPlain = $Pd

$Path = $Path.Trim('(', ')')

$host.UI.RawUI.WindowTitle = "PowerServer - Port $Port"

Write-Host "Starting Webserver"
Start-Sleep -Seconds 1

# Start HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$Port/")
$listener.Start()

Write-Host "Arguments Passed: $Path, $Port, $NoLog, $FileUploadPolicy"
Start-Sleep -Milliseconds 1

Write-Host "`n`nServing $Path on port $Port"
Write-Host "Uploads allowed: $($FileUploadPolicy -eq 'Allow' -or $FileUploadPolicy -eq 'Password')"
Start-Sleep -Seconds 2
Write-Host "`nConnections:"

function Get-ContentType($file) {
    switch -Wildcard ($file) {
        "*.html" { "text/html" }
        "*.htm"  { "text/html" }
        "*.txt"  { "text/plain" }
        "*.css"  { "text/css" }
        "*.js"   { "application/javascript" }
        "*.json" { "application/json" }
        "*.jpg"  { "image/jpeg" }
        "*.jpeg" { "image/jpeg" }
        "*.png"  { "image/png" }
        "*.gif"  { "image/gif" }
        "*.ico"  { "image/x-icon" }
        "*.svg"  { "image/svg+xml" }
        "*.zip"  { "application/zip" }
        default  { "application/octet-stream" }
    }
}

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $clientIP = $context.Request.RemoteEndPoint.Address.ToString()
    $method = $request.HttpMethod
    $url = $request.Url.LocalPath
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $relativePath = $url.TrimStart("/")
    $localPath = Join-Path $Path $relativePath

    $uploadedFile = $null
    $downloadedFile = $null

    try {
        # Handle POST requests (upload / folder create)
        if ($method -eq "POST" -and ($FileUploadPolicy -eq "Allow" -or $FileUploadPolicy -eq "Password")) {

            # Password check if required
            if ($FileUploadPolicy -eq "Password") {
                $providedPassword = $request.Headers["X-Upload-Password"]
                if (-not $providedPassword -or $providedPassword -ne $PasswordPlain) {
                    $response.StatusCode = 403
                    $response.StatusDescription = "Forbidden: Invalid upload password"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("Wrong upload password.")
                    $response.ContentType = "text/plain"
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $response.OutputStream.Close()
                    continue
                }
            }

            # Check if folder creation header is present
            $newFolderName = $request.Headers["X-New-Folder"]
            if ($newFolderName) {
                $folderPath = Join-Path $localPath ([uri]::UnescapeDataString($newFolderName))
                if (-not (Test-Path $folderPath)) {
                    New-Item -ItemType Directory -Path $folderPath | Out-Null
                    $uploadedFile = "Folder Created: $newFolderName"
                    $response.StatusCode = 200
                    $response.StatusDescription = "Folder created"
                }
                else {
                    $response.StatusCode = 409
                    $response.StatusDescription = "Folder already exists"
                }
                $response.OutputStream.Close()
                continue
            }
            
            # Handle file upload (streamed, no RAM bloat)
            $filename = $request.Headers["X-Filename"]
            if (-not $filename) {
                $response.StatusCode = 400
                $response.StatusDescription = "Missing X-Filename header"
                $response.OutputStream.Close()
                continue
            }
            
            $uploadPath = Join-Path $localPath ([uri]::UnescapeDataString($filename))
            
            try {
                $fs = [System.IO.File]::Create($uploadPath)
                $buffer = New-Object byte[] (1MB)
                while (($read = $request.InputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fs.Write($buffer, 0, $read)
                }
                $fs.Close()
                $uploadedFile = $filename
                $response.StatusCode = 200
                $response.StatusDescription = "Upload OK"
            }
            catch {
                if ($fs) { $fs.Close() }
                $response.StatusCode = 500
                $response.StatusDescription = "Failed to write file"
            }
            
            $response.OutputStream.Close()
            continue

        }

        # Serve zip archive if query ?zip=1
        if ($request.QueryString["zip"] -eq "1" -and (Test-Path $localPath -PathType Container)) {
            $zipName = "$($relativePath.TrimEnd('/') -replace '[\\/:*?"<>|]', '_').zip"
            $zipPath = Join-Path $env:TEMP $zipName
            if (Test-Path $zipPath) { Remove-Item $zipPath }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::CreateFromDirectory($localPath, $zipPath)
            $bytes = [System.IO.File]::ReadAllBytes($zipPath)
            $response.ContentType = "application/zip"
            $response.ContentLength64 = $bytes.Length
            $response.AddHeader("Content-Disposition", "attachment; filename=`"$zipName`"")
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            Remove-Item $zipPath
            $downloadedFile = $zipName
            continue
        }

        # Serve index files or directory listing
        if ([string]::IsNullOrWhiteSpace($relativePath) -or (Test-Path $localPath -PathType Container)) {
            foreach ($index in "index.html", "index.htm") {
                $indexFile = Join-Path $localPath $index
                if (Test-Path $indexFile -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($indexFile)
                    $response.ContentType = Get-ContentType $indexFile
                    $response.ContentLength64 = $bytes.Length
                    $response.StatusCode = 200
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $response.OutputStream.Close()
                    $downloadedFile = $indexFile
                    if (-not $NoLog) {
                        Write-Host "[$timestamp] $clientIP -> $method $url [200 index]"
                    }
                    continue 2
                }
            }

            $items = Get-ChildItem -Path $localPath
            $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Index of /$relativePath</title>
<style>
    body { font-family: Arial, sans-serif; }
    ul { list-style-type: none; padding-left: 0; }
    li { margin-bottom: 8px; }
    .folder-item {
        display: flex;
        align-items: center;
        gap: 10px;
    }
    .download-btn {
        padding: 3px 8px;
        font-size: 0.9em;
        cursor: pointer;
    }
</style>
</head>
<body>
<h2>Index of /$relativePath</h2>
<ul>
"@

            if ($relativePath -ne "") {
                $html += "<li><a href='../'>..</a></li>`n"
            }

            foreach ($item in $items) {
                $name = $item.Name
                $href = [uri]::EscapeDataString($name)
                if ($item.PSIsContainer) {
                    $href += "/"
                    $html += "<li class='folder-item'><a href='$href'>$name</a><button class='download-btn' onclick='downloadFolder(`"$href`")'>Download</button></li>`n"
                }
                else {
                    $html += "<li><a href='$href'>$name</a></li>`n"
                }
            }

            $html += "</ul>"
            
            if ($FileUploadPolicy -eq "Allow" -or $FileUploadPolicy -eq "Password") {
                $html += @"
<form method='POST' enctype='text/plain' id='uploadForm'>
    <p>Upload file:</p>
    <input type='file' id='fileInput' />
    <button type='button' onclick='promptUploadPassword()'>Upload</button>
</form>
            
<form method='POST' enctype='text/plain' id='folderForm' onsubmit='return promptFolderPassword();'>
    <p>Create new folder:</p>
    <input type='text' id='newFolderName' required />
    <button type='submit'>Create Folder</button>
</form>
            
<script>
function promptUploadPassword() {
    var file = document.getElementById('fileInput').files[0];
    if (!file) {
        alert('Select a file to upload.');
        return;
    }
            
    var headers = { 'X-Filename': file.name };
"@
                if ($FileUploadPolicy -eq "Password") {
                    $html += @"
    var pw = prompt('Enter password for upload:');
    if (pw === null || pw === '') {
        alert('Upload cancelled. Password required.');
        return;
    }
    headers['X-Upload-Password'] = pw;
"@
                }
                $html += @"
    fetch(window.location.href, {
        method: 'POST',
        headers: headers,
        body: file
    }).then(response => {
        if (response.ok) {
            alert('Upload successful.');
            location.reload();
        } else if (response.status === 403) {
            alert('Invalid password.');
        } else {
            alert('Upload failed.');
        }
    });
}
            
function promptFolderPassword() {
    var folderName = document.getElementById('newFolderName').value;
    if (!folderName) {
        alert('Enter a folder name.');
        return false;
    }
"@
                if ($FileUploadPolicy -eq "Password") {
                    $html += @"
    var pw = prompt('Enter password for folder creation:');
    if (pw === null || pw === '') {
        alert('Folder creation cancelled. Password required.');
        return false;
    }
    var headers = { 'X-New-Folder': folderName, 'X-Upload-Password': pw };
"@
                } else {
                    $html += @"
    var headers = { 'X-New-Folder': folderName };
"@
                }
                $html += @"
        fetch(window.location.href, {
            method: 'POST',
            headers: headers
        }).then(response => {
            if (response.status === 200) {
                alert('Folder created successfully');
                location.reload();
            } else if (response.status === 409) {
                alert('Folder already exists');
            } else if (response.status === 403) {
            alert('Invalid password');
        } else {
            alert('Failed to create folder');
        }
    });
    return false;
}
            
function downloadFolder(folderPath) {
    var basePath = (location.pathname === '/' ? '' : location.pathname);
    window.location.href = basePath + folderPath + '?zip=1';
}
</script>
"@
            }


            $html += "</body></html>"

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = "text/html"
            $response.StatusCode = 200
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
        elseif (Test-Path $localPath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            $response.ContentType = Get-ContentType $localPath
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            $downloadedFile = $localPath
        }
        else {
            foreach ($f404 in "404.html", "404.htm") {
                $custom404 = Join-Path $Path $f404
                if (Test-Path $custom404 -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($custom404)
                    $response.ContentType = Get-ContentType $custom404
                    $response.StatusCode = 404
                    $response.ContentLength64 = $bytes.Length
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $response.OutputStream.Close()
                    if (-not $NoLog) {
                        Write-Host "[$timestamp] $clientIP -> $method $url [404 custom]"
                    }
                    continue 2
                }
            }
            $response.StatusCode = 404
            $response.StatusDescription = "Not Found"
            $response.OutputStream.Close()
        }
    }
    catch {
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error"
        $response.OutputStream.Close()
    }
    finally {
        if ($NoLog -eq "False") {
            $status = $response.StatusCode
            $logMsg = "[$timestamp] $clientIP -> $method $url [$status]"
            if ($uploadedFile) { $logMsg += " Uploaded: $uploadedFile" }
            if ($downloadedFile) { $logMsg += " Downloaded: $downloadedFile" }
            Write-Host $logMsg
        }
    }
}
