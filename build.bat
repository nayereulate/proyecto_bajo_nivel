@echo off
echo Compilando TechScan64...

nasm -f win64 src\menu.asm -o bin\menu.o

gcc bin\menu.o -o bin\techscan64.exe

echo.
echo Listo! Ejecutando...
echo.
bin\techscan64.exe