[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [Parameter(Mandatory=$true)][ValidateSet('artifact','runtimeDoctor','imageBuild','containerCreate','desktopEndpoint','basicWine','installer','application','workload','nativeDialogs','export','evidence','cleanup')][string]$Stage,
    [Parameter(Mandatory=$true)][ValidateSet('PASS','FAIL','BLOCKED','NOT_RUN')][string]$Status,
    [string]$Detail,
    [Nullable[int64]]$DurationMs,
    [switch]$BlockRemaining
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'RunState.ps1')
$metadata=Join-Path $root "runs/$Container.json"
if(-not (Test-Path -LiteralPath $metadata)){throw "Run metadata not found: $metadata"}
if($BlockRemaining -and $Status -ne 'FAIL'){throw '-BlockRemaining requires -Status FAIL.'}
Update-OctaneRunStage -Path $metadata -Stage $Stage -Status $Status -Detail $Detail -DurationMs $DurationMs
if($BlockRemaining){
    Block-OctaneRunStages -Path $metadata -Detail "Blocked after $Stage failed."
}
Write-Output "Recorded $Stage=$Status for $Container."
