@echo off
chcp 65001 >nul
cd /d "%~dp0"
:: Flutter veya Python gerekmez — varsayilan tarayicida acilir
start "" "%~dp0preview.html"
exit /b 0
