#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <windows.h>
#include <intrin.h>
#include <time.h>
#include <Lmcons.h>

#pragma pack(push, 1)
typedef struct {
    uint32_t id_equipo;
    char nombre_equip[28];
    char cpu_modelo[32];
    uint64_t ram_total;
    uint64_t ram_libre;
    uint64_t disco_libre;
    char gpu_modelo[32];
    char placa_modelo[32];
    double uso_ram_pct;
    double uso_cpu_pct;
    uint32_t procesos;
    uint32_t categoria;
    char timestamp[24];
} EquipoInfo;
#pragma pack(pop)

extern void guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo);



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
    double pct = ((double)ram_libre / (double)ram_total) * 100.0;
    if (pct >= 50.0) return 0;
    if (pct >= 30.0) return 1;
    if (pct >= 15.0) return 2;
    return 3;
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
    DWORD procesadores;
    EquipoInfo equipo;
    memset(&equipo, 0, sizeof(equipo));
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
    strcpy(equipo.gpu_modelo,   "No detectada");
    strcpy(equipo.placa_modelo, "No detectada");
    equipo.uso_ram_pct = 100.0 * (1.0 - ((double)equipo.ram_libre / (double)equipo.ram_total));
    equipo.uso_cpu_pct = 0.0;
    equipo.procesos    = 0;
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
    printf("RAM total  : %llu MB\n", (unsigned long long)equipo.ram_total);
    printf("RAM libre  : %llu MB\n", (unsigned long long)equipo.ram_libre);
    printf("Uso RAM    : %.2f%%\n", equipo.uso_ram_pct);
    printf("Disco libre: %llu MB\n", (unsigned long long)equipo.disco_libre);
    printf("Disco %% libre : %.2f%%\n", disco_pct);
    printf("Categoria  : %s\n",   cat[equipo.categoria]);

    printf("Usuario   : %s\n", usuario);
    printf("SO        : %s\n", so);
    printf("Arquitect.: %s\n", arquitectura);
    printf("CPU Log.  : %lu\n", procesadores);

    
    printf("==========================================\n");
    char nombre_archivo[128];
    snprintf(nombre_archivo, sizeof(nombre_archivo),
             "reportes\\%s_%ld.rep", equipo.nombre_equip, (long)t);
    guardar_reporte(nombre_archivo, &equipo);
    printf("Reporte guardado: %s\n", nombre_archivo);
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