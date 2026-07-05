@echo off
setlocal
cd /d "%~dp0.."
if exist ".venv\Scripts\python.exe" (
  set "PY=.venv\Scripts\python.exe"
) else (
  set "PY=python"
)
%PY% -m pip install -q -r requirements-dev.txt
%PY% -m pytest
exit /b %ERRORLEVEL%
