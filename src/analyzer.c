// ==========================================
// TECHSCAN64 - Modulo 5: Analisis Central
// Analisis general, historial por equipo,
// categorias, promedios, top/bottom y graficas ASCII
// ==========================================

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <windows.h>
#include <ctype.h>

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

#define MAX_EQUIPOS 256
#define MAX_RUTAS   512
#define MAX_NOMBRE  28

typedef struct {
    EquipoInfo info;
    char ruta[MAX_RUTAS];
    FILETIME ft_write;
    int valido;
} ReporteLeido;

// =========================================================
// Utilidades
// =========================================================

static int es_firma_valida(const ReporteHeader *h) {
    return memcmp(h->firma, "SCAN", 4) == 0;
}

static const char *nombre_categoria(uint32_t cat) {
    switch (cat) {
        case 0: return "Excelente";
        case 1: return "Bueno";
        case 2: return "Regular";
        case 3: return "Critico";
        default: return "Desconocido";
    }
}

static uint32_t clasificar_equipo(uint64_t ram_total, uint64_t ram_libre) {
    if (ram_total == 0) return 3;

    double pct_libre = ((double)ram_libre / (double)ram_total) * 100.0;

    if (pct_libre >= 50.0) return 0;
    if (pct_libre >= 30.0) return 1;
    if (pct_libre >= 15.0) return 2;
    return 3;
}

static void imprimir_barra_pct(double pct) {
    int bloques = (int)((pct / 100.0) * 20.0);
    if (bloques < 0) bloques = 0;
    if (bloques > 20) bloques = 20;

    putchar('[');
    for (int i = 0; i < 20; i++) {
        putchar(i < bloques ? '#' : '-');
    }
    putchar(']');
}

static void imprimir_linea_separacion(void) {
    puts("==========================================");
}

static int comparar_ft_desc(const FILETIME *a, const FILETIME *b) {
    // retorna >0 si a es mas reciente que b
    if (a->dwHighDateTime > b->dwHighDateTime) return 1;
    if (a->dwHighDateTime < b->dwHighDateTime) return -1;
    if (a->dwLowDateTime > b->dwLowDateTime) return 1;
    if (a->dwLowDateTime < b->dwLowDateTime) return -1;
    return 0;
}

static void copiar_nombre_normalizado(char *dst, size_t dst_sz, const char *src) {
    size_t i = 0;
    for (; i + 1 < dst_sz && src[i] != '\0'; ++i) {
        dst[i] = (char)tolower((unsigned char)src[i]);
    }
    dst[i] = '\0';
}

static void extraer_nombre_base(const char *texto, char *dst, size_t dst_sz) {
    // Si el nombre viene como "DESKTOP-01_123.rep", devuelve "DESKTOP-01"
    const char *p = texto;
    char temp[MAX_NOMBRE];
    size_t i = 0;

    while (*p && *p != '_' && *p != '.' && i + 1 < sizeof(temp)) {
        temp[i++] = *p++;
    }
    temp[i] = '\0';

    strncpy(dst, temp, dst_sz - 1);
    dst[dst_sz - 1] = '\0';
}

static void imprimir_resumen_equipo(const EquipoInfo *e) {
    imprimir_linea_separacion();
    printf("EQUIPO : %s\n", e->nombre_equip);
    printf("CPU    : %s\n", e->cpu_modelo);
    printf("RAM    : %llu MB\n", (unsigned long long)e->ram_total);
    printf("RAM LI : %llu MB\n", (unsigned long long)e->ram_libre);
    printf("DISCO  : %llu MB\n", (unsigned long long)e->disco_libre);
    printf("CAT    : %s\n", nombre_categoria(e->categoria));
    printf("TIME   : %s\n", e->timestamp);
}

static int leer_reporte_binario(const char *ruta, EquipoInfo *equipo) {
    FILE *f = fopen(ruta, "rb");
    if (!f) return 0;

    ReporteHeader h;
    if (fread(&h, sizeof(h), 1, f) != 1) {
        fclose(f);
        return 0;
    }

    if (!es_firma_valida(&h)) {
        fclose(f);
        return 0;
    }

    if (fread(equipo, sizeof(*equipo), 1, f) != 1) {
        fclose(f);
        return 0;
    }

    fclose(f);
    return 1;
}

static int obtener_fecha_archivo(const char *ruta, FILETIME *ft_write) {
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (!GetFileAttributesExA(ruta, GetFileExInfoStandard, &data)) return 0;
    *ft_write = data.ftLastWriteTime;
    return 1;
}

static int cargar_reportes(const char *carpeta, ReporteLeido *salida, int max_salidas) {
    char patron[MAX_RUTAS];
    snprintf(patron, sizeof(patron), "%s\\*.rep", carpeta);

    WIN32_FIND_DATAA fd;
    HANDLE hFind = FindFirstFileA(patron, &fd);
    if (hFind == INVALID_HANDLE_VALUE) {
        return 0;
    }

    int total = 0;
    do {
        if (total >= max_salidas) break;

        char ruta[MAX_RUTAS];
        snprintf(ruta, sizeof(ruta), "%s\\%s", carpeta, fd.cFileName);

        EquipoInfo e;
        if (!leer_reporte_binario(ruta, &e)) {
            continue;
        }

        salida[total].info = e;
        strncpy(salida[total].ruta, ruta, sizeof(salida[total].ruta) - 1);
        salida[total].ruta[sizeof(salida[total].ruta) - 1] = '\0';
        salida[total].valido = 1;

        if (!obtener_fecha_archivo(ruta, &salida[total].ft_write)) {
            ZeroMemory(&salida[total].ft_write, sizeof(FILETIME));
        }

        total++;
    } while (FindNextFileA(hFind, &fd));

    FindClose(hFind);
    return total;
}

static int buscar_indice_mas_reciente_por_nombre(const ReporteLeido *arr, int n, const char *nombre_base) {
    char buscado[MAX_NOMBRE];
    char actual[MAX_NOMBRE];

    copiar_nombre_normalizado(buscado, sizeof(buscado), nombre_base);

    int idx = -1;
    for (int i = 0; i < n; i++) {
        extraer_nombre_base(arr[i].info.nombre_equip, actual, sizeof(actual));
        char actual_norm[MAX_NOMBRE];
        copiar_nombre_normalizado(actual_norm, sizeof(actual_norm), actual);

        if (strcmp(actual_norm, buscado) != 0) continue;

        if (idx == -1 || comparar_ft_desc(&arr[i].ft_write, &arr[idx].ft_write) > 0) {
            idx = i;
        }
    }
    return idx;
}

static int obtener_unicos_latest(const ReporteLeido *arr, int n, ReporteLeido *out_latest, int max_out) {
    char nombres[MAX_EQUIPOS][MAX_NOMBRE];
    int cant_nombres = 0;

    for (int i = 0; i < n; i++) {
        char base[MAX_NOMBRE];
        extraer_nombre_base(arr[i].info.nombre_equip, base, sizeof(base));
        char norm[MAX_NOMBRE];
        copiar_nombre_normalizado(norm, sizeof(norm), base);

        int existe = 0;
        for (int j = 0; j < cant_nombres; j++) {
            if (strcmp(nombres[j], norm) == 0) {
                existe = 1;
                break;
            }
        }
        if (!existe && cant_nombres < MAX_EQUIPOS) {
            strncpy(nombres[cant_nombres], norm, sizeof(nombres[cant_nombres]) - 1);
            nombres[cant_nombres][sizeof(nombres[cant_nombres]) - 1] = '\0';
            cant_nombres++;
        }
    }

    int total_latest = 0;
    for (int i = 0; i < cant_nombres && total_latest < max_out; i++) {
        int idx = buscar_indice_mas_reciente_por_nombre(arr, n, nombres[i]);
        if (idx >= 0) {
            out_latest[total_latest++] = arr[idx];
        }
    }

    return total_latest;
}

static void ordenar_por_timestamp_desc(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = i + 1; j < n; j++) {
            if (comparar_ft_desc(&arr[j].ft_write, &arr[i].ft_write) > 0) {
                ReporteLeido tmp = arr[i];
                arr[i] = arr[j];
                arr[j] = tmp;
            }
        }
    }
}

static void imprimir_grafica_categorias(const int cont_cat[4]) {
    int total = cont_cat[0] + cont_cat[1] + cont_cat[2] + cont_cat[3];
    if (total <= 0) total = 1;

    const char *nombres[4] = {"Excelente", "Bueno", "Regular", "Critico"};

    puts("Distribucion por categoria:");
    for (int i = 0; i < 4; i++) {
        int barras = (cont_cat[i] * 20) / total;
        printf("%-10s [", nombres[i]);
        for (int b = 0; b < 20; b++) {
            putchar(b < barras ? '#' : '-');
        }
        printf("] %d\n", cont_cat[i]);
    }
}

static void imprimir_grafica_porcentaje(const char *titulo, double pct) {
    if (pct < 0.0) pct = 0.0;
    if (pct > 100.0) pct = 100.0;

    printf("%s\n", titulo);
    printf("[");
    for (int i = 0; i < 20; i++) {
        double limite = (double)(i + 1) * 5.0;
        putchar(pct >= limite ? '#' : '-');
    }
    printf("] %.1f%%\n", pct);
}

// =========================================================
// ANALISIS GENERAL
// Usa el reporte mas reciente de cada equipo
// =========================================================
static void analizar_general(const char *carpeta) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido latest[MAX_EQUIPOS];

    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    if (total <= 0) {
        imprimir_linea_separacion();
        puts("ANALISIS GENERAL");
        imprimir_linea_separacion();
        puts("No hay reportes .rep para analizar todavia.");
        puts("Use la opcion 1 (Diagnosticar este equipo) primero.");
        imprimir_linea_separacion();
        return;
    }

    int total_latest = obtener_unicos_latest(reportes, total, latest, MAX_EQUIPOS);
    if (total_latest <= 0) {
        imprimir_linea_separacion();
        puts("ANALISIS GENERAL");
        imprimir_linea_separacion();
        puts("No se pudieron consolidar equipos unicos.");
        imprimir_linea_separacion();
        return;
    }

    int cont_cat[4] = {0, 0, 0, 0};
    double suma_ram = 0.0;
    double suma_disco = 0.0;

    int idx_critico = 0;
    int idx_mejor = 0;
    uint64_t menor_ram_libre = latest[0].info.ram_libre;
    uint64_t mayor_ram_libre = latest[0].info.ram_libre;

    for (int i = 0; i < total_latest; i++) {
        EquipoInfo *e = &latest[i].info;

        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);
        cont_cat[e->categoria]++;

        suma_ram += (double)e->ram_libre;
        suma_disco += (double)e->disco_libre;

        if (e->ram_libre < menor_ram_libre) {
            menor_ram_libre = e->ram_libre;
            idx_critico = i;
        }
        if (e->ram_libre > mayor_ram_libre) {
            mayor_ram_libre = e->ram_libre;
            idx_mejor = i;
        }
    }

    double prom_ram = suma_ram / (double)total_latest;
    double prom_disco = suma_disco / (double)total_latest;

    ordenar_por_timestamp_desc(latest, total_latest);

    imprimir_linea_separacion();
    puts("ANALISIS GENERAL");
    imprimir_linea_separacion();
    printf("Equipos unicos analizados : %d\n", total_latest);
    printf("Excelente : %d\n", cont_cat[0]);
    printf("Bueno     : %d\n", cont_cat[1]);
    printf("Regular   : %d\n", cont_cat[2]);
    printf("Critico   : %d\n", cont_cat[3]);
    puts("------------------------------------------");
    printf("Promedio RAM libre  : %.1f MB\n", prom_ram);
    printf("Promedio Disco libre: %.1f MB\n", prom_disco);
    printf("Equipo mas critico  : %s (%llu MB RAM libre)\n",
           latest[idx_critico].info.nombre_equip,
           (unsigned long long)latest[idx_critico].info.ram_libre);
    printf("Equipo con mas RAM  : %s (%llu MB RAM libre)\n",
           latest[idx_mejor].info.nombre_equip,
           (unsigned long long)latest[idx_mejor].info.ram_libre);
    puts("------------------------------------------");

    imprimir_grafica_categorias(cont_cat);
    puts("------------------------------------------");
    imprimir_grafica_porcentaje("RAM promedio libre:", (prom_ram > 0.0 ? (prom_ram / 1024.0) * 100.0 : 0.0));
    imprimir_grafica_porcentaje("Disco promedio libre:", (prom_disco > 0.0 ? (prom_disco / 1024.0) * 100.0 : 0.0));
    imprimir_linea_separacion();

    puts("Ultimos equipos detectados:");
    for (int i = 0; i < total_latest && i < 10; i++) {
        printf(" - %s | %s | %s\n",
               latest[i].info.nombre_equip,
               latest[i].info.timestamp,
               nombre_categoria(latest[i].info.categoria));
    }
    imprimir_linea_separacion();
}

// =========================================================
// HISTORIAL DE UN EQUIPO
// Muestra todos los reportes de una PC especifica
// =========================================================
static void mostrar_historial_equipo(const char *carpeta, const char *nombre_equipo) {
    ReporteLeido reportes[MAX_EQUIPOS];
    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);

    if (total <= 0) {
        imprimir_linea_separacion();
        puts("HISTORIAL DE EQUIPO");
        imprimir_linea_separacion();
        puts("No hay reportes para analizar.");
        imprimir_linea_separacion();
        return;
    }

    char buscado_norm[MAX_NOMBRE];
    copiar_nombre_normalizado(buscado_norm, sizeof(buscado_norm), nombre_equipo);

    ReporteLeido filtrados[MAX_EQUIPOS];
    int total_filtrados = 0;

    for (int i = 0; i < total; i++) {
        char base[MAX_NOMBRE];
        extraer_nombre_base(reportes[i].info.nombre_equip, base, sizeof(base));

        char norm[MAX_NOMBRE];
        copiar_nombre_normalizado(norm, sizeof(norm), base);

        if (strcmp(norm, buscado_norm) == 0) {
            filtrados[total_filtrados++] = reportes[i];
        }
    }

    if (total_filtrados == 0) {
        imprimir_linea_separacion();
        puts("HISTORIAL DE EQUIPO");
        imprimir_linea_separacion();
        printf("No se encontraron reportes para: %s\n", nombre_equipo);
        imprimir_linea_separacion();
        return;
    }

    ordenar_por_timestamp_desc(filtrados, total_filtrados);

    imprimir_linea_separacion();
    printf("HISTORIAL DE %s\n", nombre_equipo);
    imprimir_linea_separacion();
    printf("Reportes encontrados: %d\n", total_filtrados);
    puts("------------------------------------------");

    double min_ram = (double)filtrados[0].info.ram_libre;
    double max_ram = (double)filtrados[0].info.ram_libre;
    double suma_ram = 0.0;

    for (int i = 0; i < total_filtrados; i++) {
        EquipoInfo *e = &filtrados[i].info;
        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);

        suma_ram += (double)e->ram_libre;
        if ((double)e->ram_libre < min_ram) min_ram = (double)e->ram_libre;
        if ((double)e->ram_libre > max_ram) max_ram = (double)e->ram_libre;

        printf("%2d) %s | RAM libre: %llu MB | Disco libre: %llu MB | %s\n",
               i + 1,
               e->timestamp,
               (unsigned long long)e->ram_libre,
               (unsigned long long)e->disco_libre,
               nombre_categoria(e->categoria));
    }

    puts("------------------------------------------");

    double prom_ram = suma_ram / (double)total_filtrados;
    printf("RAM libre promedio: %.1f MB\n", prom_ram);
    printf("RAM libre minima  : %.1f MB\n", min_ram);
    printf("RAM libre maxima  : %.1f MB\n", max_ram);

    puts("------------------------------------------");
    puts("Evolucion de RAM libre (ASCII):");
    for (int i = total_filtrados - 1; i >= 0; i--) {
        double pct = 0.0;
        if (filtrados[i].info.ram_total > 0) {
            pct = ((double)filtrados[i].info.ram_libre / (double)filtrados[i].info.ram_total) * 100.0;
        }
        printf("%s  ", filtrados[i].info.timestamp);
        imprimir_barra_pct(pct);
        printf("  %.1f%%\n", pct);
    }

    imprimir_linea_separacion();
}

// =========================================================
// EXPORTACION SIMPLE DE HISTORIAL A CONSOLA
// =========================================================
static void mostrar_estado_global_con_historial(const char *carpeta) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido latest[MAX_EQUIPOS];

    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    if (total <= 0) {
        imprimir_linea_separacion();
        puts("ESTADISTICAS GLOBALES");
        imprimir_linea_separacion();
        puts("No hay reportes .rep para analizar.");
        imprimir_linea_separacion();
        return;
    }

    int total_latest = obtener_unicos_latest(reportes, total, latest, MAX_EQUIPOS);
    if (total_latest <= 0) {
        imprimir_linea_separacion();
        puts("ESTADISTICAS GLOBALES");
        imprimir_linea_separacion();
        puts("No se pudieron consolidar equipos.");
        imprimir_linea_separacion();
        return;
    }

    int cont_cat[4] = {0, 0, 0, 0};
    double suma_ram = 0.0;
    double suma_disco = 0.0;

    for (int i = 0; i < total_latest; i++) {
        EquipoInfo *e = &latest[i].info;
        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);

        cont_cat[e->categoria]++;
        suma_ram += (double)e->ram_libre;
        suma_disco += (double)e->disco_libre;
    }

    double prom_ram = suma_ram / (double)total_latest;
    double prom_disco = suma_disco / (double)total_latest;

    imprimir_linea_separacion();
    puts("ESTADISTICAS GLOBALES DEL LABORATORIO");
    imprimir_linea_separacion();
    printf("Equipos unicos : %d\n", total_latest);
    printf("RAM promedio   : %.1f MB\n", prom_ram);
    printf("Disco promedio : %.1f MB\n", prom_disco);
    puts("------------------------------------------");
    imprimir_grafica_categorias(cont_cat);
    imprimir_linea_separacion();
}

// =========================================================
// FUNCIONES LLAMADAS DESDE EL MENU
// =========================================================
void modulo5_analizar() {
    analizar_general("reportes");
}

void modulo5_estadisticas() {
    mostrar_estado_global_con_historial("reportes");
}

// Opcional: por si luego quieres conectarlo al menu
void modulo5_historial_equipo(const char *nombre_equipo) {
    if (nombre_equipo == NULL || nombre_equipo[0] == '\0') {
        puts("Nombre de equipo invalido.");
        return;
    }
    mostrar_historial_equipo("reportes", nombre_equipo);
}