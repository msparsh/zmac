$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$releaseDirectory = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
$outputDirectory = Join-Path $repositoryRoot 'dist'
$outputPath = Join-Path $outputDirectory 'Zmac-Setup.exe'
$iexpress = Join-Path $env:SystemRoot 'System32\iexpress.exe'
$workDirectory = Join-Path ([IO.Path]::GetTempPath()) "zmac-installer-$PID"

if (-not (Test-Path -LiteralPath $iexpress -PathType Leaf)) {
    throw 'Windows IExpress is required to build the installer.'
}

Push-Location $repositoryRoot
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'The Windows release build failed.'
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory 'zmac.exe'))) {
    throw 'The Windows release executable was not produced.'
}

try {
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    $bundleDirectory = Join-Path $workDirectory 'bundle'
    New-Item -ItemType Directory -Path $bundleDirectory | Out-Null
    Get-ChildItem -LiteralPath $releaseDirectory -Force |
        Copy-Item -Destination $bundleDirectory -Recurse -Force
    Copy-Item `
        -LiteralPath (Join-Path $PSScriptRoot 'uninstall.ps1') `
        -Destination (Join-Path $bundleDirectory 'uninstall.ps1')

    $payloadPath = Join-Path $workDirectory 'payload.zip'
    Compress-Archive `
        -Path (Join-Path $bundleDirectory '*') `
        -DestinationPath $payloadPath `
        -CompressionLevel Optimal
    Copy-Item `
        -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') `
        -Destination (Join-Path $workDirectory 'install.ps1')

    $sourceDirectory = $workDirectory.TrimEnd('\')
    $sedPath = Join-Path $workDirectory 'zmac-installer.sed'
    $sedContents = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=Install Zmac for your Windows account?
FinishMessage=Zmac is ready to use.
TargetName=$outputPath
FriendlyName=Zmac Setup
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$sourceDirectory
[SourceFiles0]
%FILE0%=
%FILE1%=
[Strings]
FILE0="install.ps1"
FILE1="payload.zip"
"@
    Set-Content -LiteralPath $sedPath -Value $sedContents -Encoding ASCII

    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Force
    }
    & $iexpress /N $sedPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
        throw 'IExpress could not create the Zmac installer.'
    }
}
finally {
    if (Test-Path -LiteralPath $workDirectory -PathType Container) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force
    }
}

Write-Output "Installer created: $outputPath"
