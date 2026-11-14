[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [string]$Installer,
    [ValidateRange(1024,65535)][int]$Port=3010,
    [string]$EvidenceDirectory,
    [switch]$RemoveAfterTest
)

$ErrorActionPreference='Stop'
$package=[IO.Path]::GetFullPath($PackageRoot)
$id=[Guid]::NewGuid().ToString('N').Substring(0,10)
$distribution="Octane-Test-$id"
$home=Join-Path $env:LOCALAPPDATA "Octane-Test-$id"
if(-not $EvidenceDirectory){$EvidenceDirectory=Join-Path (Get-Location) "evidence/appliance-test-$id"}
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$container=$null
$result=[ordered]@{schemaVersion=1;testId=$id;distribution=$distribution;startedAtUtc=[DateTime]::UtcNow.ToString('o');stages=[ordered]@{};container=$null;cleanup='NOT_RUN'}
try{
    & (Join-Path $package 'Install-Octane.ps1') -PackageRoot $package -OctaneHome $home -DistributionName $distribution -SkipPathUpdate -Confirm:$false
    $result.stages.install='PASS'
    & (Join-Path $home 'Octane.ps1') doctor -Deep -Port $Port | Set-Content -LiteralPath (Join-Path $evidence 'doctor.log') -Encoding utf8
    $result.stages.doctor='PASS'
    if($Installer){
        $runtime=Join-Path $home 'runtime'
        $output=Join-Path $evidence 'operator-output'
        $lines=@(& (Join-Path $home 'Octane.ps1') open $Installer -InputDirectory (Join-Path $runtime 'fixtures') -OutputDirectory $output -Port $Port -BuildLabel "appliance-test-$id" -NoBrowser)
        $lines | Set-Content -LiteralPath (Join-Path $evidence 'open.log') -Encoding utf8
        $containerLine=$lines | Where-Object {$_ -match '^Container: octane-[a-f0-9]{10}$'} | Select-Object -First 1
        if(-not $containerLine){throw 'Appliance preview did not return an exact container identity.'}
        $container=($containerLine -replace '^Container:\s*','').Trim()
        $result.container=$container
        & (Join-Path $runtime 'scripts/Test-OctaneBrowserComponents.ps1') -Container $container -WslDistro $distribution -OutputDirectory (Join-Path $evidence 'browser-components') | Set-Content -LiteralPath (Join-Path $evidence 'components.log') -Encoding utf8
        $result.stages.previewComponents='PASS'
        & (Join-Path $home 'Octane.ps1') collect -Container $container | Set-Content -LiteralPath (Join-Path $evidence 'collect.log') -Encoding utf8
        $result.stages.collection='PASS'
        & (Join-Path $home 'Octane.ps1') stop -Container $container | Set-Content -LiteralPath (Join-Path $evidence 'stop.log') -Encoding utf8
        $container=$null
        $result.stages.previewCleanup='PASS'
    }else{
        $result.stages.previewComponents='NOT_RUN'
    }
}catch{
    $result.error=$_.Exception.Message
    throw
}finally{
    if($container){
        try{& (Join-Path $home 'Octane.ps1') collect -Container $container *> $null}catch{}
        try{& (Join-Path $home 'Octane.ps1') stop -Container $container *> $null}catch{}
    }
    if($RemoveAfterTest -and (Test-Path -LiteralPath (Join-Path $home 'config.json'))){
        try{
            & (Join-Path $home 'Uninstall-Octane.ps1') -OctaneHome $home -ConfirmDistributionRemoval -Confirm:$false
            $result.cleanup='PASS'
        }catch{
            $result.cleanup="FAIL: $($_.Exception.Message)"
        }
    }
    $result.finishedAtUtc=[DateTime]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidence 'result.json') -Encoding utf8
}
Write-Output "Appliance package evidence: $evidence"
Write-Output "Distribution: $distribution"
Write-Output "Cleanup: $($result.cleanup)"
