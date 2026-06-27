#include "techscan_shared.h"

#include <stdio.h>
#include <string.h>
#include <windows.h>
#include <intrin.h>
#include <time.h>
#include <Lmcons.h>

/* Declaracion de la funcion FPU implementada en fpu_calc.asm (NASM x64).
   Usa registros x87 (FINIT, FILD, FMUL, FADDP, FSUBP, FSTP, FISTP)
   para calcular un Puntaje de Salud ponderado del equipo (0-100).
   Convencion FastCall: RCX=ram_libre%, RDX=disco_libre%, R8=cpu_usado% */
extern int calcular_puntaje_fpu(uint64_t ram_libre_pct,
                                 uint64_t disco_libre_pct,
                                 uint64_t cpu_pct_usado);
extern int calcular_porcentaje_fpu(uint64_t parte, uint64_t total);

/* Resultado double expuesto por fpu_calc.asm para inspeccion */
extern double puntaje_fpu_real;



void obtener_nombre_equipo(char *destino, int tam) {
    DWORD size = tam;
    if (!GetComputerNameA(destino, &size)) strcpy(destino, "DESCONOCIDO");
}

void obtener_memoria(uint64_t *total_mb, uint64_t *libre_mb) {
    MEMORYSTATUSEX status;
    status.dwLength = sizeof(status);
    GlobalMemoryStatusEx(&status);
    *total_mb = status.ullTotalPhys / (1024 * 1024);
    *libre_mb = status.ullAvailPhys / (1024 * 1024);
}

uint64_t obtener_disco_libre() {
    ULARGE_INTEGER libres;
    if (GetDiskFreeSpaceExA("C:\\", &libres, NULL, NULL))
        return libres.QuadPart / (1024 * 1024);
    return 0;
}

void obtener_modelo_cpu(char *destino, int tam) {
    int cpu_info[4] = {0};
    char marca[49];
    memset(marca, 0, sizeof(marca));
    __cpuid(cpu_info, 0x80000002); memcpy(marca,      cpu_info, 16);
    __cpuid(cpu_info, 0x80000003); memcpy(marca + 16, cpu_info, 16);
    __cpuid(cpu_info, 0x80000004); memcpy(marca + 32, cpu_info, 16);
    strncpy(destino, marca, tam - 1);
    destino[tam - 1] = '\0';
}

uint32_t clasificar(uint64_t ram_total, uint64_t ram_libre) {
    return techscan_clasificar_equipo(ram_total, ram_libre);
}

void obtener_usuario(char *destino, int tam);
void obtener_so(char *destino, int tam);
void obtener_sistema(char *arquitectura,
                     int tam,
                     DWORD *procesadores);
double obtener_porcentaje_disco(void);

void modulo2_diagnosticar() {
    double disco_pct;
    char usuario[64];
    char so[64];
    char arquitectura[16];
    char cpu_generacion[32];
    const char *cpu_clase;
    DWORD procesadores;
    EquipoInfo equipo;
    BloqueHardwareAvanzado hw;
    BloqueProcesos procesos;
    memset(&equipo, 0, sizeof(equipo));
    memset(&hw, 0, sizeof(hw));
    memset(&procesos, 0, sizeof(procesos));

    equipo.id_equipo = 1;
    obtener_nombre_equipo(equipo.nombre_equip, sizeof(equipo.nombre_equip));
    obtener_usuario(usuario,
                    sizeof(usuario));

    obtener_so(so,
            sizeof(so));

    obtener_sistema(
        arquitectura,
        sizeof(arquitectura),
        &procesadores
    );
    obtener_modelo_cpu(equipo.cpu_modelo, sizeof(equipo.cpu_modelo));
    obtener_memoria(&equipo.ram_total, &equipo.ram_libre);
    equipo.disco_libre = obtener_disco_libre();
    disco_pct =obtener_porcentaje_disco();
    techscan_obtener_bios_y_placa(&hw);
    techscan_obtener_gpu(hw.gpu_nombre, sizeof(hw.gpu_nombre));
    cpu_clase = techscan_clasificar_cpu(equipo.cpu_modelo,
                                        cpu_generacion,
                                        sizeof(cpu_generacion));
    techscan_copy_text(hw.cpu_generacion, sizeof(hw.cpu_generacion), cpu_generacion);
    techscan_copy_text(hw.cpu_clasificacion, sizeof(hw.cpu_clasificacion), cpu_clase);
    hw.nucleos_fisicos = techscan_contar_nucleos_fisicos();
    hw.nucleos_logicos = procesadores;

    techscan_copy_text(equipo.gpu_modelo, sizeof(equipo.gpu_modelo), hw.gpu_nombre);
    techscan_copy_text(equipo.placa_modelo, sizeof(equipo.placa_modelo), hw.placa_modelo);

    equipo.uso_ram_pct = 100.0 - (double)calcular_porcentaje_fpu(equipo.ram_libre, equipo.ram_total);
    equipo.uso_cpu_pct = techscan_obtener_uso_cpu_instantaneo();
    equipo.procesos = techscan_contar_procesos_top(&procesos, equipo.ram_total, equipo.ram_libre);
    equipo.categoria   = clasificar(equipo.ram_total, equipo.ram_libre);
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(equipo.timestamp, sizeof(equipo.timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    const char *cat[] = {"EXCELENTE", "BUENO", "REGULAR", "CRITICO"};
    printf("==========================================\n");
    printf("     DIAGNOSTICO DEL EQUIPO\n");
    printf("==========================================\n");
    printf("PC         : %s\n",   equipo.nombre_equip);
    printf("CPU        : %s\n",   equipo.cpu_modelo);
    printf("CPU Gen.   : %s\n",   hw.cpu_generacion);
    printf("Tec. CPU   : %s\n",   hw.cpu_clasificacion);
    printf("Nucleos    : %u fisicos / %lu logicos\n",
           hw.nucleos_fisicos, procesadores);
    printf("GPU        : %s\n",   hw.gpu_nombre);
    printf("Placa      : %s %s\n", hw.placa_fabricante, hw.placa_modelo);
    printf("BIOS       : %s | %s | %s\n",
           hw.bios_fabricante, hw.bios_version, hw.bios_fecha);
    printf("RAM total  : %llu MB\n", (unsigned long long)equipo.ram_total);
    printf("RAM libre  : %llu MB\n", (unsigned long long)equipo.ram_libre);
    printf("Uso RAM    : %.2f%%\n", equipo.uso_ram_pct);
    printf("Uso CPU    : %.2f%%\n", equipo.uso_cpu_pct);
    printf("Disco libre: %llu MB\n", (unsigned long long)equipo.disco_libre);
    printf("Disco %% libre : %.2f%%\n", disco_pct);
    printf("Procesos   : %u\n", equipo.procesos);
    printf("Presion Mem: %s\n", procesos.presion_memoria);
    printf("Categoria  : %s\n",   cat[equipo.categoria]);

    printf("Usuario   : %s\n", usuario);
    printf("SO        : %s\n", so);
    printf("Arquitect.: %s\n", arquitectura);
    printf("CPU Log.  : %lu\n", procesadores);
    printf("------------------------------------------\n");
    printf("Top procesos por memoria:\n");
    for (int i = 0; i < TECHSCAN_MAX_TOP_PROC; i++) {
        if (procesos.top[i].memoria_mb == 0) continue;
        printf("%-20s %llu MB\n",
               procesos.top[i].nombre,
               (unsigned long long)procesos.top[i].memoria_mb);
    }

    
    /* ---- Puntaje de Salud calculado por el coprocesador FPU x87 ---- */
    {
        /* Calcular porcentajes de recursos libres para la formula FPU:
           ram_libre_pct  = 100 - uso_ram_pct  (% de RAM disponible)
           disco_libre_pct = disco_pct          (ya es % libre)
           cpu_pct_usado   = 0 (no se mide CPU en diagnostico estatico) */
        uint64_t ram_libre_pct   = (equipo.ram_total > 0)
            ? (uint64_t)calcular_porcentaje_fpu(equipo.ram_libre, equipo.ram_total)
            : 0;
        uint64_t disco_libre_pct = (uint64_t)disco_pct;
        uint64_t cpu_pct_usado   = (uint64_t)equipo.uso_cpu_pct;

        /* Llamada al modulo FPU (fpu_calc.asm):
           RCX=ram_libre_pct, RDX=disco_libre_pct, R8=cpu_pct_usado
           Retorna en EAX el puntaje entero 0-100 calculado con x87 */
        int puntaje = calcular_puntaje_fpu(ram_libre_pct,
                                           disco_libre_pct,
                                           cpu_pct_usado);

        const char *nivel = (puntaje >= 80) ? "EXCELENTE" :
                            (puntaje >= 60) ? "BUENO"     :
                            (puntaje >= 40) ? "REGULAR"   : "CRITICO";

        printf("Puntaje FPU: %d/100 [%s]  (real: %.2f  --  formula x87)\n",
               puntaje, nivel, puntaje_fpu_real);
    }
    printf("==========================================\n");
    char nombre_archivo[128];
    snprintf(nombre_archivo, sizeof(nombre_archivo),
             "reportes\\%s_%ld.rep", equipo.nombre_equip, (long)t);
    if (guardar_reporte(nombre_archivo, &equipo)) {
        agregar_bloque_hardware(nombre_archivo, &hw);
        agregar_bloque_procesos(nombre_archivo, &procesos);
        printf("Reporte guardado: %s\n", nombre_archivo);
    } else {
        printf("ERROR: No se pudo guardar el reporte: %s\n", nombre_archivo);
    }
    printf("==========================================\n");
}
void obtener_usuario(char *destino, int tam) {
    DWORD size = tam;

    if (!GetUserNameA(destino, &size))
        strcpy(destino, "DESCONOCIDO");
}
void obtener_so(char *destino, int tam) {
    OSVERSIONINFOEXA os;
    ZeroMemory(&os, sizeof(os));

    os.dwOSVersionInfoSize = sizeof(os);

    if (GetVersionExA((OSVERSIONINFOA*)&os)) {
        snprintf(destino,
                 tam,
                 "Windows %lu.%lu",
                 os.dwMajorVersion,
                 os.dwMinorVersion);
    } else {
        strcpy(destino, "Windows");
    }
}
void obtener_sistema(char *arquitectura,int tam,DWORD *procesadores)
{
    SYSTEM_INFO si;
    (void)tam;

    GetSystemInfo(&si);

    *procesadores = si.dwNumberOfProcessors;

    if (si.wProcessorArchitecture ==
        PROCESSOR_ARCHITECTURE_AMD64)
    {
        strcpy(arquitectura, "x64");
    }
    else
    {
        strcpy(arquitectura, "x86");
    }
}
double obtener_porcentaje_disco()
{
    ULARGE_INTEGER libre;
    ULARGE_INTEGER total;

    if(GetDiskFreeSpaceExA(
        "C:\\",
        &libre,
        &total,
        NULL))
    {
        return (100.0 *
                libre.QuadPart)
                /
                total.QuadPart;
    }

    return 0.0;
}
