@echo off
cd /d "%~dp0"
echo Abre http://127.0.0.1:8080 mientras esta ventana permanezca abierta.
echo Esta demostracion usa Python; no instala ni cambia Windows Server.
where py >nul 2>nul
if errorlevel 1 (
    python demo\server.py
) else (
    py -3 demo\server.py
)
pause
