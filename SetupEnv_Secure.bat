@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem ============================================================================
rem SetupEnv_Secure.bat
rem
rem Secure, project-local Windows bootstrap for the Mbed TLS test project.
rem
rem MACHINE PREREQUISITES:
rem   - 64-bit Windows 10/11
rem   - Microsoft Visual Studio installed
rem   - Git installed and available on PATH
rem   - curl.exe, certutil.exe, Windows PowerShell
rem
rem PROJECT-LOCAL TOOLS:
rem   - Strawberry Perl 5.42.2.1 portable (includes MinGW-w64 GCC 13.2)
rem   - Python 3.13.1
rem   - CMake 4.2.3
rem   - Ninja 1.12.0
rem
rem SECURITY RULE:
rem   Every future tool-version update MUST update and review all three:
rem       1. Version / artifact name
rem       2. Exact download URL
rem       3. Pinned SHA-256
rem
rem   Never update a pinned SHA-256 merely because a newly downloaded file
rem   produces a different hash. Compare it to trusted vendor/project release
rem   information first.
rem
rem LOGGING:
rem   The complete inner bootstrap transcript is written to:
rem       install log.txt
rem   in the project root.
rem ============================================================================

set "BOOTSTRAP_ROOT=%~dp0"
if "%BOOTSTRAP_ROOT:~-1%"=="\" set "BOOTSTRAP_ROOT=%BOOTSTRAP_ROOT:~0,-1%"
set "BOOTSTRAP_LOG=%BOOTSTRAP_ROOT%\install log.txt"

rem ----------------------------------------------------------------------------
rem Logging wrapper.
rem The inner invocation writes stdout/stderr to the log. When finished, the
rem wrapper prints the complete log to the console and pauses on failure.
rem ----------------------------------------------------------------------------
if /I not "%~1"=="__BOOTSTRAP_INNER__" (
    >"%BOOTSTRAP_LOG%" echo ============================================================
    >>"%BOOTSTRAP_LOG%" echo  Mbed TLS Secure Bootstrap Install Log
    >>"%BOOTSTRAP_LOG%" echo ============================================================
    >>"%BOOTSTRAP_LOG%" echo Project root: %BOOTSTRAP_ROOT%
    >>"%BOOTSTRAP_LOG%" echo Started     : %DATE% %TIME%
    >>"%BOOTSTRAP_LOG%" echo.

    call "%~f0" __BOOTSTRAP_INNER__ >>"%BOOTSTRAP_LOG%" 2>&1
    set "BOOTSTRAP_RC=!ERRORLEVEL!"

    cls
    type "%BOOTSTRAP_LOG%"
    echo.
    echo Install log:
    echo   "%BOOTSTRAP_LOG%"
    echo.

    if not "!BOOTSTRAP_RC!"=="0" (
        echo ============================================================
        echo  BOOTSTRAP FAILED - SEE install log.txt
        echo ============================================================
        echo.
        pause
    ) else (
        echo ============================================================
        echo  BOOTSTRAP COMPLETED SUCCESSFULLY
        echo ============================================================
        echo.
    )

    exit /b !BOOTSTRAP_RC!
)

rem Inner bootstrap begins here. Delayed expansion is already enabled.

set "PROJECT_ROOT=%BOOTSTRAP_ROOT%"
set "TOOLS_DIR=%PROJECT_ROOT%\tools"
set "DOWNLOAD_DIR=%TOOLS_DIR%\downloads"
set "CLIENT_DIR=%PROJECT_ROOT%\client"
set "EXTERNAL_DIR=%PROJECT_ROOT%\external"
set "MBEDTLS_DIR=%EXTERNAL_DIR%\mbedtls"

rem ============================================================================
rem Pinned tool versions, URLs, and SHA-256 values
rem ============================================================================

set "STRAWBERRY_VERSION=5.42.3.1"
set "STRAWBERRY_TAG=SP_54231_64bit"
set "STRAWBERRY_FILE=strawberry-perl-%STRAWBERRY_VERSION%-64bit-portable.zip"
set "STRAWBERRY_URL=https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/%STRAWBERRY_TAG%/%STRAWBERRY_FILE%"
set "STRAWBERRY_SHA256=6a081a811781c30aca51dbc036afd93092af91e3297901f02c17043795a10690"
set "STRAWBERRY_DIR=%TOOLS_DIR%\strawberry-perl"

set "PYTHON_VERSION=3.13.1"
set "PYTHON_FILE=python-%PYTHON_VERSION%-amd64.exe"
set "PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/%PYTHON_FILE%"
set "PYTHON_SHA256=6b33fa9a439a86f553f9f60e538ccabc857d2f308bc77c477c04a46552ade81f"
set "PYTHON_DIR=%TOOLS_DIR%\python"

set "CMAKE_VERSION=4.2.3"
set "CMAKE_FILE=cmake-%CMAKE_VERSION%-windows-x86_64.zip"
set "CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v%CMAKE_VERSION%/%CMAKE_FILE%"
set "CMAKE_SHA256=eb4ebf5155dbb05436d675706b2a08189430df58904257ae5e91bcba4c86933c"
set "CMAKE_DIR=%TOOLS_DIR%\cmake"

set "NINJA_VERSION=1.12.0"
set "NINJA_FILE=ninja-win.zip"
set "NINJA_URL=https://github.com/ninja-build/ninja/releases/download/v%NINJA_VERSION%/%NINJA_FILE%"
set "NINJA_SHA256=51d99be9ceea8835edf536d52d47fa4c316aa332e57f71a08df5bd059da11417"
set "NINJA_DIR=%TOOLS_DIR%\ninja"

set "MBEDTLS_TAG=mbedtls-4.1.1"

echo.
echo ============================================================
echo  Mbed TLS Secure Windows Bootstrap
echo ============================================================
echo Project root:
echo   %PROJECT_ROOT%
echo.

echo NOTE: Strawberry Perl Portable is most reliable when the project path
echo       contains no spaces or non-ASCII characters.
echo.

rem ============================================================================
rem STEP 1 - Verify machine prerequisites
rem ============================================================================

echo ============================================================
echo STEP 1 - Machine prerequisites
echo ============================================================

call :RequireCommand git.exe "Git"
if errorlevel 1 goto :FAIL

call :RequireCommand curl.exe "curl"
if errorlevel 1 goto :FAIL

call :RequireCommand powershell.exe "Windows PowerShell"
if errorlevel 1 goto :FAIL

call :RequireCommand certutil.exe "certutil"
if errorlevel 1 goto :FAIL

set "VSWHERE_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE_EXE%" (
    set "VSWHERE_EXE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
)

if not exist "%VSWHERE_EXE%" (
    echo [FAIL] Visual Studio Installer's vswhere.exe was not found.
    echo        Checked the standard Visual Studio Installer locations.
    goto :FAIL
)

set "VS_PATH="
for /f "usebackq delims=" %%I in (`"%VSWHERE_EXE%" -latest -products * -property installationPath`) do (
    set "VS_PATH=%%I"
)

if not defined VS_PATH (
    echo [FAIL] vswhere.exe did not report a Visual Studio installation.
    goto :FAIL
)

echo [PASS] Visual Studio:
echo        !VS_PATH!
echo.

rem ============================================================================
rem STEP 2 - Create project directory structure and missing source/config files
rem ============================================================================

echo ============================================================
echo STEP 2 - Project structure
echo ============================================================

call :EnsureDir "%TOOLS_DIR%"
if errorlevel 1 goto :FAIL
call :EnsureDir "%DOWNLOAD_DIR%"
if errorlevel 1 goto :FAIL
call :EnsureDir "%CLIENT_DIR%"
if errorlevel 1 goto :FAIL
call :EnsureDir "%EXTERNAL_DIR%"
if errorlevel 1 goto :FAIL

call :GenerateRequirements
if errorlevel 1 goto :FAIL
call :GenerateSetProjectEnv
if errorlevel 1 goto :FAIL
call :GenerateCMakeLists
if errorlevel 1 goto :FAIL
call :GenerateCMakePresets
if errorlevel 1 goto :FAIL
call :GenerateMainC
if errorlevel 1 goto :FAIL
call :GenerateCleanBuild
if errorlevel 1 goto :FAIL

echo.

rem ============================================================================
rem STEP 3 - Strawberry Perl / GCC
rem ============================================================================

echo ============================================================
echo STEP 3 - Strawberry Perl / GCC
echo ============================================================

rem Check the two required Strawberry executables independently.
rem Do not use "if A if B (...) else (...)" here: CMD binds ELSE to the
rem inner IF, which skips the install branch completely when A is false.
if exist "%STRAWBERRY_DIR%\perl\bin\perl.exe" (
    if exist "%STRAWBERRY_DIR%\c\bin\gcc.exe" (
        echo [PASS] Existing project-local Strawberry Perl/GCC found.
        goto :STRAWBERRY_VERIFY
    )
)

if exist "%STRAWBERRY_DIR%" (
    echo [INFO] Incomplete Strawberry Perl directory found.
    echo        Removing it before reinstalling.
    rmdir /s /q "%STRAWBERRY_DIR%"
    if exist "%STRAWBERRY_DIR%" (
        echo [FAIL] Could not remove incomplete Strawberry directory.
        goto :FAIL
    )
)

echo [INFO] Strawberry Perl/GCC is not installed locally.
echo        Beginning secure download and installation.

call :SecureDownload "%STRAWBERRY_URL%" "%DOWNLOAD_DIR%\%STRAWBERRY_FILE%" "%STRAWBERRY_SHA256%" "Strawberry Perl %STRAWBERRY_VERSION%"
if errorlevel 1 goto :FAIL

if not exist "%DOWNLOAD_DIR%\%STRAWBERRY_FILE%" (
    echo [FAIL] Strawberry archive is missing after SecureDownload returned success.
    goto :FAIL
)

mkdir "%STRAWBERRY_DIR%"
if errorlevel 1 (
    echo [FAIL] Could not create Strawberry Perl directory.
    goto :FAIL
)

echo Extracting Strawberry Perl with PowerShell Expand-Archive...
set "STRAWBERRY_ARCHIVE=%DOWNLOAD_DIR%\%STRAWBERRY_FILE%"
set "STRAWBERRY_DEST=%STRAWBERRY_DIR%"

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
    -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:STRAWBERRY_ARCHIVE -DestinationPath $env:STRAWBERRY_DEST -Force"
if errorlevel 1 (
    echo [FAIL] Strawberry Perl extraction failed.
    goto :FAIL
)

:STRAWBERRY_VERIFY
if not exist "%STRAWBERRY_DIR%\perl\bin\perl.exe" (
    echo.
    echo [FAIL] Expected Strawberry perl.exe was not found:
    echo        %STRAWBERRY_DIR%\perl\bin\perl.exe
    echo.
    echo Diagnostic search for perl.exe under Strawberry directory:
    dir /s /b "%STRAWBERRY_DIR%\*perl.exe" 2>nul
    echo.
    echo Diagnostic search for portableshell.bat:
    dir /s /b "%STRAWBERRY_DIR%\*portableshell.bat" 2>nul
    echo.
    echo Top-level Strawberry directory contents:
    dir /b "%STRAWBERRY_DIR%"
    goto :FAIL
)
if not exist "%STRAWBERRY_DIR%\c\bin\gcc.exe" (
    echo.
    echo [FAIL] Expected Strawberry gcc.exe was not found:
    echo        %STRAWBERRY_DIR%\c\bin\gcc.exe
    echo.
    echo Diagnostic search for gcc.exe under Strawberry directory:
    dir /s /b "%STRAWBERRY_DIR%\*gcc.exe" 2>nul
    goto :FAIL
)

echo [PASS] Strawberry Perl / GCC installed.
"%STRAWBERRY_DIR%\perl\bin\perl.exe" -e "print qq(Perl version: $^V\n)"
if errorlevel 1 goto :FAIL
"%STRAWBERRY_DIR%\c\bin\gcc.exe" --version
if errorlevel 1 goto :FAIL
echo.

rem ============================================================================
rem STEP 4 - Python
rem ============================================================================

echo ============================================================
echo STEP 4 - Python
echo ============================================================

if exist "%PYTHON_DIR%\python.exe" (
    echo [PASS] Existing project-local Python found.
) else (
    if exist "%PYTHON_DIR%" (
        echo [INFO] Incomplete Python directory found.
        echo        Removing it before reinstalling.
        rmdir /s /q "%PYTHON_DIR%"
        if exist "%PYTHON_DIR%" (
            echo [FAIL] Could not remove incomplete Python directory.
            goto :FAIL
        )
    )

    call :SecureDownload "%PYTHON_URL%" "%DOWNLOAD_DIR%\%PYTHON_FILE%" "%PYTHON_SHA256%" "Python %PYTHON_VERSION%"
    if errorlevel 1 goto :FAIL

    echo Installing Python into:
    echo   %PYTHON_DIR%
    start /wait "" "%DOWNLOAD_DIR%\%PYTHON_FILE%" /quiet InstallAllUsers=0 TargetDir="%PYTHON_DIR%" PrependPath=0 Include_pip=1 Include_launcher=0 Include_test=0 AssociateFiles=0 Shortcuts=0
    if errorlevel 1 (
        echo [FAIL] Python installer returned an error.
        goto :FAIL
    )
)

if not exist "%PYTHON_DIR%\python.exe" (
    echo [FAIL] python.exe was not found after installation.
    goto :FAIL
)

"%PYTHON_DIR%\python.exe" --version
if errorlevel 1 goto :FAIL
echo.

rem ============================================================================
rem STEP 5 - CMake
rem ============================================================================

echo ============================================================
echo STEP 5 - CMake
echo ============================================================

if exist "%CMAKE_DIR%\bin\cmake.exe" (
    echo [PASS] Existing project-local CMake found.
) else (
    if exist "%CMAKE_DIR%" (
        echo [INFO] Incomplete CMake directory found.
        rmdir /s /q "%CMAKE_DIR%"
        if exist "%CMAKE_DIR%" (
            echo [FAIL] Could not remove incomplete CMake directory.
            goto :FAIL
        )
    )

    call :SecureDownload "%CMAKE_URL%" "%DOWNLOAD_DIR%\%CMAKE_FILE%" "%CMAKE_SHA256%" "CMake %CMAKE_VERSION%"
    if errorlevel 1 goto :FAIL

    set "CMAKE_EXTRACTED=%TOOLS_DIR%\cmake-%CMAKE_VERSION%-windows-x86_64"
    if exist "!CMAKE_EXTRACTED!" rmdir /s /q "!CMAKE_EXTRACTED!"

    echo Extracting CMake with PowerShell Expand-Archive...
    set "CMAKE_ARCHIVE=%DOWNLOAD_DIR%\%CMAKE_FILE%"
    set "CMAKE_EXTRACT_DEST=%TOOLS_DIR%"
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
        -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:CMAKE_ARCHIVE -DestinationPath $env:CMAKE_EXTRACT_DEST -Force"
    if errorlevel 1 (
        echo [FAIL] CMake extraction failed.
        goto :FAIL
    )

    if not exist "!CMAKE_EXTRACTED!\bin\cmake.exe" (
        echo [FAIL] Expected extracted CMake directory was not found:
        echo        !CMAKE_EXTRACTED!
        goto :FAIL
    )

    move "!CMAKE_EXTRACTED!" "%CMAKE_DIR%" >nul
    if errorlevel 1 (
        echo [FAIL] Could not rename extracted CMake directory.
        goto :FAIL
    )
)

"%CMAKE_DIR%\bin\cmake.exe" --version
if errorlevel 1 goto :FAIL
echo.

rem ============================================================================
rem STEP 6 - Ninja
rem ============================================================================

echo ============================================================
echo STEP 6 - Ninja
echo ============================================================

if exist "%NINJA_DIR%\ninja.exe" (
    echo [PASS] Existing project-local Ninja found.
) else (
    if exist "%NINJA_DIR%" (
        echo [INFO] Incomplete Ninja directory found.
        rmdir /s /q "%NINJA_DIR%"
        if exist "%NINJA_DIR%" (
            echo [FAIL] Could not remove incomplete Ninja directory.
            goto :FAIL
        )
    )

    call :SecureDownload "%NINJA_URL%" "%DOWNLOAD_DIR%\%NINJA_FILE%" "%NINJA_SHA256%" "Ninja %NINJA_VERSION%"
    if errorlevel 1 goto :FAIL

    mkdir "%NINJA_DIR%"
    if errorlevel 1 (
        echo [FAIL] Could not create Ninja directory.
        goto :FAIL
    )

    echo Extracting Ninja with PowerShell Expand-Archive...
    set "NINJA_ARCHIVE=%DOWNLOAD_DIR%\%NINJA_FILE%"
    set "NINJA_DEST=%NINJA_DIR%"
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
        -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:NINJA_ARCHIVE -DestinationPath $env:NINJA_DEST -Force"
    if errorlevel 1 (
        echo [FAIL] Ninja extraction failed.
        goto :FAIL
    )
)

if not exist "%NINJA_DIR%\ninja.exe" (
    echo [FAIL] ninja.exe was not found after extraction.
    goto :FAIL
)

"%NINJA_DIR%\ninja.exe" --version
if errorlevel 1 goto :FAIL
echo.

rem ============================================================================
rem STEP 7 - Establish project-local environment
rem ============================================================================

echo ============================================================
echo STEP 7 - Project-local environment
echo ============================================================

set "PATH=%STRAWBERRY_DIR%\perl\bin;%STRAWBERRY_DIR%\c\bin;%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%CMAKE_DIR%\bin;%NINJA_DIR%;%PATH%"

where gcc.exe
if errorlevel 1 goto :FAIL
where perl.exe
if errorlevel 1 goto :FAIL
where python.exe
if errorlevel 1 goto :FAIL
where cmake.exe
if errorlevel 1 goto :FAIL
where ninja.exe
if errorlevel 1 goto :FAIL

echo GCC target:
gcc.exe -dumpmachine
if errorlevel 1 goto :FAIL
echo.

rem ============================================================================
rem STEP 8 - Python build dependencies
rem ============================================================================

echo ============================================================
echo STEP 8 - Python dependencies
echo ============================================================

"%PYTHON_DIR%\python.exe" -m pip --version
if errorlevel 1 (
    echo [FAIL] pip is not available in the project-local Python installation.
    goto :FAIL
)

"%PYTHON_DIR%\python.exe" -m pip install --disable-pip-version-check -r "%PROJECT_ROOT%\requirements.txt"
if errorlevel 1 (
    echo [FAIL] Python requirements installation failed.
    goto :FAIL
)

"%PYTHON_DIR%\python.exe" -c "import jsonschema, jinja2; print('Python modules: jsonschema and jinja2 OK')"
if errorlevel 1 (
    echo [FAIL] Python dependency import verification failed.
    goto :FAIL
)
echo.

rem ============================================================================
rem STEP 9 - Mbed TLS
rem ============================================================================

echo ============================================================
echo STEP 9 - Mbed TLS %MBEDTLS_TAG%
echo ============================================================

if not exist "%MBEDTLS_DIR%\.git" (
    if exist "%MBEDTLS_DIR%" (
        echo [FAIL] external\mbedtls exists but is not a Git repository.
        echo        Remove or rename that directory and rerun the bootstrap.
        goto :FAIL
    )

    echo Cloning Mbed TLS...
    git clone https://github.com/Mbed-TLS/mbedtls.git "%MBEDTLS_DIR%"
    if errorlevel 1 (
        echo [FAIL] Mbed TLS clone failed.
        goto :FAIL
    )

    pushd "%MBEDTLS_DIR%"
    if errorlevel 1 goto :FAIL

    echo Checking out %MBEDTLS_TAG%...
    git checkout "%MBEDTLS_TAG%"
    if errorlevel 1 (
        popd
        echo [FAIL] Mbed TLS checkout failed.
        goto :FAIL
    )

    echo Initializing Mbed TLS submodules...
    git submodule update --init --recursive
    if errorlevel 1 (
        popd
        echo [FAIL] Mbed TLS submodule initialization failed.
        goto :FAIL
    )

    popd
) else (
    echo [PASS] Existing Mbed TLS Git repository found.

    pushd "%MBEDTLS_DIR%"
    if errorlevel 1 goto :FAIL

    set "MBEDTLS_FOUND="
    for /f "delims=" %%I in ('git describe --tags --always 2^>nul') do set "MBEDTLS_FOUND=%%I"

    echo Current Mbed TLS revision:
    echo   !MBEDTLS_FOUND!

    if /I not "!MBEDTLS_FOUND!"=="%MBEDTLS_TAG%" (
        echo [WARN] Expected %MBEDTLS_TAG% but found !MBEDTLS_FOUND!.
        echo        The existing source tree will NOT be changed automatically.
    )

    git submodule update --init --recursive
    if errorlevel 1 (
        popd
        echo [FAIL] Mbed TLS submodule verification/update failed.
        goto :FAIL
    )

    popd
)
echo.

rem ============================================================================
rem STEP 10 - Final verification
rem ============================================================================

echo ============================================================
echo STEP 10 - Final verification
echo ============================================================

cd /d "%PROJECT_ROOT%"
if errorlevel 1 goto :FAIL

echo Verifying CMake presets...
"%CMAKE_DIR%\bin\cmake.exe" --list-presets
if errorlevel 1 (
    echo [FAIL] CMake preset validation failed.
    goto :FAIL
)

echo.
echo Verifying required project files...
call :RequireFile "%PROJECT_ROOT%\CMakeLists.txt"
if errorlevel 1 goto :FAIL
call :RequireFile "%PROJECT_ROOT%\CMakePresets.json"
if errorlevel 1 goto :FAIL
call :RequireFile "%PROJECT_ROOT%\SetProjectEnv.bat"
if errorlevel 1 goto :FAIL
call :RequireFile "%PROJECT_ROOT%\CleanBuild.bat"
if errorlevel 1 goto :FAIL
call :RequireFile "%PROJECT_ROOT%\requirements.txt"
if errorlevel 1 goto :FAIL
call :RequireFile "%PROJECT_ROOT%\client\main.c"
if errorlevel 1 goto :FAIL

echo.
echo ============================================================
echo  BOOTSTRAP READY
echo ============================================================
echo.
echo No permanent user or system PATH changes were made.
echo.
echo Next command:
echo   CleanBuild.bat
echo.
echo Or open this folder directly in Visual Studio:
echo   %PROJECT_ROOT%
echo.
echo Finished: %DATE% %TIME%
endlocal
exit /b 0

:FAIL
echo.
echo ============================================================
echo  BOOTSTRAP FAILED
echo ============================================================
echo.
echo Failure time:
echo   %DATE% %TIME%
echo.
echo Review the messages immediately above this line.
echo The complete transcript is in:
echo   "%BOOTSTRAP_LOG%"
echo.
endlocal
exit /b 1

rem ============================================================================
rem Helper subroutines
rem ============================================================================

:RequireCommand
where "%~1" >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Required command not found on PATH: %~2
    exit /b 1
)
echo [PASS] %~2
exit /b 0

:RequireFile
if not exist "%~1" (
    echo [FAIL] Required file missing:
    echo        %~1
    exit /b 1
)
echo [PASS] %~1
exit /b 0

:EnsureDir
if not exist "%~1" (
    mkdir "%~1"
    if errorlevel 1 (
        echo [FAIL] Could not create directory:
        echo        %~1
        exit /b 1
    )
    echo [CREATE] %~1
) else (
    echo [KEEP]   %~1
)
exit /b 0

:SecureDownload
setlocal EnableDelayedExpansion
set "SD_URL=%~1"
set "SD_FILE=%~2"
set "SD_HASH=%~3"
set "SD_NAME=%~4"

echo.
echo Artifact:
echo   !SD_NAME!
echo URL:
echo   !SD_URL!
echo File:
echo   !SD_FILE!

if exist "!SD_FILE!" (
    echo [INFO] Cached artifact found. Verifying SHA-256 before reuse...
    call :VerifySHA256 "!SD_FILE!" "!SD_HASH!" "!SD_NAME!"
    if not errorlevel 1 (
        echo [PASS] Cached artifact is trusted.
        endlocal
        exit /b 0
    )

    echo [WARN] Cached artifact failed SHA-256 verification.
    echo        Deleting it and downloading a fresh copy once.
    del /q "!SD_FILE!" >nul 2>&1
)

echo Downloading...
curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 30 -o "!SD_FILE!" "!SD_URL!"
if errorlevel 1 (
    echo [FAIL] Download failed: !SD_NAME!
    if exist "!SD_FILE!" del /q "!SD_FILE!" >nul 2>&1
    endlocal
    exit /b 1
)

if not exist "!SD_FILE!" (
    echo [FAIL] curl returned without creating the expected artifact:
    echo        !SD_FILE!
    endlocal
    exit /b 1
)

for %%Z in ("!SD_FILE!") do set "SD_SIZE=%%~zZ"
echo Downloaded size: !SD_SIZE! bytes

if "!SD_SIZE!"=="0" (
    echo [FAIL] Downloaded artifact is zero bytes.
    del /q "!SD_FILE!" >nul 2>&1
    endlocal
    exit /b 1
)

call :VerifySHA256 "!SD_FILE!" "!SD_HASH!" "!SD_NAME!"
if errorlevel 1 (
    echo [SECURITY] Freshly downloaded artifact failed SHA-256 verification.
    echo            The file will be deleted and will NOT be used.
    del /q "!SD_FILE!" >nul 2>&1
    endlocal
    exit /b 1
)

echo [PASS] Download and SHA-256 verification complete.
endlocal
exit /b 0

:VerifySHA256
setlocal EnableDelayedExpansion
set "VH_FILE=%~1"
set "VH_EXPECTED=%~2"
set "VH_NAME=%~3"
set "VH_TEMP=%TEMP%\mbedtls_hash_!RANDOM!_!RANDOM!.txt"
set "VH_ACTUAL="

certutil.exe -hashfile "!VH_FILE!" SHA256 >"!VH_TEMP!" 2>&1
if errorlevel 1 (
    echo [FAIL] certutil could not calculate SHA-256 for !VH_NAME!.
    type "!VH_TEMP!"
    del /q "!VH_TEMP!" >nul 2>&1
    endlocal
    exit /b 1
)

for /f "usebackq skip=1 tokens=* delims=" %%H in ("!VH_TEMP!") do (
    if not defined VH_ACTUAL set "VH_ACTUAL=%%H"
)

del /q "!VH_TEMP!" >nul 2>&1

set "VH_ACTUAL=!VH_ACTUAL: =!"

if not defined VH_ACTUAL (
    echo [FAIL] SHA-256 output could not be parsed for !VH_NAME!.
    endlocal
    exit /b 1
)

if /I not "!VH_EXPECTED!"=="!VH_ACTUAL!" (
    echo.
    echo ============================================================
    echo  SECURITY ERROR - SHA-256 VERIFICATION FAILED
    echo ============================================================
    echo Artifact:
    echo   !VH_NAME!
    echo Expected:
    echo   !VH_EXPECTED!
    echo Actual:
    echo   !VH_ACTUAL!
    echo.
    echo This artifact will NOT be extracted or executed.
    echo ============================================================
    endlocal
    exit /b 1
)

echo [PASS] SHA-256 verified:
echo        !VH_ACTUAL!
endlocal
exit /b 0

rem ============================================================================
rem File generation helpers
rem Existing files are intentionally preserved.
rem ============================================================================

:GenerateRequirements
if exist "%PROJECT_ROOT%\requirements.txt" (
    echo [KEEP] requirements.txt
    exit /b 0
)
>"%PROJECT_ROOT%\requirements.txt" echo jsonschema
>>"%PROJECT_ROOT%\requirements.txt" echo jinja2
if errorlevel 1 exit /b 1
echo [CREATE] requirements.txt
exit /b 0

:GenerateSetProjectEnv
if exist "%PROJECT_ROOT%\SetProjectEnv.bat" (
    echo [KEEP] SetProjectEnv.bat
    exit /b 0
)
>"%PROJECT_ROOT%\SetProjectEnv.bat" echo @echo off
>>"%PROJECT_ROOT%\SetProjectEnv.bat" echo rem Project-local Mbed TLS development environment.
>>"%PROJECT_ROOT%\SetProjectEnv.bat" echo rem No permanent Windows PATH modification is performed.
>>"%PROJECT_ROOT%\SetProjectEnv.bat" echo set "PROJECT_ROOT=%%~dp0"
>>"%PROJECT_ROOT%\SetProjectEnv.bat" echo if "%%PROJECT_ROOT:~-1%%"=="\" set "PROJECT_ROOT=%%PROJECT_ROOT:~0,-1%%"
>>"%PROJECT_ROOT%\SetProjectEnv.bat" echo set "PATH=%%PROJECT_ROOT%%\tools\strawberry-perl\perl\bin;%%PROJECT_ROOT%%\tools\strawberry-perl\c\bin;%%PROJECT_ROOT%%\tools\python;%%PROJECT_ROOT%%\tools\python\Scripts;%%PROJECT_ROOT%%\tools\cmake\bin;%%PROJECT_ROOT%%\tools\ninja;%%PATH%%"
if errorlevel 1 exit /b 1
echo [CREATE] SetProjectEnv.bat
exit /b 0

:GenerateCMakeLists
if exist "%PROJECT_ROOT%\CMakeLists.txt" (
    echo [KEEP] CMakeLists.txt
    exit /b 0
)
>"%PROJECT_ROOT%\CMakeLists.txt" echo cmake_minimum_required(VERSION 3.20)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo project(MbedTLS_Test LANGUAGES C)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo set(ENABLE_PROGRAMS OFF CACHE BOOL "Build Mbed TLS programs" FORCE)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo set(ENABLE_TESTING OFF CACHE BOOL "Build Mbed TLS tests" FORCE)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo set(GEN_FILES ON CACHE BOOL "Generate Mbed TLS source files" FORCE)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo add_subdirectory(external/mbedtls)
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo add_executable(mbedtls_client
>>"%PROJECT_ROOT%\CMakeLists.txt" echo     client/main.c
>>"%PROJECT_ROOT%\CMakeLists.txt" echo )
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo set_target_properties(mbedtls_client PROPERTIES
>>"%PROJECT_ROOT%\CMakeLists.txt" echo     C_STANDARD 99
>>"%PROJECT_ROOT%\CMakeLists.txt" echo     C_STANDARD_REQUIRED YES
>>"%PROJECT_ROOT%\CMakeLists.txt" echo )
>>"%PROJECT_ROOT%\CMakeLists.txt" echo.
>>"%PROJECT_ROOT%\CMakeLists.txt" echo target_link_libraries(mbedtls_client PRIVATE
>>"%PROJECT_ROOT%\CMakeLists.txt" echo     MbedTLS::mbedtls
>>"%PROJECT_ROOT%\CMakeLists.txt" echo     MbedTLS::mbedx509
>>"%PROJECT_ROOT%\CMakeLists.txt" echo )
if errorlevel 1 exit /b 1
echo [CREATE] CMakeLists.txt
exit /b 0

:GenerateCMakePresets
if exist "%PROJECT_ROOT%\CMakePresets.json" (
    echo [KEEP] CMakePresets.json
    exit /b 0
)
>"%PROJECT_ROOT%\CMakePresets.json" echo {
>>"%PROJECT_ROOT%\CMakePresets.json" echo   "version": 6,
>>"%PROJECT_ROOT%\CMakePresets.json" echo   "configurePresets": [
>>"%PROJECT_ROOT%\CMakePresets.json" echo     {
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "name": "gcc-debug",
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "displayName": "Project GCC Debug",
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "generator": "Ninja",
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "binaryDir": "${sourceDir}/out/build/gcc-debug",
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "environment": {
>>"%PROJECT_ROOT%\CMakePresets.json" echo         "PATH": "${sourceDir}/tools/strawberry-perl/perl/bin;${sourceDir}/tools/strawberry-perl/c/bin;${sourceDir}/tools/python;${sourceDir}/tools/python/Scripts;${sourceDir}/tools/cmake/bin;${sourceDir}/tools/ninja;$penv{PATH}"
>>"%PROJECT_ROOT%\CMakePresets.json" echo       },
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "cacheVariables": {
>>"%PROJECT_ROOT%\CMakePresets.json" echo         "CMAKE_BUILD_TYPE": "Debug",
>>"%PROJECT_ROOT%\CMakePresets.json" echo         "CMAKE_C_COMPILER": "${sourceDir}/tools/strawberry-perl/c/bin/gcc.exe",
>>"%PROJECT_ROOT%\CMakePresets.json" echo         "CMAKE_MAKE_PROGRAM": "${sourceDir}/tools/ninja/ninja.exe",
>>"%PROJECT_ROOT%\CMakePresets.json" echo         "Python3_EXECUTABLE": "${sourceDir}/tools/python/python.exe"
>>"%PROJECT_ROOT%\CMakePresets.json" echo       }
>>"%PROJECT_ROOT%\CMakePresets.json" echo     }
>>"%PROJECT_ROOT%\CMakePresets.json" echo   ],
>>"%PROJECT_ROOT%\CMakePresets.json" echo   "buildPresets": [
>>"%PROJECT_ROOT%\CMakePresets.json" echo     {
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "name": "gcc-debug",
>>"%PROJECT_ROOT%\CMakePresets.json" echo       "configurePreset": "gcc-debug"
>>"%PROJECT_ROOT%\CMakePresets.json" echo     }
>>"%PROJECT_ROOT%\CMakePresets.json" echo   ]
>>"%PROJECT_ROOT%\CMakePresets.json" echo }
if errorlevel 1 exit /b 1
echo [CREATE] CMakePresets.json
exit /b 0

:GenerateMainC
if exist "%PROJECT_ROOT%\client\main.c" (
    echo [KEEP] client\main.c
    exit /b 0
)
>"%PROJECT_ROOT%\client\main.c" echo #include ^<stdio.h^>
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo #include "mbedtls/version.h"
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo int main(void)
>>"%PROJECT_ROOT%\client\main.c" echo {
>>"%PROJECT_ROOT%\client\main.c" echo     const char* version;
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo     printf("Mbed TLS Client Test\n");
>>"%PROJECT_ROOT%\client\main.c" echo     printf("--------------------\n");
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo #ifdef __GNUC__
>>"%PROJECT_ROOT%\client\main.c" echo     printf("Compiler : GCC %%d.%%d.%%d\n",
>>"%PROJECT_ROOT%\client\main.c" echo         __GNUC__,
>>"%PROJECT_ROOT%\client\main.c" echo         __GNUC_MINOR__,
>>"%PROJECT_ROOT%\client\main.c" echo         __GNUC_PATCHLEVEL__);
>>"%PROJECT_ROOT%\client\main.c" echo #endif
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo #ifdef _WIN64
>>"%PROJECT_ROOT%\client\main.c" echo     printf("Platform : 64-bit Windows\n");
>>"%PROJECT_ROOT%\client\main.c" echo #endif
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo     /*
>>"%PROJECT_ROOT%\client\main.c" echo      * Mbed TLS 4.x returns a pointer to the version string.
>>"%PROJECT_ROOT%\client\main.c" echo      */
>>"%PROJECT_ROOT%\client\main.c" echo     version = mbedtls_version_get_string_full();
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo     printf("Mbed TLS : %%s\n", version);
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo     printf("\nMbed TLS library test successful.\n");
>>"%PROJECT_ROOT%\client\main.c" echo.
>>"%PROJECT_ROOT%\client\main.c" echo     return 0;
>>"%PROJECT_ROOT%\client\main.c" echo }
if errorlevel 1 exit /b 1
echo [CREATE] client\main.c
exit /b 0

:GenerateCleanBuild
if exist "%PROJECT_ROOT%\CleanBuild.bat" (
    echo [KEEP] CleanBuild.bat
    exit /b 0
)
>"%PROJECT_ROOT%\CleanBuild.bat" echo @echo off
>>"%PROJECT_ROOT%\CleanBuild.bat" echo setlocal EnableExtensions
>>"%PROJECT_ROOT%\CleanBuild.bat" echo set "PROJECT_ROOT=%%~dp0"
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if "%%PROJECT_ROOT:~-1%%"=="\" set "PROJECT_ROOT=%%PROJECT_ROOT:~0,-1%%"
>>"%PROJECT_ROOT%\CleanBuild.bat" echo call "%%PROJECT_ROOT%%\SetProjectEnv.bat"
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if errorlevel 1 exit /b 1
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo ============================================================
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo  Mbed TLS Clean Build
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo ============================================================
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if exist "%%PROJECT_ROOT%%\out\build\gcc-debug" rmdir /s /q "%%PROJECT_ROOT%%\out\build\gcc-debug"
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if exist "%%PROJECT_ROOT%%\out\build\gcc-debug" ^(
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     echo [FAIL] Unable to remove previous build directory.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     pause
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     exit /b 1
>>"%PROJECT_ROOT%\CleanBuild.bat" echo ^)
>>"%PROJECT_ROOT%\CleanBuild.bat" echo cd /d "%%PROJECT_ROOT%%"
>>"%PROJECT_ROOT%\CleanBuild.bat" echo cmake --preset gcc-debug
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if errorlevel 1 ^(
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     echo [FAIL] CMake configuration failed.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     pause
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     exit /b 1
>>"%PROJECT_ROOT%\CleanBuild.bat" echo ^)
>>"%PROJECT_ROOT%\CleanBuild.bat" echo cmake --build --preset gcc-debug
>>"%PROJECT_ROOT%\CleanBuild.bat" echo if errorlevel 1 ^(
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     echo [FAIL] Build failed.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     pause
>>"%PROJECT_ROOT%\CleanBuild.bat" echo     exit /b 1
>>"%PROJECT_ROOT%\CleanBuild.bat" echo ^)
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo echo [PASS] Clean build successful.
>>"%PROJECT_ROOT%\CleanBuild.bat" echo pause
>>"%PROJECT_ROOT%\CleanBuild.bat" echo endlocal
>>"%PROJECT_ROOT%\CleanBuild.bat" echo exit /b 0
if errorlevel 1 exit /b 1
echo [CREATE] CleanBuild.bat
exit /b 0
