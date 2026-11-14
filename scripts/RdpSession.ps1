Set-StrictMode -Version Latest

function Start-OctaneRdpClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$WslDistro,
        [Parameter(Mandatory=$true)][ValidateRange(1024,65535)][int]$Port,
        [Parameter(Mandatory=$true)][string]$Username,
        [Parameter(Mandatory=$true)][string]$Password
    )

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'wsl.exe'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($argument in @(
        '-d',$WslDistro,'--exec','env','DISPLAY=:0','xfreerdp3',
        "/v:127.0.0.1:$Port","/u:$Username",'/from-stdin:force','/cert:ignore',
        '/size:1280x800','/bpp:24','/network:lan','-clipboard','-audio','+auto-reconnect'
    )) { [void]$psi.ArgumentList.Add($argument) }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw 'Unable to start the unattended FreeRDP client.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.WriteLine($Password)
    $process.StandardInput.Close()
    Start-Sleep -Seconds 2
    if ($process.HasExited) {
        $detail = ($stderr.GetAwaiter().GetResult() + "`n" + $stdout.GetAwaiter().GetResult()).Trim()
        $process.Dispose()
        throw "FreeRDP exited before creating a desktop session. $detail"
    }

    return [pscustomobject]@{
        Process = $process
        StdOutTask = $stdout
        StdErrTask = $stderr
        StartedAtUtc = [DateTime]::UtcNow.ToString('o')
        WslDistro = $WslDistro
        Port = $Port
        Username = $Username
        SecurityAccommodation = 'FreeRDP /cert:ignore for the container XRDP self-signed certificate on loopback only.'
    }
}

function Stop-OctaneRdpClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Session,
        [string]$OutputDirectory
    )
    $process = $Session.Process
    if (-not $process.HasExited) {
        try { $process.Kill($true) } catch { }
        try { $process.WaitForExit(10000) | Out-Null } catch { }
    }
    $stdout = try { $Session.StdOutTask.GetAwaiter().GetResult() } catch { '' }
    $stderr = try { $Session.StdErrTask.GetAwaiter().GetResult() } catch { '' }
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $process.Dispose()
    if ($OutputDirectory) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        $stdout | Set-Content -LiteralPath (Join-Path $OutputDirectory 'freerdp.stdout.log') -Encoding utf8
        $stderr | Set-Content -LiteralPath (Join-Path $OutputDirectory 'freerdp.stderr.log') -Encoding utf8
        [ordered]@{
            schemaVersion = 1
            startedAtUtc = $Session.StartedAtUtc
            stoppedAtUtc = [DateTime]::UtcNow.ToString('o')
            exitCode = $exitCode
            wslDistro = $Session.WslDistro
            endpoint = "127.0.0.1:$($Session.Port)"
            username = $Session.Username
            securityAccommodation = $Session.SecurityAccommodation
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'freerdp-session.json') -Encoding utf8
    }
}
