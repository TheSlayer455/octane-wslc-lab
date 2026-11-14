Set-StrictMode -Version Latest

function Get-OctaneWineProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('WineGui','DockerWine')][string]$WineProfile,
        [string]$BaseImage
    )

    if ($WineProfile -eq 'WineGui') {
        return [pscustomobject]@{
            Name = 'WineGui'
            BaseImage = if ($BaseImage) { $BaseImage } else { 'lscr.io/linuxserver/winegui@sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab' }
            Dockerfile = 'lab/Dockerfile'
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
        BaseImage = if ($BaseImage) { $BaseImage } else { 'scottyhardy/docker-wine@sha256:c61cfc490aaee10b96782b88733a0f3d0e7b425d93b4e96617d9ab9a2b6bcfd2' }
        Dockerfile = 'lab/Dockerfile.docker-wine'
        EndpointKind = 'Rdp'
        ContainerPort = 3389
        Username = 'wineuser'
        ExecUser = 'wineuser'
        StateDirectory = '/home/wineuser/.octane'
        EvidenceDirectory = '/home/wineuser/.octane/evidence'
        DesktopLabel = 'RDP desktop'
    }
}
