; ==========================================
; TECHSCAN64 - Modulo 4: Monitoreo Local
; ==========================================

global monitoreo_local
extern printf
extern system
extern Sleep
extern GlobalMemoryStatusEx
extern _kbhit
extern _getch

section .data
    cls_cmd     db "cls", 0

    titulo      db "==========================================", 10
                db "   TECHSCAN64 - MONITOREO EN TIEMPO REAL ", 10
                db "==========================================", 10, 0

    lbl_ram     db "RAM en uso:    [", 0
    lbl_cierre  db "] %llu%%", 10, 0

    fmt_ram     db "RAM Total: %llu MB  |  RAM Libre: %llu MB  |  En uso: %llu%%", 10, 0

    msg_alerta  db "*** ALERTA: RAM libre menor al 15%% ***", 10, 0
    msg_salir   db "Presione Q para volver al menu.", 10, 0
    separador   db "==========================================", 10, 0

    bloque_on   db "#", 0
    bloque_off  db ".", 0

section .bss
    mem_status  resb 64

section .text

; ==========================================
; Dibuja barra ASCII de 20 bloques
; rcx = porcentaje (0-100)
; ==========================================
dibujar_barra:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32
    push rbx
    push r12

    mov  r12, rcx

    imul r12, 20
    mov  rax, r12
    mov  rbx, 100
    xor  rdx, rdx
    div  rbx
    mov  r12, rax          ; r12 = bloques llenos

    xor  rbx, rbx
.llenos:
    cmp  rbx, r12
    jge  .vacios
    lea  rcx, [rel bloque_on]
    call printf
    inc  rbx
    jmp  .llenos

.vacios:
    mov  rbx, r12
.loop_vacios:
    cmp  rbx, 20
    jge  .fin_barra
    lea  rcx, [rel bloque_off]
    call printf
    inc  rbx
    jmp  .loop_vacios

.fin_barra:
    pop r12
    pop rbx
    add rsp, 32
    pop rbp
    ret

; ==========================================
; Monitoreo principal
; ==========================================
monitoreo_local:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64
    push r12
    push r13
    push r14
    push r15

.bucle_monitor:
    ; Limpiar pantalla
    lea  rcx, [rel cls_cmd]
    call system

    ; Titulo
    lea  rcx, [rel titulo]
    call printf

    ; --- Obtener RAM ---
    mov  dword [rel mem_status], 64
    lea  rcx, [rel mem_status]
    call GlobalMemoryStatusEx

    mov  rax, [rel mem_status + 8]
    mov  rbx, [rel mem_status + 16]

    shr  rax, 20
    shr  rbx, 20

    mov  r14, rax          ; total MB
    mov  r15, rbx          ; libre MB

    mov  rax, r14
    sub  rax, r15
    imul rax, 100
    xor  rdx, rdx
    div  r14
    mov  r12, rax          ; porcentaje usado

    ; imprimir RAM
    lea  rcx, [rel fmt_ram]
    mov  rdx, r14
    mov  r8,  r15
    mov  r9,  r12
    call printf

    ; barra RAM
    lea  rcx, [rel lbl_ram]
    call printf
    mov  rcx, r12
    call dibujar_barra

    ; cerrar barra con ] y porcentaje
    lea  rcx, [rel lbl_cierre]
    mov  rdx, r12
    call printf

    ; alerta
    cmp  r12, 85
    jl   .sin_alerta
    lea  rcx, [rel msg_alerta]
    call printf

.sin_alerta:
    lea  rcx, [rel separador]
    call printf

    lea  rcx, [rel msg_salir]
    call printf

    ; esperar 3 segundos
    mov  rcx, 3000
    call Sleep

    ; verificar si presionaron Q
    call _kbhit
    test eax, eax
    jz   .bucle_monitor

    call _getch
    ; 'q' = 113, 'Q' = 81
    cmp  eax, 113
    je   .salir
    cmp  eax, 81
    je   .salir
    jmp  .bucle_monitor

.salir:
    pop r15
    pop r14
    pop r13
    pop r12
    add rsp, 64
    pop rbp
    ret