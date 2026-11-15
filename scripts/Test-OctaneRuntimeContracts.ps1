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
            $runtimeTest=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $root 'tests/upload-server.test.sh')
            $result=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','bash',$runtimeTest) -TimeoutSeconds 120
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
