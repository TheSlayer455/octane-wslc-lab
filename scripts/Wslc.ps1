function Invoke-Wslc {
    param([Parameter(Position=0,Mandatory=$true)][string[]]$Arguments)
    & wslc.exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "WSLC failed with exit code $LASTEXITCODE ($($Arguments[0]))" }
}
function Assert-OctaneContainer {
    param([string]$Name)
    if ($Name -notmatch '^octane-[a-f0-9]{10}$') { throw 'Expected an Octane container name printed by Start-OctaneLab.' }
    $raw = Invoke-Wslc @('inspect',$Name)
    $info = ($raw -join "`n") | ConvertFrom-Json
    if ($info[0].Config.Labels.'com.octanelab.managed' -ne 'true') { throw 'Container does not have the Octane managed label' }
}
