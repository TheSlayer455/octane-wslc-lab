Set-StrictMode -Version Latest

function Get-OctaneWineProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('WineGui','DockerWine','WineGuiOle32Control','WineGuiOle32Mr12477','DockerWineStaging1121Control','DockerWineStaging1121VisRgn','DockerWineStaging1121VisRgnBrowser')][string]$WineProfile,
        [string]$BaseImage
    )

    $wineGuiBase = 'lscr.io/linuxserver/winegui@sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab'
    if ($WineProfile -eq 'DockerWineStaging1121VisRgnBrowser') {
        return [pscustomobject]@{
            Name = $WineProfile
            ProfileKind = 'DockerWineBrowser'
            BaseImage = if ($BaseImage) { $BaseImage } else { 'octane-lab:qualification-7181a47ee47a' }
            Dockerfile = 'lab/Dockerfile.browser-novnc'
            BuildArguments = [ordered]@{
                NOVNC_COMMIT = '63107bd06d9e1f6136ff21aeda8cd62cbf0d433e'
                WEBSOCKIFY_COMMIT = 'e81894751365afc19fe64fc9d0e5c6fc52655c36'
            }
            BuildTimeoutSeconds = 1800
            Experiment = 'Browser candidate over the retained qualified Wine 11.21 visible-region image; browser acceptance remains independent.'
            EndpointKind = 'Http'
            EndpointPath = '/octane.html'
            ContainerPort = 3000
            Username = $null
            ExecUser = 'wineuser'
            StateDirectory = '/home/wineuser/.octane'
            EvidenceDirectory = '/home/wineuser/.octane/evidence'
            DesktopLabel = 'authenticated noVNC browser viewer'
        }
    }
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

    if ($WineProfile -in @('DockerWineStaging1121Control','DockerWineStaging1121VisRgn')) {
        $variant = if ($WineProfile -eq 'DockerWineStaging1121VisRgn') { 'solid-edge-visrgn' } else { 'control' }
        return [pscustomobject]@{
            Name = $WineProfile
            ProfileKind = 'DockerWine'
            BaseImage = if ($BaseImage) { $BaseImage } else { 'scottyhardy/docker-wine@sha256:c61cfc490aaee10b96782b88733a0f3d0e7b425d93b4e96617d9ab9a2b6bcfd2' }
            Dockerfile = 'lab/Dockerfile.wine-staging-11.21'
            BuildArguments = [ordered]@{
                WINE_VARIANT = $variant
                WINE_SOURCE_COMMIT = '2528aff26208257fdbf980666a4f0e66d47563ce'
                WINE_STAGING_COMMIT = '04414fee61f7d283072d40905816b928875b2d4b'
                WINE_VISRGN_PATCH_SHA256 = 'f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752'
            }
            BuildTimeoutSeconds = 7200
            Experiment = if ($variant -eq 'control') {
                'Wine 11.21 plus Wine-Staging 11.21 control, built from pinned source'
            } else {
                'Wine 11.21 plus Wine-Staging 11.21 and the pinned Solid Edge cross-process visible-region patch'
            }
            EndpointKind = 'Rdp'
            ContainerPort = 3389
            Username = 'wineuser'
            ExecUser = 'wineuser'
            StateDirectory = '/home/wineuser/.octane'
            EvidenceDirectory = '/home/wineuser/.octane/evidence'
            DesktopLabel = 'RDP desktop'
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
