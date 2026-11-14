[CmdletBinding()]
param(
    [ValidateSet('Docker')][string]$Engine = 'Docker',
    [string]$WslDistro,
    [string]$ArtifactsDirectory,
    [ValidateRange(60,3600)][int]$TimeoutSeconds = 1200
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')

if ($IsWindows -and -not $WslDistro) {
    throw 'Building with Docker from Windows requires -WslDistro.'
}
if (-not $ArtifactsDirectory) {
    $ArtifactsDirectory = Join-Path $root 'diagnostics/win32-file-dialog/artifacts'
}
New-Item -ItemType Directory -Path $ArtifactsDirectory -Force | Out-Null
foreach ($name in @('FileDialogProbe.exe','FileDialogProbe.sha256','compiler-version.txt','dialog-probe-manifest.json')) {
    $path = Join-Path $ArtifactsDirectory $name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

$runtimeRoot = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $root
$dockerfile = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path (Join-Path $root 'diagnostics/win32-file-dialog/Dockerfile')
$runtimeOutput = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $ArtifactsDirectory
$build = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @(
    'build','--progress','plain','--target','export',
    '--output',"type=local,dest=$runtimeOutput",
    '-f',$dockerfile,$runtimeRoot
) -TimeoutSeconds $TimeoutSeconds

$executable = Join-Path $ArtifactsDirectory 'FileDialogProbe.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing build output: $executable" }
$hash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedLine = Get-Content -LiteralPath (Join-Path $ArtifactsDirectory 'FileDialogProbe.sha256') -Raw
$builderHash = @($expectedLine.Trim() -split '\s+')[0].ToLowerInvariant()
if ($builderHash -ne $hash) {
    throw 'Builder checksum does not match the exported probe.'
}

$commit = [string](& git -C $root rev-parse HEAD | Select-Object -First 1)
$commit = $commit.Trim()
if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve the source commit.' }
$dirty = @(& git -C $root status --porcelain).Count -gt 0
$compiler = (Get-Content -LiteralPath (Join-Path $ArtifactsDirectory 'compiler-version.txt') -First 1).Trim()

[ordered]@{
    schemaVersion = 1
    file = 'FileDialogProbe.exe'
    sha256 = $hash
    sourceCommit = $commit
    sourceDirty = $dirty
    builtAtUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    builderImage = 'ubuntu@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5'
    compiler = $compiler
    modes = @('modern-open','modern-save','legacy-open','legacy-save')
    defaultApplicationMatch = [ordered]@{
        thread = 'worker'
        owner = 'none'
        apartment = 'STA|COINIT_DISABLE_OLE1DDE'
        rfdVersion = '0.15.4'
        rfdCommit = 'bac4bd3364f2befaabafa9f58ac77fd8925b2abf'
    }
    buildDurationMs = $build.DurationMs
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ArtifactsDirectory 'dialog-probe-manifest.json') -Encoding utf8

Write-Output "Dialog probe: $executable"
Write-Output "SHA-256: $hash"
Write-Output "Manifest: $(Join-Path $ArtifactsDirectory 'dialog-probe-manifest.json')"
