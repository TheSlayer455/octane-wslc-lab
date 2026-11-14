[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ApplianceTar,
    [Parameter(Mandatory=$true)][string]$ImageArchive,
    [Parameter(Mandatory=$true)][string]$RuntimeKitDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$Version='1.0.0-candidate',
    [string]$ImageReference='octane-lab:browser-candidate-v1',
    [Parameter(Mandatory=$true)][ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ImageId,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$UncompressedImageArchiveSha256
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$appliance=[IO.Path]::GetFullPath($ApplianceTar)
$image=[IO.Path]::GetFullPath($ImageArchive)
$runtime=[IO.Path]::GetFullPath($RuntimeKitDirectory)
$output=[IO.Path]::GetFullPath($OutputDirectory)
foreach($file in @($appliance,$image)){if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "Required release input not found: $file"}}
if(-not (Test-Path -LiteralPath $runtime -PathType Container)){throw "Runtime kit not found: $runtime"}
if(Test-Path -LiteralPath $output){throw "Release output already exists: $output"}
$applianceManifestPath="$appliance.manifest.json"
$imageManifestPath="$image.manifest.json"
foreach($file in @($applianceManifestPath,$imageManifestPath,(Join-Path $runtime 'checksums.sha256'))){if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "Required input manifest not found: $file"}}
$applianceManifest=Get-Content -LiteralPath $applianceManifestPath -Raw | ConvertFrom-Json
$imageManifest=Get-Content -LiteralPath $imageManifestPath -Raw | ConvertFrom-Json
if($applianceManifest.sha256 -ne (Get-FileHash -LiteralPath $appliance -Algorithm SHA256).Hash.ToLowerInvariant()){throw 'Appliance TAR does not match its build manifest.'}
if($imageManifest.sha256 -ne (Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant()){throw 'Compressed image archive does not match its build manifest.'}
if($imageManifest.sourceSha256 -ne $UncompressedImageArchiveSha256){throw 'Compressed image source identity does not match the declared Docker save archive.'}

New-Item -ItemType Directory -Path $output | Out-Null
try{
    foreach($directory in @('appliance','images','profiles','docs')){New-Item -ItemType Directory -Path (Join-Path $output $directory) | Out-Null}
    Copy-Item -LiteralPath $appliance -Destination (Join-Path $output 'appliance/octane-ubuntu.tar')
    Copy-Item -LiteralPath $image -Destination (Join-Path $output 'images/octane-wine-image.tar.zst')
    Copy-Item -LiteralPath $runtime -Destination (Join-Path $output 'runtime') -Recurse
    foreach($name in @('Install-Octane.ps1','Octane.ps1','Octane.cmd','Uninstall-Octane.ps1')){
        Copy-Item -LiteralPath (Join-Path $root "packaging/windows/$name") -Destination (Join-Path $output $name)
    }
    Copy-Item -LiteralPath (Join-Path $root 'templates/example-app/app.json') -Destination (Join-Path $output 'profiles/windows-tauri.json')
    foreach($name in @('OCTANE-AI-HANDOFF.md','BROWSER-CANDIDATE-QUICKSTART.md','Octane-Complete-Guide.pdf','THIRD-PARTY-NOTICES.md')){
        Copy-Item -LiteralPath (Join-Path $root "docs/$name") -Destination (Join-Path $output "docs/$name")
    }
    $runtimeChecksums=Join-Path $output 'runtime/checksums.sha256'
    $manifest=[ordered]@{
        schemaVersion=1
        kind='octane-wsl-appliance-release'
        version=$Version
        createdAtUtc=[DateTime]::UtcNow.ToString('o')
        platform=@{windows='Windows 11';wslVersion=2;architecture='amd64';ubuntu='24.04'}
        appliance=@{
            path='appliance/octane-ubuntu.tar'
            length=[int64](Get-Item -LiteralPath (Join-Path $output 'appliance/octane-ubuntu.tar')).Length
            sha256=(Get-FileHash -LiteralPath (Join-Path $output 'appliance/octane-ubuntu.tar') -Algorithm SHA256).Hash.ToLowerInvariant()
            version=[string]$applianceManifest.version
            sourceCommit=[string]$applianceManifest.sourceCommit
            dockerVersion='29.6.2'
        }
        image=@{
            path='images/octane-wine-image.tar.zst'
            length=[int64](Get-Item -LiteralPath (Join-Path $output 'images/octane-wine-image.tar.zst')).Length
            sha256=(Get-FileHash -LiteralPath (Join-Path $output 'images/octane-wine-image.tar.zst') -Algorithm SHA256).Hash.ToLowerInvariant()
            uncompressedSha256=$UncompressedImageArchiveSha256
            reference=$ImageReference
            imageId=$ImageId
        }
        runtime=@{
            path='runtime'
            checksumsPath='runtime/checksums.sha256'
            checksumsLength=[int64](Get-Item -LiteralPath $runtimeChecksums).Length
            checksumsSha256=(Get-FileHash -LiteralPath $runtimeChecksums -Algorithm SHA256).Hash.ToLowerInvariant()
            defaultProfile='runtime/profiles/applications/octane-reference.app.json'
        }
        launcher=@{defaultPort=3005;browser='Windows default browser';authentication='per-run credential copied to clipboard immediately before browser open'}
        exclusions=@('target installer','target source','credentials','raw evidence','populated Docker data root')
        qualification=@{historicalRdp='QUALIFIED exact 10/10';browser='BLOCKED; candidate only; 0/10 browser runs executed'}
    }
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8
    $lines=Get-ChildItem -LiteralPath $output -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative=[IO.Path]::GetRelativePath($output,$_.FullName).Replace([IO.Path]::DirectorySeparatorChar,'/')
        "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $relative"
    }
    [IO.File]::WriteAllLines((Join-Path $output 'checksums.sha256'),$lines,[Text.UTF8Encoding]::new($false))
}catch{
    Remove-Item -LiteralPath $output -Recurse -Force -ErrorAction SilentlyContinue
    throw
}
Write-Output "Octane appliance release: $output"
Write-Output "Manifest: $(Join-Path $output 'manifest.json')"
Write-Output "Checksums: $(Join-Path $output 'checksums.sha256')"
