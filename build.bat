@echo off
echo ==========================================
echo  TECHSCAN64 - Compilando
echo  NASM + GCC (MSYS2) + FASM (RadASM)
echo ==========================================

if not exist bin      mkdir bin
if not exist reportes mkdir reportes

set NASM=C:\Users\totin\AppData\Local\bin\NASM\nasm.exe
set GCC=C:\msys64\mingw64\bin\gcc.exe
set FASM=C:\fasm\FASM.EXE
set INCLUDE=C:\fasm\INCLUDE

if not exist "%NASM%" ( echo ERROR: NASM no encontrado & pause & exit /b 1 )
if not exist "%GCC%"  ( echo ERROR: GCC  no encontrado & pause & exit /b 1 )
if not exist "%FASM%" ( echo ERROR: FASM no encontrado & pause & exit /b 1 )

echo [1/9] Ensamblando  menu.asm         (NASM x64)...
"%NASM%" -f win64 src\menu.asm -o bin\menu.o
if errorlevel 1 goto :error

echo [2/9] Ensamblando  fpu_calc.asm     (NASM x64 - FPU x87)...
"%NASM%" -f win64 src\fpu_calc.asm -o bin\fpu_calc.o
if errorlevel 1 goto :error

echo [3/9] Compilando   report_io.c      (GCC)...
"%GCC%" -c src\report_io.c -o bin\report_io.o
if errorlevel 1 goto :error

echo [4/9] Compilando   analyzer.c       (GCC)...
"%GCC%" -c src\analyzer.c -o bin\analyzer.o
if errorlevel 1 goto :error

echo [5/10] Compilando   modulo2.c        (GCC)...
"%GCC%" -c src\modulo2.c -o bin\modulo2.o
if errorlevel 1 goto :error

echo [6/10] Compilando   techscan_system.c (GCC)...
"%GCC%" -c src\techscan_system.c -o bin\techscan_system.o
if errorlevel 1 goto :error

echo [7/10] Compilando   monitor_ui.c     (GCC)...
"%GCC%" -c src\monitor_ui.c -o bin\monitor_ui.o
if errorlevel 1 goto :error

echo [8/10] Enlazando    techscan64.exe   (consola)...
"%GCC%" bin\menu.o bin\fpu_calc.o bin\report_io.o bin\analyzer.o ^
        bin\modulo2.o bin\techscan_system.o bin\monitor_ui.o ^
        -o bin\techscan64.exe -lkernel32 -lpsapi -luser32
if errorlevel 1 goto :error

echo [8/9] Ensamblando  monitor_gui.asm  (FASM/RadASM)...
"%FASM%" src\monitor_gui.asm bin\monitor_gui.exe
if errorlevel 1 goto :error

echo [9/9] Ensamblando  techscan_gui.asm (FASM/RadASM - GUI principal)...
"%FASM%" src\techscan_gui.asm bin\techscan_gui.exe
if errorlevel 1 goto :error

echo.
echo ==========================================
echo  Compilacion exitosa.
echo.
echo   bin\techscan_gui.exe  <- INTERFAZ PRINCIPAL (4 paneles)
echo   bin\techscan64.exe    <- Version consola (con FPU)
echo   bin\monitor_gui.exe   <- Monitor standalone
echo ==========================================
echo.
bin\techscan_gui.exe
goto :eof

:error
echo.
echo ==========================================
echo  ERROR en la compilacion (ver arriba).
echo ==========================================
pause
