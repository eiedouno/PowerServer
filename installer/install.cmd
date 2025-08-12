@echo off
powershell -Command "New-Item -Path 'PowerServer-Installer' -ItemType Directory -Force"
powershell -Command "New-Item -Path 'PowerServer-Installer\bin' -ItemType Directory -Force"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/eiedouno/PowerServer/main/installer/LICENSE.txt' -OutFile 'PowerServer-Installer\LICENSE.txt'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/eiedouno/PowerServer/main/installer/bin/install.ps1' -OutFile 'PowerServer-Installer\bin\install.ps1'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/eiedouno/PowerServer/main/installer/bin/initiate.ps1' -OutFile 'PowerServer-Installer\bin\initiate.ps1'"
powershell -File "PowerServer-Installer\bin\install.ps1"