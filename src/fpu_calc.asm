; ==============================================================
; Archivo      : src/fpu_calc.asm
; Proyecto     : TechScan64 - Modulo Analitico FPU
; Institucion  : U.M.S.S. - Facultad de Tecnologia
; Asignatura   : Taller de Programacion en Bajo Nivel
; Ensamblador  : NASM (Netwide Assembler) - formato COFF/Win64
; Arquitectura : Windows x86-64 (PE64, ABI Microsoft x64)
; Descripcion  :
;   Implementa el calculo del Puntaje de Salud del Equipo
;   usando EXCLUSIVAMENTE el coprocesador matematico x87 (FPU).
;   Aplica la formula ponderada de punto flotante real:
;
;     score = (ram_libre%  * 0.40)
;           + (disco_libre% * 0.35)
;           + (cpu_libre%  * 0.25)
;
;   donde: cpu_libre% = 100.0 - cpu_usado%
;
;   Requisito #5: Uso del Coprocesador Matematico / FPU
;   Instrucciones demostradas: FINIT, FILD, FMUL, FADDP,
;                              FLD, FSUBP, FSTP, FISTP
;
; Convencion   : Microsoft FastCall x64
;   Parametros: RCX=ram_libre_pct, RDX=disco_libre_pct, R8=cpu_pct
;   Retorno   : EAX = puntaje entero (0-100)
; ==============================================================

bits 64
default rel     ; Usar direccionamiento RIP-relativo por defecto

; ---- Simbolos exportados (visibles desde C y otros modulos) ----
global calcular_puntaje_fpu   ; Funcion principal de calculo FPU
global calcular_porcentaje_fpu ; RCX=parte, RDX=total -> EAX=parte/total*100
global calcular_promedio_fpu   ; RCX=suma, RDX=cantidad -> EAX=promedio
global puntaje_fpu_real        ; Variable global: resultado double

; ==============================================================
; SECCION .data - Constantes de punto flotante IEEE 754 (64-bit)
; ==============================================================
section .data

    ; ----------------------------------------------------------
    ; Factores de ponderacion para la formula de salud.
    ; Se almacenan como double precision (8 bytes, IEEE 754).
    ; La RAM recibe mayor peso (40%) por ser el recurso critico.
    ; El disco (35%) y el CPU libre (25%) completan el 100%.
    ; ----------------------------------------------------------
    peso_ram    dq 0.40        ; Factor: contribucion de RAM libre
    peso_disco  dq 0.35        ; Factor: contribucion de Disco libre
    peso_cpu    dq 0.25        ; Factor: contribucion de CPU libre

    ; Constante 100.0 para calcular cpu_libre = 100 - cpu_usado
    const_100   dq 100.0       ; Referencia de maximo porcentaje

; ==============================================================
; SECCION .bss - Variables no inicializadas
; ==============================================================
section .bss

    ; Resultado persistente en punto flotante (doble precision)
    puntaje_fpu_real   resq 1  ; double: puntaje sin truncar (0.0-100.0)

    ; Auxiliar para la conversion float -> entero (FISTP)
    _fpu_entero        resq 1  ; QWORD temporal para FISTP
    _fpu_arg1          resq 1
    _fpu_arg2          resq 1

; ==============================================================
; SECCION .text - Codigo ejecutable
; ==============================================================
section .text

; ==============================================================
; calcular_puntaje_fpu
; --------------------------------------------------------------
; Calcula el Puntaje de Salud del equipo (0-100) usando
; instrucciones del coprocesador matematico x87.
;
; CONVENCION DE LLAMADAS - Microsoft FastCall x64:
;   RCX = ram_libre_pct   (QWORD, % RAM libre,  0-100)
;   RDX = disco_libre_pct (QWORD, % Disco libre, 0-100)
;   R8  = cpu_pct_usado   (QWORD, % CPU carga,  0-100)
;
; REGISTROS MODIFICADOS (caller-saved, no preservados por callee):
;   RAX (retorno), RCX, RDX, R8, R9, R10, R11
;
; REGISTROS PRESERVADOS (callee-saved, guardados/restaurados):
;   RBX, RBP, RSI, RDI, R12-R15, XMM6-XMM15
;
; RETORNO:
;   EAX = Puntaje de Salud entero en rango [0, 100]
;         Interpretacion: 80-100=Excelente, 60-79=Bueno,
;                         40-59=Regular,    0-39=Critico
; ==============================================================
calcular_puntaje_fpu:

    ; ----------------------------------------------------------
    ; CONTROL DEL MARCO DE LA PILA (Stack Frame - Windows x64)
    ; ----------------------------------------------------------
    ; Al entrar a la funcion, RSP apunta a la dir. de retorno
    ; (push implcito del CALL), dejando RSP en (16n + 8) bytes.
    ; push rbp agrega 8 bytes -> RSP queda alineado a 16 bytes.
    ; sub rsp, 48 = 32 (shadow space obligatorio) + 16 (locales).
    ; El total de ajuste: 8 (push ret) + 8 (push rbp) + 48 = 64
    ; bytes, multiplo de 16: RSP queda alineado correctamente.
    ; ----------------------------------------------------------
    push    rbp                 ; Salva el puntero de marco anterior
    mov     rbp, rsp            ; Nuevo marco: RBP = RSP actual
    sub     rsp, 48             ; Reserva shadow space (32) + locales (16)

    ; ----------------------------------------------------------
    ; CONVENCION DE LLAMADAS: Almacenar argumentos de registro
    ; en el Shadow Space (area de 32 bytes reservada por el
    ; LLAMADOR para que el LLAMADO pueda salvar RCX..R9).
    ; Offsets desde RBP: [rbp+16]=RCX, [rbp+24]=RDX, [rbp+32]=R8
    ; Esto preserva los valores antes de que cualquier instruccion
    ; pueda destruir el contenido de los registros.
    ; ----------------------------------------------------------
    mov     [rbp + 16], rcx    ; Shadow[0] = ram_libre_pct (1er arg)
    mov     [rbp + 24], rdx    ; Shadow[1] = disco_libre_pct (2do arg)
    mov     [rbp + 32], r8     ; Shadow[2] = cpu_pct_usado (3er arg)

    ; ----------------------------------------------------------
    ; USO DEL COPROCESADOR MATEMATICO x87 - INICIALIZACION
    ; FINIT: Resetea por software el estado completo del FPU:
    ;   * Vacia la pila de registros ST(0)-ST(7)
    ;   * Limpia los flags de estado (SW) y excepciones (CW)
    ;   * Establece modo de precision extendida (80-bit interno)
    ;   Garantiza un estado limpio antes de operar con la FPU.
    ; ----------------------------------------------------------
    finit

    ; ==========================================================
    ; TERMINO 1: Contribucion RAM = ram_libre_pct * 0.40
    ; ==========================================================
    ; FILD - Carga Entero Largo (Load Integer Long):
    ;   Lee un entero de 64 bits desde memoria ([rbp+16]),
    ;   lo convierte a real de 80 bits y lo apila en ST(0).
    ;   No modifica ningun registro de proposito general.
    ;   Estado de pila FPU tras FILD: ST(0) = (double) ram_libre_pct
    ; ----------------------------------------------------------
    fild    qword [rbp + 16]    ; ST(0) = (real) ram_libre_pct

    ; FMUL - Multiplicacion de Punto Flotante:
    ;   Multiplica ST(0) por el double de 64 bits en memoria.
    ;   [peso_ram] = 0.40 almacenado como IEEE 754 en .data
    ;   Resultado: ST(0) = ram_libre_pct * 0.40 = termino_RAM
    ; ----------------------------------------------------------
    fmul    qword [peso_ram]    ; ST(0) = termino_RAM (40% de RAM)

    ; ==========================================================
    ; TERMINO 2: Contribucion Disco = disco_libre_pct * 0.35
    ; Estado FPU antes: ST(0) = termino_RAM
    ; ==========================================================
    ; FILD carga el 2do argumento (disco_libre_pct) en ST(0),
    ; desplazando termino_RAM a ST(1):
    ;   ST(0) = (real) disco_libre_pct,  ST(1) = termino_RAM
    ; ----------------------------------------------------------
    fild    qword [rbp + 24]    ; ST(0)=disco_pct, ST(1)=termino_RAM
    fmul    qword [peso_disco]  ; ST(0) = disco_pct * 0.35 = termino_DISCO

    ; FADDP - Suma con Desapilado (Floating Add and Pop):
    ;   Calcula ST(1) = ST(1) + ST(0) y luego hace POP de ST(0).
    ;   Efecto: suma termino_RAM + termino_DISCO en una sola op.
    ;   Estado FPU tras FADDP: ST(0) = suma_parcial (term1+term2)
    ; ----------------------------------------------------------
    faddp                       ; ST(0) = termino_RAM + termino_DISCO

    ; ==========================================================
    ; TERMINO 3: Contribucion CPU = (100 - cpu_pct_usado) * 0.25
    ; Invertimos el % de USO de CPU para obtener % de LIBRE.
    ; Estado FPU antes: ST(0) = suma_parcial
    ; ==========================================================
    ; FLD - Carga Real (Load Real):
    ;   Apila el valor double 100.0 en ST(0), desplaza todo.
    ;   Estado: ST(0)=100.0,  ST(1)=suma_parcial
    ; ----------------------------------------------------------
    fld     qword [const_100]   ; ST(0)=100.0, ST(1)=suma_parcial

    ; FILD carga cpu_pct_usado como real en ST(0):
    ;   Estado: ST(0)=cpu_usado, ST(1)=100.0, ST(2)=suma_parcial
    ; ----------------------------------------------------------
    fild    qword [rbp + 32]    ; ST(0)=cpu_usado, ST(1)=100.0, ST(2)=suma

    ; FSUBP - Resta con Desapilado (Floating Subtract and Pop):
    ;   Calcula ST(1) = ST(1) - ST(0) = 100.0 - cpu_usado
    ;   luego hace POP de ST(0).
    ;   Resultado: ST(0) = cpu_libre_pct,  ST(1) = suma_parcial
    ; ----------------------------------------------------------
    fsubp                       ; ST(0)=cpu_libre%, ST(1)=suma_parcial

    fmul    qword [peso_cpu]    ; ST(0) = cpu_libre% * 0.25 = termino_CPU

    ; FADDP acumula el tercer termino con la suma parcial.
    ; Resultado final: ST(0) = puntaje_final (rango 0.0 a 100.0)
    ; ----------------------------------------------------------
    faddp                       ; ST(0) = PUNTAJE FINAL (suma de 3 terminos)

    ; ==========================================================
    ; PERSISTENCIA Y CONVERSION DEL RESULTADO
    ; ==========================================================
    ; FSTP - Almacena Real y Desapila (Store Real and Pop):
    ;   Copia ST(0) como double de 64 bits a la variable global
    ;   [puntaje_fpu_real] y hace POP de la pila FPU.
    ;   La pila queda vacia despues de FSTP.
    ; ----------------------------------------------------------
    fstp    qword [puntaje_fpu_real]   ; Guarda double, vacia ST(0)

    ; FLD recarga el resultado para la conversion a entero.
    ;   Estado FPU: ST(0) = puntaje_final (double)
    ; ----------------------------------------------------------
    fld     qword [puntaje_fpu_real]   ; ST(0) = puntaje (recarga)

    ; FISTP - Almacena Entero y Desapila (Store Integer and Pop):
    ;   Convierte ST(0) a entero de 64 bits usando el modo de
    ;   redondeo del coprocesador (por defecto: "al mas cercano").
    ;   Guarda el entero en [_fpu_entero] y hace POP de la pila.
    ;   Esto cierra el ciclo FPU: ingresaron enteros, sale entero.
    ; ----------------------------------------------------------
    fistp   qword [_fpu_entero]        ; Convierte a QWORD, pop FPU

    ; ----------------------------------------------------------
    ; RETORNO: EAX = puntaje entero [0..100]
    ; En x64, escribir a EAX zero-extiende automaticamente a RAX.
    ; ----------------------------------------------------------
    mov     eax, dword [_fpu_entero]   ; EAX = puntaje (32-bit)

    ; ESTRUCTURAS DE CONTROL: Acotar el resultado al rango valido.
    ; CMP actualiza EFLAGS (CF, ZF, SF, OF) sin modificar EAX.
    ; JLE bifurca si EAX <= 100 (ZF=1 o SF=OF), preserva EAX.
    ; ----------------------------------------------------------
    cmp     eax, 100            ; Comparar con limite maximo 100
    jle     .dentro_rango       ; Si EAX <= 100, resultado valido
    mov     eax, 100            ; Saturar al maximo permitido

.dentro_rango:
    ; JGE bifurca si EAX >= 0 (SF=OF), salta si es no-negativo.
    cmp     eax, 0              ; Comparar con limite minimo 0
    jge     .retornar           ; Si EAX >= 0, resultado valido
    xor     eax, eax            ; Limpiar EAX (saturar al minimo 0)

.retornar:
    ; ----------------------------------------------------------
    ; RESTAURACION DEL MARCO DE LA PILA
    ; Se invierten exactamente las operaciones del prologo.
    ; ADD rsp, 48: libera el shadow space y variables locales.
    ; POP rbp: restaura el puntero de marco del llamador.
    ; RET: transfiere control al llamador con EAX = puntaje.
    ; ----------------------------------------------------------
    add     rsp, 48             ; Libera shadow space + vars locales
    pop     rbp                 ; Restaura el puntero de marco anterior
    ret                         ; Retorna: EAX = Puntaje de Salud (0-100)

; ==============================================================
; calcular_porcentaje_fpu
; RCX = parte, RDX = total
; Retorna EAX = round((parte / total) * 100)
; ==============================================================
calcular_porcentaje_fpu:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    test    rdx, rdx
    jz      .pct_zero

    mov     [_fpu_arg1], rcx
    mov     [_fpu_arg2], rdx

    finit
    fild    qword [_fpu_arg1]
    fild    qword [_fpu_arg2]
    fdivp   st1, st0
    fmul    qword [const_100]
    fistp   qword [_fpu_entero]

    mov     eax, dword [_fpu_entero]
    cmp     eax, 100
    jle     .pct_low
    mov     eax, 100
.pct_low:
    cmp     eax, 0
    jge     .pct_done
.pct_zero:
    xor     eax, eax
.pct_done:
    add     rsp, 32
    pop     rbp
    ret

; ==============================================================
; calcular_promedio_fpu
; RCX = suma, RDX = cantidad
; Retorna EAX = round(suma / cantidad)
; ==============================================================
calcular_promedio_fpu:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    test    rdx, rdx
    jz      .avg_zero

    mov     [_fpu_arg1], rcx
    mov     [_fpu_arg2], rdx

    finit
    fild    qword [_fpu_arg1]
    fild    qword [_fpu_arg2]
    fdivp   st1, st0
    fistp   qword [_fpu_entero]

    mov     eax, dword [_fpu_entero]
    cmp     eax, 0
    jge     .avg_done
.avg_zero:
    xor     eax, eax
.avg_done:
    add     rsp, 32
    pop     rbp
    ret
