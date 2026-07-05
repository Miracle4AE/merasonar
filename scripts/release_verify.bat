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

where flutter >nul 2>&1
if errorlevel 1 (
  if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER=C:\src\flutter\bin\flutter.bat"
  ) else (
    set "FLUTTER=flutter"
  )
) else (
  set "FLUTTER=flutter"
)

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
call %FLUTTER% pub get
if errorlevel 1 (popd & exit /b 1)
call %FLUTTER% analyze
if errorlevel 1 (popd & exit /b 1)
call %FLUTTER% test
if errorlevel 1 (popd & exit /b 1)
popd
exit /b 0

:build_windows
call :stop_merasonar_for_build
if errorlevel 1 exit /b 1
set "REPO_ROOT=%~dp0.."
set "WIN_APP_DIR=deniz_app"
for /f %%I in ('powershell -NoProfile -Command "if ('%REPO_ROOT%' -match '[^\u0000-\u007F]') { '1' } else { '0' }"') do set "WIN_NONASCII=%%I"
if "%WIN_NONASCII%"=="1" (
  echo Non-ASCII repo path detected — using subst M: for Windows build
  subst M: "%REPO_ROOT%" 2>nul
  if exist "M:\deniz_app" (
    set "WIN_APP_DIR=M:\deniz_app"
    set "WIN_USED_SUBST=1"
  )
)
pushd %WIN_APP_DIR%
call %FLUTTER% pub get
if errorlevel 1 (call :cleanup_win_subst & popd & exit /b 1)
call %FLUTTER% build windows --release
if errorlevel 1 (call :cleanup_win_subst & popd & exit /b 1)
popd
call :cleanup_win_subst
goto :build_windows_after
:cleanup_win_subst
if defined WIN_USED_SUBST subst M: /D 2>nul
set "WIN_USED_SUBST="
exit /b 0
:build_windows_after
powershell -NoProfile -Command "$src='deniz_app\build\windows\x64\runner\Release'; $dst='deniz_app\MeraSonar-windows-release.zip'; if (-not (Test-Path $src)) { exit 1 }; if (Test-Path $dst) { Remove-Item -Force $dst }; Compress-Archive -Path (Join-Path $src '*') -DestinationPath $dst -Force"
if errorlevel 1 exit /b 1
"%PY%" scripts\check_release_artifacts.py --windows-dir deniz_app\build\windows\x64\runner\Release --windows-zip deniz_app\MeraSonar-windows-release.zip
if errorlevel 1 exit /b 1
echo.
echo Windows artifact: deniz_app\build\windows\x64\runner\Release\
echo Windows zip: deniz_app\MeraSonar-windows-release.zip
exit /b 0

:build_apk
set "REPO_ROOT=%~dp0.."
set "APK_APP_DIR=deniz_app"
for /f %%I in ('powershell -NoProfile -Command "if ('%REPO_ROOT%' -match '[^\u0000-\u007F]') { '1' } else { '0' }"') do set "APK_NONASCII=%%I"
if "%APK_NONASCII%"=="1" (
  echo Non-ASCII repo path detected — using subst M: for APK build
  subst M: "%REPO_ROOT%" 2>nul
  if exist "M:\deniz_app" (
    set "APK_APP_DIR=M:\deniz_app"
    set "APK_USED_SUBST=1"
  )
)
pushd %APK_APP_DIR%
call %FLUTTER% pub get
if errorlevel 1 (call :cleanup_apk_subst & popd & exit /b 1)
call %FLUTTER% build apk --release
if errorlevel 1 (call :cleanup_apk_subst & popd & exit /b 1)
popd
call :cleanup_apk_subst
goto :build_apk_after
:cleanup_apk_subst
if defined APK_USED_SUBST subst M: /D 2>nul
set "APK_USED_SUBST="
exit /b 0
:build_apk_after
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
  echo No running MeraSonar.exe — OK.
  exit /b 0
)
echo MeraSonar.exe is running — closing before Windows build...
taskkill /IM MeraSonar.exe /F >nul 2>&1
if errorlevel 1 (
  echo ERROR: Could not close MeraSonar.exe. Close the app manually and retry.
  exit /b 1
)
timeout /t 2 /nobreak >nul
echo MeraSonar.exe closed.
exit /b 0
