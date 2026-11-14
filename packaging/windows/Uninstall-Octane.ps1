[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [string]$OctaneHome=$PSScriptRoot,
    [switch]$ConfirmDistributionRemoval
)

$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'The Octane uninstaller must run on Windows.'}
$home=[IO.Path]::GetFullPath($OctaneHome)
$configPath=Join-Path $home 'config.json'
if(-not (Test-Path -LiteralPath $configPath -PathType Leaf)){throw "Octane configuration not found: $configPath"}
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$distribution=[string]$config.distribution
if($distribution -notmatch '^Octane(?:[-A-Za-z0-9.]*)$'){throw "Refusing unsafe distribution identity: $distribution"}
if(-not $ConfirmDistributionRemoval){throw 'Re-run with -ConfirmDistributionRemoval after collecting outputs. This permanently unregisters the exact Octane WSL distribution.'}
$marker=@(& wsl.exe -d $distribution -u root --exec cat /etc/octane-appliance.json 2>$null)
if($LASTEXITCODE -ne 0 -or (($marker -join "`n") | ConvertFrom-Json).kind -ne 'octane-wsl-appliance'){throw 'The selected WSL distribution does not carry the Octane appliance marker.'}
if(-not $PSCmdlet.ShouldProcess($distribution,"Terminate and permanently unregister the Octane appliance, then remove $home")){return}
& wsl.exe --terminate $distribution *> $null
& wsl.exe --unregister $distribution *> $null
if($LASTEXITCODE -ne 0){throw "Unable to unregister $distribution. The Windows files were retained."}
$userPath=[Environment]::GetEnvironmentVariable('Path','User')
if($userPath){
    $parts=@($userPath -split ';' | Where-Object {$_ -and -not $_.Equals($home,[StringComparison]::OrdinalIgnoreCase)})
    [Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')
}
$localAppData=[IO.Path]::GetFullPath($env:LOCALAPPDATA)
if(-not $home.StartsWith($localAppData+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Distribution was removed, but the custom Octane home must be removed manually: $home"}
Remove-Item -LiteralPath $home -Recurse -Force
Write-Output "Removed Octane appliance $distribution and Windows launcher files. User data outside $home was not removed."
