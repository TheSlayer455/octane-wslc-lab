[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Lock,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$Blocker='No approved controllable browser is available in the current execution environment.'
)

$ErrorActionPreference='Stop'
$lockPath=[IO.Path]::GetFullPath($Lock)
if(-not (Test-Path -LiteralPath $lockPath -PathType Leaf)){throw "Browser candidate lock not found: $lockPath"}
$value=Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
if($value.kind -ne 'browser-candidate-lock'){throw 'The supplied file is not a browser candidate lock.'}
$lockHash=(Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash.ToLowerInvariant()
$batchId='browser-qbatch-'+[Guid]::NewGuid().ToString('N').Substring(0,12)
$runs=1..10 | ForEach-Object {[ordered]@{sequence=$_;runId="$batchId-$('{0:d2}' -f $_)";status='NOT_RUN';reason=$Blocker}}
$plan=[ordered]@{
    schemaVersion=1;batchId=$batchId;declaredAtUtc=[DateTime]::UtcNow.ToString('o');lockSha256=$lockHash
    contract='10 fresh containers/prefixes/installations through approved browser framebuffer and input path; no RDP, repaint helper, hidden retry, or manual promotion.'
    status='BLOCKED';reason=$Blocker;plannedRuns=10;executedRuns=0;runs=$runs
}
$output=[IO.Path]::GetFullPath($OutputPath)
$parent=Split-Path $output -Parent;if($parent){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
$plan | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $output -Encoding utf8
Write-Output "Blocked qualification plan: $output"
