$ErrorActionPreference = 'Stop'

$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Zmac'
$startMenuDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Zmac'
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Zmac'

if (Test-Path -LiteralPath $installDirectory -PathType Container) {
    $expectedDirectory = [IO.Path]::GetFullPath($installDirectory)
    if ($expectedDirectory -ne $installDirectory) {
        throw 'The Zmac installation path did not match the expected location.'
    }
    Remove-Item -LiteralPath $installDirectory -Recurse -Force
}

$shortcut = Join-Path $startMenuDirectory 'Zmac.lnk'
if (Test-Path -LiteralPath $shortcut -PathType Leaf) {
    Remove-Item -LiteralPath $shortcut -Force
}
if (Test-Path -LiteralPath $startMenuDirectory -PathType Container) {
    Remove-Item -LiteralPath $startMenuDirectory -Force
}
if (Test-Path -LiteralPath $registryPath) {
    Remove-Item -LiteralPath $registryPath -Recurse -Force
}

Write-Output 'Zmac was uninstalled. Your saved session history was left on this device.'
