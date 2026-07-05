@echo off
:: Tam ekran konsol + derleme: BASLA.bat
:: Konsolsuz, yalnızca masaüstü .exe: MasaustuAc.vbs ye çift tıklayın.
chcp 65001 >nul
set "ROOT=%~dp0"
cd /d "%ROOT%"

:: API'yi kucultulmus pencerede baslat, hazir olmasini bekle.
start "Deniz-API" /min "%ROOT%run_api.cmd"

set "API_READY=0"
for /L %%I in (1,1,20) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-RestMethod 'http://127.0.0.1:8000/health' -TimeoutSec 2; if ($r.status -eq 'ok' -and $r.service -eq 'MeraSonar API') { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
  if not errorlevel 1 (
    set "API_READY=1"
    goto :api_checked
  )
  timeout /t 1 /nobreak >nul
)

:api_checked
if "%API_READY%"=="0" (
  echo [UYARI] API 20 saniye icinde hazir olmadi. Uygulama yine acilacak.
  echo         Hata ayrintisi icin run_api.cmd dosyasini calistirin.
)

set "EXE=%ROOT%deniz_app\build\windows\x64\runner\Release\MeraSonar.exe"
if not exist "%EXE%" set "EXE=%ROOT%deniz_app\build\windows\x64\runner\Debug\MeraSonar.exe"

if not exist "%EXE%" (
  where flutter >nul 2>&1
  if errorlevel 1 (
    echo.
    echo [HATA] Masaustu uygulama ^(.exe^) bulunamadi ve PATH uzerinde flutter yok.
    echo        Cozum: Flutter SDK kurun ^(PATH'e flutter.bat ekleyin^) veya proje klasorunde:
    echo          cd deniz_app
    echo          flutter build windows --release
    echo        Sonra BASLA.bat'i tekrar calistirin.
    pause
    exit /b 1
  )
  echo.
  echo [BILGI] Ilk calistirma: Windows uygulamasi derleniyor ^(bir kac dakika surebilir^)...
  pushd "%ROOT%deniz_app"
  call flutter build windows --release
  if errorlevel 1 (
    popd
    echo [HATA] Derleme basarisiz. Yukaridaki flutter ciktisini kontrol edin.
    pause
    exit /b 1
  )
  popd
  set "EXE=%ROOT%deniz_app\build\windows\x64\runner\Release\MeraSonar.exe"
  if not exist "%EXE%" (
    echo [HATA] Derleme tamamlandi ancak exe bulunamadi: %EXE%
    pause
    exit /b 1
  )
)

for %%E in ("%EXE%") do set "APPDIR=%%~dpE"
:: Masaustu uygulama penceresi olarak ac (tarayici degil).
start "Deniz" /D "%APPDIR%" "%EXE%"
exit /b 0
