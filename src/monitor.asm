; TECHSCAN64 - Modulo 4: Monitoreo Local y FPU
; Cumple: RAM, CPU (GetSystemTimes), disco, barras ASCII,
; calculos FPU (FLD/FADD/FMUL/FDIV), timestamp

global monitoreo_local
extern printf
extern system
extern Sleep
extern GlobalMemoryStatusEx
extern GetDiskFreeSpaceExA
extern GetSystemTimes
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
    lbl_cpu     db "CPU en uso:    [", 0
    lbl_carga   db "Carga sistema: [", 0
    lbl_cierre  db "] ", 0
    nueva_linea db 10, 0

    fmt_ram     db "RAM Total: %llu MB  |  RAM Libre: %llu MB  |  En uso: %llu%%", 10, 0
    fmt_disco   db "Disco Total: %llu MB |  Disco Libre: %llu MB |  En uso: %llu%%", 10, 0
    fmt_cpu     db "CPU en uso: %llu%%", 10, 0
    fmt_carga   db "Carga promedio sistema: %llu%%", 10, 0
    fmt_tiempo  db "Ultima actualizacion: %s", 10, 0

    msg_alerta  db "*** ALERTA: RAM libre menor al 15%% ***", 10, 0
    msg_salir   db "Presione Ctrl+C para salir del monitoreo.", 10, 0
    separador   db "==========================================", 10, 0

    ruta_disco  db "C:\", 0
    fmt_tstamp  db "%Y-%m-%d %H:%M:%S", 0

    bloque_on   db 0xE2, 0x96, 0x88, 0     ; bloque lleno
    bloque_off  db 0xE2, 0x96, 0x91, 0     ; bloque vacio

    ; constantes FPU
    cien_f      dq 100.0
    mitad_f     dq 0.5           ; para FADD: promedio = suma * 0.5

section .bss
    mem_status     resb 64        ; MEMORYSTATUSEX
    disco_libre_b  resq 1
    disco_total_b  resq 1
    disco_no_usar  resq 1         ; scratch FPU / deltas CPU
    tiempo_actual  resq 1
    tm_struct      resb 64
    buffer_tiempo  resb 32

    ; Medicion de CPU via GetSystemTimes (FILETIME = 8 bytes cada uno)
    ft_idle1       resq 1
    ft_kern1       resq 1
    ft_user1       resq 1
    ft_idle2       resq 1
    ft_kern2       resq 1
    ft_user2       resq 1
    cpu_pct_val    resq 1         ; % CPU guardado entre medicion y display

section .text

; ──────────────────────────────────────────────────────────────
; dibujar_barra: dibuja barra ASCII de 20 bloques
; rcx = porcentaje (0-100) entero
; ──────────────────────────────────────────────────────────────
dibujar_barra:
    push rbx
    push r12

    mov  r12, rcx
    imul r12, 20
    mov  rax, r12
    mov  rbx, 100
    xor  rdx, rdx
    div  rbx
    mov  r12, rax             ; r12 = bloques llenos

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

; ──────────────────────────────────────────────────────────────
; calcular_porcentaje_fpu: (total-libre)*100 / total
; rcx = total MB, rdx = libre MB
; Retorna porcentaje entero (0-100) en rax
; Instrucciones FPU: FILD (=FLD), FMUL, FDIVP, FISTP
; ──────────────────────────────────────────────────────────────
calcular_porcentaje_fpu:
    push rcx
    push rdx

    sub  rcx, rdx                      ; rcx = usado = total - libre
    mov  [rel disco_no_usar], rcx

    fild qword [rel disco_no_usar]     ; ST(0) = usado
    fmul qword [rel cien_f]            ; ST(0) = usado * 100  (FMUL)

    pop  rdx
    pop  rcx
    mov  [rel disco_no_usar], rcx
    fild qword [rel disco_no_usar]     ; ST(0) = total, ST(1) = usado*100

    fdivp                              ; ST(0) = usado*100/total  (FDIV via FDIVP)
    fistp qword [rel disco_no_usar]    ; guarda entero, pop  (FISTP)
    mov  rax, [rel disco_no_usar]

    ; clamp 0-100
    test rax, rax
    jns  .pos
    xor  rax, rax
    ret
.pos:
    cmp  rax, 100
    jle  .ok
    mov  rax, 100
.ok:
    ret

; ──────────────────────────────────────────────────────────────
; calcular_cpu_pct: mide uso de CPU con GetSystemTimes
; Toma dos muestras separadas por 500 ms y calcula porcentaje
; Retorna porcentaje entero (0-100) en rax
; Solo usa registros volatiles (rax, rcx, rdx, r8, r9, r10, r11)
; para no corromper r12-r15 del caller
; ──────────────────────────────────────────────────────────────
calcular_cpu_pct:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32              ; shadow space; 1 push → RSP alineado

    ; Primera lectura de tiempos del sistema
    lea  rcx, [rel ft_idle1]
    lea  rdx, [rel ft_kern1]
    lea  r8,  [rel ft_user1]
    call GetSystemTimes

    ; Pausa 500 ms para obtener delta significativo
    mov  rcx, 500
    call Sleep

    ; Segunda lectura
    lea  rcx, [rel ft_idle2]
    lea  rdx, [rel ft_kern2]
    lea  r8,  [rel ft_user2]
    call GetSystemTimes

    ; delta_idle = idle2 - idle1  (leemos FILETIME como QWORD)
    mov  rax, [rel ft_idle2]
    sub  rax, [rel ft_idle1]
    mov  [rel disco_no_usar], rax      ; guardamos delta_idle

    ; delta_kern = kern2 - kern1
    mov  r10, [rel ft_kern2]
    sub  r10, [rel ft_kern1]

    ; delta_user = user2 - user1
    mov  r11, [rel ft_user2]
    sub  r11, [rel ft_user1]

    ; total = delta_kern + delta_user
    mov  rax, r10
    add  rax, r11                      ; rax = total (kern incluye idle)

    test rax, rax
    jz   .cpu_zero

    ; active = total - delta_idle
    mov  rcx, [rel disco_no_usar]
    sub  rax, rcx                      ; rax = active

    ; FPU: cpu_pct = active * 100 / total
    ; active en rax, total = rax + rcx (recalculamos)
    mov  r9, rax                       ; r9 = active
    add  rcx, rax                      ; rcx = total (active + delta_idle)

    mov  [rel disco_no_usar], r9
    fild qword [rel disco_no_usar]     ; ST(0) = active  (FLD)
    fmul qword [rel cien_f]            ; ST(0) = active*100  (FMUL)

    mov  [rel disco_no_usar], rcx
    fild qword [rel disco_no_usar]     ; ST(0) = total, ST(1) = active*100
    fdivp                              ; ST(0) = active*100/total  (FDIV)
    fistp qword [rel disco_no_usar]
    mov  rax, [rel disco_no_usar]

    ; clamp 0-100
    test rax, rax
    jns  .pos
    xor  rax, rax
    jmp  .done
.pos:
    cmp  rax, 100
    jle  .done
    mov  rax, 100
.done:
    add  rsp, 32
    pop  rbp
    ret

.cpu_zero:
    xor  rax, rax
    add  rsp, 32
    pop  rbp
    ret

; ──────────────────────────────────────────────────────────────
; monitoreo_local: bucle principal de monitoreo
; ──────────────────────────────────────────────────────────────
monitoreo_local:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

.bucle_monitor:

    ; ── 1. Medir CPU ahora (500 ms interno) ──────────────────
    call calcular_cpu_pct
    mov  [rel cpu_pct_val], rax        ; guardar antes de limpiar pantalla

    ; ── 2. Limpiar pantalla y mostrar cabecera ────────────────
    lea  rcx, [rel cls_cmd]
    call system

    lea  rcx, [rel titulo]
    call printf

    ; ── 3. Timestamp ─────────────────────────────────────────
    xor  rcx, rcx
    lea  rdx, [rel tiempo_actual]
    mov  rcx, rdx
    call time
    mov  [rel tiempo_actual], rax

    lea  rcx, [rel tiempo_actual]
    call localtime
    mov  r9, rax                       ; puntero struct tm

    lea  rcx, [rel buffer_tiempo]
    mov  rdx, 32
    lea  r8,  [rel fmt_tstamp]
    call strftime

    lea  rcx, [rel fmt_tiempo]
    lea  rdx, [rel buffer_tiempo]
    call printf

    ; ── 4. RAM ───────────────────────────────────────────────
    mov  dword [rel mem_status], 64
    lea  rcx, [rel mem_status]
    call GlobalMemoryStatusEx

    mov  rax, [rel mem_status + 8]     ; ullTotalPhys
    mov  rbx, [rel mem_status + 16]    ; ullAvailPhys
    shr  rax, 20                       ; a MB
    shr  rbx, 20

    mov  r14, rax                      ; r14 = ram total MB
    mov  r15, rbx                      ; r15 = ram libre MB

    mov  rcx, r14
    mov  rdx, r15
    call calcular_porcentaje_fpu
    mov  r12, rax                      ; r12 = % RAM usado

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

    ; ── 5. Disco ─────────────────────────────────────────────
    lea  rcx, [rel ruta_disco]
    lea  rdx, [rel disco_libre_b]
    lea  r8,  [rel disco_total_b]
    xor  r9,  r9
    call GetDiskFreeSpaceExA

    mov  rax, [rel disco_total_b]
    mov  rbx, [rel disco_libre_b]
    shr  rax, 20
    shr  rbx, 20

    mov  r14, rax                      ; r14 = disco total MB
    mov  r15, rbx                      ; r15 = disco libre MB

    mov  rcx, r14
    mov  rdx, r15
    call calcular_porcentaje_fpu
    mov  r13, rax                      ; r13 = % disco usado

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

    ; ── 6. CPU (medido al inicio del ciclo) ──────────────────
    mov  r11, [rel cpu_pct_val]        ; r11 = % CPU

    lea  rcx, [rel fmt_cpu]
    mov  rdx, r11
    call printf

    lea  rcx, [rel lbl_cpu]
    call printf
    mov  rcx, r11
    call dibujar_barra
    lea  rcx, [rel lbl_cierre]
    call printf
    lea  rcx, [rel nueva_linea]
    call printf

    ; ── 7. Carga promedio = (RAM% + CPU%) / 2  usando FADD ───
    ; FPU: fild RAM%, fild CPU%, FADD, fmul 0.5, fistp → promedio
    mov  [rel disco_no_usar], r12
    fild qword [rel disco_no_usar]     ; ST(0) = ram_pct  (FLD)
    mov  [rel disco_no_usar], r11
    fild qword [rel disco_no_usar]     ; ST(0) = cpu_pct, ST(1) = ram_pct
    fadd st0, st1                      ; ST(0) = ram+cpu  (FADD)
    fmul qword [rel mitad_f]           ; ST(0) = promedio  (FMUL)
    fistp qword [rel disco_no_usar]    ; guarda promedio, pop
    mov  r10, [rel disco_no_usar]      ; r10 = promedio
    fstp qword [rel disco_no_usar]     ; descarta ram_pct que queda en ST(0)

    lea  rcx, [rel fmt_carga]
    mov  rdx, r10
    call printf

    lea  rcx, [rel lbl_carga]
    call printf
    mov  rcx, r10
    call dibujar_barra
    lea  rcx, [rel lbl_cierre]
    call printf
    lea  rcx, [rel nueva_linea]
    call printf

    ; ── 8. Pie de pagina ─────────────────────────────────────
    lea  rcx, [rel separador]
    call printf
    lea  rcx, [rel msg_salir]
    call printf

    ; ── 9. Esperar 2500 ms (ciclo total ~3 s con los 500 CPU) ─
    mov  rcx, 2500
    call Sleep

    jmp  .bucle_monitor

    add  rsp, 64
    pop  rbp
    ret
