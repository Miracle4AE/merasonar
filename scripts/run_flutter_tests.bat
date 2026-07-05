@echo off
setlocal
cd /d "%~dp0..\deniz_app"
call "%~dp0flutter_exec.bat" pub get
if errorlevel 1 exit /b 1
call "%~dp0flutter_exec.bat" analyze
if errorlevel 1 exit /b 1
call "%~dp0flutter_exec.bat" test
exit /b %ERRORLEVEL%
