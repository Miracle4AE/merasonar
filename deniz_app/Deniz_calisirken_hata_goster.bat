@echo off
chcp 65001 >nul
title Deniz - hata ayiklama
cd /d "%~dp0build\windows\x64\runner\Debug"

if not exist "MeraSonar.exe" (
  echo MeraSonar.exe bulunamadi.
  pause
  exit /b 1
)

echo Bu pencerede uygulama KAPANIRSA veya kirmizi yazi cikarsa ekran goruntusu alin.
echo.
MeraSonar.exe
echo.
echo --- Bitti. Cikis kodu: %ERRORLEVEL% ---
pause
