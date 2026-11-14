[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine,
    [string]$WslDistro,
    [string]$ScreenshotDirectory,
    [string]$RecordingPath
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

if($ScreenshotDirectory -and -not (Test-Path -LiteralPath $ScreenshotDirectory -PathType Container)){throw "Screenshot directory not found: $ScreenshotDirectory"}
if($RecordingPath -and -not (Test-Path -LiteralPath $RecordingPath -PathType Leaf)){throw "Recording not found: $RecordingPath"}

$metadata=Join-Path $root "runs/$Container.json"
$runRecord=if(Test-Path -LiteralPath $metadata){Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json}else{$null}
if(-not $Engine){$Engine=if($runRecord){$runRecord.engine}else{'Wslc'}}
if(-not $WslDistro -and $runRecord){$WslDistro=$runRecord.wslDistro}
Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
$profileName=if($runRecord){$runRecord.wineProfile}else{'WineGui'}
$profileBase=if($runRecord){$runRecord.baseImage}else{$null}
$profile=Get-OctaneWineProfile -WineProfile $profileName -BaseImage $profileBase
$out=Join-Path $root ("evidence/"+$Container+'-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
$logs=Join-Path $out 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null

# Never save raw inspect: its environment contains the desktop password.
$containerLogs=Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('logs',$Container) -TimeoutSeconds 60 -AllowFailure
($containerLogs.StdOut+"`n"+$containerLogs.StdErr).Trim() | Set-Content -LiteralPath (Join-Path $logs 'container.log') -Encoding utf8
$evidenceDirectory=$profile.EvidenceDirectory
Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('exec',$Container,'mkdir','-p',$evidenceDirectory) -TimeoutSeconds 60 | Out-Null
$runtimeOut=ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $out
Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',"${Container}:${evidenceDirectory}/.",$runtimeOut) -TimeoutSeconds 180 | Out-Null

if($runRecord){
    Update-OctaneRunStage -Path $metadata -Stage evidence -Status PASS -Detail "Collected to $out"
    Set-OctaneRunState -Path $metadata -State COLLECTED
    Write-OctaneResultArtifacts -RunPath $metadata -OutputDirectory $out | Out-Null
    $runRecord=Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
    $doctor=Join-Path $root "runs/$Container-doctor.json"
    if(Test-Path -LiteralPath $doctor){Copy-Item -LiteralPath $doctor -Destination (Join-Path $out 'doctor.json')}
}

$versionArgs=if($Engine -eq 'Wslc'){@('version')}else{@('version','--format','{{json .}}')}
$runtimeVersion=(Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $versionArgs -TimeoutSeconds 30).StdOut.Trim()
[ordered]@{schemaVersion=1;engine=$Engine;engineContext=(Get-OctaneRuntimeCommand -Engine $Engine -WslDistro $WslDistro).Context;wslDistro=$WslDistro;runtimeVersion=$runtimeVersion;wineProfile=$profile.Name;baseImage=$profile.BaseImage;resolvedBaseImage=if($runRecord){$runRecord.resolvedBaseImage}else{$null};collectedAtUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $out 'environment.json') -Encoding utf8

if($ScreenshotDirectory){
    $screenshots=Join-Path $out 'screenshots'
    New-Item -ItemType Directory -Path $screenshots -Force | Out-Null
    Get-ChildItem -LiteralPath $ScreenshotDirectory -File | Copy-Item -Destination $screenshots
}
if($RecordingPath){
    Copy-Item -LiteralPath $RecordingPath -Destination (Join-Path $out 'recording.mp4')
}
Update-OctaneEvidenceChecksums -Directory $out
Write-Output "Evidence: $out"
Write-Output 'Review logs and reports for sensitive file paths or credentials before sharing.'
