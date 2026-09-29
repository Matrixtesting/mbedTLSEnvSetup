# Mbed TLS Windows GCC Bootstrap

This repository contains a reproducible Windows bootstrap for a small Mbed TLS client project. The compiler and supporting build tools live under the project directory, so the bootstrap does **not** require permanent additions to the Windows user or system `PATH`.

The initial target is a **64-bit Windows GCC debug build** using Mbed TLS 4.1.1.

## Machine prerequisites

The following must already be available:

- 64-bit Windows 10/11
- Microsoft Visual Studio
- Git with `git.exe` on `PATH`
- `curl.exe`
- `tar.exe`

Visual Studio is the IDE/debugger. The `gcc-debug` build uses MinGW-w64 GCC rather than MSVC.

## Project-managed tools

`SetupEnv.bat` pins and manages these under `tools\`:

| Component | Version | Location |
|---|---:|---|
| Strawberry Perl | 5.42.2.1 64-bit UCRT portable | `tools\strawberry-perl` |
| MinGW-w64 GCC | 13.2 (included with Strawberry Perl) | `tools\strawberry-perl\c\bin` |
| Python | 3.13.1 64-bit | `tools\python` |
| CMake | 4.2.3 | `tools\cmake` |
| Ninja | 1.12.0 | `tools\ninja` |
| vswhere | Visual Studio-installed copy | Visual Studio Installer directory |
| Mbed TLS | 4.1.1 | `external\mbedtls` |

Python dependencies used by Mbed TLS/TF-PSA-Crypto generated-source tooling are `jsonschema` and `jinja2`.

## Quick start

Place `SetupEnv.bat` in the repository root and run:

```cmd
SetupEnv.bat
```

The first run downloads/prepares the local toolchain, verifies Visual Studio, installs Python dependencies, clones Mbed TLS 4.1.1, initializes its submodules, and creates missing project support files.

Then run:

```cmd
CleanBuild.bat
```

The executable is expected at:

```text
out\build\gcc-debug\mbedtls_client.exe
```

## Resulting project tree

```text
project-root\
|-- SetupEnv.bat
|-- SetProjectEnv.bat
|-- CleanBuild.bat
|-- CMakeLists.txt
|-- CMakePresets.json
|-- requirements.txt
|-- README.md
|-- client\
|   `-- main.c
|-- external\
|   `-- mbedtls\
|-- tools\
|   |-- downloads\
|   |-- strawberry-perl\
|   |-- python\
|   |-- cmake\
|   |-- ninja\
|   `-- vswhere\
`-- out\build\gcc-debug\
```

`tools\` and `out\` are generated content and normally should not be committed.

## Safe reruns / idempotence

The bootstrap is designed to be rerun. Existing source/configuration files are preserved.

- Missing tool: download/install it.
- Existing tool: reuse and verify it.
- Missing directory: create it.
- Existing directory: preserve it.
- Missing `main.c`, CMake files, environment/build scripts, or `requirements.txt`: generate them.
- Existing project files: leave them unchanged.
- Missing Mbed TLS checkout: clone and check out `mbedtls-4.1.1`.
- Existing Mbed TLS checkout: report its revision, preserve it, and initialize/update submodules.

This prevents a later rerun from replacing an evolved TLS client with the starter `main.c`.

## No permanent PATH changes

`SetupEnv.bat` temporarily prepends project-local tool directories to `PATH` only inside its own process.

For an interactive command prompt, run:

```cmd
call SetProjectEnv.bat
```

That command window can then use `gcc`, `perl`, `python`, `cmake`, and `ninja`. No permanent Windows environment setting is changed.

`CleanBuild.bat` calls `SetProjectEnv.bat` automatically.

`CMakePresets.json` also contains project-relative GCC, Ninja, and Python paths, allowing Visual Studio/CMake to use the local toolchain without a global GCC/Ninja installation.

## Visual Studio

Open the repository as a CMake folder project:

1. **File > Open > Folder**.
2. Select the repository root.
3. Allow Visual Studio to detect `CMakePresets.json`.
4. Select `gcc-debug`.
5. Build `mbedtls_client`.

The preset selects `tools\strawberry-perl\c\bin\gcc.exe` and `tools\ninja\ninja.exe`.

## CMake configuration

The generated `CMakeLists.txt` disables Mbed TLS example programs/tests, enables generated source files, adds `external/mbedtls`, and creates `mbedtls_client` from `client/main.c`.

The client links against:

```text
MbedTLS::mbedtls
MbedTLS::mbedx509
```

TF-PSA-Crypto is carried through the Mbed TLS dependency tree rather than linked directly by the application.

`GEN_FILES` is enabled because the Git checkout requires generated files during the build.

## Starter client

`client\main.c` is generated only if missing. It verifies GCC compilation and calls the Mbed TLS 4.x version API. A successful run should resemble:

```text
Mbed TLS Client Test
--------------------
Compiler : GCC 13.2.0
Platform : 64-bit Windows
Mbed TLS : Mbed TLS 4.1.1

Mbed TLS library test successful.
```

This is only a build/library verification program. TLS sockets, certificate validation, and the application protocol are later milestones.

## Clean builds

`CleanBuild.bat`:

1. Loads the project-local environment.
2. Deletes `out\build\gcc-debug`.
3. Runs `cmake --preset gcc-debug`.
4. Runs `cmake --build --preset gcc-debug`.
5. Stops on configuration/build failure.

Manual equivalent:

```cmd
call SetProjectEnv.bat
cmake --preset gcc-debug
cmake --build --preset gcc-debug
out\build\gcc-debug\mbedtls_client.exe
```

## Python dependencies

The original Mbed TLS 4.1.1 bring-up required:

```text
jsonschema
jinja2
```

They are installed into the local Python installation with:

```cmd
tools\python\python.exe -m pip install -r requirements.txt
```

No global Python is required.

## Troubleshooting

### Git not found

The bootstrap requires `git --version` to work before startup. Install Git for Windows and put it on `PATH`.

### Visual Studio not found

The bootstrap downloads `vswhere.exe` and uses it to locate the newest Visual Studio installation. Confirm Visual Studio is installed correctly if detection fails.

### Download failure

Downloads use `curl.exe` with retries and are cached under `tools\downloads`. Delete a suspect cached archive and rerun `SetupEnv.bat`.

### Mbed TLS submodule failure

Run:

```cmd
cd external\mbedtls
git submodule update --init --recursive
```

Mbed TLS 4.1.x must use its corresponding TF-PSA-Crypto dependency.

### `error.c` missing

The generated CMake configuration enables:

```cmake
set(GEN_FILES ON CACHE BOOL "Generate Mbed TLS source files" FORCE)
```

This permits required generated files to be created from a Git checkout.

### `jsonschema` or `jinja2` missing

Run:

```cmd
tools\python\python.exe -m pip install -r requirements.txt
tools\python\python.exe -c "import jsonschema, jinja2; print('OK')"
```

### CMake preset not found

Preset commands must be invoked from the repository root, where `CMakePresets.json` resides. `CleanBuild.bat` handles this automatically.

### CMake deprecation warnings

Newer CMake releases may emit compatibility/deprecation warnings from Mbed TLS or TF-PSA-Crypto CMake files. These third-party warnings are not necessarily build failures; do not patch the external source tree merely to silence them.

## Updating versions

Pinned versions are declared near the top of `SetupEnv.bat`. For an upgrade:

1. Change one tool version at a time.
2. Confirm the official release asset/tag naming.
3. Remove the corresponding old local tool directory/cache if needed.
4. Rerun `SetupEnv.bat`.
5. Run `CleanBuild.bat`.
6. Run `mbedtls_client.exe` and verify Visual Studio debugging.
7. Update this README's version table.

## Git recommendations

Recommended `.gitignore` additions:

```gitignore
/tools/
/out/
CurrentDebugRun.txt
*.log
```

Normally commit:

```text
SetupEnv.bat
SetProjectEnv.bat
CleanBuild.bat
CMakeLists.txt
CMakePresets.json
requirements.txt
client/main.c
README.md
```

The bootstrap can obtain `external\mbedtls` when absent, so committing that downloaded tree is optional repository policy.

## Supply-chain hardening

The bootstrap pins release versions and downloads over HTTPS, but this first version does **not** verify a SHA-256 digest for every downloaded artifact. Before using it as a controlled or production build bootstrap, add expected SHA-256 values and verify each archive/installer before extraction or execution.

## Current project status

The current milestone is host build/toolchain validation:

```text
Visual Studio
    |
    +-- CMakePresets.json
            |
            +-- project-local CMake
            +-- project-local Ninja
            +-- project-local GCC
                    |
                    +-- Mbed TLS 4.1.1
                    +-- TF-PSA-Crypto
                    `-- mbedtls_client.exe
```

The next milestone is a minimal TLS client using Mbed TLS 4.1.x, followed by TCP connectivity and certificate verification.
