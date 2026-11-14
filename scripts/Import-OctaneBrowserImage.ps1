[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256,
    [ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ExpectedImageId,
    [string]$WslDistro='Ubuntu-24.04'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$path=[IO.Path]::GetFullPath($ArchivePath)
if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Recovery archive not found: $path"}
$actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if($actual -ne $ExpectedSha256.ToLowerInvariant()){throw "Recovery archive hash mismatch: expected $($ExpectedSha256.ToLowerInvariant()), got $actual."}
$runtimePath=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $path
$load=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','load','--input',$runtimePath) -TimeoutSeconds 3600
if($ExpectedImageId){
    $found=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$ExpectedImageId) -TimeoutSeconds 60 -AllowFailure
    if($found.ExitCode -ne 0){throw "Archive loaded, but expected image ID $ExpectedImageId is unavailable."}
}
Write-Output $load.StdOut.Trim()
Write-Output "Verified recovery archive SHA-256: $actual"
