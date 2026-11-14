[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [string]$OctaneHome=$PSScriptRoot,
    [string]$AdditionalAllowedRoot,
    [switch]$ConfirmDistributionRemoval
)

$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'The Octane uninstaller must run on Windows.'}
$octaneRoot=[IO.Path]::GetFullPath($OctaneHome)
$configPath=Join-Path $octaneRoot 'config.json'
if(-not (Test-Path -LiteralPath $configPath -PathType Leaf)){throw "Octane configuration not found: $configPath"}
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$distribution=[string]$config.distribution
$distributionRoot=[IO.Path]::GetFullPath([string]$config.distributionInstallRoot)
if($distribution -notmatch '^Octane(?:[-A-Za-z0-9.]*)$'){throw "Refusing unsafe distribution identity: $distribution"}
$localAppData=[IO.Path]::GetFullPath($env:LOCALAPPDATA)
$allowedRoots=[Collections.Generic.List[string]]::new()
$allowedRoots.Add($localAppData)
if($AdditionalAllowedRoot){
    $extra=[IO.Path]::GetFullPath($AdditionalAllowedRoot)
    if($extra.Equals([IO.Path]::GetPathRoot($extra),[StringComparison]::OrdinalIgnoreCase)){throw 'AdditionalAllowedRoot cannot be a filesystem root.'}
    $allowedRoots.Add($extra)
}
foreach($target in @($octaneRoot,$distributionRoot)){
    $allowed=$false
    foreach($allowedRoot in $allowedRoots){
        if($target.StartsWith($allowedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$allowed=$true;break}
    }
    if(-not $allowed){throw "Refusing to remove a path outside the approved roots: $target"}
}
if(-not $ConfirmDistributionRemoval){throw 'Re-run with -ConfirmDistributionRemoval after collecting outputs. This permanently unregisters the exact Octane WSL distribution.'}
$marker=@(& wsl.exe -d $distribution -u root --exec cat /etc/octane-appliance.json 2>$null)
if($LASTEXITCODE -ne 0 -or (($marker -join "`n") | ConvertFrom-Json).kind -ne 'octane-wsl-appliance'){throw 'The selected WSL distribution does not carry the Octane appliance marker.'}
if(-not $PSCmdlet.ShouldProcess($distribution,"Terminate and permanently unregister the Octane appliance, then remove $octaneRoot and $distributionRoot")){return}
& wsl.exe --terminate $distribution *> $null
& wsl.exe --unregister $distribution *> $null
if($LASTEXITCODE -ne 0){throw "Unable to unregister $distribution. The Windows files were retained."}
$userPath=[Environment]::GetEnvironmentVariable('Path','User')
if($userPath){
    $parts=@($userPath -split ';' | Where-Object {$_ -and -not $_.Equals($octaneRoot,[StringComparison]::OrdinalIgnoreCase)})
    [Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')
}
Remove-Item -LiteralPath $octaneRoot -Recurse -Force
if(Test-Path -LiteralPath $distributionRoot){Remove-Item -LiteralPath $distributionRoot -Recurse -Force}
Write-Output "Removed Octane appliance $distribution, its separate WSL storage root, and Windows launcher files. User data outside those paths was not removed."
