@echo off
setlocal EnableExtensions
cd /d "%~dp0.."

set "MODE=%~1"
if "%MODE%"=="" set "MODE=qa"

if exist ".venv\Scripts\python.exe" (
  set "PY=.venv\Scripts\python.exe"
) else (
  set "PY=python"
)

call "%~dp0_resolve_flutter.bat"
if errorlevel 1 exit /b 1
echo Using Flutter: %FLUTTER%

echo === MeraSonar release verify [%MODE%] ===

call :run_qa
if errorlevel 1 exit /b 1

if /I "%MODE%"=="qa" (
  echo.
  echo Release verify QA OK.
  exit /b 0
)

if /I "%MODE%"=="windows" goto do_windows
if /I "%MODE%"=="apk" goto do_apk
if /I "%MODE%"=="all" goto do_all

echo Unknown mode: %MODE%
echo Usage: release_verify.bat [qa^|windows^|apk^|all]
exit /b 1

:do_windows
call :build_windows
exit /b %ERRORLEVEL%

:do_apk
call :build_apk
exit /b %ERRORLEVEL%

:do_all
call :build_windows
if errorlevel 1 exit /b 1
call :build_apk
exit /b %ERRORLEVEL%

:run_qa
"%PY%" scripts\check_secrets.py
if errorlevel 1 exit /b 1
"%PY%" scripts\check_release_config.py
if errorlevel 1 exit /b 1
call "%~dp0run_backend_tests.bat"
if errorlevel 1 exit /b 1
pushd deniz_app
call "%~dp0flutter_exec.bat" pub get
if errorlevel 1 (popd & exit /b 1)
call "%~dp0flutter_exec.bat" analyze
if errorlevel 1 (popd & exit /b 1)
call "%~dp0flutter_exec.bat" test
if errorlevel 1 (popd & exit /b 1)
popd
exit /b 0

goto :eof

:resolve_build_app_dir
set "BUILD_APP_DIR=deniz_app"
for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"

if defined MERASONAR_BUILD_DRIVE (
  set "BD=%MERASONAR_BUILD_DRIVE%"
  if not "!BD:~-1!"==":" set "BD=!BD!:"
  set "BUILD_APP_DIR=!BD!deniz_app"
  if exist "!BUILD_APP_DIR!\pubspec.yaml" exit /b 0
  echo ERROR: MERASONAR_BUILD_DRIVE=!BD! but deniz_app not found.
  echo Run: scripts\prepare_windows_build_drive.bat
  exit /b 1
)

for /f %%I in ('powershell -NoProfile -Command "if ('%REPO_ROOT%' -match '[^\u0000-\u007F]') { '1' } else { '0' }"') do set "BUILD_NONASCII=%%I"
if "%BUILD_NONASCII%"=="1" (
  echo.
  echo WARNING: Non-ASCII project path detected:
  echo   %REPO_ROOT%
  echo For reliable Windows/Android release builds use an ASCII path or mapped drive.
  echo.
  echo   scripts\prepare_windows_build_drive.bat
  echo   M:
  echo   set MERASONAR_BUILD_DRIVE=M:
  echo   scripts\release_verify.bat %MODE%
  echo.
  exit /b 1
)
exit /b 0

:build_windows
setlocal EnableDelayedExpansion
call :stop_merasonar_for_build
if errorlevel 1 exit /b 1
call :resolve_build_app_dir
if errorlevel 1 exit /b 1
pushd %BUILD_APP_DIR%
call "%~dp0flutter_exec.bat" pub get
if errorlevel 1 (popd & endlocal & exit /b 1)
call "%~dp0flutter_exec.bat" build windows --release
if errorlevel 1 (popd & endlocal & exit /b 1)
popd
endlocal
powershell -NoProfile -Command "$src='deniz_app\build\windows\x64\runner\Release'; $dst='deniz_app\MeraSonar-windows-release.zip'; if (-not (Test-Path $src)) { exit 1 }; if (Test-Path $dst) { Remove-Item -Force $dst }; Compress-Archive -Path (Join-Path $src '*') -DestinationPath $dst -Force"
if errorlevel 1 exit /b 1
"%PY%" scripts\check_release_artifacts.py --windows-dir deniz_app\build\windows\x64\runner\Release --windows-zip deniz_app\MeraSonar-windows-release.zip
if errorlevel 1 exit /b 1
echo.
echo Windows artifact: deniz_app\build\windows\x64\runner\Release\
echo Windows zip: deniz_app\MeraSonar-windows-release.zip
exit /b 0

:build_apk
setlocal EnableDelayedExpansion
call :resolve_build_app_dir
if errorlevel 1 exit /b 1
pushd %BUILD_APP_DIR%
call "%~dp0flutter_exec.bat" pub get
if errorlevel 1 (popd & endlocal & exit /b 1)
call "%~dp0flutter_exec.bat" build apk --release
if errorlevel 1 (popd & endlocal & exit /b 1)
popd
endlocal
"%PY%" scripts\check_release_artifacts.py --apk deniz_app\build\app\outputs\flutter-apk\app-release.apk
if errorlevel 1 exit /b 1
echo.
echo APK artifact: deniz_app\build\app\outputs\flutter-apk\app-release.apk
exit /b 0

:stop_merasonar_for_build
echo.
echo Checking for running MeraSonar.exe (Release folder file lock)...
tasklist /FI "IMAGENAME eq MeraSonar.exe" 2>nul | find /I "MeraSonar.exe" >nul
if errorlevel 1 (
  echo No running MeraSonar.exe - OK.
  exit /b 0
)
echo MeraSonar.exe is running - closing before Windows build...
taskkill /IM MeraSonar.exe /F >nul 2>&1
if errorlevel 1 (
  echo ERROR: Could not close MeraSonar.exe. Close the app manually and retry.
  exit /b 1
)
timeout /t 2 /nobreak >nul
echo MeraSonar.exe closed.
exit /b 0
