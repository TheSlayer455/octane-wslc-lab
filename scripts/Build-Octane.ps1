[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    foreach ($tool in @('cargo','pnpm')) { if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool. See the guide prerequisites." } }
    pnpm install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
    cargo test -p octane-core --locked
    if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
    pnpm test
    if ($LASTEXITCODE -ne 0) { throw 'Frontend tests failed' }
    & (Join-Path $root 'tests/scripts.test.ps1')
    & (Join-Path $root 'tests/qualification.test.ps1')
    pnpm exec tauri build --bundles nsis
    if ($LASTEXITCODE -ne 0) { throw 'Tauri build failed' }
    $installers = @(Get-ChildItem -LiteralPath (Join-Path $root 'target/release/bundle/nsis') -Filter '*-setup.exe')
    if ($installers.Count -ne 1) { throw 'Expected exactly one NSIS installer' }
    $out = Join-Path $root 'artifacts'
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -LiteralPath $installers[0].FullName -Destination (Join-Path $out 'Octane-setup.exe')
    $hash = (Get-FileHash -LiteralPath (Join-Path $out 'Octane-setup.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    $commit = git rev-parse HEAD
    [ordered]@{schemaVersion=1;file='Octane-setup.exe';sha256=$hash;sourceCommit=$commit;builtAtUtc=[DateTime]::UtcNow.ToString('o');webviewMode='offlineInstaller';signed=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'installer-manifest.json') -Encoding utf8
    Write-Output "Built artifacts/Octane-setup.exe; SHA-256 $hash"
} finally { Pop-Location }
