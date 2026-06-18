@echo off
set PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%

echo Compilando TechScan64...

if not exist bin mkdir bin
if not exist reportes mkdir reportes

nasm -f win64 src\menu.asm    -o bin\menu.o
nasm -f win64 src\monitor.asm -o bin\monitor.o
gcc -c src\report_io.c  -o bin\report_io.o
gcc -c src\analyzer.c   -o bin\analyzer.o
gcc -c src\modulo2.c    -o bin\modulo2.o

gcc bin\menu.o bin\monitor.o bin\report_io.o bin\analyzer.o bin\modulo2.o ^
    -o bin\techscan64.exe -static -lkernel32 -lpsapi -ladvapi32

echo.
echo Listo! Ejecutando...
echo.
bin\techscan64.exe
