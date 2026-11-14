[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$Version='browser-runtime-kit-v1-candidate',
    [ValidatePattern('^[a-f0-9]{7,40}$')][string]$HarnessCommit
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$destination=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $destination){throw "Runtime-kit destination already exists: $destination"}
New-Item -ItemType Directory -Path $destination | Out-Null
try{
    $directories=@(
        'lab/browser','profiles/applications','profiles/qualification','schemas','templates','fixtures'
    )
    foreach($relative in $directories){
        $target=Join-Path $destination $relative
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $root $relative) -Force | Copy-Item -Destination $target -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Join-Path $destination 'lab') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'lab/Dockerfile.browser-novnc') -Destination (Join-Path $destination 'lab/Dockerfile.browser-novnc')
    New-Item -ItemType Directory -Path (Join-Path $destination 'scripts') -Force | Out-Null
    $scripts=@(
        'Build-OctaneBrowserImage.ps1','Collect-Evidence.ps1','Collect-OctanePreview.ps1','Doctor-OctaneLab.ps1','FileAccess.ps1',
        'Export-OctaneBrowserImage.ps1','Get-OctaneViewerCredential.ps1','Import-OctaneBrowserImage.ps1','New-OctaneBrowserCandidateLock.ps1','New-OctaneBrowserQualificationPlan.ps1','New-OctaneTarget.ps1','RunState.ps1','Runtime.ps1','RuntimeProfiles.ps1',
        'Show-OctaneManualBrowserHandoff.ps1','Stage-OctaneArtifact.ps1','Start-OctanePreview.ps1','Stop-OctaneLab.ps1',
        'Test-OctaneArtifactTransport.ps1','Test-OctaneBrowserComponents.ps1','Test-OctaneTargetProfile.ps1'
    )
    foreach($script in $scripts){Copy-Item -LiteralPath (Join-Path $root "scripts/$script") -Destination (Join-Path $destination "scripts/$script")}
    New-Item -ItemType Directory -Path (Join-Path $destination 'docs') -Force | Out-Null
    foreach($document in @('OCTANE-AI-HANDOFF.md','BROWSER-CANDIDATE-QUICKSTART.md','runtime-completion-ledger.md','compatibility-matrix.md','research-evidence-ledger.md')){
        $source=Join-Path $root "docs/$document"
        if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $destination "docs/$document")}
    }
    foreach($empty in @('runs','runs/artifacts','runs/secrets','evidence','work')){New-Item -ItemType Directory -Path (Join-Path $destination $empty) -Force | Out-Null}
    $manifest=[ordered]@{
        schemaVersion=1;version=$Version;createdAtUtc=[DateTime]::UtcNow.ToString('o')
        harnessCommit=if($HarnessCommit){$HarnessCommit}else{$null};sourceIndependent=$true
        excludes=@('target source','installer bytes','container image bytes','credentials','Git metadata','provider credentials')
        browserAcceptance='BLOCKED';browserAcceptanceReason='Candidate implementation has not been exercised through an approved controllable browser.'
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $destination 'runtime-kit.json') -Encoding utf8
    $lines=Get-ChildItem -LiteralPath $destination -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative=[IO.Path]::GetRelativePath($destination,$_.FullName).Replace([IO.Path]::DirectorySeparatorChar,'/')
        "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $relative"
    }
    [IO.File]::WriteAllLines((Join-Path $destination 'checksums.sha256'),$lines,[Text.UTF8Encoding]::new($false))
}catch{
    Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
    throw
}
Write-Output "Runtime kit: $destination"
Write-Output "Checksums: $(Join-Path $destination 'checksums.sha256')"
