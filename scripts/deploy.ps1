# Build Director.dll and deploy to the MO2 mod folder.
# Usage: .\scripts\deploy.ps1 [-Mode releasedbg|debug]
param(
    [ValidateSet("releasedbg", "debug")]
    [string]$Mode = "releasedbg"
)

$repo = Split-Path -Parent $PSScriptRoot
$deployDir = "D:\SFMO2\mods\Starfield Director\SFSE\Plugins"
$dll = Join-Path $repo "build\windows\x64\$Mode\Director.dll"

Set-Location $repo
xmake f -p windows -a x64 -m $Mode -y
if ($LASTEXITCODE -ne 0) { throw "xmake configure failed (exit $LASTEXITCODE)" }
xmake
if ($LASTEXITCODE -ne 0) { throw "xmake build failed (exit $LASTEXITCODE)" }
if (-not (Test-Path $dll)) { throw "Build artifact not found: $dll" }

New-Item -ItemType Directory -Force $deployDir | Out-Null
Copy-Item $dll $deployDir -Force
Write-Host "Deployed $dll -> $deployDir"
