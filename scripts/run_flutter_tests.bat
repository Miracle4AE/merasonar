@echo off
setlocal
cd /d "%~dp0..\deniz_app"
where flutter >nul 2>&1
if errorlevel 1 (
  if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER=C:\src\flutter\bin\flutter.bat"
  ) else (
    echo flutter not found in PATH
    exit /b 1
  )
) else (
  set "FLUTTER=flutter"
)
call %FLUTTER% pub get
call %FLUTTER% analyze
if errorlevel 1 exit /b 1
call %FLUTTER% test
exit /b %ERRORLEVEL%
