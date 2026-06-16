// ==========================================
// TECHSCAN64 - Modulo 5: Analisis Central
// Lee reportes .rep de la carpeta "reportes"
// y genera estadisticas del laboratorio
// ==========================================

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <windows.h>

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
    uint32_t categoria;   // 0=Excelente 1=Bueno 2=Regular 3=Critico
    char timestamp[24];
} EquipoInfo;

typedef struct {
    char firma[4];
    uint32_t version;
    char fecha_creacion[12];
    uint32_t cant_registros;
} ReporteHeader;

#pragma pack(pop)

#define MAX_EQUIPOS 100

// ==========================================
// Clasifica un equipo segun su RAM libre
// Devuelve: 0=Excelente 1=Bueno 2=Regular 3=Critico
// ==========================================
int clasificar_equipo(uint64_t ram_total, uint64_t ram_libre) {
    double pct_libre = ((double)ram_libre / (double)ram_total) * 100.0;

    if (pct_libre >= 50.0) return 0;   // Excelente
    if (pct_libre >= 30.0) return 1;   // Bueno
    if (pct_libre >= 15.0) return 2;   // Regular
    return 3;                          // Critico
}

const char* nombre_categoria(int cat) {
    switch (cat) {
        case 0: return "Excelente";
        case 1: return "Bueno";
        case 2: return "Regular";
        case 3: return "Critico";
        default: return "Desconocido";
    }
}

// ==========================================
// Analiza todos los .rep de una carpeta
// ==========================================
void analizar_reportes(const char *carpeta) {
    EquipoInfo equipos[MAX_EQUIPOS];
    int total = 0;

    char patron[256];
    snprintf(patron, sizeof(patron), "%s\\*.rep", carpeta);

    WIN32_FIND_DATAA datos_archivo;
    HANDLE hFind = FindFirstFileA(patron, &datos_archivo);

    if (hFind == INVALID_HANDLE_VALUE) {
        printf("No se encontraron reportes .rep en la carpeta '%s'\n", carpeta);
        return;
    }

    do {
        char ruta_completa[512];
        snprintf(ruta_completa, sizeof(ruta_completa), "%s\\%s", carpeta, datos_archivo.cFileName);

        FILE *f = fopen(ruta_completa, "rb");
        if (f == NULL) continue;

        ReporteHeader header;
        if (fread(&header, sizeof(ReporteHeader), 1, f) != 1) {
            fclose(f);
            continue;
        }

        if (memcmp(header.firma, "SCAN", 4) != 0) {
            fclose(f);
            continue;
        }

        if (total < MAX_EQUIPOS) {
            if (fread(&equipos[total], sizeof(EquipoInfo), 1, f) == 1) {
                total++;
            }
        }

        fclose(f);
    } while (FindNextFileA(hFind, &datos_archivo) && total < MAX_EQUIPOS);

    FindClose(hFind);

    if (total == 0) {
        printf("==========================================\n");
        printf("   ANALISIS DE REPORTES\n");
        printf("==========================================\n");
        printf("No hay reportes .rep para analizar todavia.\n");
        printf("Use la opcion 1 (Diagnosticar equipo) primero.\n");
        printf("==========================================\n");
        return;
    }

    // Contadores por categoria
    int cont_cat[4] = {0, 0, 0, 0};
    double suma_ram_libre = 0.0;
    double suma_disco_libre = 0.0;
    uint64_t ram_min = equipos[0].ram_libre;
    int idx_critico = 0;

    for (int i = 0; i < total; i++) {
        int cat = clasificar_equipo(equipos[i].ram_total, equipos[i].ram_libre);
        equipos[i].categoria = cat;
        cont_cat[cat]++;

        suma_ram_libre += (double)equipos[i].ram_libre;
        suma_disco_libre += (double)equipos[i].disco_libre;

        if (equipos[i].ram_libre < ram_min) {
            ram_min = equipos[i].ram_libre;
            idx_critico = i;
        }
    }

    double prom_ram = suma_ram_libre / total;
    double prom_disco = suma_disco_libre / total;

    printf("==========================================\n");
    printf("   ANALISIS DE REPORTES - LABORATORIO\n");
    printf("==========================================\n");
    printf("Equipos analizados : %d\n", total);
    printf("Excelente : %d\n", cont_cat[0]);
    printf("Bueno     : %d\n", cont_cat[1]);
    printf("Regular   : %d\n", cont_cat[2]);
    printf("Critico   : %d\n", cont_cat[3]);
    printf("------------------------------------------\n");
    printf("Promedio RAM libre  : %.1f MB\n", prom_ram);
    printf("Promedio Disco libre: %.1f MB\n", prom_disco);
    printf("Equipo mas critico  : %s (%llu MB RAM libre)\n",
           equipos[idx_critico].nombre_equip,
           (unsigned long long)equipos[idx_critico].ram_libre);
    printf("==========================================\n");
}

// ==========================================
// Funcion llamada desde el menu (Modulo 1)
// ==========================================
void modulo5_analizar() {
    analizar_reportes("reportes");
}

void modulo5_estadisticas() {
    printf("==========================================\n");
    printf("   ESTADISTICAS GLOBALES DEL LABORATORIO\n");
    printf("==========================================\n");
    analizar_reportes("reportes");
}