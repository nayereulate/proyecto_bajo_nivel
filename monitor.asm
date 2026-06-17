; ==========================================
; TECHSCAN64 - Modulo 4: Monitoreo Local
; Autor: Integrante 4
; Compilar: ver build.bat
; ==========================================

global monitoreo_local
extern printf
extern system
extern Sleep

section .data
    cls_cmd     db "cls", 0

    titulo      db "==========================================", 10
                db "   TECHSCAN64 - MONITOREO EN TIEMPO REAL ", 10
                db "==========================================", 10, 0

    lbl_ram     db "RAM en uso:    [", 0
    lbl_disco   db "Disco libre:   [", 0
    lbl_cpu     db "CPU (carga):   [", 0
    lbl_cierre  db "]", 10, 0

    fmt_ram     db "RAM Total: %llu MB  |  RAM Libre: %llu MB  |  En uso: %.1f%%", 10, 0
    fmt_disco   db "Disco Libre: %llu MB", 10, 0
    fmt_proc    db "Procesos activos: %u", 10, 0
    fmt_tiempo  db "Ultima actualizacion: %s", 10, 0

    msg_alerta  db "*** ALERTA: RAM libre menor al 15%% ***", 10, 0
    msg_salir   db "Presione Ctrl+C para salir del monitoreo.", 10, 0
    separador   db "==========================================", 10, 0

    bloque_on   db 0xE2, 0x96, 0x88, 0     ; bloque lleno
    bloque_off  db 0xE2, 0x96, 0x91, 0     ; bloque vacio

    fmt_tiempo2 db "%Y-%m-%d %H:%M:%S", 0

section .bss
    mem_status  resb 64        ; MEMORYSTATUSEX
    disk_free   resq 1
    disk_total  resq 1
    proc_count  resd 1
    timestamp   resb 32
    uso_ram_pct resq 1         ; double
    barra_buf   resb 24        ; buffer para barra ASCII

section .text

; ==========================================
; Dibuja barra ASCII de 20 bloques
; rcx = porcentaje (0-100) como entero
; ==========================================
dibujar_barra PROC
    push rbx
    push r12
    push r13

    mov  r12, rcx          ; guarda el porcentaje
    mov  r13, 20           ; total de bloques

    ; calcular bloques llenos = pct * 20 / 100
    imul r12, 20
    mov  rax, r12
    mov  rbx, 100
    xor  rdx, rdx
    div  rbx
    mov  r12, rax          ; r12 = bloques llenos

    ; imprimir bloques llenos
    xor  rbx, rbx
.llenos:
    cmp  rbx, r12
    jge  .vacios
    lea  rcx, [rel bloque_on]
    call printf
    inc  rbx
    jmp  .llenos

.vacios:
    ; imprimir bloques vacios
    mov  rbx, r12
.loop_vacios:
    cmp  rbx, 20
    jge  .fin_barra
    lea  rcx, [rel bloque_off]
    call printf
    inc  rbx
    jmp  .loop_vacios

.fin_barra:
    pop r13
    pop r12
    pop rbx
    ret
dibujar_barra ENDP

; ==========================================
; Monitoreo principal
; ==========================================
monitoreo_local PROC
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

.bucle_monitor:
    ; Limpiar pantalla
    lea  rcx, [rel cls_cmd]
    call system

    ; Titulo
    lea  rcx, [rel titulo]
    call printf

    ; --- Obtener RAM ---
    ; MEMORYSTATUSEX requiere dwLength = 64
    mov  dword [rel mem_status], 64
    lea  rcx, [rel mem_status]
    call GlobalMemoryStatusEx

    ; ram_total = mem_status+8, ram_libre = mem_status+16
    mov  rax, [rel mem_status + 8]
    mov  rbx, [rel mem_status + 16]

    ; convertir a MB
    shr  rax, 20
    shr  rbx, 20

    ; calcular porcentaje usado = (total-libre)*100/total
    push rax
    push rbx
    sub  rax, rbx          ; usado = total - libre
    imul rax, 100
    mov  rcx, [rsp+8]      ; total
    xor  rdx, rdx
    div  rcx               ; rax = porcentaje
    pop  rbx
    pop  rcx               ; rcx=total, rbx=libre

    ; imprimir RAM
    push rax               ; guarda porcentaje
    lea  rcx, [rel fmt_ram]
    mov  rdx, [rsp+8]      ; total
    ; (simplificado: mostramos total y libre)
    call printf
    pop  rax               ; recupera porcentaje

    ; barra RAM
    lea  rcx, [rel lbl_ram]
    call printf
    mov  rcx, rax
    call dibujar_barra
    lea  rcx, [rel lbl_cierre]
    call printf

    ; alerta si RAM libre < 15%
    cmp  rax, 85           ; usado > 85% = libre < 15%
    jl   .sin_alerta
    lea  rcx, [rel msg_alerta]
    call printf

.sin_alerta:
    ; separador
    lea  rcx, [rel separador]
    call printf

    ; mensaje salir
    lea  rcx, [rel msg_salir]
    call printf

    ; esperar 3 segundos
    mov  rcx, 3000
    call Sleep

    jmp  .bucle_monitor

    add  rsp, 64
    pop  rbp
    ret
monitoreo_local ENDP

EXTERN GlobalMemoryStatusEx:PROC
EXTERN Sleep:PROC