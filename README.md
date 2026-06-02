# 🔐 Suite de Criptografía de Alto Rendimiento y Análisis de Entropía

<p align="center">
  <img src="https://img.shields.io/badge/Architecture-x86--64%20(AMD64)-blue?style=for-the-badge&logo=cpu" alt="Architecture x86-64">
  <img src="https://img.shields.io/badge/Assembler-NASM%20v2.15+-orange?style=for-the-badge&logo=assemblyscript" alt="NASM">
  <img src="https://img.shields.io/badge/Compiler-GCC%20%2F%20MinGW%2064--bit-green?style=for-the-badge&logo=gnu" alt="GCC">
  <img src="https://img.shields.io/badge/Institution-UMSS%20--%20Informática-red?style=for-the-badge" alt="UMSS">
</p>

---

## 📝 1. Resumen Ejecutivo y Propósito Técnico

Este sistema representa una solución de software híbrida de grado de ingeniería que fusiona la abstracción lógica de **C** con la eficiencia matemática radical del **Lenguaje Ensamblador x86-64 nativo**. El propósito fundamental del proyecto es procesar el cifrado y descifrado simétrico de archivos de datos masivos a la velocidad teórica máxima del procesador, mitigando por completo el *overhead* (sobrecarga de ejecución) impuesto por los entornos de ejecución modernos.

De forma concurrente, el sistema evalúa la robustez del proceso mediante un análisis estadístico en tiempo real, calculando la **Entropía de Shannon** del archivo antes y después del procesamiento. Este cálculo crítico se ejecuta directamente sobre el hardware del co-procesador matemático mediante la unidad de punto flotante (**FPU**), garantizando precisión absoluta y manipulación directa de registros de punto flotante sin llamadas a librerías externas.

---

## 📊 2. Matriz Estricta de Cumplimiento Teórico-Práctico

Para garantizar la máxima puntuación en la evaluación académica, cada requerimiento de la guía docente ha sido mapeado unívocamente a un componente del software:

| 📋 Unidad / Requisito | 🛠️ Implementación Tecnológica en el Núcleo | 📂 Archivos Asociados |
| :--- | :--- | :--- |
| **Migración de Arquitectura** | Uso nativo y exclusivo de registros extendidos de 64 bits (`RAX`, `RBX`, `RCX`, `RDX`, `RSI`, `RDI`, `R8`-`R15`). Queda proscrita la ejecución en modo de compatibilidad de 32 bits. | `crypto.asm`, `fpu_analisis.asm` |
| **Convención de Llamadas** | Implementación estricta de la interfaz binaria de aplicación (ABI) *Microsoft FastCall* o *System V AMD64*. Paso de parámetros críticos (punteros a buffers y tamaños) mediante registros (`RCX`, `RDX`, `R8`, `R9`). | `main.c` ↔ `crypto.asm` |
| **Gestión de E/S y Ventanas** | Arquitectura orientada al control de flujo iterativo mediante una interfaz de consola extendida del sistema operativo (limpieza de buffers, control de errores de desbordamiento, menús anidados). | `main.c` |
| **Persistencia de Datos** | Subsistema de entrada/salida masiva mediante manipulación de descriptores de archivo en disco duro a nivel de bloques binarios indexados. | `archivos.c` |
| **Co-procesador Matemático / FPU** | Modelado probabilístico y logarítmico implementado sobre la pila de registros físicos de la FPU (`ST(0)` a `ST(7)`) mediante instrucciones de carga (`FLD`), operaciones aritméticas (`FMUL`, `FDIV`) y trascendentales (`FYL2X`). | `fpu_analisis.asm` |

---

## 🗂️ 3. Arquitectura del Software y Árbol de Directorios

El diseño del sistema sigue el principio de **desarrollo modular desacoplado**. Los módulos de alto nivel gestionan la orquestación y el estado, mientras que los archivos en bajo nivel actúan como aceleradores de hardware puros.

```text
📁 proyecto-ensamblador-umss/
│
├── 📄 main.c           # [Módulo 1] Punto de entrada. Orquestación del flujo y CLI extendida.
├── 📄 archivos.c       # [Módulo 2] Gestión de I/O en disco y asignación dinámica de memoria.
├── 📄 crypto.asm       # [Módulo 3] Algoritmos de cifrado simétrico optimizados a nivel de bit.
├── 📄 fpu_analisis.asm # [Módulo 4] Algoritmo matemático vectorizado/FPU para cálculo de entropía.
├── 📄 benchmark.c      # [Módulo 5] Captura de métricas de telemetría (ciclos de CPU y TSC).
└── 📄 compile.sh       # Script de automatización industrial para construcción del binario.
