; ==============================================================
; Archivo      : src/menu.asm
; Proyecto     : TechScan64 - Menu Principal de Consola
; Institucion  : U.M.S.S. - Facultad de Tecnologia
; Asignatura   : Taller de Programacion en Bajo Nivel
; Ensamblador  : NASM (Netwide Assembler) - formato COFF/Win64
; Arquitectura : Windows x86-64 (PE64, ABI Microsoft x64)
; Descripcion  :
;   Punto de entrada principal del ejecutable de consola.
;   Implementa el bucle de menu interactivo con 5 opciones.
;   Demuestra el Stack Frame x64, Shadow Space, llamadas a
;   funciones externas y la convencion FastCall de Windows.
;
; Requisitos implementados:
;   #1 Arquitectura 64-bit: RAX, RBX, RBP, RSP, RCX, RDX
;   #2 FastCall Win64: Shadow Space 32 bytes, args en RCX/RDX
;   #3 E/S Consola: scanf, printf (via MSVCRT)
;   #4 Persistencia: llamada a modulo2_diagnosticar (guarda .rep)
;
; Funciones externas (extern):
;   printf, scanf, system  -> MSVCRT.DLL
;   monitoreo_local        -> monitor_gui.asm (GUI FASM)
;   modulo2_diagnosticar   -> modulo2.c (diagnostico + FPU)
;   modulo5_analizar       -> analyzer.c (analisis de .rep)
;   modulo5_estadisticas   -> analyzer.c (estadisticas)
; ==============================================================

global main

extern printf
extern scanf
extern system
extern monitoreo_local
extern modulo2_diagnosticar
extern modulo5_analizar
extern modulo5_estadisticas

; ==============================================================
; SECCION .data - Cadenas de texto y formatos
; ==============================================================
section .data

    ; Titulo del sistema
    titulo      db "==========================================", 10
                db "         T E C H S C A N  6 4           ", 10
                db "   Sistema de Diagnostico de Equipos     ", 10
                db "==========================================", 10, 0

    ; Menu de opciones
    opciones    db "1. Diagnosticar este equipo              ", 10
                db "2. Monitorear en tiempo real             ", 10
                db "3. Analizar reportes del USB             ", 10
                db "4. Estadisticas globales                 ", 10
                db "5. Salir                                ", 10
                db "==========================================", 10
                db "Seleccione una opcion: ", 0

    fmt_input     db "%d", 0    ; Formato de entrada entera para scanf
    fmt_dummy     db "%c", 0    ; Formato dummy para consumir salto de linea
    msg_inv       db "Opcion invalida. Intente de nuevo.", 10, 0
    msg_salir     db "Cerrando TechScan64. Hasta luego.", 10, 0
    msg_continuar db "Presione ENTER para volver al menu...", 10, 0
    cls_cmd       db "cls", 0   ; Comando para limpiar la consola

; ==============================================================
; SECCION .bss - Variables no inicializadas
; ==============================================================
section .bss

    opcion       resd 1    ; Entero de 32 bits: opcion elegida por usuario
    buffer_dummy resb 8    ; Buffer para absorber caracteres extra de stdin

; ==============================================================
; SECCION .text - Codigo ejecutable
; ==============================================================
section .text

; ==============================================================
; main - Punto de entrada del programa (llamado por el CRT)
; --------------------------------------------------------------
; El CRT de Windows inicializa el entorno y llama a main().
; main recibe argc en RCX y argv en RDX (FastCall Win64).
; Retorna en EAX el codigo de salida (0 = exito).
; ==============================================================
main:
    ; ----------------------------------------------------------
    ; CONTROL DEL MARCO DE LA PILA (Stack Frame - Windows x64)
    ; ----------------------------------------------------------
    ; push rbp: respalda el puntero de marco del llamador (CRT).
    ; mov rbp, rsp: establece el nuevo marco; RBP = RSP actual.
    ; sub rsp, 32: reserva el Shadow Space de 32 bytes, exigido
    ;   por la ABI x64 para las llamadas a funciones externas.
    ;   Esto tambien mantiene RSP alineado a 16 bytes.
    ; ----------------------------------------------------------
    push    rbp                     ; Salva puntero de marco anterior
    mov     rbp, rsp                ; Nuevo marco de la pila
    sub     rsp, 32                 ; Reserva Shadow Space (32 bytes)

; ==============================================================
; BUCLE PRINCIPAL DEL MENU
; ==============================================================
.bucle:
    ; Limpiar pantalla antes de mostrar el menu
    ; INTERACCION CON EL ENTORNO: llamada a system() de MSVCRT.
    ; Convencion FastCall: RCX = puntero al comando "cls".
    lea     rcx, [rel cls_cmd]      ; RCX = &"cls" (arg1 para system)
    call    system                  ; Ejecuta: system("cls")

    ; Imprimir titulo del sistema
    ; printf recibe el puntero al string en RCX (1er argumento).
    lea     rcx, [rel titulo]       ; RCX = &titulo
    call    printf                  ; Muestra el encabezado

    ; Imprimir el menu de opciones
    lea     rcx, [rel opciones]     ; RCX = &opciones
    call    printf                  ; Muestra las 5 opciones

    ; Leer la opcion del usuario con scanf.
    ; INTERACCION CON EL ENTORNO: scanf lee de stdin (consola).
    ; FastCall: RCX = &fmt_input ("%d"), RDX = &opcion (buffer).
    lea     rcx, [rel fmt_input]    ; RCX = formato "%d"
    lea     rdx, [rel opcion]       ; RDX = puntero al buffer de entrada
    call    scanf                   ; Lee entero -> [opcion]

    ; Cargar la opcion leida en EAX para las comparaciones.
    ; En x64, mov eax, [mem] zero-extiende a RAX automaticamente.
    mov     eax, [rel opcion]       ; EAX = valor elegido por el usuario

    ; ----------------------------------------------------------
    ; ESTRUCTURAS DE CONTROL Y BIFURCACIONES
    ; Cada CMP compara EAX con el numero de opcion.
    ; JE bifurca si ZF=1 (EAX == inmediato), es decir si
    ; el usuario eligio esa opcion especifica.
    ; ----------------------------------------------------------
    cmp     eax, 1                  ; Comparar con opcion 1 (Diagnosticar)
    je      .op1                    ; Salto si EAX == 1

    cmp     eax, 2                  ; Comparar con opcion 2 (Monitoreo)
    je      .op2                    ; Salto si EAX == 2

    cmp     eax, 3                  ; Comparar con opcion 3 (Analizar)
    je      .op3                    ; Salto si EAX == 3

    cmp     eax, 4                  ; Comparar con opcion 4 (Estadisticas)
    je      .op4                    ; Salto si EAX == 4

    cmp     eax, 5                  ; Comparar con opcion 5 (Salir)
    je      .op5                    ; Salto si EAX == 5

    ; Opcion no reconocida: mostrar mensaje de error y reiniciar
    lea     rcx, [rel msg_inv]      ; RCX = &mensaje_invalido
    call    printf                  ; Muestra "Opcion invalida..."
    jmp     .bucle                  ; Salto incondicional al inicio del bucle

; ==============================================================
; MANEJADORES DE OPCIONES
; ==============================================================

.op1:   ; --- Opcion 1: Diagnosticar este equipo ---
    ; Llama a modulo2_diagnosticar() definida en modulo2.c.
    ; Esta funcion tambien invoca calcular_puntaje_fpu (x87).
    ; FastCall: no hay argumentos, funcion no los requiere.
    call    modulo2_diagnosticar    ; Diagnostico + guardado .rep + FPU
    call    pausar                  ; Esperar ENTER del usuario
    jmp     .bucle                  ; Volver al menu principal

.op2:   ; --- Opcion 2: Monitoreo en tiempo real ---
    ; Lanza bin\monitor_gui.exe (GUI FASM/RadASM) via CreateProcess.
    ; Espera con WaitForSingleObject hasta que el usuario lo cierre.
    call    monitoreo_local         ; monitor_ui.c: lanza y espera GUI
    jmp     .bucle                  ; Al cerrar la ventana, volver al menu

.op3:   ; --- Opcion 3: Analizar reportes ---
    call    modulo5_analizar        ; analyzer.c: lee y muestra .rep
    call    pausar                  ; Esperar ENTER
    jmp     .bucle

.op4:   ; --- Opcion 4: Estadisticas globales ---
    call    modulo5_estadisticas    ; analyzer.c: estadisticas por categoria
    call    pausar
    jmp     .bucle

.op5:   ; --- Opcion 5: Salir ---
    lea     rcx, [rel msg_salir]    ; RCX = &mensaje_despedida
    call    printf                  ; Muestra "Cerrando TechScan64..."
    xor     eax, eax                ; EAX = 0 (codigo de exito del programa)

    ; ----------------------------------------------------------
    ; RESTAURACION DEL MARCO DE LA PILA
    ; add rsp, 32: libera el Shadow Space reservado en el prologo.
    ; pop rbp: restaura el puntero de marco del llamador (CRT).
    ; ret: transfiere control al CRT con EAX=0 (exito).
    ; ----------------------------------------------------------
    add     rsp, 32                 ; Libera Shadow Space
    pop     rbp                     ; Restaura puntero de marco anterior
    ret                             ; Retorna al CRT con codigo 0 (OK)

; ==============================================================
; pausar - Muestra mensaje y espera que el usuario presione ENTER
; --------------------------------------------------------------
; Funcion de ayuda sin argumentos. Usa su propio Stack Frame.
; Consume el salto de linea pendiente en stdin con un scanf
; previo, luego muestra el mensaje y espera confirmacion.
; ==============================================================
pausar:
    ; ----------------------------------------------------------
    ; CONTROL DEL MARCO DE LA PILA (Stack Frame)
    ; Mismo patron que main: push rbp + sub rsp, 32
    ; ----------------------------------------------------------
    push    rbp                     ; Salva puntero de marco
    mov     rbp, rsp                ; Nuevo marco
    sub     rsp, 32                 ; Shadow Space para llamadas internas

    ; Consumir el '\n' que quedo en el buffer de stdin tras scanf
    ; "%c" con &buffer_dummy lee un solo caracter (el '\n').
    lea     rcx, [rel fmt_dummy]    ; RCX = "%c"
    lea     rdx, [rel buffer_dummy] ; RDX = &buffer_dummy
    call    scanf                   ; Lee y descarta el '\n'

    ; Mostrar el mensaje "Presione ENTER para continuar..."
    lea     rcx, [rel msg_continuar] ; RCX = &mensaje
    call    printf

    ; Leer ENTER del usuario (bloquea hasta que presione Enter)
    lea     rcx, [rel fmt_dummy]    ; RCX = "%c"
    lea     rdx, [rel buffer_dummy] ; RDX = &buffer_dummy
    call    scanf                   ; Espera el ENTER del usuario

    ; ----------------------------------------------------------
    ; RESTAURACION DEL MARCO
    ; ----------------------------------------------------------
    add     rsp, 32                 ; Libera Shadow Space
    pop     rbp                     ; Restaura puntero de marco
    ret                             ; Retorna al llamador
