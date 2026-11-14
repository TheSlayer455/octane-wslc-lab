Set-StrictMode -Version Latest

function Get-OctaneDirectoryManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)

    $root=[IO.Path]::GetFullPath($Path)
    if(-not (Test-Path -LiteralPath $root -PathType Container)){throw "Input directory not found: $root"}
    $entries=[Collections.Generic.List[object]]::new()
    foreach($item in Get-ChildItem -LiteralPath $root -Recurse -Force | Sort-Object FullName){
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Input contains a symlink or junction: $($item.FullName)"}
        if($item.PSIsContainer){continue}
        $relative=[IO.Path]::GetRelativePath($root,$item.FullName).Replace([IO.Path]::DirectorySeparatorChar,'/')
        $entries.Add([ordered]@{relativePath=$relative;length=[int64]$item.Length;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()})
    }
    [ordered]@{schemaVersion=1;root=$root;capturedAtUtc=[DateTime]::UtcNow.ToString('o');fileCount=$entries.Count;files=$entries}
}

function Assert-OctaneDirectoryManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Expected,
        [Parameter(Mandatory=$true)]$Actual,
        [string]$Context='Directory contents changed.'
    )
    $expectedComparable=@($Expected.files | ForEach-Object {[ordered]@{relativePath=[string]$_.relativePath;length=[int64]$_.length;sha256=[string]$_.sha256}}) | ConvertTo-Json -Depth 5 -Compress
    $actualComparable=@($Actual.files | ForEach-Object {[ordered]@{relativePath=[string]$_.relativePath;length=[int64]$_.length;sha256=[string]$_.sha256}}) | ConvertTo-Json -Depth 5 -Compress
    if($expectedComparable -cne $actualComparable){throw $Context}
}
