Set-StrictMode -Version Latest

function Write-OctaneJsonAtomic {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporary -Encoding utf8
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Initialize-OctaneRunState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][hashtable]$Identity
    )
    $stages = [ordered]@{}
    foreach ($stage in @('artifact','runtimeDoctor','imageBuild','containerCreate','desktopEndpoint','basicWine','installer','webviewDiagnostic','dialogDiagnostic','repaintDiagnostic','application','workload','nativeDialogs','export','evidence','cleanup')) {
        $stages[$stage] = [ordered]@{status='NOT_RUN'}
    }
    $record = [ordered]@{
        schemaVersion = 2
        runId = $Identity.runId
        container = $Identity.container
        image = $Identity.image
        engine = $Identity.engine
        engineContext = $Identity.engineContext
        wslDistro = $Identity.wslDistro
        wineProfile = $Identity.wineProfile
        baseImage = $Identity.baseImage
        port = $Identity.port
        endpointKind = $Identity.endpointKind
        installerSha256 = $Identity.installerSha256
        state = 'INITIALIZING'
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        updatedAtUtc = [DateTime]::UtcNow.ToString('o')
        resources = [ordered]@{imageCreated=$false;containerCreated=$false}
        stages = $stages
    }
    Write-OctaneJsonAtomic -Path $Path -Value $record
    return $record
}

function Update-OctaneRunStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','FAIL','BLOCKED','NOT_RUN')][string]$Status,
        [string]$Detail,
        [Nullable[int64]]$DurationMs
    )
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if (-not $record.stages.Contains($Stage)) { throw "Unknown run stage: $Stage" }
    $entry = [ordered]@{status=$Status;recordedAtUtc=[DateTime]::UtcNow.ToString('o')}
    if ($Detail) { $entry.detail = $Detail }
    if ($null -ne $DurationMs) { $entry.durationMs = [int64]$DurationMs }
    $record.stages[$Stage] = $entry
    $record.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-OctaneJsonAtomic -Path $Path -Value $record
}

function Set-OctaneRunResource {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][ValidateSet('imageCreated','containerCreated')][string]$Resource,[bool]$Value)
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    $record.resources[$Resource] = $Value
    $record.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-OctaneJsonAtomic -Path $Path -Value $record
}

function Set-OctaneRunState {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][ValidateSet('INITIALIZING','RUNNING','FAILED','COLLECTED','REMOVED')][string]$State)
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    $record.state = $State
    $record.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-OctaneJsonAtomic -Path $Path -Value $record
}

function Set-OctaneRunMetadata {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][hashtable]$Values)
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($key in $Values.Keys) { $record[$key] = $Values[$key] }
    $record.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-OctaneJsonAtomic -Path $Path -Value $record
}

function Block-OctaneRunStages {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[string]$Detail='Blocked by an earlier failed stage.')
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($stage in @($record.stages.Keys)) {
        if ($record.stages[$stage].status -eq 'NOT_RUN') {
            $record.stages[$stage] = [ordered]@{status='BLOCKED';detail=$Detail;recordedAtUtc=[DateTime]::UtcNow.ToString('o')}
        }
    }
    $record.state = 'FAILED'
    $record.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-OctaneJsonAtomic -Path $Path -Value $record
}

function Get-OctaneOverallStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$RunRecord)
    $entries = @($RunRecord.stages.Values)
    if (@($entries | Where-Object { $_.status -eq 'FAIL' }).Count) { return 'FAIL' }
    if (@($entries | Where-Object { $_.status -in @('BLOCKED','NOT_RUN') }).Count) { return 'INCOMPLETE' }
    return 'PASS'
}

function Write-OctaneResultArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RunPath,
        [Parameter(Mandatory=$true)][string]$OutputDirectory
    )
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $record = Get-Content -LiteralPath $RunPath -Raw | ConvertFrom-Json -AsHashtable
    $overall = Get-OctaneOverallStatus -RunRecord $record
    Copy-Item -LiteralPath $RunPath -Destination (Join-Path $OutputDirectory 'run.json') -Force
    [ordered]@{schemaVersion=1;overallStatus=$overall;stages=$record.stages} |
        ConvertTo-Json -Depth 15 |
        Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding utf8

    $xml = [Xml.XmlDocument]::new()
    [void]$xml.AppendChild($xml.CreateXmlDeclaration('1.0','utf-8',$null))
    $suite = $xml.CreateElement('testsuite')
    $entries = @($record.stages.GetEnumerator())
    $suite.SetAttribute('name','Octane acceptance')
    $suite.SetAttribute('tests',[string]$entries.Count)
    $suite.SetAttribute('failures',[string]@($entries | Where-Object { $_.Value.status -eq 'FAIL' }).Count)
    $suite.SetAttribute('skipped',[string]@($entries | Where-Object { $_.Value.status -in @('BLOCKED','NOT_RUN') }).Count)
    $suite.SetAttribute('timestamp',[DateTime]::UtcNow.ToString('o'))
    [void]$xml.AppendChild($suite)
    foreach ($stage in $entries) {
        $entry = $stage.Value
        $case = $xml.CreateElement('testcase')
        $case.SetAttribute('name',[string]$stage.Key)
        $case.SetAttribute('classname',"octane.$($record.engine).$($record.wineProfile)")
        if ($entry.Contains('durationMs')) {
            $seconds = ([double]$entry.durationMs / 1000).ToString('0.000',[Globalization.CultureInfo]::InvariantCulture)
            $case.SetAttribute('time',$seconds)
        }
        $detail = if ($entry.Contains('detail')) { [string]$entry.detail } else { [string]$entry.status }
        if ($entry.status -eq 'FAIL') {
            $failure = $xml.CreateElement('failure')
            $failure.SetAttribute('message',$detail)
            $failure.InnerText = $detail
            [void]$case.AppendChild($failure)
        } elseif ($entry.status -in @('BLOCKED','NOT_RUN')) {
            $skipped = $xml.CreateElement('skipped')
            $skipped.SetAttribute('message',$detail)
            [void]$case.AppendChild($skipped)
        } elseif ($detail) {
            $systemOut = $xml.CreateElement('system-out')
            $systemOut.InnerText = $detail
            [void]$case.AppendChild($systemOut)
        }
        [void]$suite.AppendChild($case)
    }
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $writer = [Xml.XmlWriter]::Create((Join-Path $OutputDirectory 'junit.xml'),$settings)
    try { $xml.Save($writer) } finally { $writer.Dispose() }
    return $overall
}

function Update-OctaneEvidenceChecksums {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Directory)
    $checksumLines = Get-ChildItem -LiteralPath $Directory -File -Recurse |
        Where-Object { $_.Name -ne 'checksums.sha256' } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = [IO.Path]::GetRelativePath($Directory,$_.FullName).Replace('\','/')
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relative"
        }
    $checksumLines | Set-Content -LiteralPath (Join-Path $Directory 'checksums.sha256') -Encoding ascii
}

function Sync-OctaneEvidenceBundles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$EvidenceRoot,
        [Parameter(Mandatory=$true)][string]$Container,
        [Parameter(Mandatory=$true)][string]$RunPath
    )
    if (-not (Test-Path -LiteralPath $EvidenceRoot)) { return }
    foreach ($bundle in Get-ChildItem -LiteralPath $EvidenceRoot -Directory -Filter "$Container-*") {
        Write-OctaneResultArtifacts -RunPath $RunPath -OutputDirectory $bundle.FullName | Out-Null
        Update-OctaneEvidenceChecksums -Directory $bundle.FullName
    }
}
