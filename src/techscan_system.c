#include "techscan_shared.h"

#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void techscan_copy_text(char *dst, size_t dst_sz, const char *src) {
    if (dst == NULL || dst_sz == 0) return;
    if (src == NULL) src = "";
    strncpy(dst, src, dst_sz - 1);
    dst[dst_sz - 1] = '\0';
}

const char *techscan_nombre_categoria(uint32_t cat) {
    switch (cat) {
        case 0: return "Excelente";
        case 1: return "Bueno";
        case 2: return "Regular";
        case 3: return "Critico";
        default: return "Desconocido";
    }
}

uint32_t techscan_clasificar_equipo(uint64_t ram_total, uint64_t ram_libre) {
    if (ram_total == 0) return 3;
    double pct_libre = ((double)ram_libre / (double)ram_total) * 100.0;
    if (pct_libre >= 50.0) return 0;
    if (pct_libre >= 30.0) return 1;
    if (pct_libre >= 15.0) return 2;
    return 3;
}

const char *techscan_clasificar_presion_memoria(uint64_t ram_total,
                                                uint64_t ram_libre,
                                                uint32_t procesos) {
    double libre_pct = 0.0;
    if (ram_total > 0) libre_pct = ((double)ram_libre / (double)ram_total) * 100.0;

    if (libre_pct < 10.0 || procesos >= 250) return "CRITICA";
    if (libre_pct < 20.0 || procesos >= 180) return "ALTA";
    if (libre_pct < 35.0 || procesos >= 120) return "MEDIA";
    return "BAJA";
}

static int contiene_icase(const char *texto, const char *patron) {
    size_t plen;
    if (texto == NULL || patron == NULL) return 0;
    plen = strlen(patron);
    if (plen == 0) return 1;
    for (const char *p = texto; *p; ++p) {
        size_t i = 0;
        while (i < plen && p[i] &&
               tolower((unsigned char)p[i]) == tolower((unsigned char)patron[i])) {
            i++;
        }
        if (i == plen) return 1;
    }
    return 0;
}

static int extraer_numero_despues_guion(const char *texto) {
    const char *p = strchr(texto, '-');
    int value = 0;
    int digits = 0;
    if (p == NULL) return 0;
    p++;
    while (*p && !isdigit((unsigned char)*p)) p++;
    while (*p && isdigit((unsigned char)*p) && digits < 5) {
        value = value * 10 + (*p - '0');
        digits++;
        p++;
    }
    return value;
}

const char *techscan_clasificar_cpu(const char *cpu_modelo,
                                    char *generacion,
                                    size_t generacion_sz) {
    int gen = 0;
    if (generacion != NULL && generacion_sz > 0) {
        techscan_copy_text(generacion, generacion_sz, "No determinada");
    }

    if (cpu_modelo == NULL || cpu_modelo[0] == '\0') return "VIGENTE";

    if (contiene_icase(cpu_modelo, "intel")) {
        int numero = extraer_numero_despues_guion(cpu_modelo);
        if (numero >= 10000) gen = numero / 1000;
        else if (numero >= 1000) gen = numero / 100;

        if (gen > 0 && generacion != NULL && generacion_sz > 0) {
            snprintf(generacion, generacion_sz, "Intel %da Gen", gen);
        }
        if (gen > 0 && gen <= 4) return "ANTIGUO";
        if (gen > 0 && gen <= 8) return "VIGENTE";
        if (gen >= 9) return "MODERNO";
        return "VIGENTE";
    }

    if (contiene_icase(cpu_modelo, "ryzen")) {
        const char *p = cpu_modelo;
        int serie = 0;
        while (*p && !isdigit((unsigned char)*p)) p++;
        while (*p && isdigit((unsigned char)*p)) p++;
        while (*p && !isdigit((unsigned char)*p)) p++;
        if (*p) serie = (*p - '0') * 1000;

        if (serie > 0 && generacion != NULL && generacion_sz > 0) {
            snprintf(generacion, generacion_sz, "Ryzen %d", serie);
        }
        if (serie >= 3000) return "MODERNO";
        if (serie >= 1000) return "VIGENTE";
        return "VIGENTE";
    }

    return "VIGENTE";
}

void techscan_barra_ascii(double pct, char *dst, size_t dst_sz) {
    int bloques;
    size_t pos = 0;
    if (dst == NULL || dst_sz == 0) return;
    if (pct < 0.0) pct = 0.0;
    if (pct > 100.0) pct = 100.0;
    bloques = (int)((pct / 100.0) * 20.0);

    if (pos + 1 < dst_sz) dst[pos++] = '[';
    for (int i = 0; i < 20 && pos + 1 < dst_sz; ++i) {
        dst[pos++] = (i < bloques) ? '#' : '-';
    }
    if (pos + 1 < dst_sz) dst[pos++] = ']';
    dst[pos] = '\0';
}

int techscan_crear_directorio_si_falta(const char *ruta) {
    DWORD attrs;
    if (ruta == NULL || ruta[0] == '\0') return 0;
    attrs = GetFileAttributesA(ruta);
    if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY)) return 1;
    if (CreateDirectoryA(ruta, NULL)) return 1;
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

static int leer_reg_string(HKEY root, const char *subkey, const char *value,
                           char *dst, size_t dst_sz) {
    DWORD type = 0;
    DWORD cb;
    LONG rc;
    if (dst == NULL || dst_sz == 0) return 0;
    dst[0] = '\0';
    cb = (DWORD)dst_sz;
    rc = RegGetValueA(root, subkey, value, RRF_RT_REG_SZ, &type, dst, &cb);
    if (rc != ERROR_SUCCESS) return 0;
    dst[dst_sz - 1] = '\0';
    return dst[0] != '\0';
}

static void limpiar_device_desc(char *texto) {
    char *p;
    if (texto == NULL) return;
    p = strrchr(texto, ';');
    if (p != NULL && p[1] != '\0') {
        memmove(texto, p + 1, strlen(p + 1) + 1);
    }
}

int techscan_obtener_gpu(char *destino, size_t tam) {
    HKEY h_pci = NULL;
    DWORD i = 0;
    char ven[128];
    DWORD ven_sz;

    if (destino == NULL || tam == 0) return 0;
    techscan_copy_text(destino, tam, "No detectada");

    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE,
                      "SYSTEM\\CurrentControlSet\\Enum\\PCI",
                      0, KEY_READ, &h_pci) != ERROR_SUCCESS) {
        return 0;
    }

    while (1) {
        HKEY h_ven = NULL;
        DWORD j = 0;
        ven_sz = sizeof(ven);
        if (RegEnumKeyExA(h_pci, i++, ven, &ven_sz, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) break;
        if (RegOpenKeyExA(h_pci, ven, 0, KEY_READ, &h_ven) != ERROR_SUCCESS) continue;

        while (1) {
            HKEY h_dev = NULL;
            char dev[128];
            DWORD dev_sz = sizeof(dev);
            if (RegEnumKeyExA(h_ven, j++, dev, &dev_sz, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) break;
            if (RegOpenKeyExA(h_ven, dev, 0, KEY_READ, &h_dev) != ERROR_SUCCESS) continue;

            char clase[64];
            if (leer_reg_string(h_dev, "", "Class", clase, sizeof(clase)) &&
                strcmp(clase, "Display") == 0) {
                char nombre[160];
                if (!leer_reg_string(h_dev, "", "FriendlyName", nombre, sizeof(nombre))) {
                    leer_reg_string(h_dev, "", "DeviceDesc", nombre, sizeof(nombre));
                }
                limpiar_device_desc(nombre);
                if (nombre[0] != '\0') {
                    techscan_copy_text(destino, tam, nombre);
                    RegCloseKey(h_dev);
                    RegCloseKey(h_ven);
                    RegCloseKey(h_pci);
                    return 1;
                }
            }
            RegCloseKey(h_dev);
        }
        RegCloseKey(h_ven);
    }

    RegCloseKey(h_pci);
    return 0;
}

void techscan_obtener_bios_y_placa(BloqueHardwareAvanzado *hw) {
    if (hw == NULL) return;
    memset(hw, 0, sizeof(*hw));
    memcpy(hw->tag, "HWX1", 4);
    techscan_copy_text(hw->gpu_nombre, sizeof(hw->gpu_nombre), "No detectada");
    techscan_copy_text(hw->placa_fabricante, sizeof(hw->placa_fabricante), "No detectado");
    techscan_copy_text(hw->placa_modelo, sizeof(hw->placa_modelo), "No detectado");
    techscan_copy_text(hw->placa_serial, sizeof(hw->placa_serial), "No disponible");
    techscan_copy_text(hw->bios_fabricante, sizeof(hw->bios_fabricante), "No detectado");
    techscan_copy_text(hw->bios_version, sizeof(hw->bios_version), "No detectado");
    techscan_copy_text(hw->bios_fecha, sizeof(hw->bios_fecha), "No detectado");

    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BaseBoardManufacturer", hw->placa_fabricante,
                          sizeof(hw->placa_fabricante));
    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BaseBoardProduct", hw->placa_modelo,
                          sizeof(hw->placa_modelo));
    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BaseBoardSerialNumber", hw->placa_serial,
                          sizeof(hw->placa_serial));
    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BIOSVendor", hw->bios_fabricante,
                          sizeof(hw->bios_fabricante));
    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BIOSVersion", hw->bios_version,
                          sizeof(hw->bios_version));
    (void)leer_reg_string(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                          "BIOSReleaseDate", hw->bios_fecha,
                          sizeof(hw->bios_fecha));
}

uint32_t techscan_contar_nucleos_fisicos(void) {
    DWORD len = 0;
    uint32_t cores = 0;
    PSYSTEM_LOGICAL_PROCESSOR_INFORMATION buffer;

    GetLogicalProcessorInformation(NULL, &len);
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || len == 0) return 0;

    buffer = (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION)malloc(len);
    if (buffer == NULL) return 0;

    if (GetLogicalProcessorInformation(buffer, &len)) {
        DWORD count = len / sizeof(SYSTEM_LOGICAL_PROCESSOR_INFORMATION);
        for (DWORD i = 0; i < count; ++i) {
            if (buffer[i].Relationship == RelationProcessorCore) cores++;
        }
    }

    free(buffer);
    return cores;
}

static void ordenar_top_procesos(ProcesoTop top[TECHSCAN_MAX_TOP_PROC]) {
    for (int i = 0; i < TECHSCAN_MAX_TOP_PROC - 1; ++i) {
        for (int j = i + 1; j < TECHSCAN_MAX_TOP_PROC; ++j) {
            if (top[j].memoria_mb > top[i].memoria_mb) {
                ProcesoTop tmp = top[i];
                top[i] = top[j];
                top[j] = tmp;
            }
        }
    }
}

static void considerar_proceso_top(BloqueProcesos *procesos,
                                   const char *nombre,
                                   uint64_t memoria_mb) {
    int idx_min = 0;
    for (int i = 1; i < TECHSCAN_MAX_TOP_PROC; ++i) {
        if (procesos->top[i].memoria_mb < procesos->top[idx_min].memoria_mb) idx_min = i;
    }
    if (memoria_mb > procesos->top[idx_min].memoria_mb) {
        techscan_copy_text(procesos->top[idx_min].nombre,
                           sizeof(procesos->top[idx_min].nombre),
                           nombre);
        procesos->top[idx_min].memoria_mb = memoria_mb;
    }
}

uint32_t techscan_contar_procesos_top(BloqueProcesos *procesos,
                                      uint64_t ram_total,
                                      uint64_t ram_libre) {
    HANDLE snap;
    PROCESSENTRY32 pe;
    uint32_t total = 0;

    if (procesos != NULL) {
        memset(procesos, 0, sizeof(*procesos));
        memcpy(procesos->tag, "PRC1", 4);
    }

    snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;

    pe.dwSize = sizeof(pe);
    if (Process32First(snap, &pe)) {
        do {
            HANDLE hp;
            PROCESS_MEMORY_COUNTERS pmc;
            uint64_t mb = 0;
            total++;
            hp = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe.th32ProcessID);
            if (hp != NULL) {
                if (GetProcessMemoryInfo(hp, &pmc, sizeof(pmc))) {
                    mb = (uint64_t)(pmc.WorkingSetSize / (1024 * 1024));
                }
                CloseHandle(hp);
            }
            if (procesos != NULL && mb > 0) {
                considerar_proceso_top(procesos, pe.szExeFile, mb);
            }
        } while (Process32Next(snap, &pe));
    }

    CloseHandle(snap);

    if (procesos != NULL) {
        procesos->total_procesos = total;
        techscan_copy_text(procesos->presion_memoria,
                           sizeof(procesos->presion_memoria),
                           techscan_clasificar_presion_memoria(ram_total, ram_libre, total));
        ordenar_top_procesos(procesos->top);
    }

    return total;
}

static uint64_t filetime_to_u64(const FILETIME *ft) {
    ULARGE_INTEGER u;
    u.LowPart = ft->dwLowDateTime;
    u.HighPart = ft->dwHighDateTime;
    return u.QuadPart;
}

double techscan_obtener_uso_cpu_instantaneo(void) {
    FILETIME idle1, kern1, user1;
    FILETIME idle2, kern2, user2;
    uint64_t idle_delta, kern_delta, user_delta, total;

    if (!GetSystemTimes(&idle1, &kern1, &user1)) return 0.0;
    Sleep(250);
    if (!GetSystemTimes(&idle2, &kern2, &user2)) return 0.0;

    idle_delta = filetime_to_u64(&idle2) - filetime_to_u64(&idle1);
    kern_delta = filetime_to_u64(&kern2) - filetime_to_u64(&kern1);
    user_delta = filetime_to_u64(&user2) - filetime_to_u64(&user1);
    total = kern_delta + user_delta;
    if (total == 0) return 0.0;
    if (idle_delta >= total) return 0.0;
    return 100.0 * (double)(total - idle_delta) / (double)total;
}
