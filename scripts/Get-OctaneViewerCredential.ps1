[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
    [switch]$Reveal
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root "runs/secrets/$Container/viewer-password"
if(-not (Test-Path -LiteralPath $path -PathType Leaf)){
    throw "No retained viewer credential exists for $Container. The run may have been stopped or may not be a browser run."
}
$credential=(Get-Content -LiteralPath $path -Raw).Trim()
if($Reveal){
    Write-Warning 'Revealing the per-run credential can place it in terminal history or captured output.'
    Write-Output $credential
    return
}
$clipboard=Get-Command Set-Clipboard -ErrorAction SilentlyContinue
if(-not $clipboard){throw 'Set-Clipboard is unavailable. Re-run with -Reveal only in a private terminal.'}
Set-Clipboard -Value $credential
Write-Output "Copied the per-run viewer credential for $Container to the Windows clipboard. Paste it only into that run's localhost viewer."
