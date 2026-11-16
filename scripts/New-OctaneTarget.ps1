[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z][a-z0-9-]{1,47}$')][string]$Id,
    [Parameter(Mandatory=$true)][string]$Output,
    [string]$ExecutableFileName,
    [string]$WindowTitleRegex,
    [string[]]$InstallArgument,
    [switch]$VerifiedInstallerArguments
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$outputPath=[IO.Path]::GetFullPath($Output)
if(Test-Path -LiteralPath $outputPath){throw "Target overlay already exists: $outputPath"}
New-Item -ItemType Directory -Path $outputPath | Out-Null
try{
    $template=Get-Content -LiteralPath (Join-Path $root 'templates/example-app/app.json') -Raw | ConvertFrom-Json
    $template.id=$Id
    $template.application.executableFileName=if($ExecutableFileName){$ExecutableFileName}else{"$Id.exe"}
    $template.application.windowTitleRegex=if($WindowTitleRegex){$WindowTitleRegex}else{'^REPLACE WITH VERIFIED WINDOW TITLE$'}
    $template.installer.installArguments=@($InstallArgument)
    $template.installer.argumentsVerified=[bool]$VerifiedInstallerArguments
    $template.status=if($VerifiedInstallerArguments -and $ExecutableFileName -and $WindowTitleRegex){'preview-only'}else{'template'}
    $template | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath 'app.json') -Encoding utf8
    Copy-Item -LiteralPath (Join-Path $root 'templates/example-app/MANUAL-CHECKLIST.md') -Destination (Join-Path $outputPath 'MANUAL-CHECKLIST.md')
    [ordered]@{
        schemaVersion=1
        octaneRelationship='octane-browser-runtime-kit-1.0.0'
        createdAtUtc=[DateTime]::UtcNow.ToString('o')
        targetId=$Id
        sourceRequired=$false
        artifactManifest='supply one manifest per installer build; do not place installer bytes in this overlay'
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'octane-runtime.json') -Encoding utf8
    & (Join-Path $PSScriptRoot 'Test-OctaneTargetProfile.ps1') -Profile (Join-Path $outputPath 'app.json') | Out-Null
}catch{
    Remove-Item -LiteralPath $outputPath -Recurse -Force -ErrorAction SilentlyContinue
    throw
}
Write-Output "Created target overlay: $outputPath"
Write-Output 'Review app.json. Template profiles cannot be executed until installer arguments and application identity are verified.'
