// TECHSCAN64 - Modulo 5: analisis central extendido.
// Lee reportes base y bloques opcionales HWX1/PRC1 para estadisticas reales.

#include "techscan_shared.h"

#include <windows.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>

extern int calcular_porcentaje_fpu(uint64_t parte, uint64_t total);
extern int calcular_promedio_fpu(uint64_t suma, uint64_t cantidad);

#define MAX_EQUIPOS 256
#define MAX_RUTAS   512
#define MAX_NOMBRE  28

typedef struct {
    EquipoInfo info;
    BloqueHardwareAvanzado hw;
    BloqueProcesos procesos;
    char ruta[MAX_RUTAS];
    FILETIME ft_write;
    int tiene_hw;
    int tiene_proc;
} ReporteLeido;

static void linea(void) {
    puts("==========================================");
}

static void sublinea(void) {
    puts("------------------------------------------");
}

static void normalizar(const char *src, char *dst, size_t dst_sz) {
    size_t i = 0;
    if (dst_sz == 0) return;
    if (src == NULL) src = "";
    for (; i + 1 < dst_sz && src[i]; ++i) {
        dst[i] = (char)tolower((unsigned char)src[i]);
    }
    dst[i] = '\0';
}

static void extraer_nombre_base(const char *texto, char *dst, size_t dst_sz) {
    size_t i = 0;
    if (dst_sz == 0) return;
    if (texto == NULL) texto = "";
    while (texto[i] && texto[i] != '_' && texto[i] != '.' && i + 1 < dst_sz) {
        dst[i] = texto[i];
        i++;
    }
    dst[i] = '\0';
}

static int comparar_ft_desc(const FILETIME *a, const FILETIME *b) {
    if (a->dwHighDateTime > b->dwHighDateTime) return 1;
    if (a->dwHighDateTime < b->dwHighDateTime) return -1;
    if (a->dwLowDateTime > b->dwLowDateTime) return 1;
    if (a->dwLowDateTime < b->dwLowDateTime) return -1;
    return 0;
}

static void imprimir_barra(double pct) {
    char barra[32];
    techscan_barra_ascii(pct, barra, sizeof(barra));
    printf("%s %5.1f%%", barra, pct);
}

static int obtener_fecha_archivo(const char *ruta, FILETIME *ft_write) {
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (!GetFileAttributesExA(ruta, GetFileExInfoStandard, &data)) return 0;
    *ft_write = data.ftLastWriteTime;
    return 1;
}

static int cargar_reportes(const char *carpeta, ReporteLeido *salida, int max_salidas) {
    char patron[MAX_RUTAS];
    WIN32_FIND_DATAA fd;
    HANDLE hfind;
    int total = 0;

    snprintf(patron, sizeof(patron), "%s\\*.rep", carpeta);
    hfind = FindFirstFileA(patron, &fd);
    if (hfind == INVALID_HANDLE_VALUE) return 0;

    do {
        char ruta[MAX_RUTAS];
        if (total >= max_salidas) break;
        snprintf(ruta, sizeof(ruta), "%s\\%s", carpeta, fd.cFileName);

        memset(&salida[total], 0, sizeof(salida[total]));
        if (!leer_reporte(ruta, &salida[total].info)) continue;

        techscan_copy_text(salida[total].ruta, sizeof(salida[total].ruta), ruta);
        salida[total].tiene_hw = leer_bloque_hardware(ruta, &salida[total].hw);
        salida[total].tiene_proc = leer_bloque_procesos(ruta, &salida[total].procesos);
        if (!obtener_fecha_archivo(ruta, &salida[total].ft_write)) {
            ZeroMemory(&salida[total].ft_write, sizeof(salida[total].ft_write));
        }
        total++;
    } while (FindNextFileA(hfind, &fd));

    FindClose(hfind);
    return total;
}

static int buscar_mas_reciente_por_nombre(const ReporteLeido *arr, int n, const char *nombre_norm) {
    int idx = -1;
    for (int i = 0; i < n; ++i) {
        char base[MAX_NOMBRE];
        char norm[MAX_NOMBRE];
        extraer_nombre_base(arr[i].info.nombre_equip, base, sizeof(base));
        normalizar(base, norm, sizeof(norm));
        if (strcmp(norm, nombre_norm) != 0) continue;
        if (idx == -1 || comparar_ft_desc(&arr[i].ft_write, &arr[idx].ft_write) > 0) idx = i;
    }
    return idx;
}

static int obtener_unicos_latest(const ReporteLeido *arr, int n,
                                 ReporteLeido *out, int max_out) {
    char nombres[MAX_EQUIPOS][MAX_NOMBRE];
    int cant = 0;
    int total = 0;

    for (int i = 0; i < n; ++i) {
        char base[MAX_NOMBRE];
        char norm[MAX_NOMBRE];
        int existe = 0;
        extraer_nombre_base(arr[i].info.nombre_equip, base, sizeof(base));
        normalizar(base, norm, sizeof(norm));
        for (int j = 0; j < cant; ++j) {
            if (strcmp(nombres[j], norm) == 0) {
                existe = 1;
                break;
            }
        }
        if (!existe && cant < MAX_EQUIPOS) {
            techscan_copy_text(nombres[cant], sizeof(nombres[cant]), norm);
            cant++;
        }
    }

    for (int i = 0; i < cant && total < max_out; ++i) {
        int idx = buscar_mas_reciente_por_nombre(arr, n, nombres[i]);
        if (idx >= 0) out[total++] = arr[idx];
    }
    return total;
}

static void ordenar_por_fecha_desc(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; ++i) {
        for (int j = i + 1; j < n; ++j) {
            if (comparar_ft_desc(&arr[j].ft_write, &arr[i].ft_write) > 0) {
                ReporteLeido tmp = arr[i];
                arr[i] = arr[j];
                arr[j] = tmp;
            }
        }
    }
}

static int score_criticidad(const ReporteLeido *r) {
    int score = (int)techscan_clasificar_equipo(r->info.ram_total, r->info.ram_libre) * 100;
    if (r->info.ram_total > 0) {
        int libre = calcular_porcentaje_fpu(r->info.ram_libre, r->info.ram_total);
        score += 100 - libre;
    }
    if (r->info.disco_libre < 10240) score += 25;
    if (r->info.procesos > 180) score += 25;
    if (r->tiene_hw && strcmp(r->hw.cpu_clasificacion, "ANTIGUO") == 0) score += 20;
    return score;
}

static void ordenar_por_criticidad(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; ++i) {
        for (int j = i + 1; j < n; ++j) {
            if (score_criticidad(&arr[j]) > score_criticidad(&arr[i])) {
                ReporteLeido tmp = arr[i];
                arr[i] = arr[j];
                arr[j] = tmp;
            }
        }
    }
}

static int es_moderno(const ReporteLeido *r) {
    return r->tiene_hw && strcmp(r->hw.cpu_clasificacion, "MODERNO") == 0;
}

static int es_antiguo(const ReporteLeido *r) {
    return r->tiene_hw && strcmp(r->hw.cpu_clasificacion, "ANTIGUO") == 0;
}

static void imprimir_distribucion(const int cont_cat[4], int total) {
    const char *nombres[4] = {"Excelente", "Bueno", "Regular", "Critico"};
    if (total <= 0) total = 1;

    puts("Distribucion por categorias:");
    for (int i = 0; i < 4; ++i) {
        double pct = (double)calcular_porcentaje_fpu((uint64_t)cont_cat[i], (uint64_t)total);
        printf("%-10s ", nombres[i]);
        imprimir_barra(pct);
        printf("  %d equipo(s)\n", cont_cat[i]);
    }
}

static void imprimir_top_procesos(const BloqueProcesos *p) {
    if (p == NULL || memcmp(p->tag, "PRC1", 4) != 0) {
        puts("Top procesos: no disponible en este reporte.");
        return;
    }
    puts("Top procesos por memoria:");
    for (int i = 0; i < TECHSCAN_MAX_TOP_PROC; ++i) {
        if (p->top[i].memoria_mb == 0) continue;
        printf("  %-20s %llu MB\n",
               p->top[i].nombre,
               (unsigned long long)p->top[i].memoria_mb);
    }
}

static void analizar_general(const char *carpeta) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido latest[MAX_EQUIPOS];
    ReporteLeido ranking[MAX_EQUIPOS];
    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    int total_latest;
    int cont_cat[4] = {0, 0, 0, 0};
    uint64_t suma_ram_libre = 0, suma_ram_total = 0, suma_disco = 0;
    uint64_t suma_cpu = 0, suma_procesos = 0;
    int idx_menos_ram = 0, idx_menos_disco = 0, idx_mas_proc = 0;
    int idx_antiguo = -1, idx_moderno = -1;

    linea();
    puts("ANALISIS GENERAL EXTENDIDO");
    linea();

    if (total <= 0) {
        puts("No hay reportes .rep para analizar todavia.");
        puts("Use la opcion 1 (Diagnosticar este equipo) primero.");
        linea();
        return;
    }

    total_latest = obtener_unicos_latest(reportes, total, latest, MAX_EQUIPOS);
    if (total_latest <= 0) {
        puts("No se pudieron consolidar equipos unicos.");
        linea();
        return;
    }

    for (int i = 0; i < total_latest; ++i) {
        EquipoInfo *e = &latest[i].info;
        e->categoria = techscan_clasificar_equipo(e->ram_total, e->ram_libre);
        if (e->categoria < 4) cont_cat[e->categoria]++;
        suma_ram_libre += e->ram_libre;
        suma_ram_total += e->ram_total;
        suma_disco += e->disco_libre;
        suma_cpu += (uint64_t)e->uso_cpu_pct;
        suma_procesos += e->procesos;

        if (e->ram_libre < latest[idx_menos_ram].info.ram_libre) idx_menos_ram = i;
        if (e->disco_libre < latest[idx_menos_disco].info.disco_libre) idx_menos_disco = i;
        if (e->procesos > latest[idx_mas_proc].info.procesos) idx_mas_proc = i;
        if (idx_antiguo == -1 || (es_antiguo(&latest[i]) && !es_antiguo(&latest[idx_antiguo]))) idx_antiguo = i;
        if (idx_moderno == -1 || (es_moderno(&latest[i]) && !es_moderno(&latest[idx_moderno]))) idx_moderno = i;
    }

    printf("Equipos unicos analizados : %d\n", total_latest);
    printf("Reportes totales leidos   : %d\n", total);
    sublinea();
    printf("Promedio RAM libre     : %d MB\n",
           calcular_promedio_fpu(suma_ram_libre, (uint64_t)total_latest));
    printf("Promedio RAM total     : %d MB\n",
           calcular_promedio_fpu(suma_ram_total, (uint64_t)total_latest));
    printf("Promedio disco libre   : %d MB\n",
           calcular_promedio_fpu(suma_disco, (uint64_t)total_latest));
    printf("Promedio uso CPU       : %d%%\n",
           calcular_promedio_fpu(suma_cpu, (uint64_t)total_latest));
    printf("Promedio procesos      : %d\n",
           calcular_promedio_fpu(suma_procesos, (uint64_t)total_latest));
    sublinea();
    printf("Menos RAM libre        : %s (%llu MB)\n",
           latest[idx_menos_ram].info.nombre_equip,
           (unsigned long long)latest[idx_menos_ram].info.ram_libre);
    printf("Menos disco libre      : %s (%llu MB)\n",
           latest[idx_menos_disco].info.nombre_equip,
           (unsigned long long)latest[idx_menos_disco].info.disco_libre);
    printf("Mas procesos activos   : %s (%u)\n",
           latest[idx_mas_proc].info.nombre_equip,
           latest[idx_mas_proc].info.procesos);
    printf("Equipo mas antiguo     : %s\n",
           (idx_antiguo >= 0 && latest[idx_antiguo].tiene_hw)
               ? latest[idx_antiguo].info.nombre_equip : "No determinado");
    printf("Equipo mas moderno     : %s\n",
           (idx_moderno >= 0 && latest[idx_moderno].tiene_hw)
               ? latest[idx_moderno].info.nombre_equip : "No determinado");
    sublinea();
    imprimir_distribucion(cont_cat, total_latest);

    memcpy(ranking, latest, sizeof(ReporteLeido) * (size_t)total_latest);
    ordenar_por_criticidad(ranking, total_latest);

    sublinea();
    puts("Ranking de criticidad:");
    for (int i = 0; i < total_latest && i < 10; ++i) {
        printf("%2d. %-24s score=%d  RAM=%llu MB  Disco=%llu MB  Proc=%u  %s\n",
               i + 1,
               ranking[i].info.nombre_equip,
               score_criticidad(&ranking[i]),
               (unsigned long long)ranking[i].info.ram_libre,
               (unsigned long long)ranking[i].info.disco_libre,
               ranking[i].info.procesos,
               techscan_nombre_categoria(ranking[i].info.categoria));
    }

    sublinea();
    puts("Lista priorizada de revision tecnica:");
    for (int i = 0; i < total_latest && i < 8; ++i) {
        const char *motivo = "Revision preventiva";
        if (ranking[i].info.categoria == 3) motivo = "RAM critica";
        else if (ranking[i].info.disco_libre < 10240) motivo = "Disco con poco espacio";
        else if (ranking[i].info.procesos > 180) motivo = "Muchos procesos activos";
        else if (es_antiguo(&ranking[i])) motivo = "Plataforma tecnologica antigua";
        printf(" - %-24s | %s\n", ranking[i].info.nombre_equip, motivo);
    }

    sublinea();
    puts("Comparacion de laboratorios:");
    puts(" - Laboratorio local: carpeta reportes\\");
    puts(" - Para comparar otro laboratorio, copie sus .rep a otra carpeta y ejecute el analizador con esa ruta.");
    linea();
}

static void mostrar_estado_global(const char *carpeta) {
    analizar_general(carpeta);
}

static void mostrar_historial_equipo(const char *carpeta, const char *nombre_equipo) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido filtrados[MAX_EQUIPOS];
    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    int total_filtrados = 0;
    char buscado[MAX_NOMBRE];

    normalizar(nombre_equipo, buscado, sizeof(buscado));

    for (int i = 0; i < total; ++i) {
        char base[MAX_NOMBRE];
        char norm[MAX_NOMBRE];
        extraer_nombre_base(reportes[i].info.nombre_equip, base, sizeof(base));
        normalizar(base, norm, sizeof(norm));
        if (strcmp(norm, buscado) == 0) filtrados[total_filtrados++] = reportes[i];
    }

    linea();
    printf("HISTORIAL DE %s\n", nombre_equipo);
    linea();

    if (total_filtrados == 0) {
        puts("No se encontraron reportes para ese equipo.");
        linea();
        return;
    }

    ordenar_por_fecha_desc(filtrados, total_filtrados);
    printf("Reportes encontrados: %d\n", total_filtrados);
    sublinea();
    for (int i = 0; i < total_filtrados; ++i) {
        EquipoInfo *e = &filtrados[i].info;
        double ram_libre_pct = 0.0;
        e->categoria = techscan_clasificar_equipo(e->ram_total, e->ram_libre);
        if (e->ram_total > 0) {
            ram_libre_pct = (double)calcular_porcentaje_fpu(e->ram_libre, e->ram_total);
        }
        printf("%2d) %s | RAM libre: %llu MB | Disco: %llu MB | Proc: %u | %s\n",
               i + 1, e->timestamp,
               (unsigned long long)e->ram_libre,
               (unsigned long long)e->disco_libre,
               e->procesos,
               techscan_nombre_categoria(e->categoria));
        printf("    RAM libre ");
        imprimir_barra(ram_libre_pct);
        putchar('\n');
        if (filtrados[i].tiene_hw) {
            printf("    GPU: %s | CPU: %s\n",
                   filtrados[i].hw.gpu_nombre,
                   filtrados[i].hw.cpu_clasificacion);
        }
    }
    sublinea();
    imprimir_top_procesos(filtrados[0].tiene_proc ? &filtrados[0].procesos : NULL);
    linea();
}

void modulo5_analizar(void) {
    analizar_general("reportes");
}

void modulo5_estadisticas(void) {
    mostrar_estado_global("reportes");
}

void modulo5_historial_equipo(const char *nombre_equipo) {
    if (nombre_equipo == NULL || nombre_equipo[0] == '\0') {
        puts("Nombre de equipo invalido.");
        return;
    }
    mostrar_historial_equipo("reportes", nombre_equipo);
}
