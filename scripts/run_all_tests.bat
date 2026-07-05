@echo off
setlocal
cd /d "%~dp0.."
if exist "%~dp0..\.venv\Scripts\python.exe" (
  set "PY=%~dp0..\.venv\Scripts\python.exe"
) else (
  set "PY=python"
)
"%PY%" "%~dp0check_secrets.py"
if errorlevel 1 exit /b 1
"%PY%" "%~dp0check_release_config.py"
if errorlevel 1 exit /b 1
call "%~dp0run_backend_tests.bat"
if errorlevel 1 exit /b 1
call "%~dp0run_flutter_tests.bat"
exit /b %ERRORLEVEL%
