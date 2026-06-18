; ==========================================
; TECHSCAN64 - Modulo 4: Monitoreo Local
; Monitoreo estable de RAM, disco, hora y barras ASCII
; ==========================================

global monitoreo_local

extern printf
extern system
extern Sleep
extern GlobalMemoryStatusEx
extern GetDiskFreeSpaceExA
extern time
extern localtime
extern strftime

section .data
    cls_cmd     db "cls", 0

    titulo      db "==========================================", 10
                db "   TECHSCAN64 - MONITOREO EN TIEMPO REAL  ", 10
                db "==========================================", 10, 0

    lbl_ram     db "RAM en uso:    [", 0
    lbl_disco   db "Disco en uso:  [", 0
    lbl_cierre  db "] ", 0

    fmt_ram     db "RAM Total: %llu MB  |  RAM Libre: %llu MB  |  En uso: %llu%%", 10, 0
    fmt_disco   db "Disco Total: %llu MB |  Disco Libre: %llu MB |  En uso: %llu%%", 10, 0
    fmt_tiempo  db "Ultima actualizacion: %s", 10, 0
    fmt_cierre  db "] %llu%%", 10, 0

    msg_alerta  db "*** ALERTA: RAM libre menor al 15%% ***", 10, 0
    msg_salir   db "Presione Ctrl+C para salir del monitoreo.", 10, 0
    separador   db "==========================================", 10, 0

    ruta_disco  db "C:\", 0
    fmt_tstamp  db "%Y-%m-%d %H:%M:%S", 0

section .bss
    mem_status      resb 64
    disco_libre_q   resq 1
    disco_total_q   resq 1
    tiempo_actual   resq 1
    buffer_tiempo   resb 32
    bar_buffer      resb 21

    ram_total_q     resq 1
    ram_libre_q     resq 1
    ram_pct_q       resq 1
    disco_pct_q     resq 1

section .text

; ---------------------------------------------------------
; calcular_porcentaje
; rcx = total
; rdx = libre
; retorna rax = porcentaje usado (0..100)
; ---------------------------------------------------------
calcular_porcentaje:
    push rbx

    test rcx, rcx
    jz .zero

    cmp rdx, rcx
    jae .zero

    mov rax, rcx
    sub rax, rdx          ; usado
    mov rbx, 100
    mul rbx               ; RDX:RAX = usado * 100
    div rcx               ; / total

    pop rbx
    ret

.zero:
    xor eax, eax
    pop rbx
    ret

; ---------------------------------------------------------
; construir_barra
; ecx = porcentaje (0..100)
; rdx = buffer destino (debe tener 21 bytes)
; llena 20 caracteres con # y -
; ---------------------------------------------------------
construir_barra:
    push rbx

    mov r9, rdx           ; destino
    mov eax, ecx
    imul rax, 20
    xor rdx, rdx
    mov rbx, 100
    div rbx               ; rax = bloques llenos

    xor r8d, r8d
.loop:
    cmp r8, 20
    jge .fin

    cmp r8, rax
    jb .lleno

    mov byte [r9 + r8], '-'
    jmp .sig

.lleno:
    mov byte [r9 + r8], '#'

.sig:
    inc r8
    jmp .loop

.fin:
    mov byte [r9 + 20], 0
    pop rbx
    ret

; ---------------------------------------------------------
; monitoreo_local
; ---------------------------------------------------------
monitoreo_local:
    sub rsp, 40            ; shadow space + alineacion

.bucle_monitor:
    ; Limpiar pantalla
    lea rcx, [rel cls_cmd]
    call system

    ; Titulo
    lea rcx, [rel titulo]
    call printf

    ; Hora actual
    lea rcx, [rel tiempo_actual]
    call time

    lea rcx, [rel tiempo_actual]
    call localtime

    lea rcx, [rel buffer_tiempo]
    mov edx, 32
    lea r8, [rel fmt_tstamp]
    mov r9, rax
    call strftime

    lea rcx, [rel fmt_tiempo]
    lea rdx, [rel buffer_tiempo]
    call printf

    ; ---------------- RAM ----------------
    mov dword [rel mem_status], 64
    lea rcx, [rel mem_status]
    call GlobalMemoryStatusEx
    test eax, eax
    jz .skip_ram

    mov rax, [rel mem_status + 8]     ; total bytes
    mov rdx, [rel mem_status + 16]    ; libre bytes
    shr rax, 20
    shr rdx, 20

    mov [rel ram_total_q], rax
    mov [rel ram_libre_q], rdx

    mov rcx, [rel ram_total_q]
    mov rdx, [rel ram_libre_q]
    call calcular_porcentaje
    mov [rel ram_pct_q], rax

    lea rcx, [rel fmt_ram]
    mov rdx, [rel ram_total_q]
    mov r8,  [rel ram_libre_q]
    mov r9,  [rel ram_pct_q]
    call printf

    lea rcx, [rel lbl_ram]
    call printf

    mov ecx, dword [rel ram_pct_q]
    lea rdx, [rel bar_buffer]
    call construir_barra

    lea rcx, [rel bar_buffer]
    call printf

    lea rcx, [rel fmt_cierre]
    mov rdx, [rel ram_pct_q]
    call printf

    cmp qword [rel ram_pct_q], 85
    jl .sin_alerta_ram
    lea rcx, [rel msg_alerta]
    call printf
.sin_alerta_ram:

.skip_ram:
    ; ---------------- DISCO ----------------
    lea rcx, [rel ruta_disco]
    lea rdx, [rel disco_libre_q]
    lea r8,  [rel disco_total_q]
    xor r9, r9
    call GetDiskFreeSpaceExA
    test eax, eax
    jz .skip_disk

    mov rax, [rel disco_total_q]
    mov rdx, [rel disco_libre_q]
    shr rax, 20
    shr rdx, 20

    mov [rel disco_total_q], rax
    mov [rel disco_libre_q], rdx

    mov rcx, [rel disco_total_q]
    mov rdx, [rel disco_libre_q]
    call calcular_porcentaje
    mov [rel disco_pct_q], rax

    lea rcx, [rel fmt_disco]
    mov rdx, [rel disco_total_q]
    mov r8,  [rel disco_libre_q]
    mov r9,  [rel disco_pct_q]
    call printf

    lea rcx, [rel lbl_disco]
    call printf

    mov ecx, dword [rel disco_pct_q]
    lea rdx, [rel bar_buffer]
    call construir_barra

    lea rcx, [rel bar_buffer]
    call printf

    lea rcx, [rel fmt_cierre]
    mov rdx, [rel disco_pct_q]
    call printf

.skip_disk:
    lea rcx, [rel separador]
    call printf

    lea rcx, [rel msg_salir]
    call printf

    mov rcx, 3000
    call Sleep

    jmp .bucle_monitor

    add rsp, 40
    ret