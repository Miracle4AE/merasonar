@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"

set "DRIVE=M:"
if defined MERASONAR_BUILD_DRIVE set "DRIVE=%MERASONAR_BUILD_DRIVE%"
if not "%DRIVE:~-1%"==":" set "DRIVE=%DRIVE%:"

echo === MeraSonar build drive prep ===
echo Repo: %REPO_ROOT%
echo Target drive: %DRIVE%

if exist "%DRIVE%\deniz_app\pubspec.yaml" (
  echo %DRIVE% already maps to this project - OK.
  goto :show_next_steps
)

if exist "%DRIVE%\" (
  echo ERROR: %DRIVE% is already mapped to another location.
  echo Run "subst" to inspect, or pick another drive:
  echo   set MERASONAR_BUILD_DRIVE=N:
  echo   scripts\prepare_windows_build_drive.bat
  exit /b 1
)

subst %DRIVE% "%REPO_ROOT%"
if errorlevel 1 (
  echo ERROR: subst %DRIVE% failed for:
  echo   %REPO_ROOT%
  exit /b 1
)

if not exist "%DRIVE%\deniz_app\pubspec.yaml" (
  echo ERROR: Mapped %DRIVE% but deniz_app\pubspec.yaml not found.
  exit /b 1
)

echo Mapped successfully.

:show_next_steps
echo.
echo Next steps:
echo   %DRIVE%
echo   set MERASONAR_BUILD_DRIVE=%DRIVE%
echo   scripts\release_verify.bat all
echo.
echo To unmap when finished:
echo   subst %DRIVE% /d
exit /b 0
