#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <windows.h>
#include <intrin.h>
#include <time.h>

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
    uint32_t procesos;      // reutilizado: nucleos logicos del CPU
    uint32_t categoria;
    char timestamp[24];
} EquipoInfo;
#pragma pack(pop)

extern void guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo);

// ── Nombre del equipo ──────────────────────────────────────────
static void obtener_nombre_equipo(char *dst, int tam) {
    DWORD sz = (DWORD)tam;
    if (!GetComputerNameA(dst, &sz))
        strncpy(dst, "DESCONOCIDO", tam - 1);
    dst[tam - 1] = '\0';
}

// ── Usuario activo ─────────────────────────────────────────────
static void obtener_usuario(char *dst, int tam) {
    DWORD sz = (DWORD)tam;
    if (!GetUserNameA(dst, &sz))
        strncpy(dst, "DESCONOCIDO", tam - 1);
    dst[tam - 1] = '\0';
}

// ── Sistema operativo ──────────────────────────────────────────
static void obtener_so(char *dst, int tam) {
    typedef LONG (WINAPI *RtlGetVersionPtr)(POSVERSIONINFOW);
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");
    RtlGetVersionPtr fn = ntdll
        ? (RtlGetVersionPtr)GetProcAddress(ntdll, "RtlGetVersion")
        : NULL;

    if (fn) {
        OSVERSIONINFOW vi;
        ZeroMemory(&vi, sizeof(vi));
        vi.dwOSVersionInfoSize = sizeof(vi);
        if (fn(&vi) == 0) {
            const char *nombre = "Windows";
            if (vi.dwMajorVersion == 10 && vi.dwMinorVersion == 0)
                nombre = vi.dwBuildNumber >= 22000 ? "Windows 11" : "Windows 10";
            else if (vi.dwMajorVersion == 6 && vi.dwMinorVersion == 3)
                nombre = "Windows 8.1";
            else if (vi.dwMajorVersion == 6 && vi.dwMinorVersion == 1)
                nombre = "Windows 7";
            snprintf(dst, tam, "%s (Build %lu)", nombre, vi.dwBuildNumber);
            return;
        }
    }
    strncpy(dst, "Windows (desconocido)", tam - 1);
    dst[tam - 1] = '\0';
}

// ── Arquitectura ───────────────────────────────────────────────
static void obtener_arquitectura(char *dst, int tam) {
    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    switch (si.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_AMD64:
            strncpy(dst, "x86_64 (64-bit)", tam - 1); break;
        case PROCESSOR_ARCHITECTURE_INTEL:
            strncpy(dst, "x86 (32-bit)",    tam - 1); break;
        case PROCESSOR_ARCHITECTURE_ARM64:
            strncpy(dst, "ARM64",           tam - 1); break;
        default:
            strncpy(dst, "Desconocida",     tam - 1); break;
    }
    dst[tam - 1] = '\0';
}

// ── Modelo de CPU (CPUID hojas extendidas) ─────────────────────
static void obtener_modelo_cpu(char *dst, int tam) {
    int info[4] = {0};
    char marca[49];
    memset(marca, 0, sizeof(marca));
    __cpuid(info, 0x80000002); memcpy(marca,      info, 16);
    __cpuid(info, 0x80000003); memcpy(marca + 16, info, 16);
    __cpuid(info, 0x80000004); memcpy(marca + 32, info, 16);
    const char *p = marca;
    while (*p == ' ') p++;          // quitar espacios iniciales
    strncpy(dst, p, tam - 1);
    dst[tam - 1] = '\0';
}

// ── Nucleos logicos (CPUID hoja 1, EBX[23:16]) ────────────────
static int obtener_nucleos(void) {
    int info[4] = {0};
    __cpuid(info, 1);
    int n = (info[1] >> 16) & 0xFF;
    return n > 0 ? n : 1;
}

// ── RAM total y libre ──────────────────────────────────────────
static void obtener_memoria(uint64_t *total_mb, uint64_t *libre_mb) {
    MEMORYSTATUSEX st;
    st.dwLength = sizeof(st);
    GlobalMemoryStatusEx(&st);
    *total_mb = st.ullTotalPhys  / (1024ULL * 1024ULL);
    *libre_mb = st.ullAvailPhys  / (1024ULL * 1024ULL);
}

// ── Espacio libre en disco C: ──────────────────────────────────
static uint64_t obtener_disco_libre(void) {
    ULARGE_INTEGER libres;
    if (GetDiskFreeSpaceExA("C:\\", &libres, NULL, NULL))
        return libres.QuadPart / (1024ULL * 1024ULL);
    return 0;
}

// ── GPU via registro (adaptador de pantalla primario) ──────────
static void obtener_gpu_registro(char *dst, int tam) {
    HKEY hKey;
    // Intentar primero 0000, luego 0001
    const char *rutas[] = {
        "SYSTEM\\CurrentControlSet\\Control\\Class\\"
        "{4d36e968-e325-11ce-bfc1-08002be10318}\\0000",
        "SYSTEM\\CurrentControlSet\\Control\\Class\\"
        "{4d36e968-e325-11ce-bfc1-08002be10318}\\0001"
    };
    for (int i = 0; i < 2; i++) {
        if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, rutas[i], 0,
                          KEY_READ, &hKey) == ERROR_SUCCESS) {
            DWORD tipo = REG_SZ, sz = (DWORD)tam;
            LSTATUS r = RegQueryValueExA(hKey, "DriverDesc", NULL,
                                         &tipo, (LPBYTE)dst, &sz);
            RegCloseKey(hKey);
            if (r == ERROR_SUCCESS) return;
        }
    }
    strncpy(dst, "No detectada", tam - 1);
    dst[tam - 1] = '\0';
}

// ── Placa base via registro (BIOS SMBIOS) ──────────────────────
static void obtener_placa_registro(char *dst, int tam) {
    HKEY hKey;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE,
                      "HARDWARE\\DESCRIPTION\\System\\BIOS",
                      0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD tipo = REG_SZ, sz = (DWORD)tam;
        LSTATUS r = RegQueryValueExA(hKey, "BaseBoardProduct", NULL,
                                     &tipo, (LPBYTE)dst, &sz);
        RegCloseKey(hKey);
        if (r == ERROR_SUCCESS) return;
    }
    strncpy(dst, "No detectada", tam - 1);
    dst[tam - 1] = '\0';
}

// ── Clasificacion ──────────────────────────────────────────────
static uint32_t clasificar(uint64_t ram_total, uint64_t ram_libre) {
    if (ram_total == 0) return 3;
    double pct = ((double)ram_libre / (double)ram_total) * 100.0;
    if (pct >= 50.0) return 0;
    if (pct >= 30.0) return 1;
    if (pct >= 15.0) return 2;
    return 3;
}

// ── Funcion principal del modulo ───────────────────────────────
void modulo2_diagnosticar(void) {
    EquipoInfo equipo;
    memset(&equipo, 0, sizeof(equipo));

    // Datos extra solo para display (no caben en struct)
    char usuario[64] = {0};
    char so[64]      = {0};
    char arq[32]     = {0};

    equipo.id_equipo = 1;
    obtener_nombre_equipo(equipo.nombre_equip, sizeof(equipo.nombre_equip));
    obtener_usuario(usuario, sizeof(usuario));
    obtener_so(so, sizeof(so));
    obtener_arquitectura(arq, sizeof(arq));
    obtener_modelo_cpu(equipo.cpu_modelo, sizeof(equipo.cpu_modelo));
    equipo.procesos     = (uint32_t)obtener_nucleos();
    obtener_memoria(&equipo.ram_total, &equipo.ram_libre);
    equipo.disco_libre  = obtener_disco_libre();
    obtener_gpu_registro(equipo.gpu_modelo,    sizeof(equipo.gpu_modelo));
    obtener_placa_registro(equipo.placa_modelo, sizeof(equipo.placa_modelo));
    equipo.uso_ram_pct  = 100.0 * (1.0 - ((double)equipo.ram_libre /
                                            (double)equipo.ram_total));
    equipo.uso_cpu_pct  = 0.0;
    equipo.categoria    = clasificar(equipo.ram_total, equipo.ram_libre);

    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(equipo.timestamp, sizeof(equipo.timestamp),
             "%Y-%m-%d %H:%M:%S", tm_info);

    const char *cat[] = {"EXCELENTE", "BUENO", "REGULAR", "CRITICO"};

    printf("==========================================\n");
    printf("       DIAGNOSTICO DEL EQUIPO\n");
    printf("==========================================\n");
    printf("PC           : %s\n",  equipo.nombre_equip);
    printf("Usuario      : %s\n",  usuario);
    printf("SO           : %s\n",  so);
    printf("Arquitectura : %s\n",  arq);
    printf("------------------------------------------\n");
    printf("CPU          : %s\n",  equipo.cpu_modelo);
    printf("Nucleos log. : %u\n",  equipo.procesos);
    printf("RAM total    : %llu MB\n", (unsigned long long)equipo.ram_total);
    printf("RAM libre    : %llu MB\n", (unsigned long long)equipo.ram_libre);
    printf("Disco libre  : %llu MB\n", (unsigned long long)equipo.disco_libre);
    printf("GPU          : %s\n",  equipo.gpu_modelo);
    printf("Placa base   : %s\n",  equipo.placa_modelo);
    printf("------------------------------------------\n");
    printf("Categoria    : %s\n",  cat[equipo.categoria]);
    printf("Timestamp    : %s\n",  equipo.timestamp);
    printf("==========================================\n");

    char nombre_archivo[128];
    snprintf(nombre_archivo, sizeof(nombre_archivo),
             "reportes\\%s_%ld.rep", equipo.nombre_equip, (long)t);
    guardar_reporte(nombre_archivo, &equipo);
    printf("Reporte guardado: %s\n", nombre_archivo);
    printf("==========================================\n");
}
