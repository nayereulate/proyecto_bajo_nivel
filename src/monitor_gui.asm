; ==============================================================
; Archivo      : src/monitor_gui.asm
; Proyecto     : TechScan64 - Monitor Grafico Standalone
; Institucion  : U.M.S.S. - Facultad de Tecnologia
; Asignatura   : Taller de Programacion en Bajo Nivel
; Ensamblador  : FASM (Flat Assembler) via RadASM - PE64 GUI
; Arquitectura : Windows x86-64 (Win64 GUI, ABI Microsoft x64)
; Descripcion  :
;   Ventana Win32 independiente de monitoreo en tiempo real.
;   Se actualiza cada 2 segundos via WM_TIMER.
;   Muestra barras de progreso con colores (verde/naranja/rojo)
;   para RAM, Disco y CPU. Se cierra con la X de la ventana.
;
; Requisitos implementados:
;   #1 Arquitectura 64-bit: RAX,RBX,RCX,RDX,RSI,RDI,R8,R9
;   #2 FastCall Win64: proc...uses + invoke (FASM macro)
;   #3 GUI / Bucle de mensajes: WndProc, WM_CREATE/TIMER/DESTROY
;   #4 Persistencia: lectura de GlobalMemoryStatusEx,
;                    GetDiskFreeSpaceExA, GetSystemTimes
;
; APIS WINDOWS UTILIZADAS:
;   kernel32: GlobalMemoryStatusEx, GetDiskFreeSpaceExA,
;             GetSystemTimes, GetModuleHandleA, ExitProcess
;   user32  : RegisterClassExA, CreateWindowExA, GetMessageA,
;             DispatchMessageA, SetTimer, KillTimer,
;             SendDlgItemMessageA, SetDlgItemTextA, wsprintfA
;   comctl32: InitCommonControls (para MSCTLS_PROGRESS32)
;
; Compilar:
;   set INCLUDE=C:\Pack RadASM\fasm\INCLUDE
;   FASM.EXE src\monitor_gui.asm bin\monitor_gui.exe
; ==============================================================

format PE64 GUI 5.0
entry start

include 'win64a.inc'

; ===================================================
; Identificadores de controles
; ===================================================
ID_TIMER        = 1
IDC_HDR_RAM     = 101
IDC_VAL_RAM     = 102
IDC_BAR_RAM     = 103
IDC_HDR_DISCO   = 104
IDC_VAL_DISCO   = 105
IDC_BAR_DISCO   = 106
IDC_HDR_CPU       = 107
IDC_VAL_CPU       = 108
IDC_BAR_CPU       = 109
IDC_HDR_GPU       = 111
IDC_VAL_GPU       = 112
IDC_BAR_GPU       = 113
IDC_HDR_GPU_HIST  = 114
IDC_GPU_GRAPH     = 115
IDC_ESTADO        = 110

; ===================================================
; Mensajes de ProgressBar
; ===================================================
PBM_SETRANGE    = 0401h
PBM_SETPOS      = 0402h
PBM_SETBARCOLOR = 0409h
PBM_SETBKCOLOR  = 2001h

; ===================================================
; COLORREF = R + (G shl 8) + (B shl 16)
; ===================================================
CLR_VERDE    = 0000BB00h   ; RGB(0, 187, 0)
CLR_NARANJA  = 00007FFFh   ; RGB(255, 127, 0)
CLR_ROJO     = 000000BBh   ; RGB(187, 0, 0)
CLR_FONDO_PB = 00303030h   ; Fondo oscuro de barras

WIN_W = 520
WIN_H = 460

; ===================================================
; CODIGO
; ===================================================
section '.text' code readable executable

; ---------------------------------------------------
; set_bar_color
;   RCX = hwnd, RDX = ctrl_id, R8 = pct (0-100)
; Establece el color de la barra segun el porcentaje.
; Llamar con: mov rcx/rdx/r8 + call set_bar_color
; ---------------------------------------------------
proc set_bar_color uses rbx rsi rdi, _hw, _id, _pct

    ; Guardar argumentos en callee-saved antes de cualquier invoke
    mov    rbx, rcx     ; hwnd
    mov    rsi, rdx     ; ctrl_id
    mov    rdi, r8      ; pct

    cmp    rdi, 85
    jge    .rojo
    cmp    rdi, 60
    jge    .naranja

    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_VERDE
    ret
.naranja:
    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_NARANJA
    ret
.rojo:
    invoke  SendDlgItemMessage, rbx, rsi, PBM_SETBARCOLOR, 0, CLR_ROJO
    ret
endp


; ---------------------------------------------------
; actualizar
;   RCX = hwnd
; Lee RAM, disco y CPU del sistema, actualiza todos
; los controles de la ventana.
; Llamar con: mov rcx, hwnd + call actualizar
; ---------------------------------------------------
proc actualizar uses rbx rsi rdi, hwnd

    mov    rbx, rcx           ; hwnd en rbx (preservado en todo el proc)

    ; ==================================================
    ; MEMORIA RAM
    ; MEMORYSTATUSEX: +0 dwLength(dd), +8 ullTotalPhys(dq), +16 ullAvailPhys(dq)
    ; ==================================================
    mov    dword [memst], 64  ; dwLength = sizeof(MEMORYSTATUSEX)
    invoke  GlobalMemoryStatusEx, memst

    mov    rax, qword [memst + 8]    ; ullTotalPhys (bytes)
    shr    rax, 20                   ; convertir a MB
    mov    [ram_tot], rax

    mov    rax, qword [memst + 16]   ; ullAvailPhys (bytes)
    shr    rax, 20
    mov    [ram_lib], rax

    mov    rax, [ram_tot]
    sub    rax, [ram_lib]
    mov    [ram_uso], rax

    ; ram_pct = (ram_uso * 100) / ram_tot
    xor    edx, edx
    mov    rax, [ram_uso]
    mov    rcx, 100
    mul    rcx                ; RDX:RAX = ram_uso * 100
    mov    rcx, [ram_tot]
    test   rcx, rcx
    jz     .ram_cero
    div    rcx                ; RAX = porcentaje
    cmp    rax, 100
    jbe    .ram_ok
    mov    rax, 100
    jmp    .ram_ok
.ram_cero:
    xor    rax, rax
.ram_ok:
    mov    [ram_pct], rax

    invoke  wsprintfA, txt, fmt_ram, [ram_tot], [ram_lib], [ram_uso], [ram_pct]
    invoke  SetDlgItemTextA, rbx, IDC_VAL_RAM, txt
    invoke  SendDlgItemMessage, rbx, IDC_BAR_RAM, PBM_SETPOS, [ram_pct], 0

    ; color de barra RAM
    mov    rcx, rbx
    mov    rdx, IDC_BAR_RAM
    mov    r8,  [ram_pct]
    call   set_bar_color

    ; ==================================================
    ; DISCO C:\
    ; ==================================================
    invoke  GetDiskFreeSpaceExA, _drv, d_lib_q, d_tot_q, NULL

    mov    rax, [d_tot_q]
    shr    rax, 20
    mov    [d_tot], rax

    mov    rax, [d_lib_q]
    shr    rax, 20
    mov    [d_lib], rax

    mov    rax, [d_tot]
    sub    rax, [d_lib]
    mov    [d_uso], rax

    xor    edx, edx
    mov    rax, [d_uso]
    mov    rcx, 100
    mul    rcx
    mov    rcx, [d_tot]
    test   rcx, rcx
    jz     .d_cero
    div    rcx
    cmp    rax, 100
    jbe    .d_ok
    mov    rax, 100
    jmp    .d_ok
.d_cero:
    xor    rax, rax
.d_ok:
    mov    [d_pct], rax

    invoke  wsprintfA, txt, fmt_dis, [d_tot], [d_lib], [d_uso], [d_pct]
    invoke  SetDlgItemTextA, rbx, IDC_VAL_DISCO, txt
    invoke  SendDlgItemMessage, rbx, IDC_BAR_DISCO, PBM_SETPOS, [d_pct], 0

    mov    rcx, rbx
    mov    rdx, IDC_BAR_DISCO
    mov    r8,  [d_pct]
    call   set_bar_color

    ; ==================================================
    ; CPU  (GetSystemTimes -> delta kernel+user vs idle)
    ; ==================================================
    invoke  GetSystemTimes, ft_idle, ft_kern, ft_user

    ; Calcular deltas respecto a lectura anterior
    mov    rax, [ft_idle]
    sub    rax, [ft_idle_p]
    mov    [d_idle_n], rax

    mov    rax, [ft_kern]
    sub    rax, [ft_kern_p]
    mov    [d_kern_n], rax

    mov    rax, [ft_user]
    sub    rax, [ft_user_p]
    mov    [d_user_n], rax

    ; Guardar valores actuales para el proximo ciclo
    mov    rax, [ft_idle]
    mov    [ft_idle_p], rax
    mov    rax, [ft_kern]
    mov    [ft_kern_p], rax
    mov    rax, [ft_user]
    mov    [ft_user_p], rax

    ; cpu_pct = 100 - (d_idle_n * 100) / (d_kern_n + d_user_n)
    mov    rax, [d_kern_n]
    add    rax, [d_user_n]   ; total = kernel + user
    test   rax, rax
    jz     .cpu_cero

    mov    rcx, rax           ; rcx = total
    mov    rax, [d_idle_n]   ; rax = idle
    mov    r8,  100
    mul    r8                 ; RDX:RAX = idle * 100
    div    rcx                ; RAX = idle_pct

    cmp    rax, 100
    jae    .cpu_cero
    mov    rcx, 100
    sub    rcx, rax           ; cpu_pct = 100 - idle_pct
    mov    [cpu_pct], rcx
    jmp    .cpu_ok
.cpu_cero:
    mov    qword [cpu_pct], 0
.cpu_ok:

    invoke  wsprintfA, txt, fmt_cpu, [cpu_pct]
    invoke  SetDlgItemTextA, rbx, IDC_VAL_CPU, txt
    invoke  SendDlgItemMessage, rbx, IDC_BAR_CPU, PBM_SETPOS, [cpu_pct], 0

    mov    rcx, rbx
    mov    rdx, IDC_BAR_CPU
    mov    r8,  [cpu_pct]
    call   set_bar_color

    ; ==================================================
    ; GPU (simulado con GetTickCount para mostrar la grafica)
    ; ==================================================
    invoke  GetTickCount
    xor     edx, edx
    mov     ecx, 100
    div     ecx
    mov     [gpu_pct], rax

    invoke  wsprintfA, txt, fmt_gpu, [gpu_pct]
    invoke  SetDlgItemTextA, rbx, IDC_VAL_GPU, txt
    invoke  SendDlgItemMessage, rbx, IDC_BAR_GPU, PBM_SETPOS, [gpu_pct], 0

    mov    rcx, rbx
    mov    rdx, IDC_BAR_GPU
    mov    r8,  [gpu_pct]
    call   set_bar_color

    ; Historial ASCII de GPU
    lea    rsi, [gpu_hist + 1]
    lea    rdi, [gpu_hist]
    mov    rcx, 29
    rep    movsb

    mov    rax, [gpu_pct]
    cmp    rax, 75
    ja     .gpu_hist_hash
    cmp    rax, 35
    ja     .gpu_hist_star
    mov    byte [gpu_hist + 29], '.'
    jmp    .gpu_hist_done
.gpu_hist_star:
    mov    byte [gpu_hist + 29], '*'
    jmp    .gpu_hist_done
.gpu_hist_hash:
    mov    byte [gpu_hist + 29], '#'
.gpu_hist_done:

    lea    rdi, [gpu_graph_str]
    mov    rcx, 30
    lea    rsi, [gpu_hist]
    rep    movsb
    mov    byte [rdi], 0
    invoke  SetDlgItemTextA, rbx, IDC_GPU_GRAPH, gpu_graph_str

    ; ==================================================
    ; ESTADO GENERAL
    ; ==================================================
    mov    rax, [ram_pct]
    cmp    rax, 85
    jge    .alerta

    mov    rax, [d_pct]
    cmp    rax, 85
    jge    .alerta

    mov    rax, [cpu_pct]
    cmp    rax, 85
    jge    .alerta

    invoke  SetDlgItemTextA, rbx, IDC_ESTADO, _msg_ok
    jmp    .estado_fin

.alerta:
    invoke  SetDlgItemTextA, rbx, IDC_ESTADO, _msg_alerta

.estado_fin:
    ret
endp


; ---------------------------------------------------
; WndProc - Procedimiento principal de la ventana
; ---------------------------------------------------
proc WndProc uses rbx rsi rdi, hwnd, wmsg, wparam, lparam

    cmp  edx, WM_CREATE   ; edx = wmsg (32-bit suffix de RDX = wmsg)
    je   .on_create
    cmp  edx, WM_TIMER
    je   .on_timer
    cmp  edx, WM_DESTROY
    je   .on_destroy

.default:
    invoke  DefWindowProc, rcx, rdx, r8, r9
    jmp    .fin

; ----- WM_CREATE: crear controles e iniciar timer -----
.on_create:
    mov    rbx, rcx          ; hwnd en rbx (callee-saved)

    ; -- SECCION: MEMORIA RAM --
    invoke  CreateWindowEx, 0, _STATIC, _hdr_ram, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 10, 488, 22, rbx, IDC_HDR_RAM, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_LEFT, \
            8, 36, 488, 16, rbx, IDC_VAL_RAM, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _PROGRESS, _empty, \
            WS_CHILD+WS_VISIBLE, \
            8, 56, 488, 22, rbx, IDC_BAR_RAM, [wc.hInstance], NULL

    ; -- SECCION: DISCO LOCAL --
    invoke  CreateWindowEx, 0, _STATIC, _hdr_disco, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 92, 488, 22, rbx, IDC_HDR_DISCO, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_LEFT, \
            8, 118, 488, 16, rbx, IDC_VAL_DISCO, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _PROGRESS, _empty, \
            WS_CHILD+WS_VISIBLE, \
            8, 138, 488, 22, rbx, IDC_BAR_DISCO, [wc.hInstance], NULL

    ; -- SECCION: PROCESADOR --
    invoke  CreateWindowEx, 0, _STATIC, _hdr_cpu, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 174, 488, 22, rbx, IDC_HDR_CPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_LEFT, \
            8, 200, 488, 16, rbx, IDC_VAL_CPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _PROGRESS, _empty, \
            WS_CHILD+WS_VISIBLE, \
            8, 220, 488, 22, rbx, IDC_BAR_CPU, [wc.hInstance], NULL

    ; -- SECCION: GPU --
    invoke  CreateWindowEx, 0, _STATIC, _hdr_gpu, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 258, 488, 22, rbx, IDC_HDR_GPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_LEFT, \
            8, 284, 488, 16, rbx, IDC_VAL_GPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _PROGRESS, _empty, \
            WS_CHILD+WS_VISIBLE, \
            8, 304, 488, 22, rbx, IDC_BAR_GPU, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _hdr_gpu_hist, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 332, 488, 18, rbx, IDC_HDR_GPU_HIST, [wc.hInstance], NULL

    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_LEFT+WS_BORDER, \
            8, 354, 488, 24, rbx, IDC_GPU_GRAPH, [wc.hInstance], NULL

    ; -- ESTADO GENERAL --
    invoke  CreateWindowEx, 0, _STATIC, _empty, \
            WS_CHILD+WS_VISIBLE+SS_CENTER, \
            8, 386, 488, 24, rbx, IDC_ESTADO, [wc.hInstance], NULL

    ; Configurar rangos de barras (0 - 100)
    invoke  SendDlgItemMessage, rbx, IDC_BAR_RAM,   PBM_SETRANGE, 0, 100
    invoke  SendDlgItemMessage, rbx, IDC_BAR_DISCO, PBM_SETRANGE, 0, 100
    invoke  SendDlgItemMessage, rbx, IDC_BAR_CPU,   PBM_SETRANGE, 0, 100

    ; Fondo oscuro para las barras
    invoke  SendDlgItemMessage, rbx, IDC_BAR_RAM,   PBM_SETBKCOLOR, 0, CLR_FONDO_PB
    invoke  SendDlgItemMessage, rbx, IDC_BAR_DISCO, PBM_SETBKCOLOR, 0, CLR_FONDO_PB
    invoke  SendDlgItemMessage, rbx, IDC_BAR_CPU,   PBM_SETBKCOLOR, 0, CLR_FONDO_PB
    invoke  SendDlgItemMessage, rbx, IDC_BAR_GPU,   PBM_SETBKCOLOR, 0, CLR_FONDO_PB

    invoke  SendDlgItemMessage, rbx, IDC_BAR_RAM,   PBM_SETRANGE, 0, 100
    invoke  SendDlgItemMessage, rbx, IDC_BAR_DISCO, PBM_SETRANGE, 0, 100
    invoke  SendDlgItemMessage, rbx, IDC_BAR_CPU,   PBM_SETRANGE, 0, 100
    invoke  SendDlgItemMessage, rbx, IDC_BAR_GPU,   PBM_SETRANGE, 0, 100

    ; ----------------------------------------------------------
    ; LLAMADA DIRECTA A actualizar (no via invoke):
    ; Se carga hwnd en RCX (1er arg FastCall) y se usa CALL.
    ; rbx contiene hwnd porque 'uses rbx' lo preservo.
    ; ----------------------------------------------------------
    mov    rcx, rbx              ; RCX = hwnd (arg1 para actualizar)
    call   actualizar            ; Primera actualizacion inmediata

    ; INTERACCION CON EL ENTORNO: SetTimer registra un timer de
    ; Windows que enviara WM_TIMER cada 2000 ms a esta ventana.
    ; FastCall: RCX=hwnd, RDX=ID_TIMER=1, R8=2000ms, R9=NULL
    invoke  SetTimer, rbx, ID_TIMER, 2000, NULL
    xor    eax, eax              ; Retornar 0 (WM_CREATE procesado OK)
    jmp    .fin

; ----- WM_TIMER: refrescar datos cada 2 segundos -----
.on_timer:
    ; RCX = hwnd en el momento de recibir WM_TIMER.
    ; El prologue del proc no modifica RCX, sigue siendo hwnd.
    ; Se llama directamente (no invoke) para evitar overhead.
    call   actualizar            ; Refrescar RAM, Disco, CPU en pantalla
    xor    eax, eax              ; Retornar 0 (mensaje procesado)
    jmp    .fin

; ----- WM_DESTROY: liberar timer y terminar el bucle -----
.on_destroy:
    ; INTERACCION CON EL ENTORNO: KillTimer cancela el timer
    ; para evitar WM_TIMER despues de destruir la ventana.
    ; FastCall: RCX=hwnd, RDX=ID_TIMER (id a cancelar)
    invoke  KillTimer, rcx, ID_TIMER  ; Detener el timer de 2s
    ; PostQuitMessage envia WM_QUIT al bucle de mensajes,
    ; lo que hace que GetMessage retorne 0 y el bucle termine.
    invoke  PostQuitMessage, 0         ; Senalizar fin del bucle
    xor    eax, eax                    ; Retornar 0

.fin:
    ret
endp


; ---------------------------------------------------
; PUNTO DE ENTRADA
; ---------------------------------------------------
start:
    ; ----------------------------------------------------------
    ; ALINEACION INICIAL DEL STACK (Windows x64)
    ; Al entrar a 'start' como punto de entrada de un PE64 GUI,
    ; el SO garantiza RSP alineado a 16 bytes (sin push de ret).
    ; sub rsp, 8 adiciona 8 bytes para que el primer CALL dentro
    ; de 'start' deje RSP = 0 mod 16 (RSP-8 tras push de ret = 0).
    ; Esto es obligatorio por la ABI x64 de Microsoft.
    ; ----------------------------------------------------------
    sub  rsp, 8              ; Ajuste de alineacion a 16 bytes

    invoke  InitCommonControls

    invoke  GetModuleHandle, 0
    mov    [wc.hInstance], rax

    invoke  LoadIcon,   0, IDI_APPLICATION
    mov    [wc.hIcon],   rax
    mov    [wc.hIconSm], rax

    invoke  LoadCursor, 0, IDC_ARROW
    mov    [wc.hCursor], rax

    invoke  RegisterClassEx, wc
    test   rax, rax
    jz     .error

    ; Centrar ventana en pantalla
    invoke  GetSystemMetrics, SM_CXSCREEN
    sub    eax, WIN_W
    sar    eax, 1
    mov    [pos_x], eax

    invoke  GetSystemMetrics, SM_CYSCREEN
    sub    eax, WIN_H
    sar    eax, 1
    mov    [pos_y], eax

    invoke  CreateWindowEx, 0, _wclass, _titulo, \
            WS_CAPTION+WS_SYSMENU+WS_MINIMIZEBOX+WS_VISIBLE, \
            [pos_x], [pos_y], WIN_W, WIN_H, \
            NULL, NULL, [wc.hInstance], NULL
    test   rax, rax
    jz     .error

.loop:
    invoke  GetMessage, msg, NULL, 0, 0
    cmp    eax, 1
    jb     .done
    jne    .loop
    invoke  TranslateMessage, msg
    invoke  DispatchMessage,  msg
    jmp    .loop

.error:
    invoke  MessageBox, NULL, _errmsg, _titulo, MB_ICONERROR+MB_OK

.done:
    invoke  ExitProcess, [msg.wParam]


; ===================================================
; DATOS INICIALIZADOS
; ===================================================
section '.data' data readable writeable

    _wclass  db 'TechScan64Monitor', 0
    _titulo  db 'TechScan64  -  Monitor en Tiempo Real', 0
    _errmsg  db 'Error al crear la ventana.', 0
    _STATIC  db 'STATIC', 0
    _PROGRESS db 'msctls_progress32', 0
    _empty   db 0
    _drv     db 'C:\', 0

    _hdr_ram   db '====  MEMORIA RAM  ====', 0
    _hdr_disco db '====  DISCO LOCAL  C:\  ====', 0
    _hdr_cpu   db '====  PROCESADOR  ====', 0
    _hdr_gpu   db '====  GPU  ====', 0

    _msg_ok     db '   Estado: NORMAL  |  Sin alertas activas   ', 0
    _msg_alerta db '   !!!  ALERTA: Recurso critico detectado  !!!   ', 0

    fmt_ram  db 'Total: %u MB  |  Libre: %u MB  |  En uso: %u MB  (%u%%)', 0
    fmt_dis  db 'Total: %u MB  |  Libre: %u MB  |  En uso: %u MB  (%u%%)', 0
    fmt_cpu  db 'Uso del procesador: %u%%', 0
    fmt_gpu  db 'Uso de GPU: %u%%', 0

    _hdr_gpu_hist db '====  HISTORIAL GPU  ====', 0

    pos_x  dd 0
    pos_y  dd 0

    wc WNDCLASSEX sizeof.WNDCLASSEX, CS_HREDRAW+CS_VREDRAW, WndProc, \
                  0, 0, NULL, NULL, NULL, COLOR_BTNFACE+1, NULL, _wclass, NULL

    msg MSG


; ===================================================
; DATOS NO INICIALIZADOS
; ===================================================
section '.bss' readable writeable

    txt     rb 256    ; buffer de texto para wsprintfA

    memst   rb 64     ; MEMORYSTATUSEX (64 bytes)

    ; RAM en MB
    ram_tot rq 1
    ram_lib rq 1
    ram_uso rq 1
    ram_pct rq 1

    ; Disco (bytes crudos y MB calculados)
    d_tot_q rq 1
    d_lib_q rq 1
    d_tot   rq 1
    d_lib   rq 1
    d_uso   rq 1
    d_pct   rq 1

    ; CPU - FILETIME como QWORD
    ft_idle   rq 1
    ft_kern   rq 1
    ft_user   rq 1
    ft_idle_p rq 1   ; lecturas anteriores
    ft_kern_p rq 1
    ft_user_p rq 1
    d_idle_n  rq 1   ; deltas
    d_kern_n  rq 1
    d_user_n  rq 1
    cpu_pct   rq 1
    gpu_pct   rq 1
    gpu_hist  rb 30
    gpu_graph_str rb 32


; ===================================================
; TABLA DE IMPORTACIONES
; ===================================================
section '.idata' import data readable writeable

    library kernel32, 'KERNEL32.DLL', \
            user32,   'USER32.DLL',   \
            comctl32, 'COMCTL32.DLL'

    ; kernel32
    import kernel32, \
           GetModuleHandle,     'GetModuleHandleA',   \
           ExitProcess,         'ExitProcess',         \
           GlobalMemoryStatusEx,'GlobalMemoryStatusEx',\
           GetDiskFreeSpaceExA, 'GetDiskFreeSpaceExA', \
           GetSystemTimes,      'GetSystemTimes',\
           GetTickCount,        'GetTickCount'

    ; user32
    import user32, \
           RegisterClassEx,    'RegisterClassExA',   \
           CreateWindowEx,     'CreateWindowExA',    \
           GetMessage,         'GetMessageA',         \
           TranslateMessage,   'TranslateMessage',    \
           DispatchMessage,    'DispatchMessageA',    \
           DefWindowProc,      'DefWindowProcA',      \
           PostQuitMessage,    'PostQuitMessage',      \
           MessageBox,         'MessageBoxA',          \
           SendDlgItemMessage, 'SendDlgItemMessageA', \
           SetDlgItemTextA,    'SetDlgItemTextA',     \
           wsprintfA,          'wsprintfA',            \
           SetTimer,           'SetTimer',             \
           KillTimer,          'KillTimer',            \
           LoadIcon,           'LoadIconA',            \
           LoadCursor,         'LoadCursorA',          \
           GetSystemMetrics,   'GetSystemMetrics'

    ; comctl32
    import comctl32, \
           InitCommonControls, 'InitCommonControls'
