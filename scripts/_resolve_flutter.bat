@echo off
rem Resolves FLUTTER to a quote-safe executable path.
rem Priority: FLUTTER_BIN env -> PATH flutter -> puro stable default.
rem Exit 0 and set FLUTTER on success; exit 1 with message on failure.

if defined FLUTTER_BIN (
  if exist "%FLUTTER_BIN%" (
    set "FLUTTER=%FLUTTER_BIN%"
    goto :done
  )
  echo ERROR: FLUTTER_BIN is set but file not found:
  echo   %FLUTTER_BIN%
  exit /b 1
)

where flutter.bat >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
    set "FLUTTER=%%F"
    goto :done
  )
)

where flutter >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%F in ('where flutter 2^>nul') do (
    if exist "%%F.bat" (set "FLUTTER=%%F.bat") else (set "FLUTTER=%%F")
    goto :done
  )
)

set "PURO_FLUTTER=%USERPROFILE%\.puro\envs\stable\flutter\bin\flutter.bat"
if exist "%PURO_FLUTTER%" (
  set "FLUTTER=%PURO_FLUTTER%"
  goto :done
)

echo ERROR: Flutter not found. Set FLUTTER_BIN or add Flutter to PATH.
echo   Example:
echo   set FLUTTER_BIN=%USERPROFILE%\.puro\envs\stable\flutter\bin\flutter.bat
exit /b 1

:done
exit /b 0
