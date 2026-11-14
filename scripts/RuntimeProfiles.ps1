Set-StrictMode -Version Latest

function Get-OctaneWineProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('WineGui','DockerWine','WineGuiOle32Control','WineGuiOle32Mr12477')][string]$WineProfile,
        [string]$BaseImage
    )

    $wineGuiBase = 'lscr.io/linuxserver/winegui@sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab'
    if ($WineProfile -in @('WineGui','WineGuiOle32Control','WineGuiOle32Mr12477')) {
        $experimental = $WineProfile -ne 'WineGui'
        $variant = if ($WineProfile -eq 'WineGuiOle32Mr12477') { 'mr12477' } elseif ($WineProfile -eq 'WineGuiOle32Control') { 'control' } else { $null }
        return [pscustomobject]@{
            Name = $WineProfile
            ProfileKind = 'WineGui'
            BaseImage = if ($BaseImage) { $BaseImage } else { $wineGuiBase }
            Dockerfile = if ($experimental) { 'lab/Dockerfile.wine-ole32-mr12477' } else { 'lab/Dockerfile' }
            BuildArguments = if ($experimental) { [ordered]@{WINE_VARIANT=$variant} } else { [ordered]@{} }
            BuildTimeoutSeconds = if ($experimental) { 7200 } else { 3600 }
            Experiment = if ($experimental) { "Wine 11.0 source-built ole32 $variant; MR !12477 commit 22a16b053991f95e8bbf91e4784e73f833835b72" } else { $null }
            EndpointKind = 'Https'
            ContainerPort = 3001
            Username = 'octane'
            ExecUser = 'abc'
            StateDirectory = '/config'
            EvidenceDirectory = '/config/octane-evidence'
            DesktopLabel = 'browser desktop'
        }
    }

    return [pscustomobject]@{
        Name = 'DockerWine'
        ProfileKind = 'DockerWine'
        BaseImage = if ($BaseImage) { $BaseImage } else { 'scottyhardy/docker-wine@sha256:c61cfc490aaee10b96782b88733a0f3d0e7b425d93b4e96617d9ab9a2b6bcfd2' }
        Dockerfile = 'lab/Dockerfile.docker-wine'
        BuildArguments = [ordered]@{}
        BuildTimeoutSeconds = 3600
        Experiment = $null
        EndpointKind = 'Rdp'
        ContainerPort = 3389
        Username = 'wineuser'
        ExecUser = 'wineuser'
        StateDirectory = '/home/wineuser/.octane'
        EvidenceDirectory = '/home/wineuser/.octane/evidence'
        DesktopLabel = 'RDP desktop'
    }
}
