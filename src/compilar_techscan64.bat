@echo off
setlocal

echo ==========================================
echo TECHSCAN64 - Compilador actualizado
echo NASM + GCC (MSYS2) + FASM/RadASM opcional
echo ==========================================

set NASM=C:\Users\totin\AppData\Local\bin\NASM\nasm.exe
set GCC=C:\msys64\mingw64\bin\gcc.exe
set FASM=C:\fasm\FASM.EXE
set INCLUDE=C:\fasm\INCLUDE

if not exist bin mkdir bin

if not exist "%NASM%" goto no_nasm
if not exist "%GCC%" goto no_gcc
if not exist "%FASM%" goto no_fasm
if not exist "%INCLUDE%" goto no_include

echo NASM: %NASM%
echo GCC : %GCC%
echo FASM: %FASM%
echo INCLUDE FASM: %INCLUDE%

echo [1/11] Ensamblando menu.asm             (NASM x64)...
"%NASM%" -f win64 menu.asm -o bin\menu.obj
if errorlevel 1 goto error

echo [2/11] Ensamblando fpu_calc.asm         (NASM x64 - FPU x87)...
"%NASM%" -f win64 fpu_calc.asm -o bin\fpu_calc.obj
if errorlevel 1 goto error

echo [3/11] Compilando report_io.c           (GCC)...
"%GCC%" -Wall -Wextra -c report_io.c -o bin\report_io.o
if errorlevel 1 goto error

echo [4/11] Compilando analyzer.c            (GCC)...
"%GCC%" -Wall -Wextra -c analyzer.c -o bin\analyzer.o
if errorlevel 1 goto error

echo [5/11] Compilando modulo2.c             (GCC)...
"%GCC%" -Wall -Wextra -c modulo2.c -o bin\modulo2.o
if errorlevel 1 goto error

echo [6/11] Compilando monitor_ui.c          (GCC)...
"%GCC%" -Wall -Wextra -c monitor_ui.c -o bin\monitor_ui.o
if errorlevel 1 goto error

echo [7/11] Compilando techscan_system.c     (GCC)...
"%GCC%" -Wall -Wextra -c techscan_system.c -o bin\techscan_system.o
if errorlevel 1 goto error

echo [8/11] Enlazando techscan64.exe         (consola)...
"%GCC%" bin\menu.obj bin\fpu_calc.obj bin\report_io.o bin\analyzer.o bin\modulo2.o bin\monitor_ui.o bin\techscan_system.o -o bin\techscan64.exe -lpsapi -ladvapi32
if errorlevel 1 goto error

echo [9/11] Compilando monitor_gui.asm       (FASM/RadASM)...
"%FASM%" monitor_gui.asm bin\monitor_gui.exe
if errorlevel 1 goto error

echo [10/11] Compilando techscan_gui.asm      (Interfaz RadASM/FASM)...
"%FASM%" techscan_gui.asm bin\techscan_gui.exe
if errorlevel 1 goto error

echo [11/11] Preparando carpeta reportes...
if not exist reportes mkdir reportes

echo ==========================================
echo COMPILACION COMPLETADA
echo Ejecutable: bin\techscan64.exe
if exist bin\techscan_gui.exe echo Interfaz RadASM: bin\techscan_gui.exe
if exist bin\monitor_gui.exe echo Monitor GUI: bin\monitor_gui.exe
echo ==========================================
pause
exit /b 0

:error
echo ==========================================
echo ERROR en la compilacion. Revise el mensaje anterior.
echo ==========================================
pause
exit /b 1

:no_nasm
echo ERROR: No se encontro NASM en %NASM%
pause
exit /b 1

:no_gcc
echo ERROR: No se encontro GCC en %GCC%
pause
exit /b 1

:no_fasm
echo ERROR: No se encontro FASM en %FASM%
pause
exit /b 1

:no_include
echo ERROR: No se encontro INCLUDE de FASM en %INCLUDE%
pause
exit /b 1
