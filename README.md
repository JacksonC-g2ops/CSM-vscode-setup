# Model Builder + Cameo Systems Modeler (CSM) VS Code Setup Guide

This guide explains how to set up a new developer workstation so the workflow is:

**Edit in VS Code → Build ModelBuilder → Deploy plugin into CSM → Launch CSM with the latest plugin**

This version reflects the working setup, including:

* the correct `tasks.json`
* a required `deploy-plugin.ps1` script
* the `csm.properties` Java configuration fix
* validation checks and common pitfalls

---

## 1. Assumptions

This guide assumes the developer already has:

* VS Code installed
* the **ModelBuilder** repository cloned locally
* **apache-maven-3.9.14** is installed. This guide has maven installed at:

```text
C:\Users\{USER_PROFILE}\apache-maven-3.9.14\bin
```

* **jdk-11.0.22.7-hotspot** is installed. This guide has the jdk installed at:

```text
C:\Program Files\jdk-11.0.22.7-hotspot\
```

* **Cameo Systems Modeler 2022x** installed at:

```text
C:\Users\<USER_PROFILE>\Cameo_Systems_Modeler_2022x
```

It also assumes the ModelBuilder repository may exist in different locations for different users.

In this guide, refer to the repo as:

```text
C:\Users\<USER_PROFILE>\<ModelBuilderPath>
```

Examples:

```text
C:\<USER_PROFILE>\eclipseWorkspaces\modelBuilderWorkSpace\ModelBuilder
```

```text
C:\Users\someone\source\repos\ModelBuilder
```

The setup below uses `${workspaceFolder}` so each developer can keep the repository wherever they want.

---

## 2. Verify the CSM installation

Open PowerShell and run:

```powershell
Get-ChildItem "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x\bin"
```

Verify that 3 files exist:

* `csm.exe`
* `csm.properties`
* `vm.options`

If `csm.exe` is missing, stop here and fix the CSM installation first.

---

## 3. Verify required MagicDraw / No Magic packages exist

This setup depends on the No Magic / MagicDraw packages that ship with CSM.

Run:

```powershell
Get-ChildItem "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x\plugins" | Select-Object Name
```

You will see list of plugin packages, Verify these 3 exist:

* `com.nomagic.magicdraw.sysml`
* `com.nomagic.magicdraw.coreintegrator`
* `com.nomagic.magicdraw.simulation`

If the `plugins` folder is missing, or the `com.nomagic.*` packages are missing, repair or reinstall CSM before continuing.

---

## 4. Install Maven and Java Extensions in VS Code

Follow these steps to ensure VS Code is properly configured for Java and Maven development:

- Open **VS Code**
- Select:
  - **"Open Folder..."** or  
  - **File → Open Folder**
- Navigate to your **ModelBuilder repository**
- Click **"Select Folder"**

### Install Required Extensions

- In the **left-hand sidebar**, click on **Extensions**
- In the search bar:
  - Type **"Maven for Java"**
  - Install the extension published by **Microsoft**
- Clear the search bar
- Then type **"Extension Pack for Java"**
  - Install the extension published by **Microsoft**

> These extensions provide Maven integration, Java language support, debugging tools, and dependency management features required for this project.

### Restart VS Code

- Close VS Code completely by clicking the **"X"** in the top-right corner
- Reopen VS Code

> Restarting ensures all extensions initialize correctly.

---

## 5. Verify Maven and Java are in the System PATH

Adding the binaries to your **Path** allows you to execute `java` and `mvn` commands from any terminal or integrated console without typing the full directory string.

1.  **Open Environment Variables:**
    * Click the **Windows Search Bar** (or press the `Windows Key`).
    * Type `env` and select **"Edit environment variables for your account"**.
2.  **Modify the Path Variable:**
    * In the "User variables" section (the top half), locate the variable named **Path**.
    * Select **Path** so it is highlighted, then click the **Edit...** button.
3.  **Add New Entries:**
    * Click **New** and paste the full path to your JDK bin folder: 
      `C:\Program Files\Microsoft\jdk-11.0.22.7-hotspot\bin`
    * Click **New** again and paste the full path to your Maven bin folder: 
      `C:\path\to\your\apache-maven-3.9.14\bin`
    * Press **Enter** after each entry to confirm.
4.  **Save Changes:**
    * Click **OK** on the Edit window, then click **OK** on the Environment Variables window.

---

## 6. Create the JAVA_HOME Variable

Many Java tools (including Maven) specifically look for a variable named `JAVA_HOME` to identify which JDK to use.

1.  **Open Environment Variables:**
    * Return to the **"Edit environment variables for your account"** window as described in the previous step.
2.  **Create New System Variable:**
    * In the "User variables" section, click the **New...** button.
3.  **Configure the Variable:**
    * **Variable Name:** `JAVA_HOME`
    * **Variable Value:** `C:\Program Files\Microsoft\jdk-11.0.22.7-hotspot`
    * > **Critical Note:** Do **NOT** include the `\bin` folder in this value. `JAVA_HOME` must point to the root installation directory of the JDK.
4.  **Finalize:**
    * Click **OK** to create the variable.
    * Click **OK** again to exit.

---

## 7. Verify Installation and Configuration

Before proceeding to build your project, verify that the OS recognizes the new variables.

1.  **Open a New Terminal:**
    * Right-click the Start button and select **Terminal** or **PowerShell**. 
    * *Note: If you already had a terminal open, you must close and reopen it to load the new environment variables.*
2.  **Check Java Version:**
    * Run: `java -version`
    * **Expected Output:** `openjdk version "11.0.22" 2024-01-16 LTS...`
3.  **Check Maven Version:**
    * Run: `mvn -v`
    * **Expected Output:** `Apache Maven 3.9.14...`
4.  **Verify JAVA_HOME Path:**
    * Run: `$env:JAVA_HOME`
    * **Expected Output:** `C:\Program Files\Microsoft\jdk-11.0.22.7-hotspot`

**Success:** Once these outputs match your local paths, your environment is correctly configured for local builds and development!

---

## 8. Verify Java and Maven can build the project

Open vscode and open ModelBuilder repo
From the ModelBuilder repository root, run:

```powershell
mvn clean package -DskipTests
```

This confirms:

* Java is installed
* Maven is installed
* project dependencies resolve
* the project builds successfully on the machine

### Expected build output

A successful build should produce files like:

```text
target\model-builder-5.0.0-2022.jar
target\model-builder-5.0.0-fatjar.jar
```

This setup uses the **fat jar** for deployment.

---

## 9. Verify `plugin.xml`

Verify that plugin.xml exists at ModelBuilder/plugin.xml: 

```text
C:\Users\<USER_PROFILE>\<ModelBuilderPath>\plugin.xml
```
This file should be included when the repo is cloned, just make it is there. 

This matters because the deployment step must copy the built jar into the plugin folder with exactly this name:

```text
model-builder.jar
```

---

## 10. Fix `csm.properties` Java configuration if needed

Before launching CSM from VS Code, verify the Java runtime path in:

```text
C:\Users\<USER_PROFILE>\Cameo_Systems_Modeler_2022x\bin\csm.properties
```

Open the file and inspect:

```properties
JAVA_HOME=...
```

Update `JAVA_HOME` to the local installed JDK path.

Example:

```properties
JAVA_HOME=C\:\\Program Files\\Microsoft\\jdk-11.0.22.7-hotspot
```

Then verify that this file exists:

```powershell
Test-Path "C:\Program Files\Microsoft\jdk-11.0.22.7-hotspot\bin\javaw.exe"
```

Expected result:

```text
True
```

### Notes

* CSM reads `JAVA_HOME` from `csm.properties`
* CSM may ignore the machine environment variable if `csm.properties` points somewhere else
* mixed forward and back slashes in the launcher error are not usually the core problem; the wrong root path is the real issue

---

## 11. Open the correct folder in VS Code

Open the **ModelBuilder repository root** in VS Code.

Open this:

```text
C:\Users\<USER_PROFILE>\<ModelBuilderPath>
```

Do **not** open only:

```text
C:\Users\<USER_PROFILE>\<ModelBuilderPath>\.vscode
```

The task setup depends on `${workspaceFolder}` resolving to the repository root.

---

## 12. Create `.vscode\deploy-plugin.ps1`

Inside the repository root, create:

```text
.vscode\deploy-plugin.ps1
```

Use this exact script:

```powershell
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
```

### What this script does

* deletes any previous deployed plugin folder
* creates a clean plugin folder in the CSM installation
* copies `plugin.xml`
* finds the fat jar in `target`
* deploys it as `model-builder.jar`

This matches the `plugin.xml` runtime entry:

```xml
<library name="model-builder.jar"/>
```

---

## 13. Create `.vscode\tasks.json`

Inside the repository root, create:

```text
.vscode\tasks.json
```

Use this exact configuration:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build-plugin",
      "type": "shell",
      "command": "cmd",
      "args": [
        "/c",
        "cd /d \"${workspaceFolder}\" && mvn clean package -DskipTests"
      ],
      "group": "build",
      "problemMatcher": []
    },
    {
      "label": "deploy-plugin",
      "type": "shell",
      "dependsOn": "build-plugin",
      "command": "powershell",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "${workspaceFolder}\\.vscode\\deploy-plugin.ps1"
      ],
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "problemMatcher": []
    },
    {
      "label": "run-csm",
      "type": "shell",
      "dependsOn": "deploy-plugin",
      "command": "cmd",
      "args": [
        "/c",
        "\"C:\\Users\\${env:USERNAME}\\Cameo_Systems_Modeler_2022x\\bin\\csm.exe\""
      ],
      "problemMatcher": []
    }
  ]
}
```

### Important notes about this task file

* `problemMatcher` is intentionally empty to avoid the invalid `$javac` matcher error
* `${workspaceFolder}` is already the full repo path, so do not prefix it with `C:\Users\...`
* the deploy step calls the PowerShell script by file path instead of embedding the PowerShell inline; this avoids quoting and escaping issues

---

## 14. Run the workflow in VS Code

After both files are saved, use one of these:

* **Terminal → Run Task**
* **Command Palette → Tasks: Run Task**

Then choose:

```text
run-csm
```

This runs the full chain:

```text
build-plugin → deploy-plugin → run-csm
```

---

## 15. Verify deployment

After running the task, verify the plugin was deployed here:

```powershell
Get-ChildItem "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x\plugins\ModelBuilder"
```

Expected contents:

```text
plugin.xml
model-builder.jar
```

That folder should now be the deployed runtime plugin used by CSM.

---

## 16. Verify the plugin loads in CSM

When CSM opens:

1. confirm the application starts normally
2. look for the custom toolbar or menu option added by the plugin
3. click the plugin action
4. confirm the Model Builder Java GUI launches

If all four happen, the environment is working correctly.

---

## 17. Common pitfalls and fixes

### A. `run-csm` does not show up in VS Code

Check all of the following:

* `.vscode\tasks.json` exists under the repository root
* `.vscode\deploy-plugin.ps1` exists under the repository root
* VS Code opened the repository root, not the `.vscode` folder alone
* the JSON is valid
* VS Code was restarted after saving the files

Use:

* **Terminal → Run Task**
* or **Tasks: Run Task**

### B. Build succeeds but deploy fails

If you see PowerShell parsing errors, make sure the team is using the `.ps1` file approach and not an older inline `-Command` version of the deploy task.

### C. `Invalid problemMatcher reference: $javac`

This happens when VS Code does not have that matcher available in the current setup. The provided `tasks.json` already avoids this by using:

```json
"problemMatcher": []
```

### D. Plugin deploys but does not load in CSM

Check:

* `plugin.xml` exists in the deployed plugin folder
* `model-builder.jar` exists in the deployed plugin folder
* the jar name matches the runtime entry in `plugin.xml`
* the jar contains `com.g2ops.modelbuilder.ui.plugin.ModelBuilderPlugin`

### E. Old behavior persists after rebuild

Delete the deployed plugin folder and rerun:

```powershell
Remove-Item "C:\Users\$env:USERNAME\Cameo_Systems_Modeler_2022x\plugins\ModelBuilder" -Recurse -Force
```

Then rerun `run-csm`.

### F. Fat jar is missing

This setup expects a file matching:

```text
target\*fatjar.jar
```

If the project build changes and no longer produces a fat jar, update `deploy-plugin.ps1` accordingly.

---

## 18. Final workflow summary

For day-to-day development:

```text
Open ModelBuilder repo in VS Code
Edit code
Run Task: run-csm
CSM launches with freshly built and deployed plugin
```

---

## 19. New developer checklist

Before trying to launch the plugin, confirm all of the following:

* CSM exists at `C:\Users\<USER_PROFILE>\Cameo_Systems_Modeler_2022x`
* `bin\csm.exe` exists
* `bin\csm.properties` exists
* `plugins\com.nomagic.*` packages exist
* `csm.properties` points `JAVA_HOME` to a valid installed JDK
* `plugin.xml` exists in the ModelBuilder repo root
* `.vscode\deploy-plugin.ps1` exists
* `.vscode\tasks.json` exists
* VS Code opened the repository root
* `mvn clean package -DskipTests` succeeds
* `target\model-builder-5.0.0-fatjar.jar` is produced
* deployed plugin folder contains `plugin.xml` and `model-builder.jar`

Once all items above pass, the workspace is correctly configured.
