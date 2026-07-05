@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "API_URL=http://127.0.0.1:8000/health"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-RestMethod '%API_URL%' -TimeoutSec 2; if ($r.status -eq 'ok' -and $r.service -eq 'MeraSonar API') { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 (
  echo [BILGI] MeraSonar API zaten calisiyor: %API_URL%
  exit /b 0
)

set "PY_CMD="

if exist "venv\Scripts\python.exe" (
  set "PY_CMD=venv\Scripts\python.exe"
  call :validate_python
  if not errorlevel 1 goto :run_api
)

if exist ".venv\Scripts\python.exe" (
  set "PY_CMD=.venv\Scripts\python.exe"
  call :validate_python
  if not errorlevel 1 goto :run_api
)

if exist "%ProgramFiles%\Python312\python.exe" (
  set "PY_CMD="%ProgramFiles%\Python312\python.exe""
  call :validate_python
  if not errorlevel 1 goto :run_api
)

if exist "%LocalAppData%\Programs\Python\Python312\python.exe" (
  set "PY_CMD="%LocalAppData%\Programs\Python\Python312\python.exe""
  call :validate_python
  if not errorlevel 1 goto :run_api
)

if exist "%ProgramFiles(x86)%\Python312\python.exe" (
  set "PY_CMD="%ProgramFiles(x86)%\Python312\python.exe""
  call :validate_python
  if not errorlevel 1 goto :run_api
)

where py >nul 2>&1
if not errorlevel 1 (
  set "PY_CMD=py -3.12"
  call :validate_python
  if not errorlevel 1 goto :run_api

  set "PY_CMD=py -3.11"
  call :validate_python
  if not errorlevel 1 goto :run_api

  set "PY_CMD=py -3.10"
  call :validate_python
  if not errorlevel 1 goto :run_api
)

where python >nul 2>&1
if not errorlevel 1 (
  set "PY_CMD=python"
  call :validate_python
  if not errorlevel 1 goto :run_api
)

echo [HATA] Uygun Python bulunamadi veya gerekli paketler kurulamadi.
echo        Python 3.10, 3.11 veya 3.12 kullanin; Python 3.13 bu proje icin atlanir.
echo        Gerekirse: py -3.12 -m pip install -r requirements.txt
pause
exit /b 1

:validate_python
%PY_CMD% -c "import sys; raise SystemExit(0 if (3, 10) <= sys.version_info[:2] < (3, 13) else 1)" >nul 2>&1
if errorlevel 1 exit /b 1

%PY_CMD% -c "import fastapi, uvicorn, cv2, numpy" >nul 2>&1
if not errorlevel 1 exit /b 0

echo [BILGI] Eksik Python paketleri kuruluyor: %PY_CMD%
%PY_CMD% -m pip -q install -r requirements.txt
if errorlevel 1 exit /b 1

%PY_CMD% -c "import fastapi, uvicorn, cv2, numpy" >nul 2>&1
exit /b %ERRORLEVEL%

:run_api
echo [BILGI] Yerel LAN + emülator erisimi icin tum arayuzlere dinleme gereklidir.
echo        Ornek calistirma: uvicorn main:app --host 0.0.0.0 --port 8000
echo [BILGI] API baslatiliyor: %PY_CMD%
%PY_CMD% -m uvicorn main:app --host 0.0.0.0 --port 8000
exit /b %ERRORLEVEL%
