Set-StrictMode -Version Latest

function Get-OctaneRuntimeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro
    )

    if ($Engine -eq 'Wslc') {
        if (-not $IsWindows) { throw 'The WSLC adapter requires Windows.' }
        return [pscustomobject]@{
            FileName = 'wslc.exe'
            Prefix = @()
            Context = 'wslc:windows'
        }
    }

    if ($IsWindows) {
        if (-not $WslDistro) {
            throw 'The Docker adapter on Windows requires -WslDistro so the selected daemon is explicit.'
        }
        return [pscustomobject]@{
            FileName = 'wsl.exe'
            Prefix = @('-d', $WslDistro, '--exec', 'docker')
            Context = "docker:wsl:$WslDistro"
        }
    }

    return [pscustomobject]@{
        FileName = 'docker'
        Prefix = @()
        Context = 'docker:local'
    }
}

if (-not (Get-Command Invoke-OctaneNativeProcess -CommandType Function -ErrorAction SilentlyContinue)) {
    function Invoke-OctaneNativeProcess {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)][string]$FileName,
            [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Arguments,
            [ValidateRange(1,86400)][int]$TimeoutSeconds = 300,
            [string]$StandardInput
        )

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'Octane runtime adapters require PowerShell 7 or later.'
        }

        $started = [DateTime]::UtcNow
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $FileName
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $null -ne $StandardInput
        foreach ($argument in $Arguments) { [void]$psi.ArgumentList.Add($argument) }

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $psi
        if (-not $process.Start()) { throw "Unable to start $FileName" }
        if ($null -ne $StandardInput) {
            $process.StandardInput.Write($StandardInput)
            $process.StandardInput.Close()
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            try { $process.Kill($true) } catch { }
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $watch.Stop()
        $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
        $process.Dispose()

        return [pscustomobject]@{
            StartedAtUtc = $started.ToString('o')
            DurationMs = [int64]$watch.ElapsedMilliseconds
            ExitCode = $exitCode
            TimedOut = $timedOut
            StdOut = $stdout
            StdErr = $stderr
        }
    }
}

function Invoke-OctaneRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Arguments,
        [ValidateRange(1,86400)][int]$TimeoutSeconds = 300,
        [switch]$AllowFailure
    )

    $command = Get-OctaneRuntimeCommand -Engine $Engine -WslDistro $WslDistro
    $result = Invoke-OctaneNativeProcess -FileName $command.FileName -Arguments @($command.Prefix + $Arguments) -TimeoutSeconds $TimeoutSeconds
    $result | Add-Member -NotePropertyName Engine -NotePropertyValue $Engine
    $result | Add-Member -NotePropertyName Context -NotePropertyValue $command.Context
    if (-not $AllowFailure -and ($result.TimedOut -or $result.ExitCode -ne 0)) {
        $reason = if ($result.TimedOut) { "timed out after $TimeoutSeconds seconds" } else { "exited $($result.ExitCode)" }
        $detail = ($result.StdErr.Trim() + "`n" + $result.StdOut.Trim()).Trim()
        if ($detail.Length -gt 1200) { $detail = $detail.Substring(0,1200) + '...' }
        throw "$Engine runtime command '$($Arguments[0])' $reason. $detail"
    }
    return $result
}

function ConvertTo-OctaneRuntimePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $absolute = [IO.Path]::GetFullPath($Path)
    if ($Engine -ne 'Docker' -or -not $IsWindows) { return $absolute }
    if (-not $WslDistro) { throw 'Docker path conversion on Windows requires -WslDistro.' }
    $result = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','wslpath','-a','-u',$absolute) -TimeoutSeconds 30
    if ($result.ExitCode -ne 0 -or $result.TimedOut) { throw "Unable to convert path for $WslDistro. $($result.StdErr)" }
    return $result.StdOut.Trim()
}

function Assert-OctaneContainer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro
    )

    if ($Name -notmatch '^octane-[a-f0-9]{10}$') { throw 'Expected an Octane container name printed by Start-OctaneLab.' }
    $result = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('inspect',$Name) -TimeoutSeconds 60
    $info = $result.StdOut | ConvertFrom-Json
    if (@($info).Count -ne 1 -or $info[0].Config.Labels.'com.octanelab.managed' -ne 'true') {
        throw 'Container does not have the Octane managed label.'
    }
    $recordedEngine = $info[0].Config.Labels.'com.octanelab.engine'
    if ($recordedEngine -and $recordedEngine -ne $Engine.ToLowerInvariant()) {
        throw "Container belongs to the $recordedEngine adapter, not $Engine."
    }
    return $info[0]
}

function Test-OctanePortAvailable {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateRange(1024,65535)][int]$Port)
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
    try { $listener.Start(); return $true } catch { return $false } finally { try { $listener.Stop() } catch { } }
}

if (-not (Get-Command Wait-OctaneEndpoint -CommandType Function -ErrorAction SilentlyContinue)) {
    function Wait-OctaneEndpoint {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)][ValidateSet('Https','Rdp')][string]$Kind,
            [Parameter(Mandatory=$true)][ValidateRange(1024,65535)][int]$Port,
            [ValidateRange(5,900)][int]$TimeoutSeconds = 180
        )
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            if ($Kind -eq 'Https') {
                try {
                    $response = Invoke-WebRequest -Uri "https://127.0.0.1:$Port" -SkipCertificateCheck -SkipHttpErrorCheck -TimeoutSec 5
                    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) { $watch.Stop(); return [int64]$watch.ElapsedMilliseconds }
                } catch { }
            } else {
                $client = [Net.Sockets.TcpClient]::new()
                try {
                    $task = $client.ConnectAsync([Net.IPAddress]::Loopback,$Port)
                    if ($task.Wait(2000) -and $client.Connected) { $watch.Stop(); return [int64]$watch.ElapsedMilliseconds }
                } catch { } finally { $client.Dispose() }
            }
            Start-Sleep -Milliseconds 750
        }
        throw "$Kind endpoint on 127.0.0.1:$Port did not become reachable within $TimeoutSeconds seconds."
    }
}

function New-OctaneUnixPasswordHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Password,
        [string]$WslDistro
    )
    $salt = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(6)).ToLowerInvariant()
    if ($IsWindows) {
        if (-not $WslDistro) { throw 'Docker-Wine password hashing on Windows requires -WslDistro.' }
        $file = 'wsl.exe'
        $arguments = @('-d',$WslDistro,'--exec','openssl','passwd','-1','-salt',$salt,'-stdin')
    } else {
        $file = 'openssl'
        $arguments = @('passwd','-1','-salt',$salt,'-stdin')
    }
    $result = Invoke-OctaneNativeProcess -FileName $file -Arguments $arguments -TimeoutSeconds 30 -StandardInput ($Password + "`n")
    if ($result.ExitCode -ne 0 -or $result.TimedOut) { throw "Unable to hash the Docker-Wine RDP password. $($result.StdErr)" }
    return $result.StdOut.Trim()
}

function Get-OctaneImageDigest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro,
        [Parameter(Mandatory=$true)][string]$Image
    )
    if ($Image -match '@sha256:[a-f0-9]{64}$') { return $Image }
    $result = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('image','inspect',$Image,'--format','{{json .RepoDigests}}') -TimeoutSeconds 60 -AllowFailure
    if ($result.ExitCode -ne 0 -or $result.TimedOut -or -not $result.StdOut.Trim()) { return $null }
    $digests = $result.StdOut | ConvertFrom-Json
    return @($digests | Where-Object { $_ })[0]
}
