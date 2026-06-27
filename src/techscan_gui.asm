; ==============================================================
; Archivo      : src/techscan_gui.asm
; Proyecto     : TechScan64 - Interfaz Grafica Unificada
; Institucion  : U.M.S.S. - Facultad de Tecnologia
; Asignatura   : Taller de Programacion en Bajo Nivel
; Ensamblador  : FASM (Flat Assembler) via RadASM - formato PE64
; Arquitectura : Windows x86-64 (Win64 GUI, ABI Microsoft x64)
; Descripcion  :
;   Ventana Win32 unica con 4 paneles navegables:
;     * Diagnostico  - Datos del equipo + Puntaje FPU
;     * Monitoreo    - Barras en tiempo real (timer 2s)
;     * Analizar     - Listado de reportes .rep
;     * Estadisticas - Conteo por categoria de salud
;
;   Requisitos implementados:
;     #1 Arquitectura 64-bit: registros RAX,RBX,RCX,RDX,R8,R9
;     #2 FastCall Win64: proc...uses + invoke (RCX,RDX,R8,R9)
;     #3 GUI / Bucle de mensajes: WndProc, WM_CREATE/COMMAND/TIMER
;     #4 Persistencia: CreateFileA, WriteFile (.rep binario)
;     #5 FPU x87: proc fpu_puntaje (FINIT,FILD,FMUL,FADDP,FSTP)
;
; Compilar:
;   set INCLUDE=C:\Pack RadASM\fasm\INCLUDE
;   FASM.EXE src\techscan_gui.asm bin\techscan_gui.exe
; ==============================================================

format PE64 GUI 5.0
entry start

include 'win64a.inc'

; =====================================================
; DIMENSIONES Y GEOMETRIA
; =====================================================
WIN_W  = 800
WIN_H  = 640
NAV_W  = 180          ; ancho del panel de navegacion
CT_X   = NAV_W + 5    ; inicio del area de contenido
CT_W   = WIN_W - CT_X - 5
CT_Y   = 8

; =====================================================
; IDs DE CONTROLES
; Nav (101-199): siempre visibles
; Diag (301-340), Mon (351-375), Anal (381-399), Estad (401-420)
; =====================================================
IDC_NAV_TITULO = 100
IDC_NAV_DIAG   = 101
IDC_NAV_MON    = 102
IDC_NAV_ANAL   = 103
IDC_NAV_ESTAD  = 104
IDC_NAV_SALIR  = 105

; Diagnostico
IDC_D_HDR      = 301
IDC_D_LBL_PC   = 302
IDC_D_VAL_PC   = 303
IDC_D_LBL_USR  = 304
IDC_D_VAL_USR  = 305
IDC_D_LBL_CPU  = 306
IDC_D_VAL_CPU  = 307
IDC_D_LBL_RAMT = 308
IDC_D_VAL_RAMT = 309
IDC_D_LBL_RAML = 310
IDC_D_VAL_RAML = 311
IDC_D_LBL_RAMP = 312
IDC_D_VAL_RAMP = 313
IDC_D_LBL_DISC = 314
IDC_D_VAL_DISC = 315
IDC_D_LBL_OS   = 316
IDC_D_VAL_OS   = 317
IDC_D_LBL_CAT  = 318
IDC_D_VAL_CAT  = 319
IDC_D_BTN_GUAR = 320
IDC_D_LBL_GUAR = 321
IDC_D_LBL_SCORE = 323   ; Etiqueta "Puntaje FPU:"
IDC_D_VAL_SCORE = 324   ; Valor calculado por coprocesador x87
IDC_D_LBL_GPU   = 325
IDC_D_VAL_GPU   = 326
IDC_D_LBL_PLACA = 327
IDC_D_VAL_PLACA = 328
IDC_D_LBL_BIOS  = 329
IDC_D_VAL_BIOS  = 330
IDC_D_LBL_TEC   = 331
IDC_D_VAL_TEC   = 332

; Monitoreo
IDC_M_HDR_RAM  = 351
IDC_M_VAL_RAM  = 352
IDC_M_BAR_RAM  = 353
IDC_M_HDR_DIS  = 354
IDC_M_VAL_DIS  = 355
IDC_M_BAR_DIS  = 356
IDC_M_HDR_CPU  = 357
IDC_M_VAL_CPU  = 358
IDC_M_BAR_CPU  = 359
IDC_M_ESTADO   = 360
IDC_M_HIST_CPU = 362   ; grafico ASCII historial CPU
IDC_M_HIST_RAM = 363   ; grafico ASCII historial RAM
IDC_M_HIST_DSK = 364   ; grafico ASCII historial DISCO
IDC_M_HDR_GPU  = 365
IDC_M_VAL_GPU  = 366
IDC_M_HIST_GPU = 368   ; grafico ASCII historial GPU
IDC_M_HIST_CPU = 362   ; grafico ASCII historial CPU
IDC_M_HIST_RAM = 363   ; grafico ASCII historial RAM
IDC_M_HIST_DSK = 364   ; grafico ASCII historial DISCO
IDC_M_HIST_GPU = 368   ; grafico ASCII historial GPU

; Analizar
IDC_A_HDR      = 381
IDC_A_INFO     = 382
IDC_A_LIST     = 383
IDC_A_BTN_REF  = 384
; Panel detalle de reporte seleccionado
IDC_A_DET_HDR  = 385
IDC_A_DET_PC   = 386
IDC_A_DET_TS   = 387
IDC_A_DET_CAT  = 388
IDC_A_DET_RVAL = 389
IDC_A_DET_RBAR = 390
IDC_A_DET_DVAL = 391
IDC_A_DET_DBAR = 392
; Etiquetas fijas del panel detalle (DEBEN estar en rango 381-399 para ocultarse)
IDC_A_DET_LPC  = 393
IDC_A_DET_LTS  = 394
IDC_A_DET_LCAT = 395

; Estadisticas - Dashboard visual con barras y lista de equipos
IDC_E_HDR      = 401
IDC_E_TOTAL    = 402
IDC_E_CAT0     = 403   ; label EXCELENTE con conteo
IDC_E_BAR0     = 410   ; barra EXCELENTE
IDC_E_CAT1     = 404   ; label BUENO con conteo
IDC_E_BAR1     = 411   ; barra BUENO
IDC_E_CAT2     = 405   ; label REGULAR con conteo
IDC_E_BAR2     = 412   ; barra REGULAR
IDC_E_CAT3     = 406   ; label CRITICO con conteo
IDC_E_BAR3     = 413   ; barra CRITICO
IDC_E_LBL_DIS  = 416   ; subheader "DISTRIBUCION"
IDC_E_LBL_PCS  = 415   ; subheader "TODOS LOS EQUIPOS"
IDC_E_PC_LIST  = 414   ; listbox con todos los equipos

; Historial (421-460)
IDC_H_HDR      = 421
IDC_H_LBL_PCS  = 422
IDC_H_PC_LIST  = 423
IDC_H_LBL_REP  = 424
IDC_H_REP_LIST = 425
IDC_H_BTN_REF  = 426
IDC_H_STATS    = 427
IDC_H_INFO     = 428

; Nav - boton Historial
IDC_NAV_HIST   = 106

; =====================================================
; CONSTANTES
; =====================================================
ID_TIMER_MON   = 1

PBM_SETRANGE   = 0401h
PBM_SETPOS     = 0402h
PBM_SETBARCOLOR = 0409h
PBM_SETBKCOLOR  = 2001h

LB_ADDSTRING    = 0180h
LB_RESETCONTENT = 0184h
LB_GETCURSEL    = 0188h
LB_GETITEMDATA  = 0199h
LB_SETITEMDATA  = 019Ah
LBN_SELCHANGE   = 1
LB_GETTEXT      = 0189h   ; LB_GETTEXT correcto (018Bh es LB_GETCOUNT, no LB_GETTEXT)
GW_CHILD        = 5
GW_HWNDNEXT     = 2
WM_ERASEBKGND   = 0014h
WM_CTLCOLORSTATIC = 0138h
WM_CTLCOLORBTN  = 0135h
OPAQUE_MODE     = 2

; COLORREF = R + (G shl 8) + (B shl 16)
CLR_VERDE    = 0000BB00h
CLR_NARANJA  = 00007FFFh
CLR_ROJO     = 000000BBh
CLR_FONDO_PB = 00404040h

; Paleta profesional
CLR_SIDEBAR  = 002D1E14h   ; RGB(20, 30, 45)  - azul marino oscuro
CLR_NAV_TXT  = 00E8D8C8h   ; RGB(200,216,232) - blanco azulado
CLR_ACCENT   = 00C8780Ah   ; RGB(10,120,200)  - azul acento
CLR_WHITE    = 00FFFFFFh   ; Fondo contenido
CLR_DARK_TXT = 001A1A2Eh   ; RGB(46,26,26)    - azul oscuro para valores
CLR_LABEL    = 007A7A8Ah   ; RGB(138,122,122) - gris calido para etiquetas
CLR_HDRTEXT  = 00B85A00h   ; RGB(0,90,184)    - azul Windows para headers
CLR_CONTENT_BG = 00FAF9F8h ; RGB(248,249,250) - blanco-frio de fondo
WM_SETFONT   = 0030h        ; mensaje para aplicar fuente a un control
HKEY_LOCAL_MACHINE = 80000002h
RRF_RT_REG_SZ      = 00000002h

; Constantes GDI para los controles graficos personalizados
GWL_ID       = -12         ; GetWindowLong: ID del control hijo
DT_CENTER    = 0001h       ; DrawText: centrado horizontal
DT_VCENTER   = 0004h       ; DrawText: centrado vertical
DT_SINGLELINE= 0020h       ; DrawText: una sola linea
PS_SOLID     = 0           ; CreatePen: linea solida
CS_HREDRAW   = 0002h       ; WNDCLASS style: redibuja al cambiar ancho
CS_VREDRAW   = 0001h       ; WNDCLASS style: redibuja al cambiar alto
NULL_PEN     = 8           ; GetStockObject: pluma nula (sin contorno)
NULL_BRUSH   = 5           ; GetStockObject: pincel nulo (sin fondo)

; Colores del tema TechScan64 (COLORREF = R + G*256 + B*65536)
CLR_BG_GAUGE  = 00FFFFFFh  ; Fondo barra: blanco
CLR_BG_TRACK  = 00F0E8E2h  ; Pista clara RGB(226,232,240)
CLR_BAR_GREEN = 005EC522h  ; Verde vivo  RGB(34,197,94)
CLR_BAR_AMBER = 000B9EF5h  ; Ambar vivo  RGB(245,158,11)
CLR_BAR_RED   = 004444EFh  ; Rojo vivo   RGB(239,68,68)
CLR_GRAPH_BG  = 00120D17h  ; Fondo grafico: casi negro
CLR_GRAPH_CPU = 00F7C34Fh  ; Linea CPU: azul claro    RGB(79,195,247)
CLR_GRAPH_RAM = 0073D400h  ; Linea RAM: verde vivo    RGB(0,212,115)
CLR_GRAPH_DSK = 00D893CEh  ; Linea Disco: lila        RGB(206,147,216)
CLR_GRAPH_GPU = 00FFB74Dh  ; Linea GPU: naranja       RGB(255,183,77)
CLR_GRID      = 001F2328h  ; Grid sutil: casi negro
CLR_WHITE_TXT = 00FFFFFFh  ; Texto blanco
CLR_BLACK_TXT = 00000000h  ; Texto negro

; Paneles
PANEL_DIAG  = 0
PANEL_MON   = 1
PANEL_ANAL  = 2
PANEL_ESTAD = 3
PANEL_HIST  = 4

; =====================================================
; CODIGO
; =====================================================
section '.text' code readable executable

; -------------------------------------------------------
; set_bar_color  rcx=hwnd  rdx=ctrl_id  r8=pct
; -------------------------------------------------------
proc set_bar_color uses rbx rsi rdi, _hw, _id, _pct
    mov  rbx, rcx
    mov  rsi, rdx
    mov  rdi, r8
    cmp  rdi, 85
    jge  .rojo
    cmp  rdi, 60
    jge  .naranja
    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_VERDE
    ret
.naranja:
    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_NARANJA
    ret
.rojo:
    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_ROJO
    ret
endp


; -------------------------------------------------------
; show_panel  rcx = PANEL_xxx
; Itera hijos de la ventana principal por ID y
; muestra/oculta cada control segun el panel activo.
; -------------------------------------------------------
proc show_panel uses rbx rsi rdi, _panel

    ; Guardar panel objetivo en rsi (callee-saved)
    mov  rsi, rcx

    ; Detener timer si monitoreo estaba activo
    cmp  qword [cur_panel], PANEL_MON
    jne  .no_stop
    invoke  KillTimer, [main_hwnd], ID_TIMER_MON
.no_stop:
    mov  [cur_panel], rsi

    ; Iterar controles hijos de la ventana principal
    invoke  GetWindow, [main_hwnd], GW_CHILD
    test  rax, rax
    jz    .setup_panel
    mov   rbx, rax           ; rbx = hwnd del hijo actual

.iter:
    invoke  GetDlgCtrlID, rbx   ; rax = IDC del control
    ; rbx y rsi preservados por callee-convention

    ; IDC < 300: nav / siempre visible
    cmp  eax, 300
    jl   .do_show

    ; IDC 301-340: Diagnostico
    cmp  eax, 341
    jl   .chk_diag

    ; IDC 341-375: separacion, luego IDC 351-375: Monitoreo
    cmp  eax, 351
    jl   .do_hide          ; IDC 341-350: no usados, ocultar
    cmp  eax, 376
    jl   .chk_mon

    ; IDC 376-380: no usados
    cmp  eax, 381
    jl   .do_hide

    ; IDC 381-399: Analizar
    cmp  eax, 400
    jl   .chk_anal

    ; IDC 400: no usados
    cmp  eax, 401
    jl   .do_hide

    ; IDC 401-420: Estadisticas
    cmp  eax, 421
    jl   .chk_estad

    ; IDC 421-460: Historial
    cmp  eax, 461
    jl   .chk_hist
    jmp  .do_show      ; > 460: no clasificado -> mostrar

.chk_diag:
    cmp  rsi, PANEL_DIAG
    je   .do_show
    jmp  .do_hide
.chk_mon:
    cmp  rsi, PANEL_MON
    je   .do_show
    jmp  .do_hide
.chk_anal:
    cmp  rsi, PANEL_ANAL
    je   .do_show
    jmp  .do_hide
.chk_estad:
    cmp  rsi, PANEL_ESTAD
    je   .do_show
    jmp  .do_hide
.chk_hist:
    cmp  rsi, PANEL_HIST
    je   .do_show
    jmp  .do_hide

.do_show:
    invoke  ShowWindow, rbx, SW_SHOW
    jmp  .next_child
.do_hide:
    invoke  ShowWindow, rbx, SW_HIDE

.next_child:
    ; Siguiente hermano (rbx y rsi preservados)
    invoke  GetWindow, rbx, GW_HWNDNEXT
    test  rax, rax
    jz    .setup_panel
    mov   rbx, rax
    jmp   .iter

.setup_panel:
    ; Cargar datos del nuevo panel
    cmp  rsi, PANEL_DIAG
    jne  .chk_mon2
    mov  rcx, [main_hwnd]
    call update_diag
    ret

.chk_mon2:
    cmp  rsi, PANEL_MON
    jne  .chk_anal2
    ; Lectura base de CPU
    invoke  GetSystemTimes, ft_idle, ft_kern, ft_user
    mov  rax, [ft_idle]
    mov  [ft_idle_p], rax
    mov  rax, [ft_kern]
    mov  [ft_kern_p], rax
    mov  rax, [ft_user]
    mov  [ft_user_p], rax
    mov  rcx, [main_hwnd]
    call update_mon
    invoke  SetTimer, [main_hwnd], ID_TIMER_MON, 3000, NULL
    ret

.chk_anal2:
    cmp  rsi, PANEL_ANAL
    jne  .chk_estad2
    mov  rcx, [main_hwnd]
    call update_anal
    ret

.chk_estad2:
    cmp  rsi, PANEL_ESTAD
    jne  .chk_hist2
    mov  rcx, [main_hwnd]
    call update_estad
    ret

.chk_hist2:
    cmp  rsi, PANEL_HIST
    jne  .sp_done
    mov  rcx, [main_hwnd]
    call update_hist
    ret

.sp_done:
    ret
endp


; -------------------------------------------------------
; cpuid_modelo -- llena cpu_buf con la marca del CPU
; -------------------------------------------------------
cpuid_modelo:
    push rbx
    mov  eax, 80000002h; cpuid
    cpuid
    mov  dword [cpu_buf + 0],  eax
    mov  dword [cpu_buf + 4],  ebx
    mov  dword [cpu_buf + 8],  ecx
    mov  dword [cpu_buf + 12], edx
    mov  eax, 80000003h
    cpuid
    mov  dword [cpu_buf + 16], eax
    mov  dword [cpu_buf + 20], ebx
    mov  dword [cpu_buf + 24], ecx
    mov  dword [cpu_buf + 28], edx
    mov  eax, 80000004h
    cpuid
    mov  dword [cpu_buf + 32], eax
    mov  dword [cpu_buf + 36], ebx
    mov  dword [cpu_buf + 40], ecx
    mov  dword [cpu_buf + 44], edx
    mov  byte [cpu_buf + 48], 0
    pop  rbx
    ret


; ==============================================================
; fpu_puntaje  -  Modulo Analitico con Coprocesador x87
; --------------------------------------------------------------
; Calcula el Puntaje de Salud del equipo usando instrucciones
; del coprocesador matematico x87 (punto flotante real):
;
;   score = (ram_libre%  * 0.40)
;         + (disco_libre% * 0.35)
;         + (cpu_libre%  * 0.25)    donde cpu_libre = 100-cpu_usado
;
; Convencion FastCall Windows x64:
;   RCX = ram_libre_pct   (QWORD entero, 0-100)
;   RDX = disco_libre_pct (QWORD entero, 0-100)
;   R8  = cpu_pct_usado   (QWORD entero, 0-100)
; Retorna: EAX = puntaje entero (0-100)
;
; Instrucciones x87 demostradas:
;   FINIT, FILD, FMUL, FADDP, FLD, FSUBP, FSTP, FISTP
; ==============================================================
proc fpu_puntaje uses rbx, _fr, _fd, _fc

    ; ----------------------------------------------------------
    ; CONVENCION DE LLAMADAS: Salvar argumentos antes de que
    ; FINIT o cualquier invoke posterior destruya los registros.
    ; RCX, RDX, R8 son caller-saved: se pierden tras cualquier
    ; llamada. Se guardan en variables QWORD de la seccion .bss.
    ; ----------------------------------------------------------
    mov  [fpu_tmp1], rcx        ; fpu_tmp1 = ram_libre_pct
    mov  [fpu_tmp2], rdx        ; fpu_tmp2 = disco_libre_pct
    mov  [fpu_tmp3], r8         ; fpu_tmp3 = cpu_pct_usado

    ; ----------------------------------------------------------
    ; INICIALIZACION DEL COPROCESADOR MATEMATICO x87
    ; FINIT: Resetea la pila FPU (ST0-ST7), limpia los flags
    ;        de estado y establece precision extendida (80-bit).
    ; ----------------------------------------------------------
    finit

    ; ----------------------------------------------------------
    ; TERMINO 1: ram_libre_pct * 0.40
    ; FILD: Lee entero de 64 bits de memoria y lo convierte a
    ;       real de 80 bits en la cima ST(0) de la pila FPU.
    ; FMUL: Multiplica ST(0) por el double en [fpu_peso_ram]=0.40
    ; Resultado: ST(0) = termino_RAM
    ; ----------------------------------------------------------
    fild  qword [fpu_tmp1]      ; ST(0) = (double) ram_libre_pct
    fmul  qword [fpu_peso_ram]  ; ST(0) = ram_libre_pct * 0.40

    ; ----------------------------------------------------------
    ; TERMINO 2: disco_libre_pct * 0.35
    ; Pila FPU: ST(0)=termino_RAM
    ; FILD desplaza ST(0)->ST(1) y carga disco en ST(0).
    ; FADDP: ST(1) = ST(1)+ST(0), luego POP -> ST(0)=suma_parcial
    ; ----------------------------------------------------------
    fild  qword [fpu_tmp2]       ; ST(0)=disco_pct, ST(1)=termino_RAM
    fmul  qword [fpu_peso_disco] ; ST(0) = disco_pct * 0.35
    faddp                        ; ST(0) = termino_RAM + termino_DISCO

    ; ----------------------------------------------------------
    ; TERMINO 3: (100.0 - cpu_pct_usado) * 0.25
    ; FLD carga la constante 100.0 desplazando todo.
    ; FSUBP: ST(1) = ST(1)-ST(0) = 100.0-cpu_usado, luego POP
    ; FMUL: ST(0) = cpu_libre * 0.25 = termino_CPU
    ; FADDP: suma_final = suma_parcial + termino_CPU
    ; ----------------------------------------------------------
    fld   qword [fpu_const100]  ; ST(0)=100.0, ST(1)=suma_parcial
    fild  qword [fpu_tmp3]      ; ST(0)=cpu_usado, ST(1)=100.0, ST(2)=suma
    fsubp                        ; ST(0)=100-cpu_usado=cpu_libre
    fmul  qword [fpu_peso_cpu]  ; ST(0) = cpu_libre * 0.25
    faddp                        ; ST(0) = PUNTAJE FINAL (0.0-100.0)

    ; ----------------------------------------------------------
    ; FSTP: Almacena ST(0) como double en [fpu_resultado] y pop.
    ; FLD + FISTP: recarga el double y lo convierte a QWORD entero
    ;   con el modo de redondeo del coprocesador (mas cercano).
    ; ----------------------------------------------------------
    fstp  qword [fpu_resultado]  ; Guarda puntaje double, pop FPU
    fld   qword [fpu_resultado]  ; Recarga para conversion
    fistp qword [fpu_tmp1]       ; Convierte a entero 64-bit, pop

    ; ----------------------------------------------------------
    ; RETORNO en EAX, saturado al rango [0, 100]
    ; En x64: escribir EAX zero-extiende automaticamente a RAX.
    ; CMP: actualiza EFLAGS sin modificar EAX.
    ; JLE/JGE: bifurcan segun los flags, preservan EAX.
    ; ----------------------------------------------------------
    mov   eax, dword [fpu_tmp1] ; EAX = puntaje entero
    cmp   eax, 100              ; Comparar con limite maximo
    jle   .fpu_ok               ; Si EAX <= 100, es valido -> saltar
    mov   eax, 100              ; Saturar al techo de 100
.fpu_ok:
    cmp   eax, 0                ; Comparar con limite minimo
    jge   .fpu_fin              ; Si EAX >= 0, es valido -> saltar
    xor   eax, eax              ; Saturar al piso (XOR limpia registro)
.fpu_fin:
    ret
endp


; -------------------------------------------------------
; update_diag  rcx = hwnd principal
; -------------------------------------------------------
proc update_diag uses rbx rsi rdi, hwnd
    mov  rbx, rcx

    ; Nombre del equipo
    mov  dword [pcbufsz], 32
    invoke  GetComputerNameA, pc_buf, pcbufsz
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_PC, pc_buf

    ; Usuario
    mov  dword [pcbufsz], 128
    invoke  GetUserNameA, tmp_buf, pcbufsz
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_USR, tmp_buf

    ; CPU
    call  cpuid_modelo
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_CPU, cpu_buf

    ; Hardware avanzado visible en la interfaz RadASM/FASM
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_GPU, _hw_unknown
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_PLACA, _hw_unknown
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_BIOS, _hw_unknown
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_TEC, _tec_vigente

    ; GPU: \Device\Video0 -> ruta real del adaptador -> DriverDesc
    mov  dword [reg_cb], 256
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, _reg_video_map, _reg_video0, \
            RRF_RT_REG_SZ, NULL, video_reg_path, reg_cb
    test eax, eax
    jnz  .gpu_done
    mov  dword [reg_cb], 96
    lea  rax, [video_reg_path + 18] ; salta "\Registry\Machine\"
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, rax, _reg_driver_desc, \
            RRF_RT_REG_SZ, NULL, gpu_buf, reg_cb
    test eax, eax
    jnz  .gpu_done
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_GPU, gpu_buf
.gpu_done:

    ; Placa madre: fabricante + modelo
    mov  dword [reg_cb], 96
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, _reg_bios, _reg_board_mfr, \
            RRF_RT_REG_SZ, NULL, board_mfr_buf, reg_cb
    mov  dword [reg_cb], 96
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, _reg_bios, _reg_board_product, \
            RRF_RT_REG_SZ, NULL, board_buf, reg_cb
    invoke  wsprintfA, txt, fmt_pair, board_mfr_buf, board_buf
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_PLACA, txt

    ; BIOS: fabricante + version
    mov  dword [reg_cb], 96
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, _reg_bios, _reg_bios_vendor, \
            RRF_RT_REG_SZ, NULL, bios_vendor_buf, reg_cb
    mov  dword [reg_cb], 96
    invoke  RegGetValueA, HKEY_LOCAL_MACHINE, _reg_bios, _reg_bios_version, \
            RRF_RT_REG_SZ, NULL, bios_ver_buf, reg_cb
    invoke  wsprintfA, txt, fmt_pair, bios_vendor_buf, bios_ver_buf
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_BIOS, txt

    ; RAM
    mov  dword [memst], 64
    invoke  GlobalMemoryStatusEx, memst

    mov  rax, qword [memst + 8]
    shr  rax, 20
    mov  [ram_tot], rax

    mov  rax, qword [memst + 16]
    shr  rax, 20
    mov  [ram_lib], rax

    invoke  wsprintfA, txt, fmt_mb, [ram_tot]
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_RAMT, txt

    invoke  wsprintfA, txt, fmt_mb, [ram_lib]
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_RAML, txt

    ; Uso RAM %
    mov  rax, [ram_tot]
    sub  rax, [ram_lib]
    xor  edx, edx
    mov  rcx, 100
    mul  rcx
    mov  rcx, [ram_tot]
    test rcx, rcx
    jz   .rp0
    div  rcx
    cmp  rax, 100
    jbe  .rp1
    mov  rax, 100
    jmp  .rp1
.rp0:
    xor  rax, rax
.rp1:
    mov  [ram_pct], rax
    invoke  wsprintfA, txt, fmt_pct, [ram_pct]
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_RAMP, txt

    ; Disco libre
    invoke  GetDiskFreeSpaceExA, _drv, d_lib_q, d_tot_q, NULL
    mov  rax, [d_lib_q]
    shr  rax, 20
    invoke  wsprintfA, txt, fmt_mb, rax
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_DISC, txt

    ; S.O. via RtlGetVersion (ntdll) - devuelve version real en Win10/11
    ; GetVersionExA devuelve 6.2 en Win10/11 sin manifiesto (incorrecto)
    mov  dword [os_rtl], 276      ; dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOW)
    invoke  RtlGetVersion, os_rtl  ; Siempre retorna la version real

    ; Detectar Windows 11: Build >= 22000
    mov  eax, dword [os_rtl + 12]  ; dwBuildNumber
    cmp  eax, 22000
    jge  .os_win11
    ; Windows 10 u otro: mostrar version completa
    invoke  wsprintfA, txt, fmt_os_ver, \
            dword [os_rtl + 4], dword [os_rtl + 8], dword [os_rtl + 12]
    jmp  .os_show
.os_win11:
    invoke  wsprintfA, txt, fmt_win11, dword [os_rtl + 12]
.os_show:
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_OS, txt

    ; Arquitectura
    invoke  GetSystemInfo, sys_info
    movzx  rax, word [sys_info]
    cmp  rax, 9
    je   .x64arch
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_OS+2, _arch_x86  ; IDC 319 sera categoria
    jmp  .arch_done
.x64arch:
    ; No hay IDC_D_VAL_ARCH separado - lo ponemos en categoria por ahora
    ; La arquitectura ya esta en el titulo de la ventana (64-bit)
.arch_done:

    ; Categoria (basada en % RAM libre)
    mov  rax, [ram_lib]
    xor  edx, edx
    imul rax, 100
    mov  rcx, [ram_tot]
    test rcx, rcx
    jz   .crit
    div  rcx       ; rax = % libre

    cmp  rax, 50
    jge  .cat_exc
    cmp  rax, 30
    jge  .cat_bue
    cmp  rax, 15
    jge  .cat_reg
.crit:
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_CAT, _cat3
    jmp   .do_fpu          ; Salto al bloque FPU (no retornar aun)
.cat_exc:
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_CAT, _cat0
    jmp   .do_fpu
.cat_bue:
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_CAT, _cat1
    jmp   .do_fpu
.cat_reg:
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_CAT, _cat2

; ==============================================================
; CALCULO DEL PUNTAJE FPU  (Requisito #5: Coprocesador x87)
; --------------------------------------------------------------
; Se calcula disco_libre_pct y ram_libre_pct como porcentajes
; de DISPONIBILIDAD (inverso del uso), luego se llama al proc
; fpu_puntaje que usa instrucciones FINIT/FILD/FMUL/FADDP/FSTP.
; ==============================================================
.do_fpu:
    ; Calcular disco_libre_pct = (d_lib_q_mb * 100) / d_tot_q_mb
    ; Necesario para la formula FPU (complemento al uso de disco).
    mov  rax, [d_lib_q]         ; Bytes libres en disco (QWORD)
    shr  rax, 20                ; Convertir a MB (dividir por 1M)
    mov  [fpu_tmp1], rax        ; fpu_tmp1 = disco_libre_MB

    mov  rax, [d_tot_q]         ; Bytes totales en disco (QWORD)
    shr  rax, 20                ; Convertir a MB
    test rax, rax               ; Verificar division por cero
    jz   .disco_pct_cero        ; Si disco_total=0, evitar DIV

    mov  rcx, rax               ; RCX = disco_total_MB (divisor)
    mov  rax, [fpu_tmp1]        ; RAX = disco_libre_MB (dividendo)
    imul rax, 100               ; RAX = disco_libre_MB * 100
    xor  edx, edx               ; RDX:RAX = dividendo extendido
    ; DIV: RAX = (disco_libre_MB * 100) / disco_total_MB = libre%
    ; Nota: XOR EDX,EDX limpia el registro de extension del dividendo
    div  rcx                    ; RAX = disco_libre_pct (0-100)
    mov  [fpu_tmp2], rax        ; Guardar resultado
    jmp  .disco_pct_ok
.disco_pct_cero:
    mov  qword [fpu_tmp2], 0
.disco_pct_ok:

    ; Calcular ram_libre_pct = 100 - ram_pct (% de uso -> % libre)
    mov  rax, 100
    sub  rax, [ram_pct]         ; RAM libre = 100 - RAM usada%
    mov  [fpu_tmp1], rax        ; fpu_tmp1 = ram_libre_pct

    ; ----------------------------------------------------------
    ; LLAMADA AL PROC FPU (Convencion FastCall Win64)
    ;   RCX = ram_libre_pct   (arg1 -> pasa en registro RCX)
    ;   RDX = disco_libre_pct (arg2 -> pasa en registro RDX)
    ;   R8  = cpu_pct         (arg3 -> pasa en registro R8)
    ; Retorna: EAX = puntaje entero calculado con x87
    ; ----------------------------------------------------------
    mov  rcx, [fpu_tmp1]        ; Arg1: RAM libre %
    mov  rdx, [fpu_tmp2]        ; Arg2: Disco libre %
    mov  r8,  [cpu_pct]         ; Arg3: CPU usado % (ultimo ciclo)
    call fpu_puntaje             ; EAX = puntaje FPU (0-100)
    mov  [fpu_score_i], rax      ; Guardar antes de que invoke lo destruya

    ; Seleccionar string de nivel segun el puntaje obtenido.
    ; CMP + JGE: bifurcan sin modificar EAX.
    cmp  rax, 80                 ; Comparar con umbral EXCELENTE
    jge  .sc_exc                 ; Salto si puntaje >= 80
    cmp  rax, 60                 ; Comparar con umbral BUENO
    jge  .sc_bue                 ; Salto si 60 <= puntaje < 80
    cmp  rax, 40                 ; Comparar con umbral REGULAR
    jge  .sc_reg                 ; Salto si 40 <= puntaje < 60
    ; puntaje < 40: CRITICO
    invoke  wsprintfA, txt, fmt_score, [fpu_score_i], _sc_cri
    jmp  .sc_mostrar
.sc_exc:
    invoke  wsprintfA, txt, fmt_score, [fpu_score_i], _sc_exc
    jmp  .sc_mostrar
.sc_bue:
    invoke  wsprintfA, txt, fmt_score, [fpu_score_i], _sc_bue
    jmp  .sc_mostrar
.sc_reg:
    invoke  wsprintfA, txt, fmt_score, [fpu_score_i], _sc_reg
.sc_mostrar:
    ; Mostrar el puntaje FPU en el control IDC_D_VAL_SCORE
    invoke  SetDlgItemTextA, rbx, IDC_D_VAL_SCORE, txt
    ret
endp


; -------------------------------------------------------
; update_mon  rcx = hwnd
; -------------------------------------------------------
proc update_mon uses rbx rsi rdi, hwnd
    mov  rbx, rcx

    ; RAM
    mov  dword [memst], 64
    invoke  GlobalMemoryStatusEx, memst

    mov  rax, qword [memst + 8]
    shr  rax, 20
    mov  [ram_tot], rax

    mov  rax, qword [memst + 16]
    shr  rax, 20
    mov  [ram_lib], rax

    mov  rax, [ram_tot]
    sub  rax, [ram_lib]
    mov  [ram_uso], rax

    xor  edx, edx
    mov  rax, [ram_uso]
    mov  rcx, 100
    mul  rcx
    mov  rcx, [ram_tot]
    test rcx, rcx
    jz   .rp0
    div  rcx
    cmp  rax, 100
    jbe  .rp1
    mov  rax, 100
    jmp  .rp1
.rp0:
    xor  rax, rax
.rp1:
    mov  [ram_pct], rax

    ; Barra GDI RAM: solo actualizar la variable global y forzar repintado
    ; Grafica de RAM: forzar repintado
    invoke  GetDlgItem, rbx, IDC_M_HIST_RAM
    invoke  InvalidateRect, rax, NULL, 0
    ; Info numerica detallada
    invoke  wsprintfA, txt, fmt_mon_r, [ram_tot], [ram_lib], [ram_uso], [ram_pct]
    invoke  SetDlgItemTextA, rbx, IDC_M_VAL_RAM, txt

    ; Disco
    invoke  GetDiskFreeSpaceExA, _drv, d_lib_q, d_tot_q, NULL
    mov  rax, [d_tot_q]
    shr  rax, 20
    mov  [d_tot], rax
    mov  rax, [d_lib_q]
    shr  rax, 20
    mov  [d_lib], rax
    mov  rax, [d_tot]
    sub  rax, [d_lib]
    mov  [d_uso], rax
    xor  edx, edx
    mov  rax, [d_uso]
    mov  rcx, 100
    mul  rcx
    mov  rcx, [d_tot]
    test rcx, rcx
    jz   .dp0
    div  rcx
    cmp  rax, 100
    jbe  .dp1
    mov  rax, 100
    jmp  .dp1
.dp0:
    xor  rax, rax
.dp1:
    mov  [d_pct], rax
    ; Grafica de DISCO: forzar repintado
    invoke  GetDlgItem, rbx, IDC_M_HIST_DSK
    invoke  InvalidateRect, rax, NULL, 0
    invoke  wsprintfA, txt, fmt_mon_d, [d_tot], [d_lib], [d_uso], [d_pct]
    invoke  SetDlgItemTextA, rbx, IDC_M_VAL_DIS, txt

    ; CPU  (delta entre lecturas)
    invoke  GetSystemTimes, ft_idle, ft_kern, ft_user

    mov  rax, [ft_idle]
    sub  rax, [ft_idle_p]
    mov  [d_idle_n], rax
    mov  rax, [ft_kern]
    sub  rax, [ft_kern_p]
    mov  [d_kern_n], rax
    mov  rax, [ft_user]
    sub  rax, [ft_user_p]
    mov  [d_user_n], rax

    mov  rax, [ft_idle]
    mov  [ft_idle_p], rax
    mov  rax, [ft_kern]
    mov  [ft_kern_p], rax
    mov  rax, [ft_user]
    mov  [ft_user_p], rax

    mov  rax, [d_kern_n]
    add  rax, [d_user_n]
    test rax, rax
    jz   .cp0
    mov  rcx, rax
    mov  rax, [d_idle_n]
    imul rax, 100        ; imul 2-op: rax = rax*100, NO modifica RDX
    xor  edx, edx        ; RDX=0 para que div use solo RAX como dividendo
    div  rcx             ; rax = (idle*100)/total = idle% ; sin riesgo de #DE
    cmp  rax, 100
    jae  .cp0
    mov  rcx, 100
    sub  rcx, rax
    mov  [cpu_pct], rcx
    jmp  .cp1
.cp0:
    mov  qword [cpu_pct], 0
.cp1:
    ; Grafica de CPU: forzar repintado
    invoke  GetDlgItem, rbx, IDC_M_HIST_CPU
    invoke  InvalidateRect, rax, NULL, 0
    invoke  wsprintfA, txt, fmt_mon_c, [cpu_pct]
    invoke  SetDlgItemTextA, rbx, IDC_M_VAL_CPU, txt

    ; GPU (usar valor aleatorio 0-30 para demo, normalmente obtendria de WMI/GPU API)
    ; Para ahora: simplemente usar un valor bajo fijo como placeholder
    mov  qword [gpu_pct], 5
    ; Valor GPU
    invoke  wsprintfA, txt, fmt_mon_g, [gpu_pct]
    invoke  SetDlgItemTextA, rbx, IDC_M_VAL_GPU, txt

    ; === Actualizar historial de picos (incluyendo GPU) ===
    mov  rcx, [cpu_pct]
    mov  rdx, [ram_pct]
    mov  r8,  [d_pct]
    mov  r9,  [gpu_pct]
    call store_history_4

    ; === Graficas GDI: forzar repintado de los controles TG_Graph ===
    invoke  GetDlgItem, rbx, IDC_M_HIST_CPU
    invoke  InvalidateRect, rax, NULL, 0
    invoke  GetDlgItem, rbx, IDC_M_HIST_RAM
    invoke  InvalidateRect, rax, NULL, 0
    invoke  GetDlgItem, rbx, IDC_M_HIST_DSK
    invoke  InvalidateRect, rax, NULL, 0
    invoke  GetDlgItem, rbx, IDC_M_HIST_GPU
    invoke  InvalidateRect, rax, NULL, 0

    ; === Estado general (siempre normal, sin alertas) ===
    invoke  SetDlgItemTextA, rbx, IDC_M_ESTADO, _st_ok
    ret
endp


; -------------------------------------------------------
; update_anal_detail  rcx = hwnd
; Lee el .rep seleccionado y muestra detalles graficos
; -------------------------------------------------------
proc update_anal_detail uses rbx rsi rdi, hwnd
    mov  rbx, rcx

    ; Obtener indice del item seleccionado en el listbox
    invoke  SendDlgItemMessage, rbx, IDC_A_LIST, LB_GETCURSEL, 0, 0
    cmp   rax, -1         ; LB_ERR = sin seleccion
    je    .sin_sel

    ; Obtener el indice de ruta almacenado via LB_SETITEMDATA
    invoke  SendDlgItemMessage, rbx, IDC_A_LIST, LB_GETITEMDATA, rax, 0
    cmp   rax, -1
    je    .sin_sel

    ; Calcular puntero a la ruta: anal_paths + indice*300
    imul  rax, 300
    lea   rsi, [anal_paths]
    add   rsi, rax         ; rsi = puntero a la ruta del archivo

    ; Abrir el .rep seleccionado
    invoke  CreateFileA, rsi, GENERIC_READ, FILE_SHARE_READ, NULL, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .sin_sel
    mov   [tmp_hfile], rax

    ; Leer header y verificar firma
    invoke  ReadFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    mov   eax, dword [rep_hdr]
    cmp   eax, 0x4E414353    ; "SCAN"
    jne   .cerrar_err

    ; Leer EquipoInfo (200 bytes)
    invoke  ReadFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]

    ; PC Name (equipo_buf + 4 = nombre_equip[28])
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_PC, equipo_buf + 4

    ; Timestamp (equipo_buf + 176 = timestamp[24])
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_TS, equipo_buf + 176

    ; Categoria — cada rama tiene su propio jmp explicito
    mov   ecx, dword [equipo_buf + 172]
    cmp   ecx, 0
    je    .dcat0
    cmp   ecx, 1
    je    .dcat1
    cmp   ecx, 2
    je    .dcat2
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_CAT, _cat3
    jmp   .det_bars
.dcat0:
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_CAT, _cat0
    jmp   .det_bars
.dcat1:
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_CAT, _cat1
    jmp   .det_bars
.dcat2:
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_CAT, _cat2
    jmp   .det_bars

.det_bars:
    ; --- Barra RAM: (ram_total - ram_libre) * 100 / ram_total ---
    ; equipo_buf+64 = ram_total (MB QWORD), equipo_buf+72 = ram_libre (MB QWORD)
    mov   rax, qword [equipo_buf + 64]    ; ram_total
    test  rax, rax
    jz    .bar_done

    mov   rdi, rax                         ; rdi = ram_total
    mov   rsi, qword [equipo_buf + 72]     ; rsi = ram_libre
    mov   rax, rdi
    sub   rax, rsi                         ; rax = ram_usada
    imul  rax, 100
    xor   edx, edx
    div   rdi                              ; rax = ram_pct_uso
    cmp   rax, 100
    jbe   .rp_ok_d
    mov   rax, 100
.rp_ok_d:
    mov   [det_ram_pct], rax

    invoke  wsprintfA, txt, fmt_det_ram, \
            dword [equipo_buf + 64], dword [equipo_buf + 72], [det_ram_pct]
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_RVAL, txt
    ; Barra GDI RAM del reporte: forzar repintado del TG_Gauge
    invoke  GetDlgItem, rbx, IDC_A_DET_RBAR
    invoke  InvalidateRect, rax, NULL, 0

    ; --- DISCO: mostrar libre (MB) y barra proporcional ---
    invoke  wsprintfA, txt, fmt_det_dsk, dword [equipo_buf + 80]
    invoke  SetDlgItemTextA, rbx, IDC_A_DET_DVAL, txt
    ; Barra ASCII Disco (libre como % de ~1TB referencia)
    mov   rax, qword [equipo_buf + 80]    ; disco_libre MB
    cmp   rax, 1000000              ; > 1TB libre
    jge   .dsk_100
    ; % = libre / 10000 (para base de 1TB ~ 1024000 MB)
    xor   edx, edx
    imul  rax, 100
    mov   rcx, 1024000
    div   rcx
    cmp   rax, 100; jbe .dsk_ok; mov rax, 100
    jbe   .dsk_ok
    mov   rax, 100
    jmp   .dsk_ok
.dsk_100:
    mov   rax, 100
.dsk_ok:
    mov   [det_dsk_pct], rax
    ; Barra GDI Disco del reporte: forzar repintado del TG_Gauge
    invoke  GetDlgItem, rbx, IDC_A_DET_DBAR
    invoke  InvalidateRect, rax, NULL, 0

.bar_done:
    ; Mostrar el panel de detalles si no era visible
    invoke  GetDlgItem, rbx, IDC_A_DET_HDR
    invoke  ShowWindow, rax, SW_SHOW
    ret

.cerrar_err:
    invoke  CloseHandle, [tmp_hfile]
.sin_sel:
    ret
endp


; -------------------------------------------------------
; update_anal  rcx = hwnd
; Lista cada .rep con PC, timestamp y categoria
; -------------------------------------------------------
proc update_anal uses rbx rsi rdi, hwnd
    mov  rbx, rcx

    ; Limpiar listbox y contador de rutas
    invoke  SendDlgItemMessage, rbx, IDC_A_LIST, LB_RESETCONTENT, 0, 0
    mov  qword [anal_path_cnt], 0

    invoke  FindFirstFileA, _rep_pattern, find_data
    cmp   rax, -1
    je    .no_files
    mov   rsi, rax    ; hFind (callee-saved)
    xor   rdi, rdi    ; contador

.loop_files:
    ; Construir ruta completa en tmp_buf usando rax (no rcx!)
    lea   rax, [find_data + 44]
    invoke  wsprintfA, tmp_buf, fmt_ruta, rax

    ; Abrir el archivo .rep y leer datos
    invoke  CreateFileA, tmp_buf, GENERIC_READ, FILE_SHARE_READ, NULL, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .solo_nombre

    mov   [tmp_hfile], rax

    ; Leer header y verificar firma
    invoke  ReadFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    mov   eax, dword [rep_hdr]
    cmp   eax, 0x4E414353    ; "SCAN" little-endian
    jne   .cerrar_nombre

    ; Leer EquipoInfo
    invoke  ReadFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]

    ; Formatear segun categoria (offset 172 en EquipoInfo)
    mov   ecx, dword [equipo_buf + 172]
    cmp   ecx, 0
    je    .a_exc
    cmp   ecx, 1
    je    .a_bue
    cmp   ecx, 2
    je    .a_reg

    ; Critico
    invoke  wsprintfA, txt, fmt_anal_item, equipo_buf+4, equipo_buf+176, _acat3
    jmp   .agregar

.a_exc:
    invoke  wsprintfA, txt, fmt_anal_item, equipo_buf+4, equipo_buf+176, _acat0
    jmp   .agregar
.a_bue:
    invoke  wsprintfA, txt, fmt_anal_item, equipo_buf+4, equipo_buf+176, _acat1
    jmp   .agregar
.a_reg:
    invoke  wsprintfA, txt, fmt_anal_item, equipo_buf+4, equipo_buf+176, _acat2
    jmp   .agregar

.cerrar_nombre:
    invoke  CloseHandle, [tmp_hfile]
.solo_nombre:
    ; Mostrar solo el nombre de archivo si no se pudo leer
    lea   rax, [find_data + 44]
    invoke  wsprintfA, txt, fmt_anal_fname, rax

.agregar:
    ; Agregar texto al listbox (siempre)
    lea   rax, [txt]
    invoke  SendDlgItemMessage, rbx, IDC_A_LIST, LB_ADDSTRING, 0, rax
    mov   [tmp_idx], rax            ; indice del item en listbox

    ; Guardar ruta solo si cabe en el array (max 32 = indices 0..31)
    mov   rax, [anal_path_cnt]
    cmp   rax, 31
    jge   .skip_path               ; si hay >= 32, no guardar ruta ni asociar datos

    ; Calcular slot en anal_paths y guardar ruta completa
    imul  rax, 300
    lea   rcx, [anal_paths]
    add   rcx, rax
    invoke  wsprintfA, rcx, fmt_ruta, find_data + 44

    ; Asociar el indice de ruta con el item del listbox
    invoke  SendDlgItemMessage, rbx, IDC_A_LIST, LB_SETITEMDATA, [tmp_idx], [anal_path_cnt]
    inc   qword [anal_path_cnt]
    inc   rdi
    jmp   .next_file

.skip_path:
    ; Mas de 32 reportes: agregar al listbox sin datos de detalle
    inc   rdi

.next_file:

    invoke  FindNextFileA, rsi, find_data
    test  eax, eax
    jnz   .loop_files

    invoke  FindClose, rsi

    invoke  wsprintfA, txt, fmt_anal_cnt, rdi
    invoke  SetDlgItemTextA, rbx, IDC_A_INFO, txt
    ret

.no_files:
    invoke  SetDlgItemTextA, rbx, IDC_A_INFO, _no_rep
    ret
endp


; -------------------------------------------------------
; update_estad  rcx = hwnd
; Lee todos los .rep y muestra conteo por categoria
; -------------------------------------------------------
; -------------------------------------------------------
; update_estad  rcx = hwnd
; Dashboard visual: conteo por categoria + barras + lista completa
; -------------------------------------------------------
proc update_estad uses rbx rsi rdi, hwnd
    mov  rbx, rcx

    ; Limpiar listbox de equipos y contadores
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_RESETCONTENT, 0, 0
    mov  qword [es_total], 0
    mov  qword [es_c0], 0
    mov  qword [es_c1], 0
    mov  qword [es_c2], 0
    mov  qword [es_c3], 0
    mov  qword [es_sum_ram_lib], 0
    mov  qword [es_sum_disk], 0
    mov  qword [es_avg_ram], 0
    mov  qword [es_avg_disk], 0
    mov  qword [es_min_res_score], -1
    mov  qword [es_old_score], 0

    lea  rdi, [es_min_res_name]
    xor  eax, eax
    mov  ecx, 4
    rep  stosq
    lea  rdi, [es_old_name]
    mov  ecx, 4
    rep  stosq
    lea  rdi, [es_top_pri_val]
    mov  ecx, 5
    rep  stosq
    lea  rdi, [es_top_pri_name]
    mov  ecx, 5 * 4
    rep  stosq
    lea  rdi, [es_top_ram_val]
    mov  ecx, 5
    rep  stosq
    lea  rdi, [es_top_ram_name]
    mov  ecx, 5 * 4
    rep  stosq
    lea  rdi, [es_top_disk_val]
    mov  ecx, 5
    rep  stosq
    lea  rdi, [es_top_disk_name]
    mov  ecx, 5 * 4
    rep  stosq
    lea  rdi, [es_top_age_val]
    mov  ecx, 5
    rep  stosq
    lea  rdi, [es_top_age_name]
    mov  ecx, 5 * 4
    rep  stosq

    invoke  FindFirstFileA, _rep_pattern, find_data
    cmp   rax, -1
    je    .no_data
    mov   [hist_hfind], rax    ; hFind guardado en memoria

.loop_reps:
    lea   rax, [find_data + 44]
    invoke  wsprintfA, tmp_buf, fmt_ruta, rax

    invoke  CreateFileA, tmp_buf, GENERIC_READ, FILE_SHARE_READ, NULL, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .skip_rep

    mov   [tmp_hfile], rax
    invoke  ReadFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    mov   eax, dword [rep_hdr]
    cmp   eax, 0x4E414353
    jne   .close_rep

    invoke  ReadFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]

    inc   qword [es_total]

    ; Acumular promedios globales
    mov   rax, qword [equipo_buf + 72]   ; RAM libre MB
    add   [es_sum_ram_lib], rax
    mov   rax, qword [equipo_buf + 80]   ; Disco libre MB
    add   [es_sum_disk], rax

    ; Equipo con menos recursos = RAM libre + disco libre mas bajo
    mov   rax, qword [equipo_buf + 72]
    add   rax, qword [equipo_buf + 80]
    cmp   rax, [es_min_res_score]
    jae   .min_res_ok
    mov   [es_min_res_score], rax
    lea   rsi, [equipo_buf + 4]
    lea   rdi, [es_min_res_name]
    mov   ecx, 4
    rep   movsq
.min_res_ok:

    ; Rankings: RAM total, disco libre, antiguedad estimada y prioridad tecnica
    lea   rcx, [es_top_ram_val]
    lea   rdx, [es_top_ram_name]
    mov   r8,  qword [equipo_buf + 64]
    lea   r9,  [equipo_buf + 4]
    call  rank_insert_desc

    lea   rcx, [es_top_disk_val]
    lea   rdx, [es_top_disk_name]
    mov   r8,  qword [equipo_buf + 80]
    lea   r9,  [equipo_buf + 4]
    call  rank_insert_desc

    ; Antiguedad estimada: equipos con menos RAM total y peor categoria suben.
    mov   r8, 262144
    mov   rax, qword [equipo_buf + 64]
    cmp   rax, r8
    jae   .age_base_ok
    sub   r8, rax
    jmp   .age_cat
.age_base_ok:
    xor   r8, r8
.age_cat:
    mov   eax, dword [equipo_buf + 172]
    imul  rax, 1000000
    add   r8, rax
    cmp   r8, [es_old_score]
    jbe   .old_ok
    mov   [es_old_score], r8
    lea   rsi, [equipo_buf + 4]
    lea   rdi, [es_old_name]
    mov   ecx, 4
    rep   movsq
.old_ok:
    lea   rcx, [es_top_age_val]
    lea   rdx, [es_top_age_name]
    lea   r9,  [equipo_buf + 4]
    call  rank_insert_desc

    ; Prioridad tecnica: categoria, RAM libre baja y disco bajo.
    mov   eax, dword [equipo_buf + 172]
    imul  rax, 1000000
    mov   r8, rax
    mov   rax, 262144
    mov   rcx, qword [equipo_buf + 72]
    cmp   rcx, rax
    jae   .pri_ram_done
    sub   rax, rcx
    add   r8, rax
.pri_ram_done:
    mov   rax, 262144
    mov   rcx, qword [equipo_buf + 80]
    cmp   rcx, rax
    jae   .pri_disk_done
    sub   rax, rcx
    add   r8, rax
.pri_disk_done:
    lea   rcx, [es_top_pri_val]
    lea   rdx, [es_top_pri_name]
    lea   r9,  [equipo_buf + 4]
    call  rank_insert_desc

    ; Acumular por categoria
    mov   ecx, dword [equipo_buf + 172]
    cmp   ecx, 0
    je    .inc_c0
    cmp   ecx, 1
    je    .inc_c1
    cmp   ecx, 2
    je    .inc_c2
    inc   qword [es_c3]
    jmp   .add_to_list
.inc_c0:
    inc qword [es_c0]
    jmp .add_to_list
.inc_c1:
    inc qword [es_c1]
    jmp .add_to_list
.inc_c2:
    inc qword [es_c2]

.add_to_list:
    ; Calcular RAM% para mostrar en la lista
    mov   rax, qword [equipo_buf + 64]
    test  rax, rax
    jz    .list_no_ram
    mov   [hist_tmp_tot], rax
    mov   rcx, qword [equipo_buf + 72]
    mov   rax, [hist_tmp_tot]
    sub   rax, rcx
    imul  rax, 100
    xor   edx, edx
    div   qword [hist_tmp_tot]
    cmp   rax, 100; jbe .rp_list_ok; mov rax, 100
    jbe   .rp_list_ok
    mov   rax, 100
.rp_list_ok:
    mov   [det_ram_pct], rax
    jmp   .do_list_fmt

.list_no_ram:
    mov   qword [det_ram_pct], 0

.do_list_fmt:
    ; Seleccionar string de categoria
    mov   ecx, dword [equipo_buf + 172]
    cmp   ecx, 0; je .lcat0
    je    .lcat0
    cmp   ecx, 1; je .lcat1
    je    .lcat1
    cmp   ecx, 2; je .lcat2
    je    .lcat2
    invoke  wsprintfA, txt, fmt_e_pclist, equipo_buf+4, equipo_buf+176, [det_ram_pct], _acat3
    jmp   .list_add
.lcat0:
    invoke wsprintfA, txt, fmt_e_pclist, equipo_buf+4, equipo_buf+176, [det_ram_pct], _acat0
    jmp .list_add
.lcat1:
    invoke wsprintfA, txt, fmt_e_pclist, equipo_buf+4, equipo_buf+176, [det_ram_pct], _acat1
    jmp .list_add
.lcat2:
    invoke wsprintfA, txt, fmt_e_pclist, equipo_buf+4, equipo_buf+176, [det_ram_pct], _acat2

.list_add:
    lea   rax, [txt]
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, rax
    jmp   .skip_rep

.close_rep:
    invoke  CloseHandle, [tmp_hfile]
.skip_rep:
    invoke  FindNextFileA, [hist_hfind], find_data
    test  eax, eax
    jnz   .loop_reps
    invoke  FindClose, [hist_hfind]

.no_data:
    ; === Mostrar totales en etiquetas de categoria ===
    invoke  wsprintfA, txt, fmt_stat_tot, [es_total]
    invoke  SetDlgItemTextA, rbx, IDC_E_TOTAL, txt
    mov   rax, [es_total]
    test  rax, rax
    jz    .avg_done
    mov   [hist_tmp_tot], rax
    mov   rax, [es_sum_ram_lib]
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_avg_ram], rax
    mov   rax, [es_sum_disk]
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_avg_disk], rax
.avg_done:
    invoke  wsprintfA, txt, fmt_stat_ext, [es_total], [es_avg_ram], [es_avg_disk], es_min_res_name, es_old_name
    invoke  SetDlgItemTextA, rbx, IDC_E_TOTAL, txt

    invoke  wsprintfA, txt, fmt_es_exc, [es_c0]
    invoke  SetDlgItemTextA, rbx, IDC_E_CAT0, txt

    invoke  wsprintfA, txt, fmt_es_bue, [es_c1]
    invoke  SetDlgItemTextA, rbx, IDC_E_CAT1, txt

    invoke  wsprintfA, txt, fmt_es_reg, [es_c2]
    invoke  SetDlgItemTextA, rbx, IDC_E_CAT2, txt

    invoke  wsprintfA, txt, fmt_es_cri, [es_c3]
    invoke  SetDlgItemTextA, rbx, IDC_E_CAT3, txt

    ; === Actualizar barras de distribucion (% del total) ===
    mov   rax, [es_total]
    test  rax, rax
    jz    .bars_done   ; si no hay datos, dejar barras en 0

    ; Barra 0: es_c0 * 100 / es_total
    mov   [hist_tmp_tot], rax
    ; Calcular porcentajes para las barras GDI de distribucion
    ; y forzar repintado de cada control TG_Gauge
    mov   rax, [es_c0]
    imul  rax, 100
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_pct0], rax
    invoke  GetDlgItem, rbx, IDC_E_BAR0
    invoke  InvalidateRect, rax, NULL, 0

    mov   rax, [es_c1]
    imul  rax, 100
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_pct1], rax
    invoke  GetDlgItem, rbx, IDC_E_BAR1
    invoke  InvalidateRect, rax, NULL, 0

    mov   rax, [es_c2]
    imul  rax, 100
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_pct2], rax
    invoke  GetDlgItem, rbx, IDC_E_BAR2
    invoke  InvalidateRect, rax, NULL, 0

    mov   rax, [es_c3]
    imul  rax, 100
    xor   edx, edx
    div   qword [hist_tmp_tot]
    mov   [es_pct3], rax
    invoke  GetDlgItem, rbx, IDC_E_BAR3
    invoke  InvalidateRect, rax, NULL, 0

.bars_done:
    ; === Secciones de revision y ordenamientos en el listbox ===
    mov   rcx, rbx
    lea   rdx, [_rank_pri]
    lea   r8,  [es_top_pri_name]
    lea   r9,  [es_top_pri_val]
    call  add_rank_score5

    mov   rcx, rbx
    lea   rdx, [_rank_ram]
    lea   r8,  [es_top_ram_name]
    lea   r9,  [es_top_ram_val]
    call  add_rank_mb5

    mov   rcx, rbx
    lea   rdx, [_rank_disk]
    lea   r8,  [es_top_disk_name]
    lea   r9,  [es_top_disk_val]
    call  add_rank_mb5

    mov   rcx, rbx
    lea   rdx, [_rank_age]
    lea   r8,  [es_top_age_name]
    lea   r9,  [es_top_age_val]
    call  add_rank_score5

    ret
endp


; ==============================================================
; build_ascii_bar
;   rcx = porcentaje (0-100)
;   rdx = buffer destino (al menos 50 bytes)
;   r8  = ancho de la barra en caracteres
; Llena el buffer con: [███░░░░░]
; Caracter 0DBh = █ (lleno), 0B0h = ░ (vacio)
; ==============================================================
proc build_ascii_bar uses rbx rsi rdi

    mov  rdi, rdx          ; rdi = buffer destino
    mov  rsi, r8           ; rsi = ancho total

    ; llenos = pct * ancho / 100
    mov  rax, rcx          ; pct
    imul rax, rsi          ; pct * ancho
    xor  edx, edx
    mov  rcx, 100
    div  rcx               ; rax = chars llenos
    mov  rbx, rax          ; rbx = llenos

    mov  byte [rdi], '['
    inc  rdi

    xor  rcx, rcx
.bloop:
    cmp  rcx, rsi
    je   .bend
    cmp  rcx, rbx
    jl   .bfill
    mov  byte [rdi], 0B0h  ; ░ caracter vacio
    jmp  .bnext
.bfill:
    mov  byte [rdi], 0DBh  ; █ caracter lleno
.bnext:
    inc  rdi
    inc  rcx
    jmp  .bloop
.bend:
    mov  byte [rdi], ']'
    inc  rdi
    mov  byte [rdi], 0
    ret
endp


; ==============================================================
; build_history_graph
;   rcx = puntero al array de historial (rb 30)
;   rdx = buffer destino
; Convierte 30 lecturas de porcentaje en caracteres ASCII
; Escala: 0-12: ░  13-37: ▒  38-62: ▓  63-87: █  88-100: █
; ==============================================================
proc build_history_graph uses rbx rsi rdi

    mov  rsi, rcx          ; array de historial
    mov  rdi, rdx          ; buffer destino

    ; Empezar desde hist_idx (el mas viejo) para orden cronologico
    movzx rbx, byte [hist_idx]

    xor  rcx, rcx          ; iteracion 0..29
.hloop:
    cmp  rcx, 30
    je   .hend

    ; Indice en el array circular: (hist_idx + rcx) % 30
    mov  rax, rbx
    add  rax, rcx
    cmp  rax, 30
    jl   .no_wrap_h
    sub  rax, 30
.no_wrap_h:
    movzx rax, byte [rsi + rax]   ; porcentaje de esa lectura

    ; Mapear a caracter de bloque ANSI
    cmp  al, 87
    jge  .h_full
    cmp  al, 62
    jge  .h_high
    cmp  al, 37
    jge  .h_med
    cmp  al, 12
    jge  .h_low
    mov  byte [rdi], ' '           ; 0-12: espacio
    jmp  .hnext
.h_low:
    mov  byte [rdi], 0B0h          ; ░  13-37
    jmp  .hnext
.h_med:
    mov  byte [rdi], 0B1h          ; ▒  38-62
    jmp  .hnext
.h_high:
    mov  byte [rdi], 0B2h          ; ▓  63-87
    jmp  .hnext
.h_full:
    mov  byte [rdi], 0DBh          ; █  88-100
.hnext:
    inc  rdi
    inc  rcx
    jmp  .hloop
.hend:
    mov  byte [rdi], 0
    ret
endp


; ==============================================================
; rank_insert_desc
;   rcx = puntero a valores QWORD[5]
;   rdx = puntero a nombres char[5][32]
;   r8  = valor a insertar
;   r9  = puntero al nombre
; Mantiene el top 5 ordenado de mayor a menor.
; ==============================================================
proc rank_insert_desc uses rbx rsi rdi r12 r13 r14 r15
    mov  r12, rcx
    mov  r13, rdx
    mov  r14, r8
    mov  r15, r9

    xor  ebx, ebx
.find_pos:
    cmp  ebx, 5
    jge  .done
    mov  rax, [r12 + rbx*8]
    cmp  r14, rax
    ja   .found
    inc  ebx
    jmp  .find_pos

.found:
    mov  r11, 4
.shift:
    cmp  r11, rbx
    jle  .place

    mov  rax, [r12 + r11*8 - 8]
    mov  [r12 + r11*8], rax

    mov  rax, r11
    shl  rax, 5
    lea  rdi, [r13 + rax]
    sub  rax, 32
    lea  rsi, [r13 + rax]
    mov  ecx, 4
    rep  movsq

    dec  r11
    jmp  .shift

.place:
    mov  [r12 + rbx*8], r14

    mov  rax, rbx
    shl  rax, 5
    lea  rdi, [r13 + rax]
    mov  rsi, r9
    mov  ecx, 4
    rep  movsq

.done:
    ret
endp


; Agrega al listbox hasta 5 filas de ranking con valores "score".
; rcx=hwnd, rdx=titulo, r8=puntero nombres[5][32], r9=puntero valores[5]
proc add_rank_score5 uses rbx rsi rdi r12 r13 r14
    mov  rbx, rcx
    mov  r12, rdx
    mov  r13, r8
    mov  r14, r9

    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, _blank
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, r12

    xor  rdi, rdi
.loop:
    cmp  rdi, 5
    jge  .done
    mov  rax, rdi
    shl  rax, 5
    lea  rsi, [r13 + rax]
    cmp  byte [rsi], 0
    je   .next

    mov  rax, rdi
    inc  rax
    mov  [tmp_idx], rax
    invoke  wsprintfA, txt, fmt_rank_score, [tmp_idx], rsi, qword [r14 + rdi*8]
    lea  rax, [txt]
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, rax

.next:
    inc  rdi
    jmp  .loop
.done:
    ret
endp


; Agrega al listbox hasta 5 filas de ranking con valores en MB.
; rcx=hwnd, rdx=titulo, r8=puntero nombres[5][32], r9=puntero valores[5]
proc add_rank_mb5 uses rbx rsi rdi r12 r13 r14
    mov  rbx, rcx
    mov  r12, rdx
    mov  r13, r8
    mov  r14, r9

    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, _blank
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, r12

    xor  rdi, rdi
.loop:
    cmp  rdi, 5
    jge  .done
    mov  rax, rdi
    shl  rax, 5
    lea  rsi, [r13 + rax]
    cmp  byte [rsi], 0
    je   .next

    mov  rax, rdi
    inc  rax
    mov  [tmp_idx], rax
    invoke  wsprintfA, txt, fmt_rank_mb, [tmp_idx], rsi, qword [r14 + rdi*8]
    lea  rax, [txt]
    invoke  SendDlgItemMessage, rbx, IDC_E_PC_LIST, LB_ADDSTRING, 0, rax

.next:
    inc  rdi
    jmp  .loop
.done:
    ret
endp


; ==============================================================
; store_history_4
;   rcx = pct CPU  rdx = pct RAM  r8 = pct Disco  r9 = pct GPU
; Guarda una nueva lectura en los buffers circulares (4 recursos)
; ==============================================================
store_history_4:
    push rbx
    movzx rbx, byte [hist_idx]
    cmp   rbx, 30
    jl    .sh4_ok
    xor   rbx, rbx
.sh4_ok:
    ; Guardar los 4 valores en los arrays
    mov   byte [cpu_hist + rbx], cl    ; pct CPU (byte bajo de rcx)
    mov   byte [ram_hist + rbx], dl    ; pct RAM
    mov   byte [dsk_hist + rbx], r8b   ; pct Disco
    mov   byte [gpu_hist + rbx], r9b   ; pct GPU
    ; Avanzar indice
    inc   rbx
    cmp   rbx, 30
    jl    .sh4_no_wrap
    xor   rbx, rbx
.sh4_no_wrap:
    mov   byte [hist_idx], bl
    pop   rbx
    ret

; ==============================================================
; store_history (legacy para compatibilidad)
;   rcx = pct CPU  rdx = pct RAM  r8 = pct Disco
; ==============================================================
store_history:
    push rbx
    movzx rbx, byte [hist_idx]
    cmp   rbx, 30
    jl    .sh_ok
    xor   rbx, rbx
.sh_ok:
    ; Guardar los 3 valores en los arrays
    mov   byte [cpu_hist + rbx], cl    ; pct CPU (byte bajo de rcx)
    mov   byte [ram_hist + rbx], dl    ; pct RAM
    mov   byte [dsk_hist + rbx], r8b  ; pct Disco
    ; Avanzar indice
    inc   rbx
    cmp   rbx, 30
    jl    .sh_no_wrap
    xor   rbx, rbx
.sh_no_wrap:
    mov   byte [hist_idx], bl
    pop   rbx
    ret


; ==============================================================
; GaugeProc  -  WndProc para barras graficas GDI personalizadas
; Dibuja una barra coloreada segun el porcentaje.
; El valor se obtiene del IDC del control para mapear a variables
; globales (ram_pct, d_pct, cpu_pct, etc.)
;
; Colores dinamicos:
;   0-59%  → Verde  CLR_BAR_GREEN
;   60-79% → Ambar  CLR_BAR_AMBER
;   80-100%→ Rojo   CLR_BAR_RED
; ==============================================================
proc GaugeProc uses rbx rsi rdi
    ; rcx=hwnd, rdx=msg, r8=wParam, r9=lParam
    mov   rbx, rcx

    cmp   edx, WM_ERASEBKGND
    je    .g_erase
    cmp   edx, WM_PAINT
    je    .g_paint
    invoke  DefWindowProc, rcx, rdx, r8, r9
    jmp   .g_done

.g_erase:
    mov   eax, 1       ; manejo propio del fondo: sin relleno automatico
    jmp   .g_done

.g_paint:
    ; 1. Obtener el IDC para mapear al valor global correspondiente
    invoke  GetWindowLongA, rbx, GWL_ID   ; rax = IDC
    mov   rsi, rax     ; rsi = IDC

    ; Mapear IDC → variable global de porcentaje
    cmp   rsi, IDC_A_DET_RBAR; je .gv_dr
    je    .gv_dr
    cmp   rsi, IDC_A_DET_DBAR; je .gv_dd
    je    .gv_dd
    cmp   rsi, IDC_E_BAR0; je .gv_e0
    je    .gv_e0
    cmp   rsi, IDC_E_BAR1; je .gv_e1
    je    .gv_e1
    cmp   rsi, IDC_E_BAR2; je .gv_e2
    je    .gv_e2
    cmp   rsi, IDC_E_BAR3; je .gv_e3
    je    .gv_e3
    xor   rdi, rdi
    jmp   .gv_got

.gv_ram:
    mov  rdi, [ram_pct]
    jmp  .gv_got
.gv_dis:
    mov  rdi, [d_pct]
    jmp  .gv_got
.gv_dr:
    mov  rdi, [det_ram_pct]
    jmp  .gv_got
.gv_dd:
    mov  rdi, [det_dsk_pct]
    jmp  .gv_got
.gv_e0:
    mov  rdi, [es_pct0]
    jmp  .gv_got
.gv_e1:
    mov  rdi, [es_pct1]
    jmp  .gv_got
.gv_e2:
    mov  rdi, [es_pct2]
    jmp  .gv_got
.gv_e3:
    mov  rdi, [es_pct3]

.gv_got:
    ; rdi = valor (0-100)

    ; 2. Iniciar pintura
    invoke  BeginPaint, rbx, g_ps    ; rax = HDC
    mov   [g_hdc], rax

    ; 3. Obtener dimensiones del control
    invoke  GetClientRect, rbx, g_crect

    ; 4. Fondo completo del control (color oscuro)
    invoke  CreateSolidBrush, CLR_BG_GAUGE
    invoke  FillRect, [g_hdc], g_crect, rax
    invoke  DeleteObject, rax

    ; Pista de la barra (rectangulo ligeramente mas claro, con margen 3px)
    mov   dword [g_frect + 0], 3
    mov   dword [g_frect + 4], 3
    mov   eax, dword [g_crect + 8]   ; right
    sub   eax, 3
    mov   dword [g_frect + 8], eax
    mov   eax, dword [g_crect + 12]  ; bottom
    sub   eax, 3
    mov   dword [g_frect + 12], eax
    invoke  CreateSolidBrush, CLR_BG_TRACK
    invoke  FillRect, [g_hdc], g_frect, rax
    invoke  DeleteObject, rax

    ; 5. Calcular ancho llenado: fill_w = (track_w * valor) / 100
    mov   rax, qword [g_crect + 8]    ; width total
    sub   rax, 6                       ; descontar margenes
    imul  rax, rdi                     ; * valor
    xor   edx, edx
    mov   rcx, 100
    div   rcx                          ; rax = ancho lleno
    mov   [g_val], rax

    ; 6. Elegir color segun porcentaje
    cmp   rdi, 80
    jge   .gc_red
    cmp   rdi, 60
    jge   .gc_amber
    ; Verde (0-59%): rendimiento optimo
    invoke  CreateSolidBrush, CLR_BAR_GREEN
    jmp   .gc_fill
.gc_amber:
    ; Ambar (60-79%): atencion
    invoke  CreateSolidBrush, CLR_BAR_AMBER
    jmp   .gc_fill
.gc_red:
    ; Rojo (>=80%): critico
    invoke  CreateSolidBrush, CLR_BAR_RED

.gc_fill:
    ; Dibujar la porcion llena (con margenes de 4px)
    mov   dword [g_frect + 0], 4
    mov   dword [g_frect + 4], 4
    ; right = 4 + fill_w (pero no mas que track_right-4)
    mov   rax, [g_val]
    add   rax, 4
    mov   rcx, qword [g_crect + 8]
    sub   rcx, 4
    cmp   rax, rcx
    jle   .gc_clip_ok
    mov   rax, rcx
.gc_clip_ok:
    mov   dword [g_frect + 8], eax
    mov   eax, dword [g_crect + 12]
    sub   eax, 4
    mov   dword [g_frect + 12], eax
    invoke  FillRect, [g_hdc], g_frect, rax
    invoke  DeleteObject, rax

    ; 7. Texto del porcentaje centrado en la barra
    invoke  SelectObject, [g_hdc], [hFontBold]
    cmp   rdi, 50
    jl    .g_text_black
    invoke  SetTextColor, [g_hdc], CLR_WHITE_TXT
    jmp   .g_text_ready
.g_text_black:
    invoke  SetTextColor, [g_hdc], CLR_BLACK_TXT
.g_text_ready:
    invoke  SetBkMode,    [g_hdc], 1   ; TRANSPARENT
    invoke  wsprintfA, g_txt, _pct_fmt, rdi
    ; Calcular rect centrado para el texto
    invoke  DrawTextA, [g_hdc], g_txt, -1, g_crect, DT_CENTER+DT_VCENTER+DT_SINGLELINE

    ; 8. Terminar pintura
    invoke  EndPaint, rbx, g_ps
    xor   eax, eax

.g_done:
    ret
endp


; ==============================================================
; GraphProc  -  WndProc para graficas de linea GDI en tiempo real
; Dibuja el historial circular de 30 lecturas como polilinea GDI.
; IDC_M_HIST_CPU → cpu_hist[], IDC_M_HIST_RAM → ram_hist[]
; ==============================================================
proc GraphProc uses rbx rsi rdi

    mov   rbx, rcx    ; rcx = hwnd

    cmp   edx, WM_ERASEBKGND
    je    .gr_erase
    cmp   edx, WM_PAINT
    je    .gr_paint
    invoke  DefWindowProc, rcx, rdx, r8, r9
    jmp   .gr_done

.gr_erase:
    mov   eax, 1
    jmp   .gr_done

.gr_paint:
    ; Determinar array de historial y color segun IDC
    invoke  GetWindowLongA, rbx, GWL_ID
    cmp   rax, IDC_M_HIST_CPU
    je    .gr_cpu
    cmp   rax, IDC_M_HIST_RAM
    je    .gr_ram
    cmp   rax, IDC_M_HIST_DSK
    je    .gr_dsk
    cmp   rax, IDC_M_HIST_GPU
    je    .gr_gpu
    ; Por defecto: RAM
    lea   rsi, [ram_hist]
    mov   qword [gr_color], CLR_GRAPH_RAM
    jmp   .gr_paint2
.gr_cpu:
    lea   rsi, [cpu_hist]
    mov   qword [gr_color], CLR_GRAPH_CPU
    jmp   .gr_paint2
.gr_ram:
    lea   rsi, [ram_hist]
    mov   qword [gr_color], CLR_GRAPH_RAM
    jmp   .gr_paint2
.gr_dsk:
    lea   rsi, [dsk_hist]
    mov   qword [gr_color], CLR_GRAPH_DSK
    jmp   .gr_paint2
.gr_gpu:
    lea   rsi, [gpu_hist]
    mov   qword [gr_color], CLR_GRAPH_GPU

.gr_paint2:
    invoke  BeginPaint, rbx, gr_ps
    mov   [gr_hdc], rax

    invoke  GetClientRect, rbx, gr_crect

    ; Fondo muy oscuro del grafico
    invoke  CreateSolidBrush, CLR_GRAPH_BG
    invoke  FillRect, [gr_hdc], gr_crect, rax
    invoke  DeleteObject, rax

    ; Etiqueta del grafico: CPU / RAM / DISCO
    invoke  SelectObject, [gr_hdc], [hFontBody]
    invoke  SetTextColor, [gr_hdc], CLR_WHITE_TXT
    invoke  SetBkMode, [gr_hdc], TRANSPARENT
    invoke  GetWindowLongA, rbx, GWL_ID
    cmp   rax, IDC_M_HIST_CPU
    je    .gr_label_cpu
    cmp   rax, IDC_M_HIST_RAM
    je    .gr_label_ram
    cmp   rax, IDC_M_HIST_DSK
    je    .gr_label_dsk
    cmp   rax, IDC_M_HIST_GPU
    je    .gr_label_gpu
    lea   rdx, [_hist_ram_pfx]
    jmp   .gr_draw_label
.gr_label_cpu:
    lea   rdx, [_hist_cpu_pfx]
    jmp   .gr_draw_label
.gr_label_ram:
    lea   rdx, [_hist_ram_pfx]
    jmp   .gr_draw_label
.gr_label_dsk:
    lea   rdx, [_hist_dsk_pfx]
    jmp   .gr_draw_label
.gr_label_gpu:
    lea   rdx, [_hist_gpu_pfx]
.gr_draw_label:
    invoke  DrawTextA, [gr_hdc], rdx, -1, gr_crect, DT_LEFT+DT_TOP+DT_SINGLELINE

    ; Lineas de grid horizontales en 25%, 50%, 75%
    invoke  CreatePen, PS_SOLID, 1, CLR_GRID
    invoke  SelectObject, [gr_hdc], rax
    mov   [gr_old_pen], rax

    mov   eax, dword [gr_crect + 12]  ; height
    ; y_75 = height - (height*75/100)
    mov   rcx, rax
    imul  rax, 75
    xor   edx, edx
    mov   r8, 100
    div   r8
    mov   rdi, rcx
    sub   rdi, rax    ; rdi = y for 75% line
    invoke  MoveToEx, [gr_hdc], 0, rdi, NULL
    invoke  LineTo,   [gr_hdc], dword [gr_crect + 8], rdi

    mov   eax, dword [gr_crect + 12]
    imul  rax, 50
    xor   edx, edx
    mov   rcx, 100
    div   rcx
    mov   edi, dword [gr_crect + 12]
    sub   rdi, rax
    invoke  MoveToEx, [gr_hdc], 0, rdi, NULL
    invoke  LineTo,   [gr_hdc], dword [gr_crect + 8], rdi

    mov   eax, dword [gr_crect + 12]
    imul  rax, 25
    xor   edx, edx
    mov   rcx, 100
    div   rcx
    mov   edi, dword [gr_crect + 12]
    sub   rdi, rax
    invoke  MoveToEx, [gr_hdc], 0, rdi, NULL
    invoke  LineTo,   [gr_hdc], dword [gr_crect + 8], rdi

    ; Restaurar pluma anterior y borrar la de grid
    invoke  SelectObject, [gr_hdc], [gr_old_pen]
    invoke  DeleteObject, rax

    ; Construir POINT[30] para Polyline - orden cronologico (mas viejo primero)
    ; rbx = hwnd fue preservado (proc uses rbx), NO lo sobreescribimos.
    ; Guardamos hist_idx en g_val (reusado como temp BSS) para el loop.
    movzx rax, byte [hist_idx]
    mov   [g_val], rax             ; indice de inicio del buffer circular

    xor   rdi, rdi                 ; rdi = i (0..29), counter del loop

.gr_pts_loop:
    cmp   rdi, 30
    je    .gr_pts_done

    ; Indice circular: (start + i) % 30
    mov   rax, [g_val]
    add   rax, rdi
    cmp   rax, 30
    jl    .gr_nowrap
    sub   rax, 30
.gr_nowrap:
    movzx rax, byte [rsi + rax]   ; val = history[circular_idx] (0-100)

    ; x = (width-1) * i / 29  (primera muestra siempre x=0)
    test  rdi, rdi
    jnz   .gr_calc_x
    xor   ecx, ecx               ; i=0: x=0
    jmp   .gr_x_done
.gr_calc_x:
    push  rax                     ; guardar val
    mov   eax, dword [gr_crect + 8]
    dec   rax                     ; width - 1
    imul  rax, rdi                ; (width-1) * i
    xor   edx, edx
    mov   rcx, 29
    div   rcx                     ; rax = x
    mov   rcx, rax
    pop   rax                     ; restaurar val
.gr_x_done:
    ; rcx = x, rax = val

    ; y = height - val * height / 100
    push  rcx                     ; guardar x
    push  rdi                     ; guardar i (rdi se usa en div)
    movzx rcx, word [gr_crect + 12]   ; height (lo necesitamos como 64-bit)
    ; gr_crect+12 es bottom de la RECT (cliente y=0 hasta bottom=height)
    ; En GetClientRect, bottom = height del control
    mov   rcx, 0
    mov   ecx, dword [gr_crect + 12]  ; height del control
    imul  rax, rcx                     ; val * height
    xor   edx, edx
    push  rcx                          ; guardar height
    mov   rcx, 100
    div   rcx                          ; rax = val * height / 100
    pop   r8                           ; r8 = height
    sub   r8, rax                      ; y = height - scaled
    pop   rdi                     ; restaurar i
    pop   rcx                     ; restaurar x

    ; Guardar POINT{x, y} en gr_points[i * 8]
    lea   rax, [gr_points]
    push  rdi
    imul  rdi, 8
    mov   dword [rax + rdi],     ecx   ; .x
    mov   dword [rax + rdi + 4], r8d   ; .y
    pop   rdi

    inc   rdi
    jmp   .gr_pts_loop

.gr_pts_done:
    ; Dibujar polilinea con el color del recurso (CPU=azul, RAM=verde)
    invoke  CreatePen, PS_SOLID, 2, [gr_color]
    invoke  SelectObject, [gr_hdc], rax
    mov   [gr_old_pen], rax
    invoke  Polyline, [gr_hdc], gr_points, 30
    invoke  SelectObject, [gr_hdc], [gr_old_pen]
    invoke  DeleteObject, rax

    invoke  EndPaint, rbx, gr_ps   ; rbx = hwnd (intacto por 'uses rbx')
    xor   eax, eax

.gr_done:
    ret
endp


; -------------------------------------------------------
; WndProc
; -------------------------------------------------------
proc WndProc uses rbx rsi rdi, hwnd, wmsg, wparam, lparam

    cmp  edx, WM_CREATE
    je   .on_create
    cmp  edx, WM_COMMAND
    je   .on_command
    cmp  edx, WM_TIMER
    je   .on_timer
    cmp  edx, WM_ERASEBKGND
    je   .on_erase
    cmp  edx, WM_CTLCOLORSTATIC
    je   .on_ctlcolor
    cmp  edx, WM_CTLCOLORBTN
    je   .on_ctlcolorbtn
    cmp  edx, WM_DESTROY
    je   .on_destroy

.default:
    invoke  DefWindowProc, rcx, rdx, r8, r9
    jmp    .fin

; ---- WM_ERASEBKGND: pinta el fondo dividido sidebar/contenido ----
.on_erase:
    ; r8 = wParam = HDC
    mov  [tmp_hdc], r8
    ; Sidebar izquierda (fondo oscuro)
    mov  dword [erase_rect + 0],  0
    mov  dword [erase_rect + 4],  0
    mov  dword [erase_rect + 8],  NAV_W
    mov  dword [erase_rect + 12], WIN_H
    invoke  FillRect, [tmp_hdc], erase_rect, [hBrushSide]
    ; Franja de acento
    mov  dword [erase_rect + 0],  NAV_W
    mov  dword [erase_rect + 8],  NAV_W + 3
    invoke  FillRect, [tmp_hdc], erase_rect, [hBrushAccent]
    ; Area de contenido (blanco-frio #F8F9FA)
    mov  dword [erase_rect + 0],  NAV_W + 3
    mov  dword [erase_rect + 8],  WIN_W
    invoke  FillRect, [tmp_hdc], erase_rect, [hBrushContent]
    ; Linea separadora sutil entre contenido y franja de acento
    mov  dword [erase_rect + 0],  NAV_W + 3
    mov  dword [erase_rect + 8],  NAV_W + 4
    invoke  FillRect, [tmp_hdc], erase_rect, [hBrushAccent]
    mov  eax, 1
    jmp  .fin

; ---- WM_CTLCOLORSTATIC: colores de etiquetas y valores ----
.on_ctlcolor:
    mov  [tmp_hdc],       r8
    mov  [tmp_hwnd_ctrl], r9
    invoke  GetDlgCtrlID, [tmp_hwnd_ctrl]

    ; IDC 100-199 (nav title + items): sidebar oscuro, texto claro
    cmp  rax, 100
    jl   .clr_content
    cmp  rax, 200
    jge  .clr_content
    invoke  SetBkColor,   [tmp_hdc], CLR_SIDEBAR
    invoke  SetTextColor, [tmp_hdc], CLR_NAV_TXT
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushSide]
    jmp  .fin

    ; IDC 300-340 labels (campo "label:"): gris tenue, texto gris
.clr_label:
    invoke  SetBkColor,   [tmp_hdc], CLR_WHITE
    invoke  SetTextColor, [tmp_hdc], CLR_LABEL
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

.clr_content:
    ; --- Titulos de seccion: fondo azulado tenue + texto azul bold ---
    cmp  rax, 301; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 351; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 354; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 357; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 361; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 381; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 385; je .clr_header_sec
    je   .clr_header_sec
    cmp  rax, 401; je .clr_header_sec  ; estad HDR
    je   .clr_header_sec
    cmp  rax, 415; je .clr_header_sec  ; estad LBL_PCS
    je   .clr_header_sec
    cmp  rax, 416; je .clr_header_sec  ; estad LBL_DIS
    je   .clr_header_sec
    cmp  rax, 421; je .clr_header_sec  ; hist HDR
    je   .clr_header_sec
    jmp  .clr_by_type

.clr_header_sec:
    ; Header de seccion: fondo azul palido, texto azul acento
    invoke  SetBkColor,   [tmp_hdc], 00F0F4F8h
    invoke  SetTextColor, [tmp_hdc], CLR_HDRTEXT
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushHeader]
    jmp  .fin

    ; ---- Barras ASCII del Monitoreo: color segun nivel ----
    cmp  rax, IDC_M_BAR_RAM; je .cbar_ram
    je   .cbar_ram
    cmp  rax, IDC_M_BAR_DIS; je .cbar_dis
    je   .cbar_dis
    cmp  rax, IDC_M_BAR_CPU; je .cbar_cpu
    je   .cbar_cpu
    ; Barras ASCII del detalle de Analizar
    cmp  rax, IDC_A_DET_RBAR; je .cbar_det_r
    je   .cbar_det_r
    cmp  rax, IDC_A_DET_DBAR; je .cbar_det_d
    je   .cbar_det_d
    ; Historial: texto azul oscuro
    cmp  rax, IDC_M_HIST_CPU; je .cbar_hist
    je   .cbar_hist
    cmp  rax, IDC_M_HIST_RAM; je .cbar_hist
    je   .cbar_hist
    ; Barras ASCII de Estadísticas (colores fijos por categoria)
    cmp  rax, IDC_E_BAR0; je .cbar_exc
    je   .cbar_exc
    cmp  rax, IDC_E_BAR1; je .cbar_bue
    je   .cbar_bue
    cmp  rax, IDC_E_BAR2; je .cbar_reg
    je   .cbar_reg
    cmp  rax, IDC_E_BAR3; je .cbar_cri
    je   .cbar_cri
    jmp  .clr_by_type

.cbar_ram:
    mov  rax, [ram_pct]
    jmp  .cbar_by_pct
.cbar_dis:
    mov  rax, [d_pct]
    jmp  .cbar_by_pct
.cbar_cpu:
    mov  rax, [cpu_pct]
    jmp  .cbar_by_pct
.cbar_det_r:
    mov  rax, [det_ram_pct]
    jmp  .cbar_by_pct
.cbar_det_d:
    mov  rax, [det_dsk_pct]
    jmp  .cbar_by_pct

.cbar_by_pct:
    ; Verde <60%, Naranja 60-84%, Rojo >=85%
    cmp  rax, 85
    jge  .cbar_rojo
    cmp  rax, 60
    jge  .cbar_naranja
    ; verde
    invoke  SetTextColor, [tmp_hdc], 0000AA00h
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin
.cbar_naranja:
    invoke  SetTextColor, [tmp_hdc], 00005FA0h
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin
.cbar_rojo:
    invoke  SetTextColor, [tmp_hdc], 000000BBh
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

.cbar_exc:
    invoke  SetTextColor, [tmp_hdc], 0000AA00h   ; verde
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin
.cbar_bue:
    invoke  SetTextColor, [tmp_hdc], 00A06000h   ; azul-verde
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin
.cbar_reg:
    invoke  SetTextColor, [tmp_hdc], 00007FFFh   ; naranja
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin
.cbar_cri:
    invoke  SetTextColor, [tmp_hdc], 000000BBh   ; rojo
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

.cbar_hist:
    ; Historial: morado/azul oscuro
    invoke  SetTextColor, [tmp_hdc], 00800080h
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

.clr_by_type:
    ; --- Labels (IDC par 302-338): texto gris calido ---
    cmp  rax, 302
    jl   .clr_value
    cmp  rax, 339
    jge  .clr_value
    test rax, 1
    jnz  .clr_value
    ; Es un label (par) -> color gris
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetTextColor, [tmp_hdc], CLR_LABEL
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

.clr_value:
    ; Valores, FPU score, info: fondo claro, texto oscuro-azulado
    invoke  SetBkColor,   [tmp_hdc], CLR_CONTENT_BG
    invoke  SetTextColor, [tmp_hdc], CLR_DARK_TXT
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushContent]
    jmp  .fin

; ---- WM_CTLCOLORBTN: fondo de botones de navegacion ----
.on_ctlcolorbtn:
    ; Guardar r8 (HDC) y r9 (hWnd del control) ANTES de invoke
    ; porque GetDlgCtrlID destruye r8 y r9 (caller-saved en Win64)
    mov  [tmp_hdc],       r8
    mov  [tmp_hwnd_ctrl], r9
    invoke  GetDlgCtrlID, [tmp_hwnd_ctrl]   ; rax = IDC del control
    cmp  rax, 100
    jl   .btn_default
    cmp  rax, 200
    jge  .btn_default
    ; Boton de navegacion: integrar con sidebar oscuro
    invoke  SetBkColor,   [tmp_hdc], CLR_SIDEBAR
    invoke  SetTextColor, [tmp_hdc], CLR_NAV_TXT
    invoke  SetBkMode,    [tmp_hdc], OPAQUE_MODE
    mov  rax, [hBrushSide]
    jmp  .fin
.btn_default:
    ; No es boton de nav: dejar que DefWindowProc lo maneje
    ; Usar valores guardados en memoria ya que r8/r9 estan destruidos
    invoke  DefWindowProc, [main_hwnd], WM_CTLCOLORBTN, [tmp_hdc], [tmp_hwnd_ctrl]
    jmp  .fin

; ==================== WM_CREATE =====================
.on_create:
    mov  rbx, rcx
    mov  [main_hwnd], rbx

    invoke  InitCommonControls

    ; ==== Pinceles para la paleta profesional ====
    invoke  CreateSolidBrush, CLR_SIDEBAR
    mov    [hBrushSide], rax
    invoke  CreateSolidBrush, CLR_CONTENT_BG    ; fondo ligeramente frio
    mov    [hBrushContent], rax
    invoke  CreateSolidBrush, CLR_ACCENT
    mov    [hBrushAccent], rax
    invoke  CreateSolidBrush, 00F0F4F8h          ; fondo azulado tenue para headers
    mov    [hBrushHeader], rax

    ; ==== Fuentes Segoe UI (tipografia moderna Windows 10/11) ====
    ; CreateFontA: nHeight, nWidth, nEsc, nOrient, fnWeight, Italic,
    ;              Under, Strike, CharSet, OutPrec, ClipPrec, Quality,
    ;              PitchFamily, FaceName
    ; CLEARTYPE_QUALITY = 5 para maxima claridad en pantallas LCD/OLED
    ; FW_NORMAL=400, FW_SEMIBOLD=600, FW_BOLD=700

    ; Fuente de etiquetas - Segoe UI 10pt Normal
    invoke  CreateFontA, -13, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, _segoe_ui
    mov    [hFontBody], rax

    ; Fuente de valores - Segoe UI 10pt Bold (datos resaltados)
    invoke  CreateFontA, -13, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 5, 0, _segoe_ui
    mov    [hFontBold], rax

    ; Fuente de titulos de seccion - Segoe UI 13pt Bold
    invoke  CreateFontA, -17, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 5, 0, _segoe_ui
    mov    [hFontHeader], rax

    ; Fuente de navegacion - Segoe UI 11pt SemiBold
    invoke  CreateFontA, -15, 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 5, 0, _segoe_ui
    mov    [hFontNav], rax

    ; ---- NAVEGACION (izquierda, IDC < 300) ----
    ; BS_FLAT (8000h) hace botones planos que se ven bien en sidebar oscuro

    invoke  CreateWindowEx, 0, _ST, _nav_titulo, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            4, 8, NAV_W-8, 36, rbx, IDC_NAV_TITULO, [wc.hInstance], NULL

    ; Botones de navegacion como STATIC+SS_NOTIFY+SS_CENTER:
    ; SS_NOTIFY (100h) habilita WM_COMMAND al hacer click
    ; SS_CENTER (01h) centra el texto
    ; WM_CTLCOLORSTATIC maneja fondo oscuro + texto claro para IDC 100-199
    invoke  CreateWindowEx, 0, _ST, _btn_diag, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, 52, NAV_W-8, 40, rbx, IDC_NAV_DIAG, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _btn_mon, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, 98, NAV_W-8, 40, rbx, IDC_NAV_MON, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _btn_anal, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, 144, NAV_W-8, 40, rbx, IDC_NAV_ANAL, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _btn_estad, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, 190, NAV_W-8, 40, rbx, IDC_NAV_ESTAD, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _btn_hist, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, 236, NAV_W-8, 40, rbx, IDC_NAV_HIST, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _btn_salir, \
            WS_CHILD+WS_VISIBLE+101h, \
            4, WIN_H-80, NAV_W-8, 40, rbx, IDC_NAV_SALIR, [wc.hInstance], NULL
    ; La franja de acento la pinta WM_ERASEBKGND directamente (sin control estatic)

    ; ==================== DIAGNOSTICO ====================
    ; (creados sin WS_VISIBLE -> ocultos hasta seleccionar)
    invoke  CreateWindowEx, 0, _ST, _hdr_diag, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y, CT_W, 24, rbx, IDC_D_HDR, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_pc, \
            WS_CHILD, CT_X+4, CT_Y+32, 110, 22, rbx, IDC_D_LBL_PC, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+32, CT_W-125, 22, rbx, IDC_D_VAL_PC, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_usr, \
            WS_CHILD, CT_X+4, CT_Y+60, 110, 22, rbx, IDC_D_LBL_USR, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+60, CT_W-125, 22, rbx, IDC_D_VAL_USR, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_cpu, \
            WS_CHILD, CT_X+4, CT_Y+88, 110, 22, rbx, IDC_D_LBL_CPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+88, CT_W-125, 22, rbx, IDC_D_VAL_CPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_ramt, \
            WS_CHILD, CT_X+4, CT_Y+116, 110, 22, rbx, IDC_D_LBL_RAMT, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+116, CT_W-125, 22, rbx, IDC_D_VAL_RAMT, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_raml, \
            WS_CHILD, CT_X+4, CT_Y+144, 110, 22, rbx, IDC_D_LBL_RAML, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+144, CT_W-125, 22, rbx, IDC_D_VAL_RAML, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_ramp, \
            WS_CHILD, CT_X+4, CT_Y+172, 110, 22, rbx, IDC_D_LBL_RAMP, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+172, CT_W-125, 22, rbx, IDC_D_VAL_RAMP, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_disc, \
            WS_CHILD, CT_X+4, CT_Y+200, 110, 22, rbx, IDC_D_LBL_DISC, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+200, CT_W-125, 22, rbx, IDC_D_VAL_DISC, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_os, \
            WS_CHILD, CT_X+4, CT_Y+228, 110, 22, rbx, IDC_D_LBL_OS, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+228, CT_W-125, 22, rbx, IDC_D_VAL_OS, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_gpu, \
            WS_CHILD, CT_X+4, CT_Y+256, 110, 22, rbx, IDC_D_LBL_GPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+256, CT_W-125, 22, rbx, IDC_D_VAL_GPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_placa, \
            WS_CHILD, CT_X+4, CT_Y+284, 110, 22, rbx, IDC_D_LBL_PLACA, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+284, CT_W-125, 22, rbx, IDC_D_VAL_PLACA, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_bios, \
            WS_CHILD, CT_X+4, CT_Y+312, 110, 22, rbx, IDC_D_LBL_BIOS, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+312, CT_W-125, 22, rbx, IDC_D_VAL_BIOS, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_tec, \
            WS_CHILD, CT_X+4, CT_Y+340, 110, 22, rbx, IDC_D_LBL_TEC, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+340, CT_W-125, 22, rbx, IDC_D_VAL_TEC, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_cat, \
            WS_CHILD, CT_X+4, CT_Y+368, 110, 22, rbx, IDC_D_LBL_CAT, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+368, CT_W-125, 22, rbx, IDC_D_VAL_CAT, [wc.hInstance], NULL

    ; Controles para el Puntaje de Salud calculado por FPU x87
    invoke  CreateWindowEx, 0, _ST, _lbl_score, \
            WS_CHILD, CT_X+4, CT_Y+396, 110, 22, rbx, IDC_D_LBL_SCORE, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+120, CT_Y+396, CT_W-125, 22, rbx, IDC_D_VAL_SCORE, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _BT, _btn_guardar, \
            WS_CHILD, CT_X+4, CT_Y+434, 200, 34, rbx, IDC_D_BTN_GUAR, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+215, CT_Y+438, CT_W-220, 26, rbx, IDC_D_LBL_GUAR, [wc.hInstance], NULL

    ; ==================== MONITOREO ====================
    invoke  CreateWindowEx, 0, _ST, _hdr_mon, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y, CT_W, 24, rbx, IDC_M_ESTADO+1, [wc.hInstance], NULL
    ; IDC 361: dentro del rango de monitoreo (351-375) -> correcto

    ; RAM: header (STATIC) + grafico de picos + info (STATIC)
    invoke  CreateWindowEx, 0, _ST, _hdr_ram, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+30, CT_W, 16, rbx, IDC_M_HDR_RAM, [wc.hInstance], NULL
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _graph_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+48, CT_W, 50, rbx, IDC_M_HIST_RAM, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+100, CT_W, 16, rbx, IDC_M_VAL_RAM, [wc.hInstance], NULL

    ; DISCO: header + grafico de picos + info
    invoke  CreateWindowEx, 0, _ST, _hdr_disco, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+120, CT_W, 16, rbx, IDC_M_HDR_DIS, [wc.hInstance], NULL
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _graph_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+138, CT_W, 50, rbx, IDC_M_HIST_DSK, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+190, CT_W, 16, rbx, IDC_M_VAL_DIS, [wc.hInstance], NULL

    ; CPU: header + grafico de picos + info
    invoke  CreateWindowEx, 0, _ST, _hdr_cpu, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+210, CT_W, 16, rbx, IDC_M_HDR_CPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _graph_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+228, CT_W, 50, rbx, IDC_M_HIST_CPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+280, CT_W, 16, rbx, IDC_M_VAL_CPU, [wc.hInstance], NULL

    ; GPU: header + grafico de picos + info
    invoke  CreateWindowEx, 0, _ST, _hdr_gpu, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+300, CT_W, 16, rbx, IDC_M_HDR_GPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _graph_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+318, CT_W, 50, rbx, IDC_M_HIST_GPU, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+370, CT_W, 16, rbx, IDC_M_VAL_GPU, [wc.hInstance], NULL

    ; ESTADO GENERAL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y+392, CT_W, 22, rbx, IDC_M_ESTADO, [wc.hInstance], NULL

    ; ==================== ANALIZAR ====================
    invoke  CreateWindowEx, 0, _ST, _hdr_anal, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y, CT_W, 24, rbx, IDC_A_HDR, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+30, CT_W, 20, rbx, IDC_A_INFO, [wc.hInstance], NULL
    ; Listbox reducido para dar espacio al panel de detalles
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _LB, _empty, \
            WS_CHILD+WS_VSCROLL+LBS_NOTIFY, \
            CT_X, CT_Y+54, CT_W, 180, rbx, IDC_A_LIST, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _BT, _btn_ref, \
            WS_CHILD, \
            CT_X, CT_Y+242, 160, 28, rbx, IDC_A_BTN_REF, [wc.hInstance], NULL

    ; ---- PANEL DETALLE DEL REPORTE SELECCIONADO ----
    invoke  CreateWindowEx, 0, _ST, _det_hdr, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y+280, CT_W, 22, rbx, IDC_A_DET_HDR, [wc.hInstance], NULL
    ; Etiquetas con IDC en rango 381-399 para que show_panel las oculte
    ; cuando NO estamos en el panel Analizar
    ; PC
    invoke  CreateWindowEx, 0, _ST, _det_lbl_pc, \
            WS_CHILD, CT_X+4, CT_Y+310, 90, 20, rbx, IDC_A_DET_LPC, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+100, CT_Y+310, CT_W-105, 20, rbx, IDC_A_DET_PC, [wc.hInstance], NULL
    ; Fecha
    invoke  CreateWindowEx, 0, _ST, _det_lbl_ts, \
            WS_CHILD, CT_X+4, CT_Y+336, 90, 20, rbx, IDC_A_DET_LTS, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+100, CT_Y+336, CT_W-105, 20, rbx, IDC_A_DET_TS, [wc.hInstance], NULL
    ; Categoria
    invoke  CreateWindowEx, 0, _ST, _det_lbl_cat, \
            WS_CHILD, CT_X+4, CT_Y+362, 90, 20, rbx, IDC_A_DET_LCAT, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD, CT_X+100, CT_Y+362, CT_W-105, 20, rbx, IDC_A_DET_CAT, [wc.hInstance], NULL
    ; RAM: label informativo (STATIC) + barra GDI (TG_Gauge)
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X+4, CT_Y+392, CT_W-8, 16, rbx, IDC_A_DET_RVAL, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X+4, CT_Y+411, CT_W-8, 26, rbx, IDC_A_DET_RBAR, [wc.hInstance], NULL
    ; DISCO: label + barra GDI
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X+4, CT_Y+446, CT_W-8, 16, rbx, IDC_A_DET_DVAL, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X+4, CT_Y+465, CT_W-8, 26, rbx, IDC_A_DET_DBAR, [wc.hInstance], NULL

    ; ====== ESTADISTICAS - DASHBOARD VISUAL ======
    ; Titulo principal
    invoke  CreateWindowEx, 0, _ST, _hdr_estad, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y, CT_W, 28, rbx, IDC_E_HDR, [wc.hInstance], NULL

    ; Resumen total
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+34, CT_W, 38, rbx, IDC_E_TOTAL, [wc.hInstance], NULL

    ; Sub-header: Distribucion por categoria
    invoke  CreateWindowEx, 0, _ST, _e_lbl_dist, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+80, CT_W, 22, rbx, IDC_E_LBL_DIS, [wc.hInstance], NULL

    ; EXCELENTE: label + barra GDI verde
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+108, CT_W, 20, rbx, IDC_E_CAT0, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+130, CT_W, 24, rbx, IDC_E_BAR0, [wc.hInstance], NULL

    ; BUENO: label + barra GDI azul-verde
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+162, CT_W, 20, rbx, IDC_E_CAT1, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+184, CT_W, 24, rbx, IDC_E_BAR1, [wc.hInstance], NULL

    ; REGULAR: label + barra GDI naranja
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+216, CT_W, 20, rbx, IDC_E_CAT2, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+238, CT_W, 24, rbx, IDC_E_BAR2, [wc.hInstance], NULL

    ; CRITICO: label + barra GDI roja
    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+270, CT_W, 20, rbx, IDC_E_CAT3, [wc.hInstance], NULL
    invoke  CreateWindowEx, 0, _gauge_class, _empty, \
            WS_CHILD, \
            CT_X, CT_Y+292, CT_W, 24, rbx, IDC_E_BAR3, [wc.hInstance], NULL

    ; Sub-header: Lista de todos los equipos
    invoke  CreateWindowEx, 0, _ST, _e_lbl_pcs, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+326, CT_W, 22, rbx, IDC_E_LBL_PCS, [wc.hInstance], NULL

    ; Listbox con TODOS los equipos analizados (con detalles)
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _LB, _empty, \
            WS_CHILD+WS_VSCROLL+WS_HSCROLL+LBS_NOTIFY, \
            CT_X, CT_Y+352, CT_W, 210, rbx, IDC_E_PC_LIST, [wc.hInstance], NULL

    ; ==================== HISTORIAL ====================
    invoke  CreateWindowEx, 0, _ST, _hdr_hist, \
            WS_CHILD+SS_CENTER, \
            CT_X, CT_Y, CT_W, 24, rbx, IDC_H_HDR, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_hist_pcs, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+30, CT_W, 20, rbx, IDC_H_LBL_PCS, [wc.hInstance], NULL

    ; Listbox de equipos unicos (altura 110)
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _LB, _empty, \
            WS_CHILD+WS_VSCROLL+LBS_NOTIFY, \
            CT_X, CT_Y+52, CT_W, 110, rbx, IDC_H_PC_LIST, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _lbl_hist_rep, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+170, CT_W, 20, rbx, IDC_H_LBL_REP, [wc.hInstance], NULL

    ; Listbox de reportes del equipo seleccionado (altura 250)
    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, _LB, _empty, \
            WS_CHILD+WS_VSCROLL+WS_HSCROLL+LBS_NOTIFY, \
            CT_X, CT_Y+192, CT_W, 250, rbx, IDC_H_REP_LIST, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _BT, _btn_actualizar, \
            WS_CHILD, \
            CT_X, CT_Y+450, 160, 28, rbx, IDC_H_BTN_REF, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+490, CT_W, 20, rbx, IDC_H_STATS, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _ST, _empty, \
            WS_CHILD+SS_LEFT, \
            CT_X, CT_Y+516, CT_W, 40, rbx, IDC_H_INFO, [wc.hInstance], NULL

    ; ==== Aplicar fuentes Segoe UI a todos los controles ====
    ; Iteramos por los hijos con GetWindow/GW_HWNDNEXT y enviamos
    ; WM_SETFONT segun el tipo de control detectado por su IDC.
    invoke  GetWindow, rbx, GW_CHILD
    test  rax, rax
    jz    .fonts_done
    mov   rsi, rax          ; rsi = hwnd del primer hijo

.font_loop:
    invoke  GetDlgCtrlID, rsi          ; rax = IDC del control
    mov   rcx, [hFontBody]            ; fuente default: body

    ; IDC 100-106: items de navegacion -> fuente semi-bold
    cmp  rax, 100
    jl   .fset
    cmp  rax, 107
    jge  .fchk_hdr
    mov  rcx, [hFontNav]
    jmp  .fset

.fchk_hdr:
    ; Titulos principales de seccion (IDC inicial de cada panel)
    cmp  rax, 301; je .fhdr
    je   .fhdr
    cmp  rax, 361; je .fhdr   ; titulo del panel monitoreo
    je   .fhdr
    cmp  rax, 351; je .fhdr   ; sub-header RAM
    je   .fhdr
    cmp  rax, 354; je .fhdr   ; sub-header Disco
    je   .fhdr
    cmp  rax, 357; je .fhdr   ; sub-header CPU
    je   .fhdr
    cmp  rax, 381; je .fhdr
    je   .fhdr
    cmp  rax, 385; je .fhdr   ; detalle reporte header
    je   .fhdr
    cmp  rax, 401; je .fhdr
    je   .fhdr
    cmp  rax, 421; je .fhdr
    je   .fhdr
    cmp  rax, 422; je .fhdr   ; lbl_pcs hist
    je   .fhdr
    cmp  rax, 424; je .fhdr   ; lbl_rep hist
    je   .fhdr
    jmp  .fchk_val

.fhdr:
    mov  rcx, [hFontHeader]
    jmp  .fset

.fchk_val:
    ; Controles de VALOR (texto de datos): IDC impares en 303-339 y 324
    cmp  rax, 303
    jl   .fset             ; por debajo del rango diag -> body
    cmp  rax, 340
    jge  .fset
    ; Verificar si es un valor (IDC impar = valor; IDC par = label)
    test rax, 1
    jz   .fset             ; par = label -> body font
    ; impar = valor -> bold
    mov  rcx, [hFontBold]
    jmp  .fset

.fset:
    invoke  SendMessage, rsi, WM_SETFONT, rcx, 0

    invoke  GetWindow, rsi, GW_HWNDNEXT
    test  rax, rax
    jz    .fonts_done
    mov   rsi, rax
    jmp   .font_loop
.fonts_done:

    ; Mostrar panel de diagnostico al inicio
    mov  rcx, PANEL_DIAG
    call show_panel

    xor  eax, eax
    jmp  .fin

; ==================== WM_COMMAND ====================
.on_command:
    ; Guardar wParam completo ANTES de cualquier invoke que destruya r8.
    ; r8 = wParam al entrar: LOWORD=ID control, HIWORD=notificacion.
    mov  [saved_wparam], r8   ; guardar wParam completo en memoria
    movzx rsi, r8w            ; rsi = LOWORD(wParam) = ID del control

    cmp  rsi, IDC_NAV_DIAG
    je   .go_diag
    cmp  rsi, IDC_NAV_MON
    je   .go_mon
    cmp  rsi, IDC_NAV_ANAL
    je   .go_anal
    cmp  rsi, IDC_NAV_ESTAD
    je   .go_estad
    cmp  rsi, IDC_NAV_HIST
    je   .go_hist
    cmp  rsi, IDC_NAV_SALIR
    je   .go_salir
    cmp  rsi, IDC_D_BTN_GUAR
    je   .guardar_rep
    cmp  rsi, IDC_A_BTN_REF
    je   .refrescar

    ; Notificaciones de listboxes (LBN_SELCHANGE = HIWORD de wParam = 1)
    cmp  rsi, IDC_A_LIST
    je   .lbn_anal
    cmp  rsi, IDC_H_PC_LIST
    je   .lbn_hist
    cmp  rsi, IDC_H_BTN_REF
    je   .hist_refresh
    jmp  .default

.lbn_anal:
    mov  rax, [saved_wparam]
    shr  rax, 16
    cmp  rax, LBN_SELCHANGE
    jne  .default
    mov  rcx, [main_hwnd]
    call update_anal_detail
    jmp  .fin

.lbn_hist:
    mov  rax, [saved_wparam]
    shr  rax, 16
    cmp  rax, LBN_SELCHANGE
    jne  .default
    mov  rcx, [main_hwnd]
    call update_hist_detail
    jmp  .fin

.hist_refresh:
    mov  rcx, [main_hwnd]
    call update_hist
    jmp  .fin

.go_diag:
    mov  rcx, PANEL_DIAG
    call show_panel
    jmp  .fin

.go_mon:
    mov  rcx, PANEL_MON
    call show_panel
    jmp  .fin

.go_anal:
    mov  rcx, PANEL_ANAL
    call show_panel
    jmp  .fin

.go_estad:
    mov  rcx, PANEL_ESTAD
    call show_panel
    jmp  .fin

.go_hist:
    mov  rcx, PANEL_HIST
    call show_panel
    jmp  .fin

.go_salir:
    invoke  DestroyWindow, [main_hwnd]
    jmp  .fin

.guardar_rep:
    ; Crear carpeta reportes\ si no existe (ignorar error si ya existe)
    invoke  CreateDirectoryA, _rep_dir, NULL

    ; Obtener nombre de equipo y tick como sufijo unico
    mov  dword [pcbufsz], 28
    invoke  GetComputerNameA, pc_buf, pcbufsz
    invoke  GetTickCount64
    mov  [tick_save], rax          ; guardar antes de que el siguiente invoke lo pise
    invoke  wsprintfA, rep_path, fmt_reppath, pc_buf, [tick_save]

    ; Crear archivo binario
    invoke  CreateFileA, rep_path, GENERIC_WRITE, 0, NULL, \
            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .rep_fail
    mov   [tmp_hfile], rax
    ; Header: firma "SCAN", version 1, 1 registro
    mov   dword [rep_hdr + 0], 0x4E414353  ; 'SCAN'
    mov   dword [rep_hdr + 4], 1
    mov   dword [rep_hdr + 20], 1
    invoke  WriteFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    ; Llenar EquipoInfo completo con datos actuales del sistema
    xor   rax, rax
    mov   rcx, 200/8
    lea   rdi, [equipo_buf]
    rep   stosq                          ; limpiar los 200 bytes

    ; id_equipo = 1 (offset 0)
    mov   dword [equipo_buf], 1

    ; nombre_equip[28] (offset 4) — pc_buf ya tiene el nombre del equipo
    lea   rsi, [pc_buf]
    lea   rdi, [equipo_buf + 4]
    mov   rcx, 27
.cp_pc:
    mov   al, [rsi]
    mov   [rdi], al
    inc   rsi
    inc   rdi
    dec   rcx
    jnz   .cp_pc

    ; cpu_modelo[32] (offset 32)
    lea   rsi, [cpu_buf]
    lea   rdi, [equipo_buf + 32]
    mov   rcx, 31
.cp_cpu:
    mov   al, [rsi]
    mov   [rdi], al
    inc   rsi
    inc   rdi
    dec   rcx
    jnz   .cp_cpu

    ; gpu_modelo[32] (offset 88)
    lea   rsi, [gpu_buf]
    lea   rdi, [equipo_buf + 88]
    mov   rcx, 31
.cp_gpu:
    mov   al, [rsi]
    mov   [rdi], al
    inc   rsi
    inc   rdi
    dec   rcx
    jnz   .cp_gpu

    ; placa_modelo[32] (offset 120)
    lea   rsi, [board_buf]
    lea   rdi, [equipo_buf + 120]
    mov   rcx, 31
.cp_board:
    mov   al, [rsi]
    mov   [rdi], al
    inc   rsi
    inc   rdi
    dec   rcx
    jnz   .cp_board

    ; ram_total (offset 64, QWORD en MB) — viene de las variables del monitor
    mov   rax, [ram_tot]
    mov   qword [equipo_buf + 64], rax

    ; ram_libre (offset 72, QWORD en MB)
    mov   rax, [ram_lib]
    mov   qword [equipo_buf + 72], rax

    ; disco_libre (offset 80, QWORD en MB)
    mov   rax, [d_lib_q]
    shr   rax, 20               ; bytes -> MB
    mov   qword [equipo_buf + 80], rax

    ; uso_ram_pct (offset 152, double) — almacenar como entero aproximado
    ; Usamos el entero de ram_pct y lo dejamos en los 8 bytes (aprox.)
    ; Para produccion real se usaria FILD/FSTP; aqui es suficiente para display
    mov   rax, [ram_pct]
    mov   qword [equipo_buf + 152], rax

    ; categoria (offset 172, DWORD) — basada en % libre de RAM
    mov   eax, dword [equipo_buf + 172]  ; ya calculada en update_diag si se llamo antes
    ; Si no, recalcular basado en ram_pct actual
    ; categoria: pct_uso >= 85 -> 3, >= 70 -> 2, >= 50 -> 1, else 0
    mov   rax, [ram_pct]
    cmp   rax, 85
    jge   .cat_crit_rep
    cmp   rax, 70
    jge   .cat_reg_rep
    cmp   rax, 50
    jge   .cat_bue_rep
    mov   dword [equipo_buf + 172], 0    ; EXCELENTE
    jmp   .cat_rep_done
.cat_bue_rep:
    mov   dword [equipo_buf + 172], 1    ; BUENO
    jmp   .cat_rep_done
.cat_reg_rep:
    mov   dword [equipo_buf + 172], 2    ; REGULAR
    jmp   .cat_rep_done
.cat_crit_rep:
    mov   dword [equipo_buf + 172], 3    ; CRITICO
.cat_rep_done:

    ; timestamp[24] (offset 176) — obtener hora actual
    invoke  GetLocalTime, systime_buf
    ; SYSTEMTIME tiene campos WORD; zero-extend cada uno a QWORD
    ; antes de pasarlos a wsprintfA (%u lee 32 bits)
    movzx  rax, word [systime_buf + 0]  ; wYear
    mov    [ts_y], rax
    movzx  rax, word [systime_buf + 2]  ; wMonth
    mov    [ts_m], rax
    movzx  rax, word [systime_buf + 6]  ; wDay
    mov    [ts_d], rax
    movzx  rax, word [systime_buf + 8]  ; wHour
    mov    [ts_h], rax
    movzx  rax, word [systime_buf + 10] ; wMinute
    mov    [ts_mi], rax
    movzx  rax, word [systime_buf + 12] ; wSecond
    mov    [ts_s], rax
    invoke  wsprintfA, equipo_buf+176, fmt_ts_rep, \
            [ts_y], [ts_m], [ts_d], [ts_h], [ts_mi], [ts_s]

    invoke  WriteFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]
    invoke  SetDlgItemTextA, [main_hwnd], IDC_D_LBL_GUAR, _rep_ok
    jmp   .fin
.rep_fail:
    invoke  SetDlgItemTextA, [main_hwnd], IDC_D_LBL_GUAR, _rep_fail

    jmp   .fin

.refrescar:
    mov  rcx, [main_hwnd]
    call update_anal
    jmp  .fin

; ==================== WM_TIMER ====================
.on_timer:
    ; Verificar que estamos en el panel de monitoreo
    cmp   qword [cur_panel], PANEL_MON
    jne   .fin
    mov   rcx, [main_hwnd]
    call  update_mon
    jmp   .fin

; ==================== WM_DESTROY ====================
.on_destroy:
    ; Detener timer de monitoreo
    invoke  KillTimer, [main_hwnd], ID_TIMER_MON
    ; Liberar recursos GDI (pinceles y fuentes) para evitar memory leak
    invoke  DeleteObject, [hBrushSide]
    invoke  DeleteObject, [hBrushContent]
    invoke  DeleteObject, [hBrushAccent]
    invoke  DeleteObject, [hBrushHeader]
    invoke  DeleteObject, [hFontBody]
    invoke  DeleteObject, [hFontBold]
    invoke  DeleteObject, [hFontHeader]
    invoke  DeleteObject, [hFontNav]
    invoke  PostQuitMessage, 0
    xor    eax, eax

.fin:
    ret
endp


; -------------------------------------------------------
; cmp_names28  -- Compara dos strings de PC (max 28 chars)
;   r8  = puntero a nombre1
;   r9  = puntero a nombre2
; Retorna: rax = 0 si iguales, != 0 si distintos
; -------------------------------------------------------
cmp_names28:
    push  rbx
    push  rcx
    mov   rcx, 27
    xor   rbx, rbx
.cn_loop:
    mov   al, [r8]
    cmp   al, [r9]
    jne   .cn_ne
    test  al, al
    jz    .cn_done    ; ambos null = iguales
    inc   r8
    inc   r9
    dec   rcx
    jnz   .cn_loop
    jmp   .cn_done
.cn_ne:
    mov   rbx, 1
.cn_done:
    mov   rax, rbx
    pop   rcx
    pop   rbx
    ret


; -------------------------------------------------------
; update_hist  rcx = hwnd
; Escanea reportes\ y muestra equipos unicos detectados
; -------------------------------------------------------
proc update_hist uses rbx rsi rdi, hwnd
    mov   rbx, rcx

    invoke  SendDlgItemMessage, rbx, IDC_H_PC_LIST,  LB_RESETCONTENT, 0, 0
    invoke  SendDlgItemMessage, rbx, IDC_H_REP_LIST, LB_RESETCONTENT, 0, 0
    invoke  SetDlgItemTextA, rbx, IDC_H_STATS, _empty
    invoke  SetDlgItemTextA, rbx, IDC_H_INFO,  _empty
    mov   qword [hist_pc_cnt], 0

    invoke  FindFirstFileA, _rep_pattern, find_data
    cmp   rax, -1
    je    .no_files
    mov   rsi, rax    ; hFind

.loop_scan:
    ; Construir ruta y abrir .rep
    lea   rax, [find_data + 44]
    invoke  wsprintfA, tmp_buf, fmt_ruta, rax

    invoke  CreateFileA, tmp_buf, GENERIC_READ, FILE_SHARE_READ, NULL, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .next_scan
    mov   [tmp_hfile], rax

    invoke  ReadFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    mov   eax, dword [rep_hdr]
    cmp   eax, 0x4E414353
    jne   .close_scan

    invoke  ReadFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]

    ; Verificar si este PC ya esta en la lista unica
    mov   rdi, [hist_pc_cnt]
    xor   rcx, rcx
.dup_check:
    cmp   rcx, rdi
    je    .add_pc        ; no encontrado: agregar
    imul  rax, rcx, 28
    lea   r8,  [hist_pc_names + rax]  ; nombre almacenado
    lea   r9,  [equipo_buf + 4]        ; nombre actual
    call  cmp_names28
    test  rax, rax
    jz    .next_scan     ; ya existe: saltar
    inc   rcx
    jmp   .dup_check

.add_pc:
    ; Guardar nombre en array de unicos
    cmp   rdi, 31
    jge   .next_scan
    imul  rax, rdi, 28
    lea   r8,  [hist_pc_names + rax]
    lea   r9,  [equipo_buf + 4]
    mov   rcx, 27
.cp_name:
    mov   al, [r9]
    mov   [r8], al
    inc   r8
    inc   r9
    dec   rcx
    jnz   .cp_name

    ; Agregar al listbox
    lea   rax, [equipo_buf + 4]
    invoke  SendDlgItemMessage, rbx, IDC_H_PC_LIST, LB_ADDSTRING, 0, rax
    inc   qword [hist_pc_cnt]
    jmp   .next_scan

.close_scan:
    invoke  CloseHandle, [tmp_hfile]
.next_scan:
    invoke  FindNextFileA, rsi, find_data
    test  eax, eax
    jnz   .loop_scan
    invoke  FindClose, rsi

    ; Mostrar estadistica total
    invoke  wsprintfA, txt, fmt_hist_pcs, [hist_pc_cnt]
    invoke  SetDlgItemTextA, rbx, IDC_H_STATS, txt
    invoke  SetDlgItemTextA, rbx, IDC_H_INFO, _hist_click
    ret

.no_files:
    invoke  SetDlgItemTextA, rbx, IDC_H_STATS, _no_rep
    ret
endp


; -------------------------------------------------------
; update_hist_detail  rcx = hwnd
; Lee todos los .rep del PC seleccionado y muestra timeline
; -------------------------------------------------------
proc update_hist_detail uses rbx rsi rdi, hwnd
    mov   rbx, rcx

    ; Obtener indice del PC seleccionado
    invoke  SendDlgItemMessage, rbx, IDC_H_PC_LIST, LB_GETCURSEL, 0, 0
    cmp   rax, -1
    je    .done

    ; Obtener el texto del PC seleccionado en hist_sel_pc
    invoke  SendDlgItemMessage, rbx, IDC_H_PC_LIST, LB_GETTEXT, rax, hist_sel_pc
    invoke  SendDlgItemMessage, rbx, IDC_H_REP_LIST, LB_RESETCONTENT, 0, 0

    invoke  FindFirstFileA, _rep_pattern, find_data
    cmp   rax, -1
    je    .done
    ; CORRECTO: guardar hFind en MEMORIA para que el calculo de RAM
    ; no lo destruya al usar los registros rsi/rdi como temporales.
    mov   [hist_hfind], rax
    xor   rdi, rdi   ; rdi = contador de reportes encontrados

.loop_hist:
    lea   rax, [find_data + 44]
    invoke  wsprintfA, tmp_buf, fmt_ruta, rax

    invoke  CreateFileA, tmp_buf, GENERIC_READ, FILE_SHARE_READ, NULL, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp   rax, -1
    je    .hist_next
    mov   [tmp_hfile], rax

    invoke  ReadFile, [tmp_hfile], rep_hdr, 24, bytes_w, NULL
    mov   eax, dword [rep_hdr]
    cmp   eax, 0x4E414353    ; firma "SCAN"
    jne   .hist_close

    invoke  ReadFile, [tmp_hfile], equipo_buf, 200, bytes_w, NULL
    invoke  CloseHandle, [tmp_hfile]

    ; Comparar nombre de PC del .rep con el seleccionado
    lea   r8, [equipo_buf + 4]
    lea   r9, [hist_sel_pc]
    call  cmp_names28
    test  rax, rax
    jnz   .hist_next           ; no coincide: siguiente archivo

    ; ---- Calcular RAM% usando MEMORIA (no rsi/rdi que son criticos) ----
    ; Bug prevenido: usar rcx como temporal en lugar de rsi/rdi
    ; para no destruir el hFind ni el contador de reportes.
    mov   rax, qword [equipo_buf + 64]   ; ram_total (MB)
    test  rax, rax
    jz    .hist_no_ram
    mov   [hist_tmp_tot], rax             ; ram_total -> memoria
    mov   rcx, qword [equipo_buf + 72]   ; ram_libre (MB)
    mov   rax, [hist_tmp_tot]
    sub   rax, rcx                        ; rax = ram_usada
    imul  rax, 100                        ; rax = ram_usada * 100
    xor   edx, edx                        ; limpiar RDX para DIV
    div   qword [hist_tmp_tot]            ; rax = porcentaje uso
    cmp   rax, 100
    jbe   .hist_pct_ok
    mov   rax, 100
.hist_pct_ok:
    mov   [det_ram_pct], rax
    jmp   .hist_fmt

.hist_no_ram:
    mov   qword [det_ram_pct], 0

.hist_fmt:
    ; Formatear linea del historial segun categoria
    mov   ecx, dword [equipo_buf + 172]
    cmp   ecx, 0
    je    .hcat0
    cmp   ecx, 1
    je    .hcat1
    cmp   ecx, 2
    je    .hcat2
    invoke  wsprintfA, txt, fmt_hist_rep, \
            equipo_buf+176, [det_ram_pct], dword [equipo_buf+80], _acat3
    jmp   .hist_add
.hcat0:
    invoke  wsprintfA, txt, fmt_hist_rep, \
            equipo_buf+176, [det_ram_pct], dword [equipo_buf+80], _acat0
    jmp   .hist_add
.hcat1:
    invoke  wsprintfA, txt, fmt_hist_rep, \
            equipo_buf+176, [det_ram_pct], dword [equipo_buf+80], _acat1
    jmp   .hist_add
.hcat2:
    invoke  wsprintfA, txt, fmt_hist_rep, \
            equipo_buf+176, [det_ram_pct], dword [equipo_buf+80], _acat2

.hist_add:
    lea   rax, [txt]
    invoke  SendDlgItemMessage, rbx, IDC_H_REP_LIST, LB_ADDSTRING, 0, rax
    inc   rdi           ; rdi = contador (seguro: no se destruyo)
    jmp   .hist_next

.hist_close:
    invoke  CloseHandle, [tmp_hfile]
.hist_next:
    ; Usar [hist_hfind] de memoria (no rsi que pudo ser destruido)
    invoke  FindNextFileA, [hist_hfind], find_data
    test  eax, eax
    jnz   .loop_hist
    invoke  FindClose, [hist_hfind]

    invoke  wsprintfA, txt, fmt_hist_reps, rdi
    invoke  SetDlgItemTextA, rbx, IDC_H_STATS, txt
.done:
    ret
endp


; -------------------------------------------------------
; PUNTO DE ENTRADA
; -------------------------------------------------------
start:
    sub  rsp, 8

    invoke  GetModuleHandle, 0
    mov  [wc.hInstance], rax
    mov  [gwc.hInstance], rax   ; clase TG_Gauge
    mov  [grwc.hInstance], rax  ; clase TG_Graph
    invoke  LoadIcon,   0, IDI_APPLICATION
    mov  [wc.hIcon], rax
    mov  [wc.hIconSm], rax
    invoke  LoadCursor, 0, IDC_ARROW
    mov  [wc.hCursor], rax

    invoke  RegisterClassEx, wc
    test  rax, rax
    jz    .error
    ; Registrar clases GDI personalizadas para barras y graficas
    invoke  RegisterClassEx, gwc
    invoke  RegisterClassEx, grwc

    invoke  GetSystemMetrics, SM_CXSCREEN
    sub   eax, WIN_W
    sar   eax, 1
    mov   [pos_x], eax
    invoke  GetSystemMetrics, SM_CYSCREEN
    sub   eax, WIN_H
    sar   eax, 1
    mov   [pos_y], eax

    invoke  CreateWindowEx, 0, _wclass, _wintitulo, \
            WS_CAPTION+WS_SYSMENU+WS_MINIMIZEBOX+WS_VISIBLE, \
            [pos_x], [pos_y], WIN_W, WIN_H, \
            NULL, NULL, [wc.hInstance], NULL
    test  rax, rax
    jz    .error

.loop:
    invoke  GetMessage, msg, NULL, 0, 0
    cmp   eax, 1
    jb    .done
    jne   .loop
    invoke  TranslateMessage, msg
    invoke  DispatchMessage,  msg
    jmp   .loop

.error:
    invoke  MessageBox, NULL, _errmsg, _wintitulo, MB_ICONERROR+MB_OK

.done:
    invoke  ExitProcess, [msg.wParam]


; =====================================================
; DATOS
; =====================================================
section '.data' data readable writeable

    _wclass   db 'TechScan64GUI', 0
    _segoe_ui    db 'Segoe UI', 0     ; fuente moderna Win10/11
    _gauge_class db 'TG_Gauge', 0    ; clase del control barra GDI
    _graph_class db 'TG_Graph', 0    ; clase del control grafica GDI
    _pct_fmt     db '%u%%', 0        ; formato "52%" para texto en barra

    ; WNDCLASSEX para la barra GDI (hInstance se rellena en start:)
    gwc WNDCLASSEX sizeof.WNDCLASSEX, CS_HREDRAW+CS_VREDRAW, GaugeProc, \
                   0, 0, NULL, NULL, NULL, NULL, NULL, _gauge_class, NULL

    ; WNDCLASSEX para la grafica GDI (hInstance se rellena en start:)
    grwc WNDCLASSEX sizeof.WNDCLASSEX, CS_HREDRAW+CS_VREDRAW, GraphProc, \
                    0, 0, NULL, NULL, NULL, NULL, NULL, _graph_class, NULL
    _wintitulo db 'TechScan64  -  Sistema de Diagnostico de Equipos', 0
    _errmsg   db 'Error al iniciar la ventana.', 0
    _ST       db 'STATIC', 0
    _BT       db 'BUTTON', 0
    _LB       db 'LISTBOX', 0
    _empty    db 0
    _drv         db 'C:\', 0
    _rep_dir     db 'reportes', 0
    _rep_pattern db 'reportes\*.rep', 0

    ; Textos de navegacion
    _nav_titulo db 'TECHSCAN 64', 0
    _btn_diag   db 'Diagnosticar', 0
    _btn_mon    db 'Monitoreo', 0
    _btn_anal   db 'Analizar Reportes', 0
    _btn_estad  db 'Estadisticas', 0
    _btn_salir  db 'Salir', 0
    _btn_hist   db 'Historial', 0
    _btn_actualizar db 'Actualizar', 0
    _btn_guardar db 'Guardar Reporte (.rep)', 0
    _btn_ref    db 'Actualizar Lista', 0

    ; Headers
    _hdr_diag      db 'DIAGNOSTICO DEL EQUIPO', 0
    _hdr_mon       db 'MONITOREO EN TIEMPO REAL', 0
    _hdr_anal      db 'ANALISIS DE REPORTES', 0
    _hdr_estad     db 'ESTADISTICAS GLOBALES', 0
    _hdr_hist      db 'HISTORIAL DE EQUIPOS ANALIZADOS', 0
    _lbl_hist_pcs  db 'Equipos detectados en los reportes:', 0
    _lbl_hist_rep  db 'Linea de tiempo del equipo seleccionado:', 0
    _hist_click    db 'Haz click en un equipo para ver su historial completo.', 0

    ; Labels diagnostico
    _lbl_pc    db 'Equipo:', 0
    _lbl_usr   db 'Usuario:', 0
    _lbl_cpu   db 'CPU:', 0
    _lbl_ramt  db 'RAM Total:', 0
    _lbl_raml  db 'RAM Libre:', 0
    _lbl_ramp  db 'Uso RAM:', 0
    _lbl_disc  db 'Disco Libre:', 0
    _lbl_os    db 'Sistema Op.:', 0
    _lbl_cat   db 'Categoria:', 0
    _lbl_gpu   db 'GPU:', 0
    _lbl_placa db 'Placa Madre:', 0
    _lbl_bios  db 'BIOS:', 0
    _lbl_tec   db 'Estado Tec.:', 0

    ; Headers monitoreo
    _hdr_ram   db 'RAM uso:', 0
    _hdr_disco db 'DISCO uso:', 0
    _hdr_cpu   db 'CPU picos:', 0
    _hdr_gpu   db 'GPU:', 0

    ; Categorias
    _cat0  db 'EXCELENTE  (RAM libre >= 50%)', 0
    _cat1  db 'BUENO      (RAM libre >= 30%)', 0
    _cat2  db 'REGULAR    (RAM libre >= 15%)', 0
    _cat3  db 'CRITICO    (RAM libre <  15%)', 0

    ; Estado monitoreo
    _st_ok     db 'Estado: NORMAL  -  Sin alertas activas', 0
    _st_alerta db '!!!  ALERTA: Recurso critico detectado  !!!', 0

    ; Mensajes
    _no_rep    db 'No hay reportes .rep  (use Diagnosticar -> Guardar Reporte)', 0
    _rep_ok    db 'Reporte guardado correctamente.', 0
    _rep_fail  db 'Error: no se pudo guardar el reporte.', 0
    _arch_x64  db 'x64 (AMD64)', 0
    _arch_x86  db 'x86 (32-bit)', 0
    _hw_unknown db 'No detectado', 0
    _tec_vigente db 'VIGENTE (estimado)', 0

    ; Rutas/valores de registro para hardware avanzado
    _reg_video_map db 'HARDWARE\DEVICEMAP\VIDEO', 0
    _reg_video0 db '\Device\Video0', 0
    _reg_driver_desc db 'DriverDesc', 0
    _reg_bios db 'HARDWARE\DESCRIPTION\System\BIOS', 0
    _reg_board_mfr db 'BaseBoardManufacturer', 0
    _reg_board_product db 'BaseBoardProduct', 0
    _reg_bios_vendor db 'BIOSVendor', 0
    _reg_bios_version db 'BIOSVersion', 0

    ; Formatos
    ; Strings del panel de detalle de Analizar
    _det_hdr     db 'DETALLE DEL REPORTE SELECCIONADO', 0
    _det_lbl_pc  db 'Equipo:', 0
    _det_lbl_ts  db 'Fecha:', 0
    _det_lbl_cat db 'Categoria:', 0

    fmt_mb     db '%u MB', 0
    fmt_pct    db '%u%%', 0
    fmt_pair   db '%s  %s', 0
    fmt_os     db 'Windows %u.%u', 0
    fmt_os_ver db 'Windows %u.%u  (Build %u)', 0
    fmt_win11  db 'Windows 11  (Build %u)', 0
    ; %u en lugar de %llu: wsprintfA (user32) no garantiza %llu;
    ; valores de RAM/disco en MB siempre caben en 32 bits (<4TB)
    fmt_ts_rep     db '%04u-%02u-%02u %02u:%02u:%02u', 0
    fmt_hist_pcs   db 'Equipos unicos detectados: %u', 0
    fmt_hist_reps  db 'Reportes para este equipo: %u  (selecciona uno para ver detalles)', 0
    fmt_hist_rep   db '  %s  |  RAM: %u%%  |  Disco: %u MB libre  |  [%s]', 0
    fmt_det_ram db 'RAM: %u MB total  |  %u MB libre  |  %u%% uso', 0
    fmt_det_dsk db 'Disco libre al momento del reporte:  %u MB', 0
    fmt_mon_r  db '  Total: %u MB  |  Libre: %u MB  |  Uso: %u MB  (%u%%)', 0
    fmt_mon_d  db '  Total: %u MB  |  Libre: %u MB  |  Uso: %u MB  (%u%%)', 0
    fmt_mon_c  db '  Carga del procesador: %u%%', 0
    fmt_mon_g  db '  Uso de GPU: %u%%', 0

    ; Formatos para barras ASCII y graficos de historial
    fmt_ascii_bar  db '%s  %u%%', 0
    fmt_hist_line  db '%s%s  (actual: %u%%)', 0

    ; Prefijos para los graficos de historial
    _hist_cpu_pfx  db 'CPU picos: ', 0
    _hist_ram_pfx  db 'RAM uso  : ', 0
    _hist_dsk_pfx  db 'DISCO uso : ', 0
    _hist_gpu_pfx  db 'GPU uso   : ', 0
    ; ---- Constantes para el coprocesador FPU x87 (IEEE 754 double) ----
    fpu_peso_ram   dq 0.40      ; Peso RAM libre  (40% del puntaje)
    fpu_peso_disco dq 0.35      ; Peso Disco libre (35% del puntaje)
    fpu_peso_cpu   dq 0.25      ; Peso CPU libre   (25% del puntaje)
    fpu_const100   dq 100.0     ; Constante 100.0 para invertir CPU%

    ; Formato y etiquetas del Puntaje de Salud FPU
    fmt_score  db '%d / 100  --  %s', 0
    _lbl_score db 'Puntaje FPU:', 0
    _sc_exc    db 'EXCELENTE', 0
    _sc_bue    db 'BUENO', 0
    _sc_reg    db 'REGULAR', 0
    _sc_cri    db 'CRITICO', 0

    fmt_anal_cnt  db '%u reporte(s) encontrado(s) en la carpeta reportes\', 0
    fmt_anal_item db '  %s  |  %s  |  %s', 0
    fmt_anal_fname db '  %s  (no legible)', 0
    fmt_ruta      db 'reportes\%s', 0
    fmt_reppath   db 'reportes\%s_%u.rep', 0
    fmt_stat_tot  db 'Equipos analizados en el laboratorio:  %u', 0
    fmt_stat_ext  db 'Equipos: %u  |  RAM prom: %u MB  |  Disco prom: %u MB  |  Menos recursos: %s  |  Antiguo: %s', 0
    fmt_es_exc    db 'EXCELENTE  (RAM libre >= 50%%):   %u equipo(s)', 0
    fmt_es_bue    db 'BUENO      (RAM libre >= 30%%):   %u equipo(s)', 0
    fmt_es_reg    db 'REGULAR    (RAM libre >= 15%%):   %u equipo(s)', 0
    fmt_es_cri    db 'CRITICO    (RAM libre <  15%%):   %u equipo(s)', 0
    fmt_e_pclist  db '  %-18s  %s  RAM: %u%%  [%s]', 0
    fmt_rank_mb   db '  %u. %-18s  %u MB', 0
    fmt_rank_score db '  %u. %-18s  score %u', 0

    ; Strings de sub-headers del panel Estadisticas
    _e_lbl_dist   db 'DISTRIBUCION POR CATEGORIA DE SALUD', 0
    _e_lbl_pcs    db 'EQUIPOS, REVISION TECNICA Y ORDENAMIENTOS', 0
    _blank        db '', 0
    _rank_pri     db 'LISTA PRIORIZADA DE REVISION TECNICA', 0
    _rank_ram     db 'ORDENAMIENTO POR RAM TOTAL', 0
    _rank_disk    db 'ORDENAMIENTO POR ESPACIO LIBRE', 0
    _rank_age     db 'ORDENAMIENTO POR ANTIGUEDAD ESTIMADA', 0

    ; Strings cortos de categoria para el panel de analisis
    _acat0 db 'EXCELENTE', 0
    _acat1 db 'BUENO', 0
    _acat2 db 'REGULAR', 0
    _acat3 db 'CRITICO', 0

    pos_x  dd 0
    pos_y  dd 0

    ; hbrBackground=NULL: el fondo se pinta completamente en WM_ERASEBKGND
    ; para evitar el "flash" que ocurre si Windows pinta primero con COLOR_BTNFACE
    wc WNDCLASSEX sizeof.WNDCLASSEX, CS_HREDRAW+CS_VREDRAW, WndProc, \
                  0, 0, NULL, NULL, NULL, NULL, NULL, _wclass, NULL
    msg MSG


; =====================================================
; BSS
; =====================================================
section '.bss' readable writeable

    main_hwnd  rq 1
    cur_panel  rq 1

    ; Pinceles para la paleta profesional
    hBrushSide     rq 1    ; Sidebar oscuro
    hBrushContent  rq 1    ; Fondo blanco de contenido
    hBrushAccent   rq 1    ; Franja de acento azul

    ; Fuentes Segoe UI para tipografia moderna
    hFontBody      rq 1    ; Segoe UI 10pt  - etiquetas y texto general
    hFontBold      rq 1    ; Segoe UI 10pt Bold - valores de datos
    hFontHeader    rq 1    ; Segoe UI 12pt Bold - titulos de seccion
    hFontNav       rq 1    ; Segoe UI 11pt SemiBold - items de navegacion
    hBrushHeader   rq 1    ; Pincel para fondo ligeramente azulado en headers

    ; Variables temporales del procesado de mensajes de color
    tmp_hdc         rq 1
    tmp_idx         rq 1
    tmp_hwnd_ctrl   rq 1    ; hWnd del control en WM_CTLCOLOR*
    saved_wparam    rq 1    ; wParam completo guardado al inicio de WM_COMMAND
    erase_rect rd 4        ; RECT: left,top,right,bottom (4 DWORDs)

    ; Buffer para RtlGetVersion (RTL_OSVERSIONINFOW: 276 bytes)
    ; align 4: los campos DWORD de la estructura deben estar alineados
    align 4
    os_rtl     rb 280

    ; Array de rutas para update_anal_detail (hasta 32 archivos x 300 chars)
    anal_paths     rb 300 * 32
    anal_path_cnt  rq 1

    ; Variables del panel de detalle de reportes
    det_ram_pct  rq 1
    det_dsk_pct  rq 1

    ; Historial circular para graficos de picos (30 lecturas)
    cpu_hist  rb 30     ; porcentajes CPU de las ultimas 30 mediciones
    ram_hist  rb 30     ; porcentajes RAM
    dsk_hist  rb 30     ; porcentajes Disco
    gpu_hist  rb 30     ; porcentajes GPU
    hist_idx  rq 1      ; indice actual en el buffer circular (0-29)

    ; Estructuras compartidas para GaugeProc y GraphProc (uso secuencial)
    g_ps         rb 72     ; PAINTSTRUCT (72 bytes en x64)
    g_crect      rd 4      ; RECT cliente {left,top,right,bottom}
    g_frect      rd 4      ; RECT de la porcion llena
    g_hdc        rq 1      ; HDC del control durante WM_PAINT
    g_val        rq 1      ; valor actual pintado (0-100)
    g_txt        rb 8      ; buffer "100%\0"

    gr_ps        rb 72     ; PAINTSTRUCT para graficas
    gr_crect     rd 4      ; RECT cliente de la grafica
    gr_hdc       rq 1      ; HDC de la grafica
    gr_color     rq 1      ; COLORREF de la linea
    gr_points    rb 240    ; POINT[30] = 30 * 8 bytes para Polyline
    gr_old_pen   rq 1      ; pluma anterior al seleccionar la de datos

    ; Porcentajes pre-calculados para barras de Estadisticas
    es_pct0  rq 1
    es_pct1  rq 1
    es_pct2  rq 1
    es_pct3  rq 1
    systime_buf  rw 8    ; SYSTEMTIME: 8 WORDs = 16 bytes
    ; Historial de equipos
    hist_pc_names  rb 28 * 32  ; nombres unicos (hasta 32 PCs)
    hist_pc_cnt    rq 1
    hist_sel_pc    rb 32       ; nombre del PC seleccionado (32 bytes = 28+null+margen)
    hist_hfind     rq 1        ; handle FindFirstFile guardado en memoria (no en rsi)
    hist_tmp_tot   rq 1        ; ram_total temporal para calculo % (no en rdi/rsi)

    ; Temporales para zero-extend de cada campo WORD de SYSTEMTIME
    ts_y   rq 1  ; wYear
    ts_m   rq 1  ; wMonth
    ts_d   rq 1  ; wDay
    ts_h   rq 1  ; wHour
    ts_mi  rq 1  ; wMinute
    ts_s   rq 1  ; wSecond

    ; Buffers
    txt        rb 512
    tmp_buf    rb 256
    cpu_buf    rb 64
    gpu_buf    rb 96
    board_mfr_buf rb 96
    board_buf  rb 96
    bios_vendor_buf rb 96
    bios_ver_buf rb 96
    video_reg_path rb 256
    pc_buf     rb 32
    rep_path   rb 256

    pcbufsz    rd 1
    reg_cb     rd 1

    ; MEMORYSTATUSEX (64 bytes)
    memst      rb 64

    ; OSVERSIONINFOEXA (148 bytes)
    os_info    rb 152

    ; SYSTEM_INFO (48 bytes)
    sys_info   rb 48

    ; RAM
    ram_tot    rq 1
    ram_lib    rq 1
    ram_uso    rq 1
    ram_pct    rq 1

    ; Disco
    d_tot_q    rq 1
    d_lib_q    rq 1
    d_tot      rq 1
    d_lib      rq 1
    d_uso      rq 1
    d_pct      rq 1

    ; CPU
    ft_idle    rq 1
    ft_kern    rq 1
    ft_user    rq 1
    ft_idle_p  rq 1
    ft_kern_p  rq 1
    ft_user_p  rq 1
    d_idle_n   rq 1
    d_kern_n   rq 1
    d_user_n   rq 1
    cpu_pct    rq 1

    ; GPU
    gpu_pct    rq 1

    ; Reporte
    rep_hdr    rb 24
    equipo_buf rb 200
    tmp_hfile  rq 1
    tick_save  rq 1
    bytes_w    rd 1

    ; Find data (WIN32_FIND_DATAA = 320 bytes)
    find_data  rb 320

    ; Variables del modulo FPU x87
    fpu_tmp1       rq 1    ; Temporal: arg1 (ram) y resultado entero
    fpu_tmp2       rq 1    ; Temporal: arg2 (disco)
    fpu_tmp3       rq 1    ; Temporal: arg3 (cpu)
    fpu_resultado  rq 1    ; Resultado double del coprocesador
    fpu_score_i    rq 1    ; Puntaje entero final (0-100)
    d_lib_pct      rq 1    ; Disco libre en porcentaje

    ; Estadisticas
    es_total   rq 1
    es_c0      rq 1
    es_c1      rq 1
    es_c2      rq 1
    es_c3      rq 1
    es_sum_ram_lib rq 1
    es_sum_disk    rq 1
    es_avg_ram     rq 1
    es_avg_disk    rq 1
    es_min_res_score rq 1
    es_min_res_name  rb 32
    es_old_score     rq 1
    es_old_name      rb 32
    es_top_pri_val   rq 5
    es_top_pri_name  rb 32 * 5
    es_top_ram_val   rq 5
    es_top_ram_name  rb 32 * 5
    es_top_disk_val  rq 5
    es_top_disk_name rb 32 * 5
    es_top_age_val   rq 5
    es_top_age_name  rb 32 * 5


; =====================================================
; IMPORTACIONES
; =====================================================
section '.idata' import data readable writeable

    library kernel32, 'KERNEL32.DLL', \
            user32,   'USER32.DLL',   \
            gdi32,    'GDI32.DLL',    \
            comctl32, 'COMCTL32.DLL', \
            advapi32, 'ADVAPI32.DLL', \
            ntdll,    'NTDLL.DLL'

    import kernel32, \
           GetModuleHandle,     'GetModuleHandleA',   \
           ExitProcess,         'ExitProcess',         \
           GlobalMemoryStatusEx,'GlobalMemoryStatusEx',\
           GetDiskFreeSpaceExA, 'GetDiskFreeSpaceExA', \
           GetSystemTimes,      'GetSystemTimes',       \
           GetComputerNameA,    'GetComputerNameA',     \
           GetVersionExA,       'GetVersionExA',        \
           GetSystemInfo,       'GetSystemInfo',        \
           GetTickCount64,      'GetTickCount64',       \
           GetLocalTime,        'GetLocalTime',         \
           FindFirstFileA,      'FindFirstFileA',       \
           FindNextFileA,       'FindNextFileA',        \
           FindClose,           'FindClose',            \
           CreateFileA,         'CreateFileA',          \
           ReadFile,            'ReadFile',             \
           WriteFile,           'WriteFile',            \
           CloseHandle,         'CloseHandle',          \
           CreateDirectoryA,    'CreateDirectoryA'

    import user32, \
           RegisterClassEx,    'RegisterClassExA',   \
           CreateWindowEx,     'CreateWindowExA',    \
           GetMessage,         'GetMessageA',         \
           TranslateMessage,   'TranslateMessage',    \
           DispatchMessage,    'DispatchMessageA',    \
           DefWindowProc,      'DefWindowProcA',      \
           PostQuitMessage,    'PostQuitMessage',      \
           DestroyWindow,      'DestroyWindow',        \
           MessageBox,         'MessageBoxA',          \
           ShowWindow,         'ShowWindow',           \
           GetWindow,          'GetWindow',            \
           GetDlgCtrlID,       'GetDlgCtrlID',        \
           SendDlgItemMessage, 'SendDlgItemMessageA', \
           SetDlgItemTextA,    'SetDlgItemTextA',     \
           wsprintfA,          'wsprintfA',            \
           SetTimer,           'SetTimer',             \
           KillTimer,          'KillTimer',            \
           LoadIcon,           'LoadIconA',            \
           LoadCursor,         'LoadCursorA',          \
           GetSystemMetrics,   'GetSystemMetrics', \
           GetDlgItem,         'GetDlgItem',        \
           FillRect,           'FillRect',           \
           SendMessage,        'SendMessageA',       \
           BeginPaint,         'BeginPaint',         \
           EndPaint,           'EndPaint',           \
           GetClientRect,      'GetClientRect',      \
           InvalidateRect,     'InvalidateRect',     \
           GetWindowLongA,     'GetWindowLongA',     \
           DrawTextA,          'DrawTextA',          \
           UpdateWindow,       'UpdateWindow'

    import gdi32, \
           CreateSolidBrush,  'CreateSolidBrush', \
           CreateFontA,       'CreateFontA',       \
           CreatePen,         'CreatePen',         \
           SelectObject,      'SelectObject',      \
           DeleteObject,      'DeleteObject',      \
           GetStockObject,    'GetStockObject',    \
           MoveToEx,          'MoveToEx',          \
           LineTo,            'LineTo',            \
           Polyline,          'Polyline',          \
           Rectangle,         'Rectangle',         \
           SetTextColor,      'SetTextColor',      \
           SetBkColor,        'SetBkColor',        \
           SetBkMode,         'SetBkMode'

    import comctl32, \
           InitCommonControls, 'InitCommonControls'

    import advapi32, \
           GetUserNameA,  'GetUserNameA', \
           RegGetValueA,  'RegGetValueA'

    import ntdll, \
           RtlGetVersion, 'RtlGetVersion'
