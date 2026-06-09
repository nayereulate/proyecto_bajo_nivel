# 🖥️ TechScan64

> **Sistema Portátil de Diagnóstico y Monitoreo de Equipos Informáticos**  
> Universidad Mayor de San Simón · Facultad de Ingeniería · Taller de Programación en Bajo Nivel · Junio 2026

<div align="center">

![Arquitectura](https://img.shields.io/badge/Arquitectura-x86--64-blue?style=for-the-badge&logo=intel)
![Lenguaje](https://img.shields.io/badge/Lenguaje-ASM%20%2B%20C-orange?style=for-the-badge)
![Plataforma](https://img.shields.io/badge/Plataforma-Windows-0078D6?style=for-the-badge&logo=windows)
![Estado](https://img.shields.io/badge/Estado-En%20Desarrollo-yellow?style=for-the-badge)
![Grupo](https://img.shields.io/badge/Grupo-5%20Integrantes-green?style=for-the-badge)

</div>

---

## 📋 Tabla de Contenidos

- [Resumen](#-resumen)
- [Problema que Resuelve](#-problema-que-resuelve)
- [Características Principales](#-características-principales)
- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Módulos](#-módulos)
  - [Módulo 1 – Interfaz y Menú](#módulo-1--interfaz-menú-y-control-de-flujo)
  - [Módulo 2 – Captura de Hardware](#módulo-2--captura-de-información-del-equipo)
  - [Módulo 3 – Persistencia y Reportes](#módulo-3--persistencia-y-formato-de-reportes)
  - [Módulo 4 – Monitoreo y FPU](#módulo-4--monitoreo-local-y-cálculos-fpu)
  - [Módulo 5 – Análisis Central](#módulo-5--análisis-central-y-comparación-de-laboratorios)
- [Estructura de Datos](#-estructura-de-datos)
- [Formato de Archivo `.rep`](#-formato-de-archivo-rep)
- [Interfaz de Usuario](#-interfaz-de-usuario)
- [Cálculos FPU](#-cálculos-fpu)
- [Flujos de Ejecución](#-flujos-de-ejecución)
- [División del Trabajo](#-división-del-trabajo)
- [Requisitos del Sistema](#-requisitos-del-sistema)
- [Compilación y Ensamblado](#-compilación-y-ensamblado)
- [Uso desde USB](#-uso-desde-usb)
- [Entregables](#-entregables)
- [Justificación 64 bits](#-justificación-técnica-de-64-bits)
- [Bibliografía](#-bibliografía)

---

## 🧠 Resumen

**TechScan64** es una aplicación portátil en ensamblador x86-64 y C que permite diagnosticar y monitorear equipos informáticos directamente desde una **memoria USB**, sin necesidad de instalación. El mismo ejecutable funciona en dos roles:

| Rol | Descripción |
|---|---|
| 🔍 **Herramienta de captura** | Se ejecuta en una PC individual, obtiene datos reales del hardware vía Windows API y guarda un reporte `.rep`. |
| 📊 **Analizador central** | Lee múltiples reportes almacenados en la USB y genera comparaciones, estadísticas y alertas técnicas por laboratorio. |

---

## 🔧 Problema que Resuelve

En laboratorios de computación, oficinas técnicas y entornos de soporte, el mantenimiento suele hacerse con información dispersa. TechScan64 centraliza ese flujo respondiendo estas preguntas clave:

- ¿Qué equipo tiene **menor disponibilidad de recursos**?
- ¿Cuál presenta **mayor antigüedad tecnológica**?
- ¿Qué PC requiere **revisión prioritaria**?
- ¿Cómo se comporta el **laboratorio completo** al analizar varias máquinas?

---

## ✨ Características Principales

- ✅ Ejecutable **portátil desde USB** — sin instalación en la PC objetivo
- ✅ Núcleo en **ensamblador x86-64** con convención de llamadas por registros
- ✅ Captura de hardware vía **Windows API** (CPU, RAM, disco, GPU, placa base)
- ✅ **Monitoreo en tiempo real** con refresco periódico de recursos
- ✅ Reportes binarios estructurados en formato `.rep`
- ✅ **Módulo FPU** para cálculo de porcentajes, promedios y ratios
- ✅ **Analizador central** para comparar múltiples equipos / laboratorios
- ✅ Interfaz de consola interactiva con validación de entradas

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                        TechScan64                       │
│                     (main.c + módulos)                  │
├──────────────┬──────────────┬───────────────────────────┤
│  Flujo A     │              │  Flujo B                  │
│  Diagnóstico │              │  Análisis Central         │
│  Local       │              │  (multi-reporte)          │
└──────┬───────┘              └──────────┬────────────────┘
       │                                 │
       ▼                                 ▼
┌──────────────┐              ┌──────────────────────────┐
│  api_scan    │              │  analyzer.c              │
│  .asm        │              │  Lee reportes .rep       │
│  Windows API │              │  desde la USB            │
└──────┬───────┘              └──────────┬───────────────┘
       │                                 │
       ▼                                 ▼
┌──────────────┐              ┌──────────────────────────┐
│  report_io.c │              │  stats_fpu.asm           │
│  Escribe     │◄────────────►│  Promedios, ratios,      │
│  archivos    │              │  comparaciones FPU       │
│  .rep / .log │              └──────────────────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  monitor.asm │
│  Refresco    │
│  periódico   │
│  de pantalla │
└──────────────┘
```

---

## 📁 Estructura del Proyecto

```
TechScan64/
│
├── src/
│   ├── main.c              # Control de flujo principal e interfaz
│   ├── api_scan.asm        # Obtención de datos del equipo (Windows API + CPUID)
│   ├── report_io.c         # Lectura y escritura de reportes .rep y logs .log
│   ├── monitor.asm         # Actualización periódica de recursos en pantalla
│   ├── stats_fpu.asm       # Cálculos FPU y estadísticas globales
│   └── analyzer.c          # Comparación de equipos y resumen de laboratorios
│
├── include/
│   ├── techscan.h          # Definiciones, constantes y prototipos compartidos
│   ├── structures.h        # Definición de la estructura EquipoRecord
│   └── report_format.h     # Constantes del formato binario .rep
│
├── reports/                # Carpeta de salida para archivos .rep generados
│
├── logs/                   # Archivos de eventos y errores .log
│
├── docs/
│   ├── informe_tecnico.pdf
│   ├── informe_tecnico.docx
│   └── diagrama_arquitectura.png
│
├── build/
│   └── TechScan64.exe      # Ejecutable final (se copia a la USB)
│
├── Makefile                # Script de compilación y ensamblado
└── README.md               # Este archivo
```

---

## 🧩 Módulos

### Módulo 1 – Interfaz, Menú y Control de Flujo
**Archivo:** `main.c`  
**Responsable:** Integrante 1

Gestiona toda la interacción con el usuario. Implementa el menú principal, la validación de entradas y la navegación entre modos.

**Responsabilidades:**
- Pantalla de bienvenida con banner ASCII
- Menú principal con 5 opciones
- Validación de entradas numéricas y manejo de opciones fuera de rango
- Limpieza visual de consola entre pantallas
- Coordinación de llamadas hacia los demás módulos
- Mensajes de error descriptivos y estados de espera

**Pantalla de bienvenida:**
```
╔══════════════════════════════════════╗
║          T E C H S C A N 6 4        ║
║   Diagnóstico Portátil de Equipos   ║
╚══════════════════════════════════════╝
Versión 1.0 | x86-64 | UMSS 2026
```

---

### Módulo 2 – Captura de Información del Equipo
**Archivo:** `api_scan.asm`  
**Responsable:** Integrante 2

Núcleo de adquisición de datos. Implementado en ensamblador x86-64 con llamadas directas a la Windows API.

**Datos capturados:**

| Campo | Fuente API |
|---|---|
| Nombre de la PC | `GetComputerNameEx` |
| Usuario actual | `GetUserName` |
| Sistema operativo | `RtlGetVersion` / `VerifyVersionInfo` |
| Arquitectura | `GetSystemInfo` |
| Modelo de CPU | `CPUID` (EAX=0x80000002–4) |
| Número de núcleos | `GetSystemInfo.dwNumberOfProcessors` |
| RAM total | `GlobalMemoryStatusEx.ullTotalPhys` |
| RAM disponible | `GlobalMemoryStatusEx.ullAvailPhys` |
| Espacio libre en disco | `GetDiskFreeSpaceEx` |
| Modelo de GPU | Registro WMI / `setupapi` |
| Modelo de placa base | Registro WMI |

**Convención de llamadas (x86-64 Windows):**
- Parámetros: `RCX`, `RDX`, `R8`, `R9` (primeros 4 enteros/punteros)
- Valores de retorno: `RAX` / `XMM0`
- Registros preservados: `RBX`, `RBP`, `RDI`, `RSI`, `R12–R15`
- Shadow space: 32 bytes reservados antes de cada `CALL`

---

### Módulo 3 – Persistencia y Formato de Reportes
**Archivo:** `report_io.c`  
**Responsable:** Integrante 3

Maneja toda la lectura y escritura de datos persistentes. Define el formato binario portable para los archivos `.rep`.

**Tipos de archivo generados:**

| Extensión | Propósito |
|---|---|
| `.rep` | Reporte binario principal del equipo diagnosticado |
| `.log` | Registro de eventos, errores y timestamps |
| `.csv` | Exportación opcional de resúmenes para evidencia |

**Responsabilidades:**
- Serialización / deserialización de `EquipoRecord` al formato binario
- Escritura del encabezado con firma, versión y cantidad de registros
- Apertura y cierre correcto de handles (`CreateFile`, `WriteFile`, `CloseHandle`)
- Liberación de memoria dinámica tras cada operación
- Validación de integridad del archivo al leer (firma y versión)

---

### Módulo 4 – Monitoreo Local y Cálculos FPU
**Archivo:** `monitor.asm` + `stats_fpu.asm`  
**Responsable:** Integrante 4

Implementa el modo de monitoreo en tiempo real y todos los cálculos numéricos en punto flotante.

**Monitoreo periódico — datos refrescados:**
- RAM total y RAM disponible
- Uso aproximado de CPU (delta de `GetSystemTimes`)
- Espacio libre en disco principal
- Número de procesos activos (`CreateToolhelp32Snapshot`)
- Marca de tiempo de última actualización

**Cálculos FPU implementados:**

```nasm
; Ejemplo: porcentaje de RAM libre
; ram_libre / ram_total * 100.0

fild    QWORD PTR [ram_libre]    ; ST(0) = ram_libre
fild    QWORD PTR [ram_total]    ; ST(0) = ram_total, ST(1) = ram_libre
fdivp                             ; ST(0) = ram_libre / ram_total
fld     REAL8 PTR [cien]         ; ST(0) = 100.0
fmulp                             ; ST(0) = porcentaje
fstp    REAL8 PTR [resultado]    ; almacenar resultado
```

**Instrucciones FPU utilizadas:** `FLD`, `FILD`, `FADD`, `FMUL`, `FDIV`, `FDIVP`, `FMULP`, `FSTP`

---

### Módulo 5 – Análisis Central y Comparación de Laboratorios
**Archivo:** `analyzer.c`  
**Responsable:** Integrante 5

Lee todos los reportes `.rep` almacenados en la USB, los procesa y genera conclusiones técnicas agregadas.

**Funcionalidades:**
- Enumeración de archivos `.rep` en la ruta de la USB (`FindFirstFile` / `FindNextFile`)
- Carga de todos los registros en un arreglo de `EquipoRecord`
- Ordenamiento por RAM total, espacio libre o antigüedad estimada
- Agrupación por laboratorio, aula o sede (campo `id_grupo`)
- Generación de promedios globales vía llamadas a `stats_fpu.asm`
- Clasificación de equipos: Excelente / Bueno / Regular / Crítico
- Lista priorizada de equipos que requieren revisión técnica

---

## 🗂️ Estructura de Datos

La estructura principal se define manualmente por offsets en ensamblador, equivalente a la siguiente definición en C:

```c
// structures.h
typedef struct {
    uint32_t  id_equipo;        // offset  0  — Identificador numérico
    char      nombre_equipo[28];// offset  4  — Nombre corto del equipo
    char      cpu_modelo[32];   // offset 32  — Modelo/familia del procesador
    uint64_t  ram_total;        // offset 64  — Memoria total instalada (bytes)
    uint64_t  ram_libre;        // offset 72  — Memoria disponible (bytes)
    uint64_t  disco_libre;      // offset 80  — Espacio libre en disco (bytes)
    char      gpu_modelo[32];   // offset 88  — Modelo de tarjeta gráfica
    char      placa_modelo[32]; // offset 120 — Modelo de placa base
    char      usuario[32];      // offset 152 — Usuario actual al momento del scan
    char      so_version[32];   // offset 184 — Versión del sistema operativo
    uint32_t  num_nucleos;      // offset 216 — Núcleos lógicos del CPU
    uint32_t  num_procesos;     // offset 220 — Procesos activos al momento del scan
    uint64_t  timestamp;        // offset 224 — Timestamp UNIX del diagnóstico
    uint8_t   _padding[24];     // offset 232 — Relleno para alinear a 256 bytes
} EquipoRecord;                 // Tamaño total: 256 bytes por registro
```

**Acceso por offset en ensamblador:**
```nasm
; Cargar ram_total del registro apuntado por RBX
mov     rax, QWORD PTR [rbx + 64]

; Cargar nombre_equipo (puntero al string)
lea     rcx, [rbx + 4]
```

---

## 📦 Formato de Archivo `.rep`

Formato binario compacto, diseñado para lectura secuencial desde USB:

```
┌──────────────────────────────────────────┐
│  ENCABEZADO (64 bytes)                   │
│  ├─ Firma:        "TSCAN64\0" (8 bytes)  │
│  ├─ Versión:      uint16_t  (2 bytes)    │
│  ├─ Flags:        uint16_t  (2 bytes)    │
│  ├─ Fecha/hora:   uint64_t  (8 bytes)    │
│  ├─ Num registros:uint32_t  (4 bytes)    │
│  └─ Reservado:    (40 bytes)             │
├──────────────────────────────────────────┤
│  REGISTRO PRINCIPAL (256 bytes × N)      │
│  └─ N × EquipoRecord                    │
├──────────────────────────────────────────┤
│  BLOQUE DE MONITOREO (variable)          │
│  ├─ Valores de uso actual                │
│  ├─ Intervalo de refresco               │
│  └─ Marca de tiempo de cada muestra     │
├──────────────────────────────────────────┤
│  BLOQUE DE ESTADÍSTICAS (128 bytes)      │
│  ├─ Promedios (RAM, disco, núcleos)      │
│  ├─ Porcentajes calculados por FPU       │
│  └─ Resumen del análisis central        │
└──────────────────────────────────────────┘
```

---

## 🖥️ Interfaz de Usuario

### Menú Principal
```
╔══════════════════════════════════════╗
║          T E C H S C A N 6 4        ║
╚══════════════════════════════════════╝

  [1] Diagnosticar equipo
  [2] Monitorear en tiempo real
  [3] Analizar reportes del USB
  [4] Estadísticas globales
  [5] Salir

  Ingrese una opción:
```

### Pantalla de Diagnóstico Local
```
╔══════════════════════════════════════╗
║        DIAGNÓSTICO DEL EQUIPO       ║
╚══════════════════════════════════════╝

  PC          : LAB-PC-01
  Usuario     : admin
  SO          : Windows 10 Pro (22H2)
  Arquitectura: x86-64

  CPU         : Intel Core i5-10400
  Núcleos     : 6 lógicos
  RAM total   : 16.0 GB
  RAM libre   : 6.3 GB  (39.4%)
  Disco libre : 125.0 GB

  GPU         : NVIDIA GeForce GTX 1650
  Placa base  : ASUS PRIME B460M-A

  [G] Guardar reporte   [V] Volver
```

### Pantalla de Monitoreo en Tiempo Real
```
╔══════════════════════════════════════╗
║       MONITOREO EN TIEMPO REAL      ║
╚══════════════════════════════════════╝

  RAM libre   : ████████░░░░  6.1 GB / 16.0 GB
  Uso CPU     : ███░░░░░░░░░  24%
  Disco libre : ██████████░░  125 GB
  Procesos    : 187

  Última actualización: 14:32:05
  [Refresco cada 3 s]   [Q] Salir
```

### Pantalla de Análisis Central
```
╔══════════════════════════════════════╗
║         ANÁLISIS DE REPORTES        ║
╚══════════════════════════════════════╝

  Reportes encontrados : 20
  ─────────────────────────────────────
  Estado    Equipos   Porcentaje
  ─────────────────────────────────────
  Excelente     8        40.0%
  Bueno         6        30.0%
  Regular       4        20.0%
  Crítico       2        10.0%
  ─────────────────────────────────────
  RAM promedio  : 10.4 GB
  Disco promedio: 98.2 GB

  ⚠ Equipos críticos: LAB-PC-07, LAB-PC-13
  [D] Detalle   [E] Exportar CSV   [V] Volver
```

---

## 📐 Cálculos FPU

Todos los cálculos numéricos se realizan con la Unidad de Punto Flotante x87 en `stats_fpu.asm`:

| Cálculo | Fórmula | Instrucciones FPU |
|---|---|---|
| % RAM libre | `(ram_libre / ram_total) × 100` | `FILD, FDIVP, FMUL` |
| % Disco libre | `(disco_libre / disco_total) × 100` | `FILD, FDIVP, FMUL` |
| Promedio de RAM | `Σ ram_total[i] / N` | `FILD, FADD, FDIV` |
| Promedio de disco | `Σ disco_libre[i] / N` | `FILD, FADD, FDIV` |
| Ratio RAM/núcleos | `ram_total / num_nucleos` | `FILD, FDIVP` |

---

## 🔄 Flujos de Ejecución

```
Inicio
  │
  ├──► [1] Diagnóstico local
  │         │
  │         ├─ api_scan.asm  → captura hardware
  │         ├─ monitor.asm   → muestra resultados
  │         └─ report_io.c   → guarda .rep en USB
  │
  ├──► [2] Monitoreo en tiempo real
  │         │
  │         └─ monitor.asm   → bucle de refresco periódico
  │
  ├──► [3] Análisis de reportes
  │         │
  │         ├─ analyzer.c    → enumera .rep en USB
  │         ├─ report_io.c   → deserializa cada registro
  │         └─ stats_fpu.asm → calcula estadísticas
  │
  ├──► [4] Estadísticas globales
  │         │
  │         └─ stats_fpu.asm + analyzer.c → resumen completo
  │
  └──► [5] Salir
            │
            └─ Liberar handles y memoria → EXIT
```

---

## 👥 División del Trabajo

| Integrante | Módulo | Archivos | Tecnología |
|---|---|---|---|
| Integrante 1 | Interfaz, menú y control de flujo | `main.c` | C, Windows Console API |
| Integrante 2 | Captura de información del equipo | `api_scan.asm` | ASM x86-64, CPUID, WinAPI |
| Integrante 3 | Persistencia, archivos `.rep` y logs | `report_io.c` | C, CreateFile/WriteFile |
| Integrante 4 | Monitoreo local y cálculos FPU | `monitor.asm`, `stats_fpu.asm` | ASM x86-64, FPU x87 |
| Integrante 5 | Análisis central y estadísticas | `analyzer.c` | C, FindFirstFile/FindNextFile |

---

## ⚙️ Requisitos del Sistema

### PC objetivo (donde se ejecuta el diagnóstico)
- Sistema operativo: Windows 10 / 11 (x86-64)
- Arquitectura: 64 bits obligatorio
- Permisos: usuario estándar (no requiere administrador para la mayoría de funciones)
- Espacio en USB: ~5 MB para el ejecutable + reportes generados

### Entorno de desarrollo (para compilar)
- NASM ≥ 2.15 (ensamblador)
- GCC (MinGW-w64) o MSVC para las partes en C
- GNU Make o Makefile equivalente
- Windows SDK (para headers de WinAPI)

---

## 🔨 Compilación y Ensamblado

```bash
# Ensamblar módulos .asm
nasm -f win64 src/api_scan.asm  -o build/api_scan.obj
nasm -f win64 src/monitor.asm   -o build/monitor.obj
nasm -f win64 src/stats_fpu.asm -o build/stats_fpu.obj

# Compilar módulos .c
gcc -c src/main.c      -o build/main.obj      -I include/
gcc -c src/report_io.c -o build/report_io.obj -I include/
gcc -c src/analyzer.c  -o build/analyzer.obj  -I include/

# Enlazar todo
gcc build/*.obj -o build/TechScan64.exe -lkernel32 -luser32

# O simplemente:
make all
```

---

## 💾 Uso desde USB

1. Copiar `TechScan64.exe` a la raíz de la memoria USB.
2. En la PC objetivo, abrir CMD y ejecutar:

```cmd
E:\TechScan64.exe
```

3. Desde el menú, elegir **[1] Diagnosticar equipo**. El reporte `.rep` se guarda automáticamente en `E:\reports\`.
4. Repetir en cada PC del laboratorio.
5. Volver a la PC central y ejecutar:

```cmd
E:\TechScan64.exe
```

6. Elegir **[3] Analizar reportes del USB** para ver el análisis comparativo de todos los equipos.

---

## 📦 Entregables

- [x] Código fuente completo y modular en x86-64, comentado y organizado por módulos
- [ ] Diagrama de bloques / arquitectura del sistema
- [ ] Diagrama de flujo de los modos de operación
- [ ] Informe técnico en PDF y DOCX
- [ ] Demostración funcional ejecutando desde USB

---

## 🔬 Justificación Técnica de 64 bits

| Ventaja | Aplicación en TechScan64 |
|---|---|
| Más registros de propósito general | Reduce presión de pila en procedimientos modulares |
| Registros de 64 bits (RAX, RBX…) | Manejo directo de valores de RAM y disco en bytes (>4 GB) |
| Convención de llamadas por registros | Los módulos intercambian parámetros por RCX/RDX/R8/R9 sin depender de la pila |
| Mejor manejo de buffers grandes | Estructuras de 256 bytes y arreglos de registros eficientes |
| APIs modernas de Windows | Todas las funciones objetivo tienen variantes nativas de 64 bits |
| FPU y SSE nativos | Cálculos de punto flotante sin conversiones adicionales |

---

## 📚 Bibliografía

- Instructiva oficial del Proyecto Final — Taller de Programación en Bajo Nivel, UMSS 2026
- [Microsoft Docs — Windows API Reference](https://learn.microsoft.com/en-us/windows/win32/apiindex/windows-api-list)
- [NASM Documentation](https://www.nasm.us/doc/)
- [Intel 64 and IA-32 Architectures Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- Apuntes del curso sobre estructuras de datos, procesos y aplicaciones en ensamblador — UMSS 2026

---

<div align="center">

**Universidad Mayor de San Simón · Facultad de Ciencias y Tecnología · Carrera de Ingeniería Informática**  
Taller de Programación en Bajo Nivel · Junio 2026

</div>
