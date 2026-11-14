[CmdletBinding()]
param(
    [ValidateRange(400,1024)][int]$SizeMiB=420,
    [string]$OutputDirectory
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'RunState.ps1')
$id=[Guid]::NewGuid().ToString('N').Substring(0,12)
$workspace=[IO.Path]::GetFullPath((Join-Path $root "work/artifact-transport-$id"))
$allowed=[IO.Path]::GetFullPath((Join-Path $root 'work'))
if(-not $workspace.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Transport workspace escaped the project work directory.'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root "evidence/artifact-transport-$id"}
$evidence=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $workspace,$evidence -Force | Out-Null
$sourceDirectory=Join-Path $workspace 'source'
$cacheDirectory=Join-Path $workspace 'cache'
New-Item -ItemType Directory -Path $sourceDirectory,$cacheDirectory | Out-Null
$source=Join-Path $sourceDirectory 'setup.exe'
$partial=Join-Path $sourceDirectory 'partial.exe'

function New-LargeFixture([string]$Path,[int64]$Length,[byte]$Tail){
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{
        $header=[Text.Encoding]::ASCII.GetBytes('OCTANE-TRANSPORT-CAPACITY-FIXTURE-NOT-EXECUTABLE')
        $stream.Write($header,0,$header.Length)
        $stream.SetLength($Length)
        $stream.Position=$Length-1
        $stream.WriteByte($Tail)
        $stream.Flush($true)
    }finally{$stream.Dispose()}
}

try{
    $length=[int64]$SizeMiB*1MB
    New-LargeFixture -Path $source -Length $length -Tail 0x11
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $first=& (Join-Path $PSScriptRoot 'Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $cacheDirectory -BuildLabel synthetic-capacity-one
    $timer.Stop();$firstMs=$timer.ElapsedMilliseconds

    New-LargeFixture -Path $source -Length $length -Tail 0x22
    $timer.Restart()
    $second=& (Join-Path $PSScriptRoot 'Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $cacheDirectory -BuildLabel synthetic-capacity-two
    $timer.Stop();$secondMs=$timer.ElapsedMilliseconds
    if($first.sha256 -eq $second.sha256 -or $first.artifactPath -eq $second.artifactPath){throw 'Same filename with changed bytes reused a stale artifact.'}

    New-LargeFixture -Path $partial -Length 10MB -Tail 0x33
    $partialRejected=$false
    try{& (Join-Path $PSScriptRoot 'Stage-OctaneArtifact.ps1') -Installer $partial -OutputDirectory $cacheDirectory -ProducerSha256 $first.sha256 | Out-Null}catch{$partialRejected=$true}
    if(-not $partialRejected){throw 'Partial artifact was accepted against the complete producer hash.'}

    New-LargeFixture -Path $source -Length $length -Tail 0x11
    $reused=& (Join-Path $PSScriptRoot 'Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $cacheDirectory -BuildLabel synthetic-capacity-reuse
    if(-not $reused.reused -or $reused.sha256 -ne $first.sha256){throw 'An identical artifact did not reuse its immutable cache identity.'}

    Remove-Item -LiteralPath $workspace -Recurse -Force
    if(Test-Path -LiteralPath $workspace){throw 'Synthetic transport workspace cleanup failed.'}

    $record=[ordered]@{
        schemaVersion=1;scope='Synthetic transport/integrity only; not an executable installer or GUI result.'
        status='PASS';testedAtUtc=[DateTime]::UtcNow.ToString('o');requestedSizeMiB=$SizeMiB;actualLength=$length
        first=[ordered]@{sha256=$first.sha256;durationMs=$firstMs;artifactId=$first.artifactId}
        sameNameDifferentBytes=[ordered]@{sha256=$second.sha256;durationMs=$secondMs;artifactId=$second.artifactId;distinctIdentity=$true}
        interruptedOrPartialTransfer=[ordered]@{status='PASS';method='truncated bytes checked against the authoritative full-artifact hash';rejected=$partialRejected}
        immutableCacheReuse=[ordered]@{status='PASS';reused=[bool]$reused.reused;artifactId=$reused.artifactId}
        workspaceRemoved=$true
    }
    Write-OctaneJsonAtomic -Path (Join-Path $evidence 'transport-results.json') -Value $record
    Update-OctaneEvidenceChecksums -Directory $evidence
    Write-Output "Artifact transport evidence: $evidence"
}finally{
    if(Test-Path -LiteralPath $workspace){Remove-Item -LiteralPath $workspace -Recurse -Force}
}
