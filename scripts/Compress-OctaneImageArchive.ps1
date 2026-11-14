[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$WslDistro='Ubuntu-24.04',
    [ValidateRange(1,19)][int]$CompressionLevel=10
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$input=[IO.Path]::GetFullPath($InputPath)
$output=[IO.Path]::GetFullPath($OutputPath)
if(-not (Test-Path -LiteralPath $input -PathType Leaf)){throw "Input image archive not found: $input"}
if(Test-Path -LiteralPath $output){throw "Compressed output already exists: $output"}
New-Item -ItemType Directory -Path (Split-Path $output -Parent) -Force | Out-Null
$runtimeInput=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $input
$runtimeOutput=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $output
$result=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
    '-d',$WslDistro,'--exec','zstd',"-$CompressionLevel",'-T0','--no-progress','--force','--output',$runtimeOutput,$runtimeInput
) -TimeoutSeconds 3600
if($result.TimedOut -or $result.ExitCode -ne 0){throw "zstd compression failed. $($result.StdErr)"}
$test=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
    '-d',$WslDistro,'--exec','zstd','--test','--no-progress',$runtimeOutput
) -TimeoutSeconds 1800
if($test.TimedOut -or $test.ExitCode -ne 0){throw "Compressed archive verification failed. $($test.StdErr)"}
$source=Get-Item -LiteralPath $input
$compressed=Get-Item -LiteralPath $output
$record=[ordered]@{
    schemaVersion=1
    kind='octane-compressed-docker-image-archive'
    createdAtUtc=[DateTime]::UtcNow.ToString('o')
    sourceFileName=$source.Name
    sourceLength=[int64]$source.Length
    sourceSha256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    fileName=$compressed.Name
    length=[int64]$compressed.Length
    sha256=(Get-FileHash -LiteralPath $compressed.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    compression="zstd-$CompressionLevel"
    integrityTest='PASS'
}
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$output.manifest.json" -Encoding utf8
Write-Output "Compressed image archive: $output"
Write-Output "SHA-256: $($record.sha256)"
Write-Output "Source SHA-256: $($record.sourceSha256)"
