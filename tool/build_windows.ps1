<#
.SYNOPSIS
    Builds the Windows GUI and bundles the companion CLI next to it.

.DESCRIPTION
    Produces:

        build\windows\x64\runner\Release\ft_file_sorter.exe   (GUI)
        build\windows\x64\runner\Release\index_folder.exe     (CLI)

    The CLI is compiled from tool/index_folder.dart with `dart compile exe`, so
    the installed app does not need a Dart SDK.

    Both executables resolve their shared document-type rules from the same
    per-user file, %APPDATA%\FtFileSorter\allowed_types.json, so the rules
    edited in the GUI's "File Type Rules" dialog are exactly the ones the CLI
    applies. Shipping them together avoids pointing the two at different files.

.PARAMETER Installer
    Also build the Inno Setup installer (requires Inno Setup 6).

.PARAMETER Version
    Version passed to the installer. Defaults to 0.0.0.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Installer -Version 1.2.3
#>
[CmdletBinding()]
param(
    [switch]$Installer,
    [string]$Version = '0.0.0'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$release = Join-Path $repoRoot 'build\windows\x64\runner\Release'

Push-Location $repoRoot
try {
    Write-Host '==> flutter pub get'
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    Write-Host '==> flutter build windows --release'
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }

    Write-Host '==> dart compile exe tool/index_folder.dart'
    dart compile exe tool/index_folder.dart -o (Join-Path $release 'index_folder.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Compiling the CLI failed.' }

    Write-Host ''
    Write-Host 'Built:'
    Write-Host ('  GUI: ' + (Join-Path $release 'ft_file_sorter.exe'))
    Write-Host ('  CLI: ' + (Join-Path $release 'index_folder.exe'))

    if ($Installer) {
        $iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
        if (-not (Test-Path $iscc)) {
            throw "Inno Setup not found at $iscc. Install Inno Setup 6 or omit -Installer."
        }

        Write-Host '==> Inno Setup installer'
        & $iscc "/DMyAppVersion=$Version" (Join-Path $repoRoot 'windows\installer\setup.iss')
        if ($LASTEXITCODE -ne 0) { throw 'Building the installer failed.' }
    }
}
finally {
    Pop-Location
}
