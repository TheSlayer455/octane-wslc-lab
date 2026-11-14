[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param(
    [string]$PackageRoot=$PSScriptRoot,
    [string]$OctaneHome,
    [ValidatePattern('^Octane(?:[-A-Za-z0-9.]*)$')][string]$DistributionName='Octane',
    [string]$DistributionInstallRoot,
    [switch]$SkipPathUpdate,
    [switch]$PlanOnly
)

$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Install-Octane.ps1 must run on Windows in PowerShell 7.'}
if($PSVersionTable.PSVersion.Major -lt 7){throw 'Octane installation requires PowerShell 7 or later.'}

$package=[IO.Path]::GetFullPath($PackageRoot)
if(-not $OctaneHome){$OctaneHome=Join-Path $env:LOCALAPPDATA 'Octane'}
$octaneRoot=[IO.Path]::GetFullPath($OctaneHome)
if(-not $DistributionInstallRoot){
    $octaneParent=Split-Path $octaneRoot -Parent
    $octaneLeaf=Split-Path $octaneRoot -Leaf
    $DistributionInstallRoot=Join-Path $octaneParent "$octaneLeaf-wsl"
}
$distributionRoot=[IO.Path]::GetFullPath($DistributionInstallRoot)
if($distributionRoot.Equals($octaneRoot,[StringComparison]::OrdinalIgnoreCase) -or
   $distributionRoot.StartsWith($octaneRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
   $octaneRoot.StartsWith($distributionRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'The WSL distribution install root and Windows launcher home must be separate sibling trees.'
}
$manifestPath=Join-Path $package 'manifest.json'
if(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw "Package manifest not found: $manifestPath"}
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if($manifest.kind -ne 'octane-wsl-appliance-release'){throw 'The package manifest is not an Octane WSL appliance release.'}

function Assert-PackageFile([string]$RelativePath,[string]$ExpectedSha256,[int64]$ExpectedLength){
    if([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)'){throw "Unsafe package-relative path: $RelativePath"}
    $path=[IO.Path]::GetFullPath((Join-Path $package $RelativePath))
    if(-not $path.StartsWith($package+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Package path escapes its root: $RelativePath"}
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Required package file is missing: $RelativePath"}
    $file=Get-Item -LiteralPath $path
    if($file.Length -ne $ExpectedLength){throw "Length mismatch for $RelativePath. Expected $ExpectedLength, got $($file.Length)."}
    $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if($actual -ne $ExpectedSha256.ToLowerInvariant()){throw "SHA-256 mismatch for $RelativePath."}
    return $path
}

function Get-WslDistributions {
    $lines=@(& wsl.exe --list --quiet 2>$null)
    if($LASTEXITCODE -ne 0){throw 'Unable to list WSL distributions.'}
    return @($lines | ForEach-Object {([string]$_).Replace(([char]0).ToString(),[string]::Empty).Trim()} | Where-Object {$_})
}

function Invoke-WslChecked([string[]]$Arguments,[string]$Description){
    $output=@(& wsl.exe @Arguments 2>&1)
    if($LASTEXITCODE -ne 0){throw "$Description failed with exit code $LASTEXITCODE. $($output -join [Environment]::NewLine)"}
    return $output
}

$appliance=Assert-PackageFile -RelativePath ([string]$manifest.appliance.path) -ExpectedSha256 ([string]$manifest.appliance.sha256) -ExpectedLength ([int64]$manifest.appliance.length)
$imageArchive=Assert-PackageFile -RelativePath ([string]$manifest.image.path) -ExpectedSha256 ([string]$manifest.image.sha256) -ExpectedLength ([int64]$manifest.image.length)
$runtimeChecksums=Assert-PackageFile -RelativePath ([string]$manifest.runtime.checksumsPath) -ExpectedSha256 ([string]$manifest.runtime.checksumsSha256) -ExpectedLength ([int64]$manifest.runtime.checksumsLength)
$runtimeSource=Join-Path $package ([string]$manifest.runtime.path)
if(-not (Test-Path -LiteralPath $runtimeSource -PathType Container)){throw "Runtime directory not found: $runtimeSource"}

$runtimeRoot=[IO.Path]::GetFullPath($runtimeSource)
$runtimeErrors=@()
Get-Content -LiteralPath $runtimeChecksums | ForEach-Object {
    if($_ -notmatch '^([a-f0-9]{64})  (.+)$'){$runtimeErrors += "Malformed runtime checksum row: $_"; return}
    $relative=$Matches[2].Replace('/',[IO.Path]::DirectorySeparatorChar)
    if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){$runtimeErrors += "Unsafe runtime checksum path: $relative"; return}
    $path=[IO.Path]::GetFullPath((Join-Path $runtimeRoot $relative))
    if(-not $path.StartsWith($runtimeRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)){$runtimeErrors += "Missing runtime file: $relative"; return}
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Matches[1]){$runtimeErrors += "Runtime checksum mismatch: $relative"}
}
if($runtimeErrors.Count){throw ($runtimeErrors -join [Environment]::NewLine)}

$plan=[ordered]@{
    packageVersion=[string]$manifest.version
    distribution=$DistributionName
    distributionInstallRoot=$distributionRoot
    octaneHome=$octaneRoot
    appliance=$appliance
    imageArchive=$imageArchive
    imageReference=[string]$manifest.image.reference
    imageId=[string]$manifest.image.imageId
    pathUpdate=(-not $SkipPathUpdate)
}
if($PlanOnly){
    [pscustomobject]$plan
    Write-Output 'PLAN ONLY: package hashes and runtime checksums passed; no host state was changed.'
    return
}

if(Test-Path -LiteralPath $octaneRoot){throw "Octane home already exists; refusing to overwrite it: $octaneRoot"}
if(Test-Path -LiteralPath $distributionRoot){throw "WSL install directory already exists; refusing to overwrite it: $distributionRoot"}
if((Get-WslDistributions) -contains $DistributionName){throw "WSL distribution already exists; refusing to replace or unregister it: $DistributionName"}

& wsl.exe --version *> $null
if($LASTEXITCODE -ne 0){throw 'WSL is unavailable or blocked by policy.'}
if(-not $PSCmdlet.ShouldProcess($DistributionName,"Import Octane appliance into $distributionRoot and install launcher into $octaneRoot")){return}

$imported=$false
try{
    New-Item -ItemType Directory -Path (Split-Path $distributionRoot -Parent) -Force | Out-Null
    Invoke-WslChecked -Arguments @('--import',$DistributionName,$distributionRoot,$appliance,'--version','2') -Description 'WSL appliance import' | Out-Null
    $imported=$true
    $marker=(Invoke-WslChecked -Arguments @('-d',$DistributionName,'-u','root','--exec','cat','/etc/octane-appliance.json') -Description 'Appliance marker verification') -join "`n"
    $markerValue=$marker | ConvertFrom-Json
    if($markerValue.kind -ne 'octane-wsl-appliance' -or $markerValue.version -ne $manifest.appliance.version){throw 'Imported appliance marker does not match the package manifest.'}
    Invoke-WslChecked -Arguments @('-d',$DistributionName,'-u','root','--exec','systemctl','start','docker.service') -Description 'Docker service start' | Out-Null
    $ready=$false
    for($attempt=0;$attempt -lt 60;$attempt++){
        & wsl.exe -d $DistributionName -u root --exec docker info *> $null
        if($LASTEXITCODE -eq 0){$ready=$true;break}
        Start-Sleep -Milliseconds 500
    }
    if(-not $ready){throw 'Docker Engine did not become ready inside the imported appliance.'}
    $linuxArchive=(Invoke-WslChecked -Arguments @('-d',$DistributionName,'-u','root','--exec','wslpath','-a','-u',$imageArchive) -Description 'Image archive path conversion' | Select-Object -First 1).Trim()
    Invoke-WslChecked -Arguments @('-d',$DistributionName,'-u','root','--exec','bash','-lc','zstd -dc -- "$1" | docker load','octane-image-load',$linuxArchive) -Description 'Pinned Octane image load' | Out-Null
    $loadedId=(Invoke-WslChecked -Arguments @('-d',$DistributionName,'-u','root','--exec','docker','image','inspect','--format','{{.Id}}',[string]$manifest.image.reference) -Description 'Loaded image identity verification' | Select-Object -First 1).Trim()
    if($loadedId -ne [string]$manifest.image.imageId){throw "Loaded image identity mismatch. Expected $($manifest.image.imageId), got $loadedId."}

    New-Item -ItemType Directory -Path $octaneRoot -Force | Out-Null
    Copy-Item -LiteralPath $runtimeSource -Destination (Join-Path $octaneRoot 'runtime') -Recurse
    foreach($name in @('Octane.ps1','Octane.cmd','Uninstall-Octane.ps1')){
        Copy-Item -LiteralPath (Join-Path $package $name) -Destination (Join-Path $octaneRoot $name)
    }
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $octaneRoot 'package-manifest.json')
    $inputRoot=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Octane\Input'
    $outputRoot=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Octane\Output'
    New-Item -ItemType Directory -Path $inputRoot,$outputRoot -Force | Out-Null
    $config=[ordered]@{
        schemaVersion=1
        installedAtUtc=[DateTime]::UtcNow.ToString('o')
        packageVersion=[string]$manifest.version
        distribution=$DistributionName
        distributionInstallRoot=$distributionRoot
        runtimeRoot=(Join-Path $octaneRoot 'runtime')
        imageReference=[string]$manifest.image.reference
        imageId=[string]$manifest.image.imageId
        defaultProfile=(Join-Path $octaneRoot ([string]$manifest.runtime.defaultProfile))
        defaultInputDirectory=$inputRoot
        defaultOutputDirectory=$outputRoot
        defaultPort=[int]$manifest.launcher.defaultPort
    }
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $octaneRoot 'config.json') -Encoding utf8
    if(-not $SkipPathUpdate){
        $current=[Environment]::GetEnvironmentVariable('Path','User')
        $parts=@($current -split ';' | Where-Object {$_})
        if($parts -notcontains $octaneRoot){
            [Environment]::SetEnvironmentVariable('Path',(($parts+$octaneRoot) -join ';'),'User')
        }
    }
}catch{
    if($imported){Write-Warning "Installation failed after importing $DistributionName. It was retained for diagnosis; remove it only with the explicit uninstaller after reviewing the failure."}
    throw
}

Write-Output "Octane installed: $octaneRoot"
Write-Output "WSL appliance: $DistributionName at $distributionRoot"
Write-Output "Loaded image: $($manifest.image.reference) ($($manifest.image.imageId))"
Write-Output "Launcher: $(Join-Path $octaneRoot 'Octane.cmd')"
if(-not $SkipPathUpdate){Write-Output 'Open a new terminal before invoking octane from PATH.'}
