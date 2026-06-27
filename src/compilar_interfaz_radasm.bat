@echo off
setlocal

echo ==========================================
echo TECHSCAN64 - Interfaz RadASM/FASM
echo ==========================================

if not exist bin mkdir bin

set FASM=C:\fasm\FASM.EXE
set INCLUDE=C:\fasm\INCLUDE

if not exist "%FASM%" goto no_fasm
if not exist "%INCLUDE%" goto no_include

echo FASM: %FASM%
echo INCLUDE FASM: %INCLUDE%

echo Compilando interfaz unificada...
"%FASM%" techscan_gui.asm bin\techscan_gui.exe
if errorlevel 1 goto error

echo Compilando monitor grafico...
"%FASM%" monitor_gui.asm bin\monitor_gui.exe
if errorlevel 1 goto error

echo ==========================================
echo INTERFAZ RADASM COMPILADA
echo Ejecutable principal: bin\techscan_gui.exe
echo Monitor grafico:      bin\monitor_gui.exe
echo ==========================================
pause
exit /b 0

:no_fasm
echo No se encontro FASM en:
echo   %FASM%
echo No se pudo generar bin\techscan_gui.exe.
pause
exit /b 1

:no_include
echo No se encontro INCLUDE de FASM en:
echo   %INCLUDE%
echo No se pudo generar bin\techscan_gui.exe.
pause
exit /b 1

:error
echo ==========================================
echo ERROR compilando la interfaz RadASM/FASM.
echo Revise el mensaje anterior.
echo ==========================================
pause
exit /b 1
