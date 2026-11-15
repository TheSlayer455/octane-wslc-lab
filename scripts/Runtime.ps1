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

function New-OctaneRuntimeSecretFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro,
        [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
        [Parameter(Mandatory=$true)][string]$Secret,
        [Parameter(Mandatory=$true)][string]$ControllerPath
    )

    if ($Engine -eq 'Docker' -and $IsWindows) {
        if (-not $WslDistro) { throw 'Staging a Docker secret on Windows requires -WslDistro.' }
        $directory = "/var/lib/octane/runtime-secrets/$Container"
        $path = "$directory/viewer-password"
        $script = 'set -euo pipefail; install -d -m 0711 -- "$1"; umask 133; cat > "$2"; test -s "$2"'
        $result = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
            '-d',$WslDistro,'-u','root','--exec','bash','-c',$script,'octane-secret',$directory,$path
        ) -TimeoutSeconds 30 -StandardInput $Secret
        if ($result.TimedOut -or $result.ExitCode -ne 0) {
            throw "Unable to stage the per-run viewer credential inside $WslDistro. $($result.StdErr.Trim())"
        }
        return $path
    }

    return ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $ControllerPath
}

function Remove-OctaneRuntimeSecretFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Wslc','Docker')][string]$Engine,
        [string]$WslDistro,
        [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container
    )

    if ($Engine -ne 'Docker' -or -not $IsWindows) { return }
    if (-not $WslDistro) { throw 'Removing a staged Docker secret on Windows requires -WslDistro.' }
    $directory = "/var/lib/octane/runtime-secrets/$Container"
    $script = 'set -euo pipefail; test "$1" = "/var/lib/octane/runtime-secrets/$2"; rm -f -- "$1/viewer-password"; rmdir -- "$1" 2>/dev/null || true'
    $result = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
        '-d',$WslDistro,'-u','root','--exec','bash','-c',$script,'octane-secret-cleanup',$directory,$Container
    ) -TimeoutSeconds 30
    if ($result.TimedOut -or $result.ExitCode -ne 0) {
        throw "Unable to remove the staged viewer credential from $WslDistro. $($result.StdErr.Trim())"
    }
}

function New-OctaneRuntimeSessionStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Docker')][string]$Engine,
        [Parameter(Mandatory=$true)][string]$WslDistro,
        [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
        [Parameter(Mandatory=$true)][string]$InputDirectory,
        [Parameter(Mandatory=$true)][string]$ArtifactPath,
        [Parameter(Mandatory=$true)][string]$ArtifactManifestPath,
        [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ArtifactSha256
    )

    if(-not $IsWindows){throw 'WSL-native session storage currently requires the Windows Docker-in-WSL adapter.'}
    $inputRuntime=ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $InputDirectory
    $artifactRuntime=ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $ArtifactPath
    $manifestRuntime=ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $ArtifactManifestPath
    $root="/var/lib/octane/sessions/$Container"
    $script=@'
set -euo pipefail
root="$1"; container="$2"; input="$3"; artifact="$4"; manifest="$5"; expected="$6"
test "$root" = "/var/lib/octane/sessions/$container"
test ! -e "$root"
trap 'rm -rf --one-file-system -- "$root"' ERR
install -d -m 0700 -- "$root"
install -d -o 1010 -g 1010 -m 0755 -- "$root/home" "$root/home/.octane" "$root/home/.octane/target" "$root/home/.octane/input" "$root/home/.octane/output" "$root/home/.octane/evidence"
install -d -o root -g root -m 0555 -- "$root/selected" "$root/artifact"
install -d -o 1010 -g 1010 -m 0755 -- "$root/upload"
cp -a -- "$input"/. "$root/selected"/
cp -- "$artifact" "$root/artifact"/
cp -- "$manifest" "$root/artifact"/
find "$root/selected" -type d -exec chmod 0555 {} +
find "$root/selected" -type f -exec chmod 0444 {} +
find "$root/artifact" -type d -exec chmod 0555 {} +
find "$root/artifact" -type f -exec chmod 0444 {} +
actual=$(sha256sum "$root/artifact/$(basename "$artifact")" | awk '{print $1}')
test "$actual" = "$expected"
printf '{"schemaVersion":1,"kind":"octane-session-storage","container":"%s"}\n' "$container" > "$root/session.json"
chmod 0444 "$root/session.json"
trap - ERR
'@
    $result=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
        '-d',$WslDistro,'-u','root','--exec','bash','-c',$script,'octane-session-create',
        $root,$Container,$inputRuntime,$artifactRuntime,$manifestRuntime,$ArtifactSha256
    ) -TimeoutSeconds 900
    if($result.TimedOut -or $result.ExitCode -ne 0){
        throw "Unable to create WSL-native session storage for $Container. $($result.StdErr.Trim())"
    }
    return [pscustomobject]@{
        root=$root
        home="$root/home"
        selectedInput="$root/selected"
        uploadedInput="$root/upload"
        artifact="$root/artifact"
        output="$root/home/.octane/output"
        evidence="$root/home/.octane/evidence"
    }
}

function Remove-OctaneRuntimeSessionStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Docker')][string]$Engine,
        [Parameter(Mandatory=$true)][string]$WslDistro,
        [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container
    )
    if(-not $IsWindows){throw 'WSL-native session cleanup currently requires the Windows Docker-in-WSL adapter.'}
    $root="/var/lib/octane/sessions/$Container"
    $script=@'
set -euo pipefail
root="$1"; container="$2"
test "$root" = "/var/lib/octane/sessions/$container"
if [[ ! -e "$root" ]]; then exit 0; fi
test -f "$root/session.json"
grep -Fq '"kind":"octane-session-storage"' "$root/session.json"
grep -Fq '"container":"'"$container"'"' "$root/session.json"
rm -rf --one-file-system -- "$root"
'@
    $result=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
        '-d',$WslDistro,'-u','root','--exec','bash','-c',$script,'octane-session-remove',$root,$Container
    ) -TimeoutSeconds 300
    if($result.TimedOut -or $result.ExitCode -ne 0){
        throw "Unable to remove exact WSL-native session storage for $Container. $($result.StdErr.Trim())"
    }
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
            [Parameter(Mandatory=$true)][ValidateSet('Http','Https','Rdp')][string]$Kind,
            [Parameter(Mandatory=$true)][ValidateRange(1024,65535)][int]$Port,
            [ValidatePattern('^/[A-Za-z0-9._~!$&''()*+,;=:@%/-]*$')][string]$Path = '/',
            [ValidateRange(5,900)][int]$TimeoutSeconds = 180
        )
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            if ($Kind -in @('Http','Https')) {
                try {
                    $scheme = $Kind.ToLowerInvariant()
                    $request = @{Uri="$scheme`://127.0.0.1:$Port$Path";SkipHttpErrorCheck=$true;TimeoutSec=5}
                    if ($Kind -eq 'Https') { $request.SkipCertificateCheck = $true }
                    $response = Invoke-WebRequest @request
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
        throw "$Kind endpoint on 127.0.0.1:$Port$Path did not become reachable within $TimeoutSeconds seconds."
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
