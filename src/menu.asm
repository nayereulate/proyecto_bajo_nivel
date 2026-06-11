; ==========================================
; TECHSCAN64 - Modulo 1: Menu Principal
; ==========================================

global main
extern printf
extern scanf
extern system

section .data
    titulo      db "==========================================", 10
                db "         T E C H S C A N  6 4           ", 10
                db "   Sistema de Diagnostico de Equipos     ", 10
                db "==========================================", 10, 0

    opciones    db "1. Diagnosticar este equipo              ", 10
                db "2. Monitorear en tiempo real             ", 10
                db "3. Analizar reportes del USB             ", 10
                db "4. Estadisticas globales                 ", 10
                db "5. Salir                                 ", 10
                db "==========================================", 10
                db "Seleccione una opcion: ", 0

    fmt_input   db "%d", 0
    msg_inv     db "Opcion invalida. Intente de nuevo.", 10, 0
    msg_salir   db "Cerrando TechScan64. Hasta luego.", 10, 0
    msg_op1     db "[Modulo 2] Diagnosticando equipo...", 10, 0
    msg_op2     db "[Modulo 4] Iniciando monitoreo...", 10, 0
    msg_op3     db "[Modulo 5] Leyendo reportes USB...", 10, 0
    msg_op4     db "[Modulo 5] Cargando estadisticas...", 10, 0
    cls_cmd     db "cls", 0

section .bss
    opcion      resd 1

section .text

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

.bucle:
    lea  rcx, [rel cls_cmd]
    call system

    lea  rcx, [rel titulo]
    call printf

    lea  rcx, [rel opciones]
    call printf

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
    jmp  .bucle

.op1:
    lea  rcx, [rel msg_op1]
    call printf
    jmp  .bucle

.op2:
    lea  rcx, [rel msg_op2]
    call printf
    jmp  .bucle

.op3:
    lea  rcx, [rel msg_op3]
    call printf
    jmp  .bucle

.op4:
    lea  rcx, [rel msg_op4]
    call printf
    jmp  .bucle

.op5:
    lea  rcx, [rel msg_salir]
    call printf

    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret