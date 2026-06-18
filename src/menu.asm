; ==========================================
; TECHSCAN64 - Modulo 1: Menu Principal
; Colores ANSI + recuadro con graficos ASCII
; ==========================================

global main
extern printf
extern scanf
extern system
extern GetStdHandle
extern SetConsoleMode
extern monitoreo_local
extern modulo2_diagnosticar
extern modulo5_analizar
extern modulo5_estadisticas

STD_OUTPUT_HANDLE       equ -11
ENABLE_PROCESSED_OUTPUT equ 0x01
ENABLE_VIRTUAL_TERMINAL equ 0x04

section .data

    cls_cmd  db "cls", 0
    chcp_cmd db "chcp 65001 > nul", 0
    fmt_input db " %d", 0
    fmt_dummy db "%c", 0

    ; ── Recuadro (48 chars visibles, 46 de interior) ─────────────
    ; Linea superior:  ╔ + 46x═ + ╗
    ln_top  db 27,"[96m╔══════════════════════════════════════════════╗",27,"[0m",10,0
    ; Linea de separacion: ╠ + 46x═ + ╣
    ln_mid  db 27,"[96m╠══════════════════════════════════════════════╣",27,"[0m",10,0
    ; Linea inferior: ╚ + 46x═ + ╝
    ln_bot  db 27,"[96m╚══════════════════════════════════════════════╝",27,"[0m",10,0
    ; Linea vacia: ║ + 46 espacios + ║
    ln_void db 27,"[96m║                                              ║",27,"[0m",10,0

    ; ║ + 13 esp + "T E C H S C A N  6 4" (20) + 13 esp + ║ = 48
    ln_title db 27,"[96m║",27,"[1;97m             T E C H S C A N  6 4             ",27,"[0m",27,"[96m║",27,"[0m",10,0

    ; ║ + 6 esp + "Sistema de Diagnostico de Equipos" (33) + 7 esp + ║ = 48
    ln_sub   db 27,"[96m║",27,"[2;37m      Sistema de Diagnostico de Equipos       ",27,"[0m",27,"[96m║",27,"[0m",10,0

    ; Formato opciones: ║ + "  " + "[ N ]" + texto+padding (39) + ║ = 48
    ; "Diagnosticar este equipo" (24) + 13 esp + 2 esp prefijo = 39
    ln_op1  db 27,"[96m║",27,"[0m  ",27,"[93m[ 1 ]",27,"[97m  Diagnosticar este equipo             ",27,"[96m║",27,"[0m",10,0
    ; "Monitorear en tiempo real" (25) + 12 esp = 39
    ln_op2  db 27,"[96m║",27,"[0m  ",27,"[93m[ 2 ]",27,"[97m  Monitorear en tiempo real            ",27,"[96m║",27,"[0m",10,0
    ; "Analizar reportes del USB" (25) + 12 esp = 39
    ln_op3  db 27,"[96m║",27,"[0m  ",27,"[93m[ 3 ]",27,"[97m  Analizar reportes del USB            ",27,"[96m║",27,"[0m",10,0
    ; "Estadisticas globales" (21) + 16 esp = 39 (con 2 de prefijo)
    ln_op4  db 27,"[96m║",27,"[0m  ",27,"[93m[ 4 ]",27,"[97m  Estadisticas globales                 ",27,"[96m║",27,"[0m",10,0
    ; "Salir" (5) + 32 esp = 39 (con 2 de prefijo)
    ln_op5  db 27,"[96m║",27,"[0m  ",27,"[91m[ 5 ]",27,"[2;37m  Salir                                 ",27,"[96m║",27,"[0m",10,0

    ln_prompt  db 10,27,"[93m  >> Seleccione una opcion: ",27,"[97m",0

    msg_inv    db 10,27,"[91m  [!] Opcion invalida. Intente de nuevo.",27,"[0m",10,0
    msg_salir  db 10,27,"[92m  Hasta luego. TechScan64 cerrado.",27,"[0m",10,0
    msg_cont   db 10,27,"[2;37m  Presione ENTER para volver al menu...",27,"[0m",0

    msg_carga1 db 10,27,"[92m  >> Iniciando diagnostico...",27,"[0m",10,10,0
    msg_carga2 db 10,27,"[92m  >> Iniciando monitoreo en tiempo real...",27,"[0m",10,10,0
    msg_carga3 db 10,27,"[92m  >> Cargando analizador de reportes...",27,"[0m",10,10,0
    msg_carga4 db 10,27,"[92m  >> Cargando estadisticas globales...",27,"[0m",10,10,0

section .bss
    opcion       resd 1
    buffer_dummy resb 8
    hConsole     resq 1

section .text

; ──────────────────────────────────────────────
; habilitar_ansi: activa ESC sequences en CMD
; ──────────────────────────────────────────────
habilitar_ansi:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    mov  ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  [rel hConsole], rax

    mov  rcx, rax
    mov  edx, ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL
    call SetConsoleMode

    add  rsp, 32
    pop  rbp
    ret

; ──────────────────────────────────────────────
; dibujar_menu: imprime el recuadro completo
; ──────────────────────────────────────────────
dibujar_menu:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    lea  rcx, [rel ln_top]
    call printf
    lea  rcx, [rel ln_void]
    call printf
    lea  rcx, [rel ln_title]
    call printf
    lea  rcx, [rel ln_sub]
    call printf
    lea  rcx, [rel ln_void]
    call printf
    lea  rcx, [rel ln_mid]
    call printf
    lea  rcx, [rel ln_void]
    call printf
    lea  rcx, [rel ln_op1]
    call printf
    lea  rcx, [rel ln_op2]
    call printf
    lea  rcx, [rel ln_op3]
    call printf
    lea  rcx, [rel ln_op4]
    call printf
    lea  rcx, [rel ln_op5]
    call printf
    lea  rcx, [rel ln_void]
    call printf
    lea  rcx, [rel ln_bot]
    call printf
    lea  rcx, [rel ln_prompt]
    call printf

    add  rsp, 32
    pop  rbp
    ret

; ──────────────────────────────────────────────
; pausar: consume \n pendiente y espera ENTER
; ──────────────────────────────────────────────
pausar:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    lea  rcx, [rel fmt_dummy]
    lea  rdx, [rel buffer_dummy]
    call scanf

    lea  rcx, [rel msg_cont]
    call printf

    lea  rcx, [rel fmt_dummy]
    lea  rdx, [rel buffer_dummy]
    call scanf

    add  rsp, 32
    pop  rbp
    ret

; ──────────────────────────────────────────────
; main
; ──────────────────────────────────────────────
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    lea  rcx, [rel chcp_cmd]
    call system

    call habilitar_ansi

.bucle:
    lea  rcx, [rel cls_cmd]
    call system

    call dibujar_menu

    lea  rcx, [rel fmt_input]
    lea  rdx, [rel opcion]
    call scanf

    mov  eax, [rel opcion]

    cmp  eax, 1
    je   .op1
    cmp  eax, 2
    je   .op2
    cmp  eax, 3
    je   .op3
    cmp  eax, 4
    je   .op4
    cmp  eax, 5
    je   .op5

    lea  rcx, [rel msg_inv]
    call printf
    call pausar
    jmp  .bucle

.op1:
    lea  rcx, [rel cls_cmd]
    call system
    lea  rcx, [rel msg_carga1]
    call printf
    call modulo2_diagnosticar
    call pausar
    jmp  .bucle

.op2:
    lea  rcx, [rel cls_cmd]
    call system
    lea  rcx, [rel msg_carga2]
    call printf
    call monitoreo_local
    jmp  .bucle

.op3:
    lea  rcx, [rel cls_cmd]
    call system
    lea  rcx, [rel msg_carga3]
    call printf
    call modulo5_analizar
    call pausar
    jmp  .bucle

.op4:
    lea  rcx, [rel cls_cmd]
    call system
    lea  rcx, [rel msg_carga4]
    call printf
    call modulo5_estadisticas
    call pausar
    jmp  .bucle

.op5:
    lea  rcx, [rel cls_cmd]
    call system
    lea  rcx, [rel msg_salir]
    call printf

    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
