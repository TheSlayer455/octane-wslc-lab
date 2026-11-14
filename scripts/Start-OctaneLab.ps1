[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port=3001,
      [string]$BaseImage='lscr.io/linuxserver/winegui:latest')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Wslc.ps1')
if (-not (Test-Path -LiteralPath (Join-Path $root 'artifacts/Octane-setup.exe'))) { throw 'Build or download the installer to artifacts/Octane-setup.exe first.' }
$manifest = Get-Content -LiteralPath (Join-Path $root 'artifacts/installer-manifest.json') -Raw | ConvertFrom-Json
$actual = (Get-FileHash -LiteralPath (Join-Path $root 'artifacts/Octane-setup.exe') -Algorithm SHA256).Hash
if ($actual -ne $manifest.sha256) { throw 'Installer hash does not match manifest' }
Invoke-Wslc @('version')
Invoke-Wslc @('container','cp','--help') | Out-Null
$id = [Guid]::NewGuid().ToString('N').Substring(0,10)
$name = "octane-$id"
$image = "octane-lab:$id"
$runs = Join-Path $root 'runs'
New-Item -ItemType Directory -Path $runs -Force | Out-Null
$passwordBytes = New-Object byte[] 24
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($passwordBytes) } finally { $rng.Dispose() }
$password = [Convert]::ToBase64String($passwordBytes)
Push-Location $root
try {
    Invoke-Wslc @('build','--build-arg',"BASE_IMAGE=$BaseImage",'-f','lab/Dockerfile','-t',$image,'.')
    Invoke-Wslc @('run','-d','--name',$name,'--label','com.octanelab.managed=true','--shm-size=1gb','-p',"127.0.0.1:${Port}:3001",'-e','CUSTOM_USER=octane','-e',"PASSWORD=$password",'-e','TZ=America/Chicago',$image)
    [ordered]@{schemaVersion=1;container=$name;image=$image;baseImage=$BaseImage;port=$Port;installerSha256=$actual.ToLowerInvariant();createdAtUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runs "$name.json") -Encoding utf8
    Write-Output "Container: $name"
    Write-Output "Desktop: https://localhost:$Port"
    Write-Output 'Username: octane'
    Write-Output "Password: $password"
    Write-Output 'Keep the password local. It is not stored in run metadata.'
    Write-Output "Run metadata: runs/$name.json"
    Write-Output 'Open the browser desktop terminal and run: octane-lab notepad; octane-lab install; octane-lab launch (one at a time).'
} finally { Pop-Location }
