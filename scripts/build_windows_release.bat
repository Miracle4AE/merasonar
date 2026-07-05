@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
call "%~dp0_resolve_flutter.bat"
if errorlevel 1 exit /b 1
call "%~dp0release_verify.bat" windows
exit /b %ERRORLEVEL%
