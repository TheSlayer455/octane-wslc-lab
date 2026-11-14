[CmdletBinding()]
param(
    [Parameter(Position=0,Mandatory=$true)][ValidateSet('doctor','open','status','collect','stop','credential','target')][string]$Command,
    [Parameter(Position=1)][string]$Installer,
    [string]$Profile,
    [string]$InputDirectory,
    [string]$OutputDirectory,
    [ValidateRange(0,65535)][int]$Port=0,
    [string]$Container,
    [string]$BuildLabel,
    [switch]$NoBrowser,
    [switch]$Deep,
    [ValidatePattern('^[a-z][a-z0-9-]{1,47}$')][string]$Id,
    [string]$TargetOutput,
    [string]$ExecutableFileName,
    [string]$WindowTitleRegex,
    [string[]]$InstallArgument,
    [switch]$VerifiedInstallerArguments
)

$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'The installed Octane launcher must run on Windows in PowerShell 7.'}
$home=if($env:OCTANE_HOME){[IO.Path]::GetFullPath($env:OCTANE_HOME)}else{$PSScriptRoot}
$configPath=Join-Path $home 'config.json'
if(-not (Test-Path -LiteralPath $configPath -PathType Leaf)){throw "Octane is not installed at $home. Run Install-Octane.ps1 first."}
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$runtime=[IO.Path]::GetFullPath([string]$config.runtimeRoot)
if(-not (Test-Path -LiteralPath $runtime -PathType Container)){throw "Installed runtime is missing: $runtime"}

function Require-Container {
    if($Container -notmatch '^octane-[a-f0-9]{10}$'){throw 'This command requires -Container with an exact ID printed by octane open.'}
}

switch($Command){
    'doctor' {
        $arguments=@{Engine='Docker';WslDistro=[string]$config.distribution;Port=if($Port){$Port}else{[int]$config.defaultPort}}
        if($Deep){$arguments.Deep=$true}
        & (Join-Path $runtime 'scripts/Doctor-OctaneLab.ps1') @arguments
    }
    'open' {
        if(-not $Installer){throw 'Usage: octane open <installer.exe> [-Profile app.json] [-InputDirectory path] [-OutputDirectory path].'}
        $selectedProfile=if($Profile){[IO.Path]::GetFullPath($Profile)}else{[IO.Path]::GetFullPath([string]$config.defaultProfile)}
        $selectedInput=if($InputDirectory){[IO.Path]::GetFullPath($InputDirectory)}else{[IO.Path]::GetFullPath([string]$config.defaultInputDirectory)}
        $selectedOutput=if($OutputDirectory){[IO.Path]::GetFullPath($OutputDirectory)}else{[IO.Path]::GetFullPath([string]$config.defaultOutputDirectory)}
        New-Item -ItemType Directory -Path $selectedInput,$selectedOutput -Force | Out-Null
        $arguments=@{
            Profile=$selectedProfile
            Installer=[IO.Path]::GetFullPath($Installer)
            InputDirectory=$selectedInput
            OutputDirectory=$selectedOutput
            WslDistro=[string]$config.distribution
            Port=if($Port){$Port}else{[int]$config.defaultPort}
            Image=[string]$config.imageReference
        }
        if($BuildLabel){$arguments.BuildLabel=$BuildLabel}
        $lines=@(& (Join-Path $runtime 'scripts/Start-OctanePreview.ps1') @arguments)
        $lines | Write-Output
        $containerLine=$lines | Where-Object {$_ -match '^Container: octane-[a-f0-9]{10}$'} | Select-Object -First 1
        $viewerLine=$lines | Where-Object {$_ -match '^Viewer: http://127\.0\.0\.1:[0-9]+/octane\.html$'} | Select-Object -First 1
        if(-not $containerLine -or -not $viewerLine){throw 'Preview started without a parseable container/viewer identity; browser was not opened.'}
        $startedContainer=($containerLine -replace '^Container:\s*','').Trim()
        $viewer=($viewerLine -replace '^Viewer:\s*','').Trim()
        if(-not $NoBrowser){
            & (Join-Path $runtime 'scripts/Get-OctaneViewerCredential.ps1') -Container $startedContainer | Write-Output
            Start-Process $viewer
            Write-Output 'The per-run viewer credential is in the Windows clipboard.'
        }else{
            Write-Output "Browser opening disabled. Retrieve the credential with: octane credential -Container $startedContainer"
        }
    }
    'status' {
        if($Container){
            Require-Container
            $path=Join-Path $runtime "runs/$Container.json"
            if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Run record not found: $Container"}
            Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        }else{
            Get-ChildItem -LiteralPath (Join-Path $runtime 'runs') -Filter 'octane-??????????.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object {
                $value=Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                [pscustomobject]@{container=$value.container;state=$value.state;target=$value.targetId;viewer=$value.desktopAddress;updatedAtUtc=$value.updatedAtUtc}
            }
        }
    }
    'collect' {
        Require-Container
        & (Join-Path $runtime 'scripts/Collect-OctanePreview.ps1') -Container $Container -WslDistro ([string]$config.distribution)
    }
    'stop' {
        Require-Container
        & (Join-Path $runtime 'scripts/Stop-OctaneLab.ps1') -Container $Container -Engine Docker -WslDistro ([string]$config.distribution)
    }
    'credential' {
        Require-Container
        & (Join-Path $runtime 'scripts/Get-OctaneViewerCredential.ps1') -Container $Container
    }
    'target' {
        if(-not $Id -or -not $TargetOutput){throw 'Usage: octane target -Id example-app -TargetOutput <directory> [verified application options].'}
        $arguments=@{Id=$Id;Output=$TargetOutput}
        if($ExecutableFileName){$arguments.ExecutableFileName=$ExecutableFileName}
        if($WindowTitleRegex){$arguments.WindowTitleRegex=$WindowTitleRegex}
        if($InstallArgument){$arguments.InstallArgument=$InstallArgument}
        if($VerifiedInstallerArguments){$arguments.VerifiedInstallerArguments=$true}
        & (Join-Path $runtime 'scripts/New-OctaneTarget.ps1') @arguments
    }
}
