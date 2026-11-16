[CmdletBinding()]
param(
    [ValidateSet('All','PowerShell','PowerShellPortable','Node')][string]$Scope='All',
    [string]$WslDistro='Ubuntu-24.04'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try{
    if($Scope -in @('All','PowerShell','PowerShellPortable')){
        & pwsh -NoProfile -File (Join-Path $root 'tests/browser-runtime.test.ps1')
        if($LASTEXITCODE -ne 0){throw 'Browser/runtime PowerShell contract tests failed.'}
        & pwsh -NoProfile -File (Join-Path $root 'tests/appliance-packaging.test.ps1')
        if($LASTEXITCODE -ne 0){throw 'WSL appliance packaging contract tests failed.'}
    }
    if($Scope -eq 'All'){
        if($IsWindows){
            . (Join-Path $root 'scripts/Runtime.ps1')
            $testPath=Join-Path $root 'tests/upload-server.test.sh'
            $wslList=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('--list','--quiet') -TimeoutSeconds 30
            $availableDistros=if($wslList.ExitCode -eq 0 -and -not $wslList.TimedOut){
                @($wslList.StdOut -split "`r?`n" | ForEach-Object {([string]$_).Replace(([char]0).ToString(),[string]::Empty).Trim()} | Where-Object {$_})
            }else{@()}
            if($availableDistros -contains $WslDistro){
                $runtimeTest=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $testPath
                $result=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','bash',$runtimeTest) -TimeoutSeconds 120
            }else{
                $git=(Get-Command git -ErrorAction SilentlyContinue).Source
                if(-not $git){throw 'Upload protocol tests require either the selected WSL distribution or Git for Windows.'}
                $gitRoot=Split-Path (Split-Path $git -Parent) -Parent
                $bash=Join-Path $gitRoot 'bin/bash.exe'
                $cygpath=Join-Path $gitRoot 'usr/bin/cygpath.exe'
                if(-not (Test-Path -LiteralPath $bash -PathType Leaf) -or -not (Test-Path -LiteralPath $cygpath -PathType Leaf)){
                    throw 'Git for Windows Bash/cygpath is unavailable for the portable upload protocol tests.'
                }
                $portableTest=(& $cygpath -u $testPath).Trim()
                if($LASTEXITCODE -ne 0 -or -not $portableTest){throw 'Unable to convert the upload protocol test path for Git Bash.'}
                $result=Invoke-OctaneNativeProcess -FileName $bash -Arguments @($portableTest) -TimeoutSeconds 120
            }
            if($result.ExitCode -ne 0 -or $result.TimedOut){throw "Browser upload protocol tests failed. $($result.StdErr) $($result.StdOut)"}
            $result.StdOut.Trim() | Write-Output
        }else{
            & bash (Join-Path $root 'tests/upload-server.test.sh')
            if($LASTEXITCODE -ne 0){throw 'Browser upload protocol tests failed.'}
        }
    }
    if($Scope -in @('All','PowerShell')){
        & pwsh -NoProfile -File (Join-Path $root 'tests/scripts.test.ps1')
        if($LASTEXITCODE -ne 0){throw 'Harness PowerShell contract tests failed.'}
    }
    if($Scope -in @('All','PowerShell','PowerShellPortable')){
        & pwsh -NoProfile -File (Join-Path $root 'tests/qualification.test.ps1')
        if($LASTEXITCODE -ne 0){throw 'Qualification-policy PowerShell tests failed.'}
    }
    if($Scope -in @('All','Node')){
        if(-not (Get-Command node -ErrorAction SilentlyContinue)){throw 'Node is required for the JavaScript contract tests.'}
        $tests=@(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter '*.test.mjs' | Sort-Object Name | Select-Object -ExpandProperty FullName)
        & node --test @tests
        if($LASTEXITCODE -ne 0){throw 'Node contract tests failed.'}
    }
}finally{Pop-Location}
Write-Output "Shared runtime contracts PASS for scope $Scope. This is not live browser acceptance."
