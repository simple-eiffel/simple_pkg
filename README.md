<p align="center">
  <img src="docs/images/logo.svg" alt="simple_pkg logo" width="400">
</p>

# simple_pkg

**[Documentation](https://simple-eiffel.github.io/simple_pkg/)** | **[GitHub](https://github.com/simple-eiffel/simple_pkg)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)]()
[![Libraries](https://img.shields.io/badge/libraries-85+-blue)](https://github.com/simple-eiffel)

GitHub-based package manager for the Simple Eiffel ecosystem (85+ libraries).

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

**Production**

## Overview

simple_pkg is a modern package manager that dynamically discovers packages from the simple-eiffel GitHub organization. It handles installation, updates, dependency resolution, and environment variable setup - all with a simple CLI interface inspired by npm, cargo, and pip.

```eiffel
-- Install packages from command line
-- $ simple install json web sql

-- Or use the library API
local
    config: PKG_CONFIG
    installer: PKG_INSTALLER
do
    create config.make
    create installer.make (config)
    installer.install_package ("json")
end
```

## Features

- **Dynamic Discovery** - Fetches available packages from GitHub API
- **Dependency Resolution** - Parses ECF files to find dependencies
- **Environment Setup** - Sets persistent Windows environment variables
- **Package Commands** - install, update, uninstall, search, info
- **Diagnostics** - doctor command checks environment health
- **Visualization** - tree command shows dependency graph
- **Project Init** - Scaffolds new projects with dependencies

## Installation

### Windows Installer

Download and run `simple-setup-1.1.0.exe` from the [releases page](https://github.com/simple-eiffel/simple_pkg/releases).

### Manual Installation (Building from Source)

Building simple_pkg requires cloning its dependencies first. This is a one-time bootstrap process - once simple_pkg is built, it can install the remaining packages.

#### Prerequisites

- **Windows 10/11** (64-bit)
- **EiffelStudio 25.02** - [Download](https://www.eiffel.org/downloads)
- **Visual Studio 2022** (64-bit) with:
  - "Desktop development with C++" workload
  - Windows 11 SDK (or Windows 10 SDK)
  - MSVC v143 build tools
- **Git for Windows**
- **Gobo Eiffel** - [Download](https://github.com/gobo-eiffel/gobo/releases)

> **Warning**: Visual Studio must be the **64-bit version**. If your VS is installed in `Program Files (x86)`, you have the 32-bit version which will not work with EiffelStudio.

#### 1. Clone Dependencies

```bash
# Create a directory for all simple_* libraries
mkdir C:\simple-eiffel
cd C:\simple-eiffel

# Clone simple_pkg and its dependencies
git clone https://github.com/simple-eiffel/simple_pkg.git
git clone https://github.com/simple-eiffel/simple_cli.git
git clone https://github.com/simple-eiffel/simple_console.git
git clone https://github.com/simple-eiffel/simple_env.git
git clone https://github.com/simple-eiffel/simple_file.git
git clone https://github.com/simple-eiffel/simple_http.git
git clone https://github.com/simple-eiffel/simple_json.git
git clone https://github.com/simple-eiffel/simple_process.git
git clone https://github.com/simple-eiffel/simple_xml.git
git clone https://github.com/simple-eiffel/simple_sql.git
git clone https://github.com/simple-eiffel/simple_datetime.git
git clone https://github.com/simple-eiffel/simple_logger.git
git clone https://github.com/simple-eiffel/eiffel_sqlite_2025.git
```

#### 2. Set Environment Variables

> **Warning**: The `setx` command has a **1024 character limit** and silently truncates longer values. This is particularly dangerous for PATH. Use the PowerShell method below instead.

**Option A: PowerShell (Recommended)**

Open PowerShell and run:

```powershell
[Environment]::SetEnvironmentVariable("SIMPLE_EIFFEL", "C:\simple-eiffel", "User")
[Environment]::SetEnvironmentVariable("GOBO", "C:\path\to\gobo", "User")
[Environment]::SetEnvironmentVariable("GOBO_LIBRARY", "C:\path\to\gobo\library", "User")
```

**Option B: GUI Method (Safest)**

1. Press `Win+R`, type `sysdm.cpl`, press Enter
2. Click "Advanced" tab → "Environment Variables"
3. Under "User variables", click "New" for each variable

**Option C: setx (Legacy - use with caution)**

```cmd
setx SIMPLE_EIFFEL C:\simple-eiffel
setx GOBO C:\path\to\gobo
setx GOBO_LIBRARY %GOBO%\library
```

> **Important**: Close and reopen your command prompt after setting environment variables for the changes to take effect.

#### 3. Verify Your Setup

Before building, verify all prerequisites are configured:

```cmd
:: Check EiffelStudio is in PATH
ec -version

:: Check SIMPLE_EIFFEL is set
echo %SIMPLE_EIFFEL%

:: Check GOBO_LIBRARY is set
echo %GOBO_LIBRARY%
```

All commands should succeed. If any fail, fix them before proceeding.

#### 4. Compile C Libraries

Some libraries have C code that must be compiled before building.

Open the **x64 Native Tools Command Prompt for VS 2022**:
- Start Menu → Visual Studio 2022 → x64 Native Tools Command Prompt

> **Important**: Do not use the regular "Developer Command Prompt" - it may default to 32-bit.

Verify you have the 64-bit compiler:

```cmd
cl
```

The output should show: `Microsoft (R) C/C++ Optimizing Compiler ... for x64`

If it shows "for x86", you're using the wrong prompt.

Now compile the C libraries:

```cmd
cd %SIMPLE_EIFFEL%\simple_process\Clib
cl /c simple_process.c

cd %SIMPLE_EIFFEL%\simple_env\Clib
cl /c simple_env.c

cd %SIMPLE_EIFFEL%\eiffel_sqlite_2025\Clib
build-x64-fts5.bat
```

Each command should complete without errors and produce a `.obj` file.

#### 5. Build simple_pkg

Still in the x64 Native Tools Command Prompt:

```cmd
cd %SIMPLE_EIFFEL%\simple_pkg
ec -config simple_pkg.ecf -target simple_pkg_exe -finalize -c_compile
```

This will take several minutes. Wait for "C compilation completed".

#### 6. Add to PATH

**Option A - GUI (Recommended):**
1. Press Win+R, type `sysdm.cpl`, press Enter
2. Click "Environment Variables"
3. Under "User variables", select "Path" and click "Edit"
4. Click "New" and add: `C:\simple-eiffel\simple_pkg\EIFGENs\simple_pkg_exe\F_code`
5. Click OK to save

**Option B - PowerShell:**
```powershell
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = $currentPath + ";C:\simple-eiffel\simple_pkg\EIFGENs\simple_pkg_exe\F_code"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
```

> **Warning**: Avoid using `setx PATH "%PATH%;..."` as it can corrupt your PATH variable if it exceeds 1024 characters or contains special characters.

#### 7. Verify Installation

Open a new command prompt and run:

```cmd
simple version
```

You should see the version number displayed.

## Usage

```bash
# Install packages
simple install json web sql

# See all available packages
simple universe
simple -u

# List installed packages
simple inventory
simple -i

# Update packages
simple update           # Update all
simple update json      # Update specific

# Search packages
simple search http

# Show package info
simple info json

# Show dependency tree
simple tree json

# Check environment health
simple doctor

# Create new project
simple init my_app json web
```

## Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `install <pkg>...` | `i` | Install packages with dependencies |
| `update [<pkg>...]` | `up` | Update packages (all if none specified) |
| `uninstall <pkg>` | `rm` | Remove a package |
| `move <pkg>` | `mv` | Move package to current directory |
| `search <query>` | `s` | Search for packages |
| `list` | - | List all available packages |
| `universe` | `-u` | Show all packages with install status |
| `inventory` | `-i` | List installed packages |
| `info <pkg>` | - | Show package details |
| `tree [<pkg>]` | `deps` | Show dependency tree |
| `doctor` | `check` | Diagnose environment issues |
| `outdated` | - | Check for package updates |
| `init <name> [<pkg>...]` | - | Create new project |
| `env [--save]` | - | Show/save environment script |
| `version` | `-v` | Show version |
| `help` | `-h` | Show help |

## Dependencies

Uses these simple_* libraries:
- simple_json - JSON parsing for GitHub API responses
- simple_http - HTTP client for API calls
- simple_file - File operations
- simple_process - Git command execution
- simple_env - Environment variable access
- simple_console - CLI output formatting
- simple_sql - SQLite database (requires eiffel_sqlite_2025)
- simple_cli - Command-line argument parsing
- simple_datetime - Timestamp handling
- simple_logger - Logging
- simple_xml - ECF parsing

## Troubleshooting

### "windows.h: no include path set"

You're not using the correct Visual Studio command prompt. Open **x64 Native Tools Command Prompt for VS 2022** instead of the regular Developer Command Prompt or a standard cmd.exe.

### "limits.h: No such file or directory"

1. Verify Windows SDK is installed: VS Installer → Modify → Individual Components → Windows 11 SDK
2. Check for PATH corruption - if you see errors when the VS command prompt opens, your PATH may be corrupted
3. Open a fresh x64 Native Tools Command Prompt and try again

### "WARNING: The data being saved is truncated to 1024 characters"

The `setx` command has a hard 1024 character limit. If you see this warning, **your environment variable was corrupted**. This commonly happens when appending to PATH.

**Fix**:
1. Open GUI: `Win+R` → `sysdm.cpl` → Environment Variables
2. Check the affected variable and restore it manually
3. Use PowerShell instead: `[Environment]::SetEnvironmentVariable("VAR", "value", "User")`

### "\Windows was unexpected at this time" (or similar parsing errors)

Your PATH variable has parsing errors, often caused by:
- Truncation from `setx` exceeding 1024 characters
- Trailing semicolons at the end of PATH entries
- Unescaped special characters
- Missing closing quotes

**Fix**: Edit PATH via the GUI (Win+R → `sysdm.cpl` → Environment Variables → Edit Path) and remove any malformed entries.

### Compiler shows "for x86" instead of "for x64"

Either:
1. You installed the 32-bit Visual Studio (check if it's in `Program Files (x86)`)
2. You're using the wrong command prompt - use **x64 Native Tools Command Prompt**

### sqlite3.obj or esqlite.obj errors during ec compilation

The C libraries weren't compiled correctly or were compiled with the wrong compiler. Return to Step 4 and recompile all C files using the x64 Native Tools Command Prompt.

### "GOBO_LIBRARY" or "SIMPLE_EIFFEL" not found

Environment variables weren't set or the command prompt wasn't restarted after `setx`. Either:
1. Close and reopen your command prompt
2. Set them temporarily in the current session:
   ```cmd
   set SIMPLE_EIFFEL=C:\simple-eiffel
   set GOBO_LIBRARY=%GOBO%\library
   ```

### ec command not found

EiffelStudio is not in your PATH. Add `C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard\studio\spec\win64\bin` to your PATH.

## License

MIT License
