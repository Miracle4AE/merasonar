@echo off
setlocal
cd /d "%~dp0.."

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000" ^| findstr "LISTENING"') do (
  echo Port 8000 is in use by PID %%a
  for /f "tokens=1" %%b in ('tasklist /FI "PID eq %%a" /NH') do echo Process: %%b
  echo.
  echo Options:
  echo   1. Stop the process above if it is a stale uvicorn instance
  echo   2. Or use the existing backend for QA
  exit /b 2
)

echo Starting backend on port 8000...
python -m uvicorn main:app --host 127.0.0.1 --port 8000
exit /b %ERRORLEVEL%
