@echo off
rem Nested-batch-safe Flutter launcher for release scripts.
rem Prefers "puro flutter" when puro is on PATH (puro flutter.bat breaks call chains).

setlocal EnableExtensions

if defined FLUTTER_BIN (
  if exist "%FLUTTER_BIN%" (
    call :run_with_bin "%FLUTTER_BIN%" %*
    exit /b %ERRORLEVEL%
  )
)

where puro >nul 2>&1
if not errorlevel 1 (
  puro flutter %*
  exit /b %ERRORLEVEL%
)

where flutter.bat >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
    call :run_with_bin "%%F" %*
    exit /b %ERRORLEVEL%
  )
)

set "PURO_FLUTTER=%USERPROFILE%\.puro\envs\stable\flutter\bin\flutter.bat"
if exist "%PURO_FLUTTER%" (
  call :run_with_bin "%PURO_FLUTTER%" %*
  exit /b %ERRORLEVEL%
)

echo ERROR: Flutter not found. Set FLUTTER_BIN or add puro/flutter to PATH.
exit /b 1

:run_with_bin
set "BIN=%~1"
shift
findstr /I /C:"puro" "%BIN%" >nul 2>&1
if not errorlevel 1 (
  where puro >nul 2>&1
  if not errorlevel 1 (
    puro flutter %*
    exit /b %ERRORLEVEL%
  )
)
call "%BIN%" %*
exit /b %ERRORLEVEL%
