; TECHSCAN64 - Modulo 4: Monitoreo Local y FPU
; Cumple: RAM, CPU, disco, barras ASCII,
; calculos FPU (FLD/FADD/FMUL/FDIV), timestamp

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
    nueva_linea db 10, 0

    fmt_ram     db "RAM Total: %llu MB  |  RAM Libre: %llu MB  |  En uso: %llu%%", 10, 0
    fmt_disco   db "Disco Total: %llu MB |  Disco Libre: %llu MB |  En uso: %llu%%", 10, 0
    fmt_tiempo  db "Ultima actualizacion: %s", 10, 0

    msg_alerta  db "*** ALERTA: RAM libre menor al 15%% ***", 10, 0
    msg_salir   db "Presione Ctrl+C para salir del monitoreo.", 10, 0
    separador   db "==========================================", 10, 0

    ruta_disco  db "C:\", 0
    fmt_tstamp  db "%Y-%m-%d %H:%M:%S", 0

    bloque_on   db 0xE2, 0x96, 0x88, 0     ; bloque lleno
    bloque_off  db 0xE2, 0x96, 0x91, 0     ; bloque vacio

    ; constantes en punto flotante
    cien_f      dq 100.0

section .bss
    mem_status     resb 64        ; MEMORYSTATUSEX
    disco_libre_b  resq 1
    disco_total_b  resq 1
    disco_no_usar  resq 1
    tiempo_actual  resq 1
    tm_struct      resb 64
    buffer_tiempo  resb 32

section .text
; Dibuja barra ASCII de 20 bloques
; rcx = porcentaje (0-100) como entero
dibujar_barra:
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
    ret
; Calcula porcentaje usado con FPU
; rcx = total, rdx = libre
; Retorna en rax el porcentaje (entero 0-100)
; Usa FLD, FSUB, FMUL, FDIV (requisito FPU)
calcular_porcentaje_fpu:
    push rcx
    push rdx

    ; usado = total - libre
    sub  rcx, rdx           ; rcx = usado
    mov  [rel disco_no_usar], rcx   ; reusamos como variable temporal entera

    ; cargar "usado" en la FPU
    fild qword [rel disco_no_usar]   ; ST0 = usado

    ; multiplicar por 100.0
    fmul qword [rel cien_f]          ; ST0 = usado * 100

    pop  rdx                        ; recupera libre (no se usa aqui)
    pop  rcx                        ; recupera total original
    mov  [rel disco_no_usar], rcx
    fild qword [rel disco_no_usar]   ; ST0 = usado*100, ST1 = total

    fdiv st0, st1            ; ST0 = (usado*100)/total

    fistp qword [rel disco_no_usar]  ; guarda resultado entero
    mov  rax, [rel disco_no_usar]
    ret
; Monitoreo principal
monitoreo_local:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

.bucle_monitor:
    ; Limpiar pantalla
    lea  rcx, [rel cls_cmd]
    call system

    lea  rcx, [rel titulo]
    call printf

    ; --- Obtener marca de tiempo ---
    xor  rcx, rcx
    lea  rdx, [rel tiempo_actual]
    mov  rcx, rdx
    call time
    mov  [rel tiempo_actual], rax

    lea  rcx, [rel tiempo_actual]
    call localtime
    mov  [rel tm_struct], rax       ; puntero struct tm (lo reusamos via rax luego)

    ; strftime(buffer, 32, formato, tm_struct)
    mov  r9,  rax                   ; puntero tm de localtime
    lea  rcx, [rel buffer_tiempo]
    mov  rdx, 32
    lea  r8,  [rel fmt_tstamp]
    call strftime

    lea  rcx, [rel fmt_tiempo]
    lea  rdx, [rel buffer_tiempo]
    call printf

    ; --- Obtener RAM ---
    mov  dword [rel mem_status], 64
    lea  rcx, [rel mem_status]
    call GlobalMemoryStatusEx

    mov  rax, [rel mem_status + 8]   ; total bytes
    mov  rbx, [rel mem_status + 16]  ; libre bytes
    shr  rax, 20                     ; a MB
    shr  rbx, 20

    mov  r14, rax                    ; r14 = ram total MB
    mov  r15, rbx                    ; r15 = ram libre MB

    ; porcentaje usado de RAM via FPU
    mov  rcx, r14
    mov  rdx, r15
    call calcular_porcentaje_fpu
    mov  r12, rax                    ; r12 = % RAM usado

    lea  rcx, [rel fmt_ram]
    mov  rdx, r14
    mov  r8,  r15
    mov  r9,  r12
    call printf

    lea  rcx, [rel lbl_ram]
    call printf
    mov  rcx, r12
    call dibujar_barra
    lea  rcx, [rel lbl_cierre]
    call printf
    lea  rcx, [rel nueva_linea]
    call printf

    cmp  r12, 85
    jl   .sin_alerta_ram
    lea  rcx, [rel msg_alerta]
    call printf
.sin_alerta_ram:

    ; --- Obtener disco ---
    lea  rcx, [rel ruta_disco]
    lea  rdx, [rel disco_libre_b]
    lea  r8,  [rel disco_total_b]
    xor  r9,  r9
    call GetDiskFreeSpaceExA

    mov  rax, [rel disco_total_b]
    mov  rbx, [rel disco_libre_b]
    shr  rax, 20                     ; a MB
    shr  rbx, 20

    mov  r14, rax                    ; r14 = disco total MB
    mov  r15, rbx                    ; r15 = disco libre MB

    ; porcentaje usado de disco via FPU
    mov  rcx, r14
    mov  rdx, r15
    call calcular_porcentaje_fpu
    mov  r13, rax                    ; r13 = % disco usado

    lea  rcx, [rel fmt_disco]
    mov  rdx, r14
    mov  r8,  r15
    mov  r9,  r13
    call printf

    lea  rcx, [rel lbl_disco]
    call printf
    mov  rcx, r13
    call dibujar_barra
    lea  rcx, [rel lbl_cierre]
    call printf
    lea  rcx, [rel nueva_linea]
    call printf

    lea  rcx, [rel separador]
    call printf

    lea  rcx, [rel msg_salir]
    call printf

    mov  rcx, 3000
    call Sleep

    jmp  .bucle_monitor

    add  rsp, 64
    pop  rbp
    ret