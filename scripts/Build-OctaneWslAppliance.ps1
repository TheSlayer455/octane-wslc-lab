[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z.-]{0,63}$')][string]$Version='1.0.0-candidate',
    [string]$WslDistro='Ubuntu-24.04',
    [string]$UbuntuBase='ubuntu@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5',
    [string]$DockerCeVersion='5:29.6.2-1~ubuntu.24.04~noble',
    [string]$ContainerdVersion='2.2.6-1~ubuntu.24.04~noble',
    [string]$BuildxVersion='0.36.0-1~ubuntu.24.04~noble',
    [string]$ComposeVersion='5.3.1-1~ubuntu.24.04~noble'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')

$output=[IO.Path]::GetFullPath($OutputPath)
if(Test-Path -LiteralPath $output){throw "Appliance output already exists: $output"}
$parent=Split-Path $output -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null

$sourceCommit='unknown'
try{
    $candidate=(& git -C $root rev-parse HEAD 2>$null).Trim()
    if($candidate -match '^[a-f0-9]{40}$'){$sourceCommit=$candidate}
}catch{}

$tagVersion=($Version.ToLowerInvariant() -replace '[^a-z0-9_.-]','-')
$image="octane-appliance-rootfs:$tagVersion"
$id=[Guid]::NewGuid().ToString('N').Substring(0,10)
$container="octane-appliance-export-$id"
$runtimeRoot=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $root
$runtimeOutput=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $output
$created=$false

try{
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
        'build','--platform','linux/amd64',
        '--file',"$runtimeRoot/lab/Dockerfile.wsl-appliance",
        '--tag',$image,
        '--build-arg',"UBUNTU_BASE=$UbuntuBase",
        '--build-arg',"OCTANE_APPLIANCE_VERSION=$Version",
        '--build-arg',"OCTANE_SOURCE_COMMIT=$sourceCommit",
        '--build-arg',"DOCKER_CE_VERSION=$DockerCeVersion",
        '--build-arg',"CONTAINERD_VERSION=$ContainerdVersion",
        '--build-arg',"BUILDX_VERSION=$BuildxVersion",
        '--build-arg',"COMPOSE_VERSION=$ComposeVersion",
        $runtimeRoot
    ) -TimeoutSeconds 3600 | Out-Null

    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
        'create','--name',$container,
        '--label','com.octanelab.appliance-export=true',
        '--label',"com.octanelab.appliance-version=$Version",
        $image
    ) -TimeoutSeconds 120 | Out-Null
    $created=$true
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
        'export','--output',$runtimeOutput,$container
    ) -TimeoutSeconds 1800 | Out-Null
}finally{
    if($created){
        $inspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('inspect',$container) -TimeoutSeconds 60 -AllowFailure
        if($inspect.ExitCode -eq 0){
            $value=@($inspect.StdOut | ConvertFrom-Json)[0]
            if($value.Config.Labels.'com.octanelab.appliance-export' -eq 'true'){
                Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('rm',$container) -TimeoutSeconds 120 | Out-Null
            }else{
                throw "Refusing to remove export container without the expected label: $container"
            }
        }
    }
}

if(-not (Test-Path -LiteralPath $output -PathType Leaf)){throw 'Docker export did not produce the appliance TAR.'}
$file=Get-Item -LiteralPath $output
$sha=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
$imageInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$image) -TimeoutSeconds 60
$imageValue=@($imageInspect.StdOut | ConvertFrom-Json)[0]
$manifest=[ordered]@{
    schemaVersion=1
    kind='octane-wsl-appliance-rootfs'
    createdAtUtc=[DateTime]::UtcNow.ToString('o')
    version=$Version
    sourceCommit=$sourceCommit
    fileName=$file.Name
    length=[int64]$file.Length
    sha256=$sha
    architecture='amd64'
    ubuntuBase=$UbuntuBase
    docker=@{
        dockerCe=$DockerCeVersion
        containerd=$ContainerdVersion
        buildx=$BuildxVersion
        compose=$ComposeVersion
    }
    buildImage=$image
    buildImageId=[string]$imageValue.Id
}
$manifestPath="$output.manifest.json"
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "WSL appliance TAR: $output"
Write-Output "SHA-256: $sha"
Write-Output "Manifest: $manifestPath"
