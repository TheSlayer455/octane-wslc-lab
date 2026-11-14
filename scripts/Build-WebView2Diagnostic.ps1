[CmdletBinding()]
param(
    [string]$NuGetCommand = 'nuget',
    [string]$MSBuildCommand = 'msbuild',
    [string]$ArtifactsDirectory,
    [switch]$SkipRestore
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $root 'diagnostics/webview2-win32'
$solution = Join-Path $project 'WebView2Diagnostic.sln'
$packages = Join-Path $project 'packages'
$source = Join-Path $project 'bin/x64/Release/WebView2Diagnostic.exe'
if (-not $ArtifactsDirectory) { $ArtifactsDirectory = Join-Path $project 'artifacts' }

if (-not $SkipRestore) {
    & $NuGetCommand restore $solution -PackagesDirectory $packages -NonInteractive
    if ($LASTEXITCODE -ne 0) { throw "NuGet restore failed with exit code $LASTEXITCODE." }
}

& $MSBuildCommand $solution /m /p:Configuration=Release /p:Platform=x64 /p:ContinuousIntegrationBuild=true
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $source)) { throw "Missing build output: $source" }

New-Item -ItemType Directory -Path $ArtifactsDirectory -Force | Out-Null
$output = Join-Path $ArtifactsDirectory 'WebView2Diagnostic.exe'
Copy-Item -LiteralPath $source -Destination $output -Force
$hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
$commit = [string](& git -C $root rev-parse HEAD | Select-Object -First 1)
$commit = $commit.Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve the source commit.' }
$dirty = @(& git -C $root status --porcelain).Count -gt 0

[ordered]@{
    schemaVersion = 2
    file = 'WebView2Diagnostic.exe'
    sha256 = $hash
    sourceCommit = $commit
    sourceDirty = $dirty
    builtAtUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    webView2Sdk = '1.0.3856.49'
    upstreamSampleRepository = 'https://github.com/MicrosoftEdge/WebView2Samples'
    upstreamSampleReference = '06d49d546ba5dc0e2773798ee5b982f68275af4c'
    capabilities = @(
        'installed-or-fixed-runtime-selection'
        'additional-browser-arguments'
        'initialization-deadlines'
        'request-animation-frame-telemetry'
        'native-window-lifecycle-events'
        'process-failure-events'
    )
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $ArtifactsDirectory 'diagnostic-manifest.json') -Encoding utf8

Write-Output "Diagnostic: $output"
Write-Output "SHA-256: $hash"
Write-Output "Manifest: $(Join-Path $ArtifactsDirectory 'diagnostic-manifest.json')"
