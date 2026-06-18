// ==========================================
// TECHSCAN64 - Modulo 5: Analisis Central
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
        case 0:  return "Excelente";
        case 1:  return "Bueno";
        case 2:  return "Regular";
        case 3:  return "Critico";
        default: return "Desconocido";
    }
}

static uint32_t clasificar_equipo(uint64_t ram_total, uint64_t ram_libre) {
    if (ram_total == 0) return 3;
    double pct = ((double)ram_libre / (double)ram_total) * 100.0;
    if (pct >= 50.0) return 0;
    if (pct >= 30.0) return 1;
    if (pct >= 15.0) return 2;
    return 3;
}

static void imprimir_barra_pct(double pct) {
    int bloques = (int)((pct / 100.0) * 20.0);
    if (bloques < 0)  bloques = 0;
    if (bloques > 20) bloques = 20;
    putchar('[');
    for (int i = 0; i < 20; i++) putchar(i < bloques ? '#' : '-');
    putchar(']');
}

static void imprimir_sep(void) {
    puts("==========================================");
}

static int comparar_ft_desc(const FILETIME *a, const FILETIME *b) {
    if (a->dwHighDateTime > b->dwHighDateTime) return  1;
    if (a->dwHighDateTime < b->dwHighDateTime) return -1;
    if (a->dwLowDateTime  > b->dwLowDateTime)  return  1;
    if (a->dwLowDateTime  < b->dwLowDateTime)  return -1;
    return 0;
}

static void copiar_nombre_normalizado(char *dst, size_t sz, const char *src) {
    size_t i = 0;
    for (; i + 1 < sz && src[i]; i++)
        dst[i] = (char)tolower((unsigned char)src[i]);
    dst[i] = '\0';
}

static void extraer_nombre_base(const char *src, char *dst, size_t sz) {
    char tmp[MAX_NOMBRE];
    size_t i = 0;
    const char *p = src;
    while (*p && *p != '_' && *p != '.' && i + 1 < sizeof(tmp))
        tmp[i++] = *p++;
    tmp[i] = '\0';
    strncpy(dst, tmp, sz - 1);
    dst[sz - 1] = '\0';
}

// =========================================================
// Ordenamiento
// =========================================================

static void ordenar_por_timestamp_desc(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (comparar_ft_desc(&arr[j].ft_write, &arr[i].ft_write) > 0) {
                ReporteLeido t = arr[i]; arr[i] = arr[j]; arr[j] = t;
            }
}

// Ordena por ram_libre ascendente (menos RAM libre primero)
static void ordenar_por_ram_asc(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (arr[j].info.ram_libre < arr[i].info.ram_libre) {
                ReporteLeido t = arr[i]; arr[i] = arr[j]; arr[j] = t;
            }
}

// Ordena por disco_libre ascendente (menos espacio libre primero)
static void ordenar_por_disco_asc(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (arr[j].info.disco_libre < arr[i].info.disco_libre) {
                ReporteLeido t = arr[i]; arr[i] = arr[j]; arr[j] = t;
            }
}

// Ordena por prioridad: categoria desc (critico=3 primero),
// desempate por ram_libre asc
static void ordenar_por_prioridad(ReporteLeido *arr, int n) {
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++) {
            int pi = (int)arr[i].info.categoria;
            int pj = (int)arr[j].info.categoria;
            int swap = 0;
            if (pj > pi) swap = 1;
            else if (pj == pi &&
                     arr[j].info.ram_libre < arr[i].info.ram_libre) swap = 1;
            if (swap) { ReporteLeido t = arr[i]; arr[i] = arr[j]; arr[j] = t; }
        }
}

// =========================================================
// Carga de reportes
// =========================================================

static int leer_reporte_binario(const char *ruta, EquipoInfo *equipo) {
    FILE *f = fopen(ruta, "rb");
    if (!f) return 0;
    ReporteHeader h;
    if (fread(&h, sizeof(h), 1, f) != 1 || !es_firma_valida(&h)) {
        fclose(f); return 0;
    }
    if (fread(equipo, sizeof(*equipo), 1, f) != 1) {
        fclose(f); return 0;
    }
    fclose(f);
    return 1;
}

static int obtener_fecha_archivo(const char *ruta, FILETIME *ft) {
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (!GetFileAttributesExA(ruta, GetFileExInfoStandard, &d)) return 0;
    *ft = d.ftLastWriteTime;
    return 1;
}

static int cargar_reportes(const char *carpeta,
                            ReporteLeido *salida, int max) {
    char patron[MAX_RUTAS];
    snprintf(patron, sizeof(patron), "%s\\*.rep", carpeta);
    WIN32_FIND_DATAA fd;
    HANDLE h = FindFirstFileA(patron, &fd);
    if (h == INVALID_HANDLE_VALUE) return 0;
    int total = 0;
    do {
        if (total >= max) break;
        char ruta[MAX_RUTAS];
        snprintf(ruta, sizeof(ruta), "%s\\%s", carpeta, fd.cFileName);
        EquipoInfo e;
        if (!leer_reporte_binario(ruta, &e)) continue;
        salida[total].info = e;
        strncpy(salida[total].ruta, ruta, sizeof(salida[total].ruta) - 1);
        salida[total].ruta[sizeof(salida[total].ruta) - 1] = '\0';
        salida[total].valido = 1;
        if (!obtener_fecha_archivo(ruta, &salida[total].ft_write))
            ZeroMemory(&salida[total].ft_write, sizeof(FILETIME));
        total++;
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    return total;
}

// Consolida el reporte mas reciente por nombre de equipo
static int obtener_unicos_latest(const ReporteLeido *arr, int n,
                                  ReporteLeido *out, int max_out) {
    char nombres[MAX_EQUIPOS][MAX_NOMBRE];
    int cant = 0;

    for (int i = 0; i < n; i++) {
        char base[MAX_NOMBRE], norm[MAX_NOMBRE];
        extraer_nombre_base(arr[i].info.nombre_equip, base, sizeof(base));
        copiar_nombre_normalizado(norm, sizeof(norm), base);
        int existe = 0;
        for (int j = 0; j < cant; j++)
            if (strcmp(nombres[j], norm) == 0) { existe = 1; break; }
        if (!existe && cant < MAX_EQUIPOS)
            strncpy(nombres[cant++], norm, sizeof(nombres[0]) - 1);
    }

    int total = 0;
    for (int i = 0; i < cant && total < max_out; i++) {
        int idx = -1;
        for (int j = 0; j < n; j++) {
            char base[MAX_NOMBRE], norm[MAX_NOMBRE];
            extraer_nombre_base(arr[j].info.nombre_equip, base, sizeof(base));
            copiar_nombre_normalizado(norm, sizeof(norm), base);
            if (strcmp(norm, nombres[i]) != 0) continue;
            if (idx == -1 ||
                comparar_ft_desc(&arr[j].ft_write, &arr[idx].ft_write) > 0)
                idx = j;
        }
        if (idx >= 0) out[total++] = arr[idx];
    }
    return total;
}

// =========================================================
// Graficas ASCII
// =========================================================

static void imprimir_grafica_categorias(const int cont[4]) {
    int total = cont[0] + cont[1] + cont[2] + cont[3];
    if (total <= 0) total = 1;
    const char *nombres[4] = {"Excelente", "Bueno", "Regular", "Critico"};
    puts("Distribucion por categoria:");
    for (int i = 0; i < 4; i++) {
        int b = (cont[i] * 20) / total;
        printf("%-10s [", nombres[i]);
        for (int k = 0; k < 20; k++) putchar(k < b ? '#' : '-');
        printf("] %d\n", cont[i]);
    }
}

static void imprimir_grafica_pct(const char *titulo, double pct) {
    if (pct < 0.0) pct = 0.0;
    if (pct > 100.0) pct = 100.0;
    printf("%s\n", titulo);
    printf("[");
    for (int i = 0; i < 20; i++) {
        double lim = (double)(i + 1) * 5.0;
        putchar(pct >= lim ? '#' : '-');
    }
    printf("] %.1f%%\n", pct);
}

// =========================================================
// Lista priorizada de revision tecnica
// =========================================================

static void imprimir_lista_priorizada(const ReporteLeido *arr, int n) {
    ReporteLeido sorted[MAX_EQUIPOS];
    int cnt = n < MAX_EQUIPOS ? n : MAX_EQUIPOS;
    memcpy(sorted, arr, cnt * sizeof(ReporteLeido));
    ordenar_por_prioridad(sorted, cnt);

    imprimir_sep();
    puts("LISTA PRIORIZADA DE REVISION TECNICA");
    imprimir_sep();
    printf("%-3s %-12s %-20s %-12s %s\n",
           "#", "Prioridad", "Equipo", "Categoria", "RAM libre");
    puts("------------------------------------------");
    for (int i = 0; i < cnt; i++) {
        const char *prio;
        switch (sorted[i].info.categoria) {
            case 3:  prio = "[URGENTE]  "; break;
            case 2:  prio = "[REVISAR]  "; break;
            case 1:  prio = "[ACEPTABLE]"; break;
            default: prio = "[OK]       "; break;
        }
        printf("%-3d %s %-20s %-12s %llu MB\n",
               i + 1, prio,
               sorted[i].info.nombre_equip,
               nombre_categoria(sorted[i].info.categoria),
               (unsigned long long)sorted[i].info.ram_libre);
    }
    imprimir_sep();
}

// =========================================================
// ANALISIS GENERAL
// =========================================================

static void analizar_general(const char *carpeta) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido latest[MAX_EQUIPOS];

    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    if (total <= 0) {
        imprimir_sep();
        puts("ANALISIS GENERAL");
        imprimir_sep();
        puts("No hay reportes .rep para analizar todavia.");
        puts("Use la opcion 1 (Diagnosticar este equipo) primero.");
        imprimir_sep();
        return;
    }

    int tl = obtener_unicos_latest(reportes, total, latest, MAX_EQUIPOS);
    if (tl <= 0) {
        imprimir_sep();
        puts("ANALISIS GENERAL");
        imprimir_sep();
        puts("No se pudieron consolidar equipos unicos.");
        imprimir_sep();
        return;
    }

    // Estadisticas
    int cont_cat[4] = {0};
    double suma_ram = 0.0, suma_disco = 0.0;
    int idx_critico = 0, idx_mejor = 0, idx_antiguo = 0;
    uint64_t menor_ram  = latest[0].info.ram_libre;
    uint64_t mayor_ram  = latest[0].info.ram_libre;

    for (int i = 0; i < tl; i++) {
        EquipoInfo *e = &latest[i].info;
        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);
        cont_cat[e->categoria]++;
        suma_ram   += (double)e->ram_libre;
        suma_disco += (double)e->disco_libre;
        if (e->ram_libre < menor_ram) { menor_ram = e->ram_libre; idx_critico = i; }
        if (e->ram_libre > mayor_ram) { mayor_ram = e->ram_libre; idx_mejor   = i; }
        // equipo mas antiguo = FILETIME mas pequeño
        if (comparar_ft_desc(&latest[i].ft_write,
                              &latest[idx_antiguo].ft_write) < 0)
            idx_antiguo = i;
    }

    double prom_ram   = suma_ram   / (double)tl;
    double prom_disco = suma_disco / (double)tl;

    imprimir_sep();
    puts("ANALISIS GENERAL");
    imprimir_sep();
    printf("Equipos unicos analizados : %d\n", tl);
    printf("Excelente : %d\n", cont_cat[0]);
    printf("Bueno     : %d\n", cont_cat[1]);
    printf("Regular   : %d\n", cont_cat[2]);
    printf("Critico   : %d\n", cont_cat[3]);
    puts("------------------------------------------");
    printf("Promedio RAM libre  : %.1f MB\n", prom_ram);
    printf("Promedio Disco libre: %.1f MB\n", prom_disco);
    puts("------------------------------------------");
    printf("Equipo mas critico  : %s (%llu MB RAM libre)\n",
           latest[idx_critico].info.nombre_equip,
           (unsigned long long)latest[idx_critico].info.ram_libre);
    printf("Equipo con mas RAM  : %s (%llu MB RAM libre)\n",
           latest[idx_mejor].info.nombre_equip,
           (unsigned long long)latest[idx_mejor].info.ram_libre);
    printf("Equipo mas antiguo  : %s (%s)\n",
           latest[idx_antiguo].info.nombre_equip,
           latest[idx_antiguo].info.timestamp);
    puts("------------------------------------------");

    imprimir_grafica_categorias(cont_cat);
    puts("------------------------------------------");
    imprimir_grafica_pct("RAM promedio libre:",
        prom_ram   > 0.0 ? (prom_ram   / 1024.0) * 100.0 : 0.0);
    imprimir_grafica_pct("Disco promedio libre:",
        prom_disco > 0.0 ? (prom_disco / 1024.0) * 100.0 : 0.0);
    imprimir_sep();

    // Ordenados por RAM libre ascendente (los mas criticos primero)
    ReporteLeido por_ram[MAX_EQUIPOS];
    memcpy(por_ram, latest, tl * sizeof(ReporteLeido));
    ordenar_por_ram_asc(por_ram, tl);
    puts("Top equipos con MENOS RAM libre:");
    for (int i = 0; i < tl && i < 5; i++)
        printf("  %d. %-20s %llu MB  [%s]\n", i + 1,
               por_ram[i].info.nombre_equip,
               (unsigned long long)por_ram[i].info.ram_libre,
               nombre_categoria(por_ram[i].info.categoria));

    puts("------------------------------------------");

    // Ordenados por disco libre ascendente
    ReporteLeido por_disco[MAX_EQUIPOS];
    memcpy(por_disco, latest, tl * sizeof(ReporteLeido));
    ordenar_por_disco_asc(por_disco, tl);
    puts("Top equipos con MENOS disco libre:");
    for (int i = 0; i < tl && i < 5; i++)
        printf("  %d. %-20s %llu MB\n", i + 1,
               por_disco[i].info.nombre_equip,
               (unsigned long long)por_disco[i].info.disco_libre);

    puts("------------------------------------------");

    // Ordenados por antiguedad (mas antiguo primero)
    ReporteLeido por_fecha[MAX_EQUIPOS];
    memcpy(por_fecha, latest, tl * sizeof(ReporteLeido));
    ordenar_por_timestamp_desc(por_fecha, tl);  // desc = mas reciente primero
    puts("Ultimos equipos detectados (mas reciente primero):");
    for (int i = 0; i < tl && i < 10; i++)
        printf("  - %-20s | %s | %s\n",
               por_fecha[i].info.nombre_equip,
               por_fecha[i].info.timestamp,
               nombre_categoria(por_fecha[i].info.categoria));
    imprimir_sep();

    // Lista priorizada
    imprimir_lista_priorizada(latest, tl);
}

// =========================================================
// ESTADISTICAS GLOBALES
// =========================================================

static void mostrar_estadisticas_globales(const char *carpeta) {
    ReporteLeido reportes[MAX_EQUIPOS];
    ReporteLeido latest[MAX_EQUIPOS];

    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    if (total <= 0) {
        imprimir_sep();
        puts("ESTADISTICAS GLOBALES");
        imprimir_sep();
        puts("No hay reportes .rep para analizar.");
        imprimir_sep();
        return;
    }

    int tl = obtener_unicos_latest(reportes, total, latest, MAX_EQUIPOS);
    if (tl <= 0) {
        imprimir_sep();
        puts("ESTADISTICAS GLOBALES");
        imprimir_sep();
        puts("No se pudieron consolidar equipos.");
        imprimir_sep();
        return;
    }

    int cont_cat[4] = {0};
    double suma_ram = 0.0, suma_disco = 0.0;

    for (int i = 0; i < tl; i++) {
        EquipoInfo *e = &latest[i].info;
        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);
        cont_cat[e->categoria]++;
        suma_ram   += (double)e->ram_libre;
        suma_disco += (double)e->disco_libre;
    }

    double prom_ram   = suma_ram   / (double)tl;
    double prom_disco = suma_disco / (double)tl;

    imprimir_sep();
    puts("ESTADISTICAS GLOBALES DEL LABORATORIO");
    imprimir_sep();
    printf("Equipos unicos : %d\n", tl);
    printf("RAM promedio   : %.1f MB libres\n", prom_ram);
    printf("Disco promedio : %.1f MB libres\n", prom_disco);
    puts("------------------------------------------");
    imprimir_grafica_categorias(cont_cat);
    imprimir_sep();

    // Lista priorizada de revision
    imprimir_lista_priorizada(latest, tl);
}

// =========================================================
// HISTORIAL DE UN EQUIPO
// =========================================================

static void mostrar_historial_equipo(const char *carpeta,
                                      const char *nombre_equipo) {
    ReporteLeido reportes[MAX_EQUIPOS];
    int total = cargar_reportes(carpeta, reportes, MAX_EQUIPOS);
    if (total <= 0) {
        imprimir_sep(); puts("HISTORIAL DE EQUIPO"); imprimir_sep();
        puts("No hay reportes para analizar."); imprimir_sep(); return;
    }

    char buscado[MAX_NOMBRE];
    copiar_nombre_normalizado(buscado, sizeof(buscado), nombre_equipo);

    ReporteLeido filtrados[MAX_EQUIPOS];
    int tf = 0;
    for (int i = 0; i < total; i++) {
        char base[MAX_NOMBRE], norm[MAX_NOMBRE];
        extraer_nombre_base(reportes[i].info.nombre_equip, base, sizeof(base));
        copiar_nombre_normalizado(norm, sizeof(norm), base);
        if (strcmp(norm, buscado) == 0) filtrados[tf++] = reportes[i];
    }

    if (tf == 0) {
        imprimir_sep(); puts("HISTORIAL DE EQUIPO"); imprimir_sep();
        printf("No se encontraron reportes para: %s\n", nombre_equipo);
        imprimir_sep(); return;
    }

    ordenar_por_timestamp_desc(filtrados, tf);

    imprimir_sep();
    printf("HISTORIAL DE %s\n", nombre_equipo);
    imprimir_sep();
    printf("Reportes encontrados: %d\n", tf);
    puts("------------------------------------------");

    double min_ram = (double)filtrados[0].info.ram_libre;
    double max_ram = (double)filtrados[0].info.ram_libre;
    double suma_ram = 0.0;

    for (int i = 0; i < tf; i++) {
        EquipoInfo *e = &filtrados[i].info;
        e->categoria = clasificar_equipo(e->ram_total, e->ram_libre);
        suma_ram += (double)e->ram_libre;
        if ((double)e->ram_libre < min_ram) min_ram = (double)e->ram_libre;
        if ((double)e->ram_libre > max_ram) max_ram = (double)e->ram_libre;
        printf("%2d) %s | RAM: %llu MB | Disco: %llu MB | %s\n",
               i + 1, e->timestamp,
               (unsigned long long)e->ram_libre,
               (unsigned long long)e->disco_libre,
               nombre_categoria(e->categoria));
    }

    puts("------------------------------------------");
    printf("RAM libre promedio: %.1f MB\n", suma_ram / (double)tf);
    printf("RAM libre minima  : %.1f MB\n", min_ram);
    printf("RAM libre maxima  : %.1f MB\n", max_ram);
    puts("------------------------------------------");
    puts("Evolucion RAM libre (cronologico):");
    for (int i = tf - 1; i >= 0; i--) {
        double pct = filtrados[i].info.ram_total > 0
            ? ((double)filtrados[i].info.ram_libre /
               (double)filtrados[i].info.ram_total) * 100.0
            : 0.0;
        printf("%s  ", filtrados[i].info.timestamp);
        imprimir_barra_pct(pct);
        printf("  %.1f%%\n", pct);
    }
    imprimir_sep();
}

// =========================================================
// FUNCIONES EXPORTADAS AL MENU
// =========================================================

void modulo5_analizar(void) {
    analizar_general("reportes");
}

void modulo5_estadisticas(void) {
    mostrar_estadisticas_globales("reportes");
}

void modulo5_historial_equipo(const char *nombre_equipo) {
    if (!nombre_equipo || nombre_equipo[0] == '\0') {
        puts("Nombre de equipo invalido."); return;
    }
    mostrar_historial_equipo("reportes", nombre_equipo);
}
