@echo off
setlocal EnableExtensions
rem MAINTAINER UTILITY ONLY. Calculated hashes are candidates, not trust anchors.
rem Compare every result with official vendor/project release metadata before
rem changing SetupEnv.bat. Never automatically copy a newly calculated hash
rem into the bootstrap.
set "WORK=%~dp0HashReview"
if not exist "%WORK%" mkdir "%WORK%"

call :Fetch "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54221_64bit/strawberry-perl-5.42.2.1-64bit-portable.zip" "strawberry-perl-5.42.2.1-64bit-portable.zip" "Strawberry Perl 5.42.2.1"
if errorlevel 1 exit /b 1
call :Fetch "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe" "python-3.13.1-amd64.exe" "Python 3.13.1 amd64"
if errorlevel 1 exit /b 1
call :Fetch "https://github.com/Kitware/CMake/releases/download/v4.2.3/cmake-4.2.3-windows-x86_64.zip" "cmake-4.2.3-windows-x86_64.zip" "CMake 4.2.3"
if errorlevel 1 exit /b 1
call :Fetch "https://github.com/ninja-build/ninja/releases/download/v1.12.0/ninja-win.zip" "ninja-win.zip" "Ninja 1.12.0"
if errorlevel 1 exit /b 1

echo.
echo ============================================================
echo HASH REVIEW COMPLETE - MANUAL TRUST REVIEW STILL REQUIRED
echo ============================================================
echo Future updates MUST change and review together:
echo   1. Version
 echo   2. Exact URL/artifact name
 echo   3. Pinned SHA-256
 echo   4. README documentation
exit /b 0

:Fetch
echo.
echo %~3
curl.exe -f -L --retry 3 --retry-delay 2 -o "%WORK%\%~2" "%~1"
if errorlevel 1 exit /b 1
certutil.exe -hashfile "%WORK%\%~2" SHA256
exit /b %errorlevel%
