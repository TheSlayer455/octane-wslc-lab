[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$BuildLabel,
    [ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ProducerSha256,
    [string]$Provenance
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'RunState.ps1')
$source=[IO.Path]::GetFullPath($Installer)
if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw "Installer not found: $source"}
if([IO.Path]::GetExtension($source) -ine '.exe'){throw 'The core intake currently accepts a Windows .exe installer.'}
$destination=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$before=Get-Item -LiteralPath $source
if($before.Length -le 0){throw 'Installer is empty.'}
$temporary=Join-Path $destination ('.incoming-'+[Guid]::NewGuid().ToString('N')+'.tmp')
$input=$null;$output=$null;$hasher=$null
try{
    $input=[IO.File]::Open($source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $output=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $hasher=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    $buffer=[byte[]]::new(8MB)
    $copied=[int64]0
    while(($count=$input.Read($buffer,0,$buffer.Length)) -gt 0){
        $hasher.AppendData($buffer,0,$count)
        $output.Write($buffer,0,$count)
        $copied+=$count
    }
    $output.Flush($true)
    $sha=[Convert]::ToHexString($hasher.GetHashAndReset()).ToLowerInvariant()
}finally{
    if($hasher){$hasher.Dispose()}
    if($output){$output.Dispose()}
    if($input){$input.Dispose()}
}
$after=Get-Item -LiteralPath $source
if($before.Length -ne $after.Length -or $before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc -or $copied -ne $before.Length){
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    throw 'The source installer changed during staging; no artifact was admitted.'
}
$stagedHash=(Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
if($stagedHash -ne $sha){
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    throw 'The atomic staged copy did not match the streamed hash.'
}
if($ProducerSha256 -and $ProducerSha256.ToLowerInvariant() -ne $sha){
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    throw "Producer hash mismatch: expected $($ProducerSha256.ToLowerInvariant()), staged $sha."
}
$finalName="installer-$sha.exe"
$final=Join-Path $destination $finalName
$reused=Test-Path -LiteralPath $final
if($reused){
    $existing=Get-Item -LiteralPath $final
    if($existing.Length -ne $copied -or (Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha){
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        throw 'An immutable artifact path already exists with different bytes.'
    }
    Remove-Item -LiteralPath $temporary -Force
}else{
    Move-Item -LiteralPath $temporary -Destination $final
}

$signature=[ordered]@{inspected=$false;status=$null;subject=$null;thumbprint=$null}
$signatureCommand=Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue
if($signatureCommand){
    $auth=Get-AuthenticodeSignature -LiteralPath $final
    $signature.inspected=$true
    $signature.status=[string]$auth.Status
    if($auth.SignerCertificate){$signature.subject=[string]$auth.SignerCertificate.Subject;$signature.thumbprint=[string]$auth.SignerCertificate.Thumbprint}
}
$manifest=[ordered]@{
    schemaVersion=1
    artifactId="sha256:$sha`:$copied"
    originalFileName=[IO.Path]::GetFileName($source)
    stagedFileName=$finalName
    length=$copied
    sha256=$sha
    calculatedAtUtc=[DateTime]::UtcNow.ToString('o')
    acquiredAtUtc=[DateTime]::UtcNow.ToString('o')
    buildLabel=if($BuildLabel){$BuildLabel}else{$null}
    producerSha256=if($ProducerSha256){$ProducerSha256.ToLowerInvariant()}else{$null}
    provenance=if($Provenance){$Provenance}else{$null}
    signature=$signature
}
$manifestPath=Join-Path $destination "installer-$sha.manifest.json"
Write-OctaneJsonAtomic -Path $manifestPath -Value $manifest
if(-not (Test-Json -Json (Get-Content -LiteralPath $manifestPath -Raw) -SchemaFile (Join-Path $root 'schemas/artifact-manifest.schema.json'))){throw 'Generated artifact manifest failed its schema.'}
[pscustomobject]@{artifactPath=$final;manifestPath=$manifestPath;artifactId=$manifest.artifactId;sha256=$sha;length=$copied;reused=$reused;signatureStatus=$signature.status}
