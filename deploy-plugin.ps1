param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PluginName = "",
    [string]$CsmRoot = $(if ($env:CSM_ROOT) { $env:CSM_ROOT } else { "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x" })
)

$ErrorActionPreference = "Stop"

if (-not $PluginName) {
    $PluginName = Split-Path -Leaf $WorkspaceRoot
}

$pluginRoot = Join-Path (Join-Path $CsmRoot "plugins") $PluginName
$buildDir = Join-Path $WorkspaceRoot "target"
$pluginXml = Join-Path $WorkspaceRoot "plugin.xml"

if (-not (Test-Path -LiteralPath $pluginXml)) {
    throw "plugin.xml not found: $pluginXml"
}

if (-not (Test-Path -LiteralPath $buildDir)) {
    throw "Build output folder not found: $buildDir"
}

[xml]$pluginDefinition = Get-Content -LiteralPath $pluginXml
$runtimeLibraryNode = $pluginDefinition.plugin.runtime.library
if (-not $runtimeLibraryNode) {
    throw "No runtime library was declared in plugin.xml"
}

$runtimeLibraryName = $runtimeLibraryNode.GetAttribute("name")
if (-not $runtimeLibraryName) {
    throw "The runtime library in plugin.xml is missing a name attribute"
}

$jar = Get-ChildItem -LiteralPath $buildDir -File |
    Where-Object {
        $_.Extension -eq ".jar" -and
        $_.Name -notlike "original-*" -and
        $_.Name -notlike "*-sources.jar" -and
        $_.Name -notlike "*-javadoc.jar"
    } |
    Sort-Object `
        @{ Expression = { $_.Name -match "fatjar|dependencies" }; Descending = $true }, `
        @{ Expression = { $_.LastWriteTime }; Descending = $true } |
    Select-Object -First 1

if (-not $jar) {
    throw "No plugin jar found in $buildDir"
}

Remove-Item -LiteralPath $pluginRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null

Copy-Item -LiteralPath $pluginXml -Destination $pluginRoot -Force
Copy-Item -LiteralPath $jar.FullName -Destination (Join-Path $pluginRoot $runtimeLibraryName) -Force

Write-Host "Plugin '$PluginName' deployed to $pluginRoot using $($jar.Name)"
