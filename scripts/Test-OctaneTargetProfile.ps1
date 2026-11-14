[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Profile,
    [switch]$Operational
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$profilePath=[IO.Path]::GetFullPath($Profile)
if(-not (Test-Path -LiteralPath $profilePath -PathType Leaf)){throw "Application profile not found: $profilePath"}
$schema=Join-Path $root 'schemas/application-profile.schema.json'
$raw=Get-Content -LiteralPath $profilePath -Raw
if(-not (Test-Json -Json $raw -SchemaFile $schema -ErrorAction Stop)){throw 'Application profile did not satisfy the versioned schema.'}
$value=$raw | ConvertFrom-Json

function Assert-SafeArgument([string]$Argument,[string]$Field){
    if($Argument.IndexOf([char]0) -ge 0 -or $Argument -match '[\r\n]'){throw "$Field contains a NUL or newline."}
}
foreach($argument in @($value.installer.installArguments)){Assert-SafeArgument $argument 'installer.installArguments'}
foreach($argument in @($value.application.launchArguments)){Assert-SafeArgument $argument 'application.launchArguments'}

$relative=[string]$value.application.expectedRelativePath
if($relative){
    if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){throw 'application.expectedRelativePath must be a traversal-free relative path.'}
    if([IO.Path]::GetFileName($relative) -ine [string]$value.application.executableFileName){throw 'expectedRelativePath filename must match executableFileName.'}
}
try{[void][Text.RegularExpressions.Regex]::new([string]$value.application.windowTitleRegex,[Text.RegularExpressions.RegexOptions]::CultureInvariant,[TimeSpan]::FromSeconds(1))}
catch{throw "application.windowTitleRegex is invalid or unsafe: $($_.Exception.Message)"}

foreach($endpoint in @($value.network.requiredEndpoints)){
    $uri=[Uri]$endpoint.url
    if($uri.Scheme -notin @('http','https')){throw "Endpoint '$($endpoint.id)' must use HTTP or HTTPS."}
    if(-not [string]::IsNullOrEmpty($uri.UserInfo)){throw "Endpoint '$($endpoint.id)' must not embed credentials."}
}

if($Operational){
    if(-not [bool]$value.installer.argumentsVerified){throw 'Operational use requires installer.argumentsVerified=true after the unchanged installer has been inspected.'}
    if([string]$value.status -eq 'template'){throw 'Operational use rejects a template-status profile.'}
}

[pscustomobject]@{
    schemaVersion=[int]$value.schemaVersion
    id=[string]$value.id
    status=[string]$value.status
    operational=([bool]$value.installer.argumentsVerified -and [string]$value.status -ne 'template')
    profilePath=$profilePath
    profileSha256=(Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    wineProfile=[string]$value.runtime.wineProfile
    scenarioStatus=[string]$value.scenario.status
}
