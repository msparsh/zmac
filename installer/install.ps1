$ErrorActionPreference = 'Stop'

$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Zmac'
$startMenuDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Zmac'
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Zmac'
$archive = Join-Path $PSScriptRoot 'payload.zip'

if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw 'The Zmac application bundle is missing from this installer.'
}

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $installDirectory -Force

$application = Join-Path $installDirectory 'zmac.exe'
$uninstaller = Join-Path $installDirectory 'uninstall.ps1'
if (-not (Test-Path -LiteralPath $application -PathType Leaf)) {
    throw 'The Zmac application could not be installed.'
}

New-Item -ItemType Directory -Path $startMenuDirectory -Force | Out-Null
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut(
    (Join-Path $startMenuDirectory 'Zmac.lnk')
)
$shortcut.TargetPath = $application
$shortcut.WorkingDirectory = $installDirectory
$shortcut.IconLocation = "$application,0"
$shortcut.Save()

$uninstallCommand = '"powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "' +
    $uninstaller + '"'
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name DisplayName -Value 'Zmac' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name DisplayVersion -Value '1.0.0' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name InstallLocation -Value $installDirectory -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name UninstallString -Value $uninstallCommand -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name NoModify -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $registryPath -Name NoRepair -Value 1 -PropertyType DWord -Force | Out-Null

Start-Process -FilePath $application -WorkingDirectory $installDirectory
