[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$Image='octane-lab:browser-candidate-v1',
    [string]$WslDistro='Ubuntu-24.04'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
$path=[IO.Path]::GetFullPath($OutputPath)
if([IO.Path]::GetExtension($path) -ine '.tar'){throw 'Image recovery output must use a .tar extension.'}
if(Test-Path -LiteralPath $path){throw "Recovery archive already exists: $path"}
$parent=Split-Path $path -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$inspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
$value=@($inspect.StdOut | ConvertFrom-Json)[0]
if($value.Config.Labels.'com.octanelab.browser-transport' -ne 'novnc'){throw 'Selected image is not an identified Octane browser image.'}
$runtimePath=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $path
try{
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','save','--output',$runtimePath,$Image) -TimeoutSeconds 3600 | Out-Null
    $archive=Get-Item -LiteralPath $path
    $sha=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest=[ordered]@{
        schemaVersion=1;createdAtUtc=[DateTime]::UtcNow.ToString('o');imageReference=$Image;imageId=[string]$value.Id
        repoDigests=@($value.RepoDigests);archiveFileName=$archive.Name;archiveLength=[int64]$archive.Length;archiveSha256=$sha
        integrityMeaning='The archive checksum detects byte changes; it is not a signature or proof of reproducible build.'
    }
    Write-OctaneJsonAtomic -Path "$path.manifest.json" -Value $manifest
    Write-Output "Recovery archive: $path"
    Write-Output "SHA-256: $sha"
}catch{
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    throw
}
