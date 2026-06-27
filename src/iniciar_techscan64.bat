@echo off
setlocal

if exist bin\techscan_gui.exe (
    start "" bin\techscan_gui.exe
    exit /b 0
)

if exist bin\techscan64.exe (
    echo No se encontro bin\techscan_gui.exe.
    echo Se abrira la version de consola.
    echo.
    bin\techscan64.exe
    exit /b 0
)

echo No hay ejecutables compilados.
echo Ejecuta primero:
echo   compilar_techscan64.bat
pause
exit /b 1
