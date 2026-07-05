@echo off
setlocal
cd /d "%~dp0..\deniz_app"
where flutter >nul 2>&1
if errorlevel 1 (
  if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER=C:\src\flutter\bin\flutter.bat"
  ) else (
    echo flutter not found
    exit /b 1
  )
) else (
  set "FLUTTER=flutter"
)
echo Checking for running MeraSonar.exe (Release folder file lock)...
tasklist /FI "IMAGENAME eq MeraSonar.exe" 2>nul | find /I "MeraSonar.exe" >nul
if not errorlevel 1 (
  echo MeraSonar.exe is running — closing before Windows build...
  taskkill /IM MeraSonar.exe /F >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Could not close MeraSonar.exe. Close the app manually and retry.
    exit /b 1
  )
  timeout /t 2 /nobreak >nul
)
call %FLUTTER% pub get
call %FLUTTER% analyze
if errorlevel 1 exit /b 1
call %FLUTTER% test
if errorlevel 1 exit /b 1
call %FLUTTER% build windows --release
echo.
echo Output: deniz_app\build\windows\x64\runner\Release\
exit /b %ERRORLEVEL%
