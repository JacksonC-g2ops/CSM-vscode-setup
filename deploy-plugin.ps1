<#
.SYNOPSIS
    Deploys a built Cameo Systems Modeler plugin into the local CSM plugins directory.

.DESCRIPTION
    This script copies the workspace's plugin descriptor and canonical runtime jar into the
    target plugin folder under the local CSM installation.

    Deployment contract:
    - The deployable artifact is the jar produced by maven-assembly-plugin using the
      jar-with-dependencies descriptor.
    - The assembly plugin must declare configuration.finalName so the deployable jar name
      can be resolved deterministically from pom.xml.
    - plugin.xml must contain one plugin-local runtime library entry, such as
      <library name="model-builder.jar"/>. Additional runtime library entries that use
      relative paths are treated as supporting dependencies and are not used as the
      destination filename for the main plugin jar.

    This contract allows different repositories to produce differently named fat jars
    while still deploying them to the stable runtime jar name expected by plugin.xml.

.PARAMETER WorkspaceRoot
    The root directory of the plugin workspace. Defaults to the parent directory of the
    script file.

.PARAMETER PluginName
    The destination folder name under the CSM plugins directory. Defaults to the workspace
    folder name when omitted.

.PARAMETER CsmRoot
    The local Cameo Systems Modeler installation root. Defaults to C:\Users\<user>\
    Cameo_Systems_Modeler_2022x unless the CSM_ROOT environment variable is set.
#>
param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PluginName = "",
    [string]$CsmRoot = $(if ($env:CSM_ROOT) { $env:CSM_ROOT } else { "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x" })
)

$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
    Resolves simple Maven property placeholders in a string value.

.DESCRIPTION
    Replaces tokens such as ${project.artifactId} and ${project.version} using the provided
    property table. Resolution is iterative so nested property references can be expanded
    as long as they ultimately resolve within a small bounded number of passes.

.PARAMETER Value
    The Maven string value to resolve.

.PARAMETER Properties
    A hashtable containing Maven property names and their resolved values.

.OUTPUTS
    System.String
#>
function Resolve-MavenValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties
    )

    $resolvedValue = $Value

    for ($iteration = 0; $iteration -lt 10; $iteration++) {
        # Maven properties may reference other properties, so resolve in passes until the
        # value stabilizes or the bounded loop ends.
        $updatedValue = [regex]::Replace($resolvedValue, '\$\{([^}]+)\}', {
            param($match)

            $propertyName = $match.Groups[1].Value
            if ($Properties.ContainsKey($propertyName)) {
                return [string]$Properties[$propertyName]
            }

            return $match.Value
        })

        if ($updatedValue -eq $resolvedValue) {
            break
        }

        $resolvedValue = $updatedValue
    }

    if ($resolvedValue -match '\$\{[^}]+\}') {
        # Unresolved placeholders indicate the workspace does not fully satisfy the
        # deployment contract, so fail with a direct message instead of guessing.
        throw "Unable to resolve Maven property in value '$Value'"
    }

    return $resolvedValue
}

<#
.SYNOPSIS
    Locates the canonical deployable jar declared by pom.xml.

.DESCRIPTION
    Reads pom.xml, finds the maven-assembly-plugin configuration that produces the
    jar-with-dependencies artifact, resolves its configured finalName, and returns the
    matching jar from the build output directory.

    The intent is to avoid ambiguous "pick any jar in target" behavior. Repositories may
    legitimately produce a thin jar, a fat jar, source jars, or other variants, but only
    the assembly-produced fat jar is considered deployable by this script.

.PARAMETER PomPath
    The absolute path to the workspace pom.xml file.

.PARAMETER BuildDir
    The absolute path to the workspace target directory.

.OUTPUTS
    System.IO.FileInfo
#>
function Get-DeployableJar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PomPath,

        [Parameter(Mandatory = $true)]
        [string]$BuildDir
    )

    [xml]$pomDefinition = Get-Content -LiteralPath $PomPath

    $projectNode = $pomDefinition.SelectSingleNode("/*[local-name()='project']")
    if (-not $projectNode) {
        throw "Unable to parse Maven project from $PomPath"
    }

    # Seed the property map with the standard project coordinates used by Maven property
    # expressions. Additional custom properties are merged in below.
    $properties = @{
        "project.artifactId" = $projectNode.SelectSingleNode("*[local-name()='artifactId']").InnerText
        "project.groupId"    = $projectNode.SelectSingleNode("*[local-name()='groupId']").InnerText
        "project.version"    = $projectNode.SelectSingleNode("*[local-name()='version']").InnerText
    }

    $projectNameNode = $projectNode.SelectSingleNode("*[local-name()='name']")
    if ($projectNameNode) {
        $properties["project.name"] = $projectNameNode.InnerText
    }

    foreach ($propertyNode in $projectNode.SelectNodes("*[local-name()='properties']/*")) {
        $properties[$propertyNode.LocalName] = $propertyNode.InnerText
    }

    # The deployment contract is intentionally tied to the assembly plugin that produces
    # the fat jar. If that plugin is not present, the script should stop rather than infer
    # a deployable artifact from ad hoc naming conventions.
    $assemblyPluginNode = $projectNode.SelectSingleNode(
        "*[local-name()='build']/*[local-name()='plugins']/*[local-name()='plugin']" +
        "[*[local-name()='artifactId' and normalize-space()='maven-assembly-plugin']]" +
        "[*[local-name()='configuration']/*[local-name()='descriptorRefs']/*[local-name()='descriptorRef' and normalize-space()='jar-with-dependencies']]"
    )

    if (-not $assemblyPluginNode) {
        throw "Deployment contract not met in $PomPath. Expected maven-assembly-plugin configured with descriptorRef 'jar-with-dependencies'."
    }

    $assemblyFinalNameNode = $assemblyPluginNode.SelectSingleNode("*[local-name()='configuration']/*[local-name()='finalName']")
    if (-not $assemblyFinalNameNode -or [string]::IsNullOrWhiteSpace($assemblyFinalNameNode.InnerText)) {
        throw "Deployment contract not met in $PomPath. Expected maven-assembly-plugin to declare configuration.finalName."
    }

    # Maven writes the assembly output to target/<finalName>.jar, so resolve the exact
    # filename rather than sorting or pattern matching across multiple jars.
    $deployableJarName = (Resolve-MavenValue -Value $assemblyFinalNameNode.InnerText.Trim() -Properties $properties) + ".jar"
    $deployableJarPath = Join-Path $BuildDir $deployableJarName

    if (-not (Test-Path -LiteralPath $deployableJarPath)) {
        $availableJars = Get-ChildItem -LiteralPath $BuildDir -Filter *.jar -File | Select-Object -ExpandProperty Name
        $availableJarList = if ($availableJars) { $availableJars -join ", " } else { "<none>" }
        throw "Expected deployable jar '$deployableJarName' was not found in $BuildDir. Available jars: $availableJarList"
    }

    return Get-Item -LiteralPath $deployableJarPath
}

<#
.SYNOPSIS
    Determines the runtime jar filename expected by plugin.xml.

.DESCRIPTION
    Selects the first runtime library entry that refers to a jar stored directly in the
    plugin folder. Entries containing path separators are treated as external or supporting
    library references and are not used as the destination name for the main plugin jar.

.PARAMETER PluginXmlPath
    The absolute path to the workspace plugin.xml file.

.OUTPUTS
    System.String
#>
function Get-PluginRuntimeLibraryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginXmlPath
    )

    [xml]$pluginDefinition = Get-Content -LiteralPath $PluginXmlPath
    $runtimeLibraryNodes = @($pluginDefinition.plugin.runtime.library)

    if (-not $runtimeLibraryNodes) {
        throw "No runtime library was declared in plugin.xml"
    }

    # A plugin may declare several runtime libraries. The deployable jar is the plugin-local
    # entry with a simple filename such as "model-builder.jar", not a relative dependency
    # path such as "../some-other-plugin/lib/dependency.jar".
    $deployableLibraryNode = $runtimeLibraryNodes |
        Where-Object {
            $libraryName = $_.GetAttribute("name")
            $libraryName -and
            $libraryName -like "*.jar" -and
            $libraryName -notmatch "[\\/]"
        } |
        Select-Object -First 1

    if (-not $deployableLibraryNode) {
        throw "Deployment contract not met in $PluginXmlPath. Expected one plugin-local runtime library jar entry in plugin.xml."
    }

    return $deployableLibraryNode.GetAttribute("name")
}

if (-not $PluginName) {
    $PluginName = Split-Path -Leaf $WorkspaceRoot
}

$pluginRoot = Join-Path (Join-Path $CsmRoot "plugins") $PluginName
$buildDir = Join-Path $WorkspaceRoot "target"
$pluginXml = Join-Path $WorkspaceRoot "plugin.xml"
$pomPath = Join-Path $WorkspaceRoot "pom.xml"

if (-not (Test-Path -LiteralPath $pluginXml)) {
    throw "plugin.xml not found: $pluginXml"
}

if (-not (Test-Path -LiteralPath $pomPath)) {
    throw "pom.xml not found: $pomPath"
}

if (-not (Test-Path -LiteralPath $buildDir)) {
    throw "Build output folder not found: $buildDir"
}

# Resolve both sides of the deployment contract before touching the plugin directory:
# 1. the runtime jar name the plugin expects in plugin.xml
# 2. the canonical fat jar produced by the Maven assembly build
$runtimeLibraryName = Get-PluginRuntimeLibraryName -PluginXmlPath $pluginXml
$jar = Get-DeployableJar -PomPath $pomPath -BuildDir $buildDir

# Replace the target plugin directory atomically from the script's perspective so stale
# jars from prior builds do not linger beside the newly deployed artifact.
Remove-Item -LiteralPath $pluginRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null

# Copy the descriptor first, then copy the resolved deployable jar under the stable runtime
# filename expected by the plugin definition.
Copy-Item -LiteralPath $pluginXml -Destination $pluginRoot -Force
Copy-Item -LiteralPath $jar.FullName -Destination (Join-Path $pluginRoot $runtimeLibraryName) -Force

Write-Host "Plugin '$PluginName' deployed to $pluginRoot using $($jar.Name)"
