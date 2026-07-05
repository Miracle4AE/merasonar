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
call %FLUTTER% pub get
call %FLUTTER% analyze
if errorlevel 1 exit /b 1
call %FLUTTER% test
if errorlevel 1 exit /b 1
call %FLUTTER% build apk --release
echo.
echo Output: deniz_app\build\app\outputs\flutter-apk\app-release.apk
exit /b %ERRORLEVEL%
