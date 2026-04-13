$ErrorActionPreference = "Stop"

$pluginRoot = "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x\plugins\ModelBuilder"
$buildDir = Join-Path $PWD "target"
$pluginXml = Join-Path $PWD "plugin.xml"

Remove-Item $pluginRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null

Copy-Item $pluginXml $pluginRoot -Force

$jar = Get-ChildItem "$buildDir\*fatjar.jar" | Select-Object -First 1
if (-not $jar) {
    throw "No fat jar found in target"
}

Copy-Item $jar.FullName (Join-Path $pluginRoot "model-builder.jar") -Force

Write-Host "Plugin deployed to $pluginRoot"