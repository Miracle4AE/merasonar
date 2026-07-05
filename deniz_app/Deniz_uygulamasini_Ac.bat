@echo off
chcp 65001 >nul
set "HERE=%~dp0"
set "DIR=%HERE%build\windows\x64\runner\Debug"
set "EXE=%DIR%\MeraSonar.exe"

if not exist "%EXE%" (
  echo.
  echo [HATA] Uygulama bulunamadi:
  echo   %EXE%
  echo   Once: flutter build windows  (Flutter gerekir^)
  echo.
  pause
  exit /b 1
)

:: Calisma dizini olmazsa DLL yuklenemeyebilir — /D ile ayarla
start "Deniz App" /D "%DIR%" "%EXE%"
exit /b 0
