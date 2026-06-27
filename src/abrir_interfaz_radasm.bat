@echo off
setlocal

if exist bin\techscan_gui.exe (
    start "" bin\techscan_gui.exe
    exit /b 0
)

echo No se encontro bin\techscan_gui.exe.
echo Primero compila la interfaz con:
echo   compilar_techscan64.bat
echo.
echo Si el compilador dice que FASM no fue detectado, abre RadASM/FASM
echo y compila techscan_gui.asm hacia bin\techscan_gui.exe.
pause
exit /b 1
