[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ReportPath,
    [Parameter(Mandatory=$true)][string]$FixtureDirectory,
    [string]$OutputPath
)
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)){throw "Report not found: $ReportPath"}
if(-not (Test-Path -LiteralPath $FixtureDirectory -PathType Container)){throw "Fixture directory not found: $FixtureDirectory"}

$report=Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
$fixtures=@(Get-ChildItem -LiteralPath $FixtureDirectory -File -Recurse | Sort-Object FullName)
$actual=@($report.files)
$assertions=[Collections.Generic.List[object]]::new()
function Add-Assertion([string]$Name,[bool]$Passed,[string]$Detail){
    $script:assertions.Add([ordered]@{name=$Name;passed=$Passed;detail=$Detail})
}

Add-Assertion 'schemaVersion' ($report.schemaVersion -eq 1) "actual=$($report.schemaVersion); expected=1"
Add-Assertion 'errorCount' (@($report.errors).Count -eq 0) "actual=$(@($report.errors).Count); expected=0"
Add-Assertion 'fileCount' ($actual.Count -eq $fixtures.Count) "actual=$($actual.Count); expected=$($fixtures.Count)"

$expectedGroups=[ordered]@{}
foreach($fixture in $fixtures){
    $extension=if($fixture.Extension){$fixture.Extension.TrimStart('.').ToLowerInvariant()}else{'(none)'}
    if(-not $expectedGroups.Contains($extension)){$expectedGroups[$extension]=0}
    $expectedGroups[$extension]++
    $entry=@($actual | Where-Object {[IO.Path]::GetFileName([string]$_.path) -eq $fixture.Name})
    $hash=(Get-FileHash -LiteralPath $fixture.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $matched=$entry.Count -eq 1 -and [string]$entry[0].sha256 -eq $hash -and [int64]$entry[0].bytes -eq $fixture.Length -and [string]$entry[0].extension -eq $extension
    Add-Assertion "file:$($fixture.Name)" $matched "sha256=$hash; bytes=$($fixture.Length); extension=$extension"
}

$groupMatch=$true
if(@($report.groups.PSObject.Properties).Count -ne $expectedGroups.Count){$groupMatch=$false}
foreach($key in $expectedGroups.Keys){
    $property=$report.groups.PSObject.Properties[$key]
    if($null -eq $property -or [int]$property.Value -ne [int]$expectedGroups[$key]){$groupMatch=$false}
}
Add-Assertion 'extensionGroups' $groupMatch "actual=$(@($report.groups.PSObject.Properties).Count); expected=$($expectedGroups.Count)"

$totalBytes=($fixtures | Measure-Object -Property Length -Sum).Sum
Add-Assertion 'totalBytes' ([int64]$report.totalBytes -eq [int64]$totalBytes) "actual=$($report.totalBytes); expected=$totalBytes"
$duplicateHashes=@($fixtures | ForEach-Object {[pscustomobject]@{Name=$_.Name;Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}} | Group-Object Hash | Where-Object Count -gt 1)
Add-Assertion 'duplicateSetCount' (@($report.duplicateSets).Count -eq $duplicateHashes.Count) "actual=$(@($report.duplicateSets).Count); expected=$($duplicateHashes.Count)"

$status=if(@($assertions | Where-Object {-not $_.passed}).Count){'FAIL'}else{'PASS'}
$result=[ordered]@{
    schemaVersion=1
    status=$status
    validatedAtUtc=[DateTime]::UtcNow.ToString('o')
    reportSha256=(Get-FileHash -LiteralPath $ReportPath -Algorithm SHA256).Hash.ToLowerInvariant()
    fixtureCount=$fixtures.Count
    expectedContract=[ordered]@{files=$fixtures.Count;extensionGroups=$expectedGroups.Count;duplicateSets=$duplicateHashes.Count;errors=0;totalBytes=[int64]$totalBytes}
    assertions=$assertions
}
$json=$result | ConvertTo-Json -Depth 10
if($OutputPath){
    $parent=Split-Path $OutputPath -Parent
    if($parent){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
    $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
$json
if($status -ne 'PASS'){throw 'Octane report validation failed. Inspect the emitted assertions.'}

