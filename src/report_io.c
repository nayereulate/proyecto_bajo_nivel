// modulo 3: persistencia y formato de Reportes
// estructura y lectura de archivos .rep, log de eventos y exportacion CSV

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

// Forzamos a GCC a no dejar espacios vacios (padding) en la memoria,garantizando que los offsets coincidan exactamente con el codigo .asm y con las copias de la estructura en modulo2.c y analyzer.c.
#pragma pack(push, 1)
// Estructura de Datos el oficial
typedef struct {
    uint32_t id_equipo;       // Offset 0   (4 bytes)
    char nombre_equip[28];    // Offset 4   (28 bytes)
    char cpu_modelo[32];      // Offset 32  (32 bytes)
    uint64_t ram_total;       // Offset 64  (8 bytes) - En MB
    uint64_t ram_libre;       // Offset 72  (8 bytes) - En MB
    uint64_t disco_libre;     // Offset 80  (8 bytes) - En MB
    char gpu_modelo[32];      // Offset 88  (32 bytes)
    char placa_modelo[32];    // Offset 120 (32 bytes)
    double uso_ram_pct;       // Offset 152 (8 bytes)  - Valor FPU
    double uso_cpu_pct;       // Offset 160 (8 bytes)  - Valor FPU
    uint32_t procesos;        // Offset 168 (4 bytes)
    uint32_t categoria;       // Offset 172 (4 bytes)  - 0=Excel, 1=Buen, 2=Reg, 3=Crit
    char timestamp[24];       // Offset 176 (24 bytes) - Marca de tiempo de la captura
} EquipoInfo;                 // Tamano total: 200 bytes

// Formato de Encabezado oficial. Tamaño fijo de 24 bytes
typedef struct {
    char firma[4];            // 4 bytes: "SCAN"
    uint32_t version;         // Version del formato base (1)
    char fecha_creacion[12];  // Fecha corta de creacion
    uint32_t cant_registros;  // Cantidad de registros principales en el archivo
} ReporteHeader;

// Bloque de monitoreo opcional . Se anexa despues del registro principal con su propia firma "MON1".Un lector que no lo conozca como analyzer.c jamas llega a leerlo porque se detiene justo despues de leer el registro principal
typedef struct {
    char tag[4];               // "MON1"
    double uso_ram_pct;        // Snapshot de uso de RAM al momento del refresco
    double uso_cpu_pct;        // Snapshot de uso de CPU al momento del refresco
    uint64_t disco_libre;      // Snapshot de disco libre en MB
    char timestamp[24];        // Marca de tiempo del ultimo refresco
} BloqueMonitoreo;

// Bloque de estadisticas opcional. Se anexa despues del bloque de monitoreo o del registro principal si no haymonitoreo con su propia firma "STA1". Mismo principio de compatibilidad.
typedef struct {
    char tag[4];                  // "STA1"
    double promedio_ram_libre;    // Promedio de RAM libre del laboratorio (MB)
    double promedio_disco_libre;  // Promedio de disco libre del laboratorio (MB)
    uint32_t categoria_final;     // Categoria final asignada tras el analisis
    char resumen[64];             // Resumen breve del analisis central
} BloqueEstadisticas;

#pragma pack(pop)

#define FIRMA_REPORTE   "SCAN"
#define VERSION_REPORTE 1

// Declaracion adelantada: las demas funciones registran eventos en el log.
void registrar_log(const char *mensaje);

// 1. Guardar reporte binario  el encabezado + registro principal

void guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo) {
    FILE *archivo = fopen(nombre_archivo, "wb");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo crear el archivo de reporte binario.");
        return;
    }

    ReporteHeader header;
    memcpy(header.firma, FIRMA_REPORTE, 4);
    header.version = VERSION_REPORTE;
    header.cant_registros = 1;

    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(header.fecha_creacion, sizeof(header.fecha_creacion), "%Y-%m-%d", tm_info);

    if (fwrite(&header, sizeof(ReporteHeader), 1, archivo) != 1 ||
        fwrite(equipo, sizeof(EquipoInfo), 1, archivo) != 1) {
        registrar_log("ERROR: Fallo al escribir el reporte binario (disco lleno o USB desconectada).");
        fclose(archivo);
        return;
    }

    fclose(archivo);
    registrar_log("OK: Reporte binario .rep guardado con exito.");
}

// 2.leer reporte en binario con validacion completa

int leer_reporte(const char *nombre_archivo, EquipoInfo *equipo) {
    FILE *archivo = fopen(nombre_archivo, "rb");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo abrir el archivo .rep para lectura.");
        return 0;
    }

    ReporteHeader header;
    if (fread(&header, sizeof(ReporteHeader), 1, archivo) != 1) {
        registrar_log("ERROR: Encabezado ilegible o archivo demasiado pequeno.");
        fclose(archivo);
        return 0;
    }

    if (memcmp(header.firma, FIRMA_REPORTE, 4) != 0) {
        registrar_log("ERROR: Firma de archivo invalida (no es un .rep de TechScan64).");
        fclose(archivo);
        return 0;
    }

    if (header.version != VERSION_REPORTE) {
        registrar_log("ERROR: Version de formato .rep no soportada por este modulo.");
        fclose(archivo);
        return 0;
    }

    if (fread(equipo, sizeof(EquipoInfo), 1, archivo) != 1) {
        registrar_log("ERROR: Registro de datos ilegible o archivo .rep truncado.");
        fclose(archivo);
        return 0;
    }

    fclose(archivo);
    return 1; // Exito
}

// 3. archivo .log con marcas dE en tiempo reales 
void registrar_log(const char *mensaje) {
    FILE *log = fopen("events.log", "a");
    if (log != NULL) {
        time_t t = time(NULL);
        struct tm *tm_info = localtime(&t);
        char timestamp[26];
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

        // Imprime en el archivo Ejemplo: [2026-06-12 11:14:30] [LOG]: Mensaje
        fprintf(log, "[%s] %s\n", timestamp, mensaje);
        fclose(log);
    }
}

// 4. exportacion opcinal a .CSV

void exportar_csv(const char *nombre_csv, const EquipoInfo *equipo) {
    FILE *csv = fopen(nombre_csv, "w");
    if (csv == NULL) {
        registrar_log("ERROR: No se pudo exportar a formato CSV.");
        return;
    }

    // Cabeceras del CSV
    fprintf(csv, "ID,Hostname,CPU,RAM_Total(MB),RAM_Libre(MB),Disco_Libre(MB),GPU,Placa,Uso_RAM(%%),Uso_CPU(%%),Procesos,Categoria,Timestamp\n");

    // Contenido del registro separado por comas
    fprintf(csv, "%u,%s,%s,%llu,%llu,%llu,%s,%s,%.2f,%.2f,%u,%u,%s\n",
            equipo->id_equipo, equipo->nombre_equip, equipo->cpu_modelo,
            (unsigned long long)equipo->ram_total, (unsigned long long)equipo->ram_libre, (unsigned long long)equipo->disco_libre,
            equipo->gpu_modelo, equipo->placa_modelo, equipo->uso_ram_pct, equipo->uso_cpu_pct,
            equipo->procesos, equipo->categoria, equipo->timestamp);

    fclose(csv);
    registrar_log("OK: Evidencia adicional exportada a formato CSV correctamente.");
}


// 5.Bloque de monitoreo opcinal 
// puede llamar el Modulo 4 monitor.asm, via wrapper en C cuando quiera dejar constancia de un snapshot de monitoreo dentro del .rep.

void agregar_bloque_monitoreo(const char *nombre_archivo, double uso_ram_pct,
                               double uso_cpu_pct, uint64_t disco_libre) {
    FILE *archivo = fopen(nombre_archivo, "ab");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo abrir el .rep para anexar el bloque de monitoreo.");
        return;
    }

    BloqueMonitoreo bloque;
    memcpy(bloque.tag, "MON1", 4);
    bloque.uso_ram_pct = uso_ram_pct;
    bloque.uso_cpu_pct = uso_cpu_pct;
    bloque.disco_libre = disco_libre;

    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(bloque.timestamp, sizeof(bloque.timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

    if (fwrite(&bloque, sizeof(BloqueMonitoreo), 1, archivo) != 1) {
        registrar_log("ERROR: Fallo al escribir el bloque de monitoreo.");
        fclose(archivo);
        return;
    }

    fclose(archivo);
    registrar_log("OK: Bloque de monitoreo anexado al reporte.");
}

// Lee el bloque de monitoreo si existe busca la firma "MON1" justo despues del registro principal. Devuelve 0 si el .rep no tieneese bloque por ejemplo los reportes antiguos generados antes de integrar el Modulo 4.
int leer_bloque_monitoreo(const char *nombre_archivo, BloqueMonitoreo *bloque) {
    FILE *archivo = fopen(nombre_archivo, "rb");
    if (archivo == NULL) return 0;

    long offset_bloque = (long)(sizeof(ReporteHeader) + sizeof(EquipoInfo));
    if (fseek(archivo, offset_bloque, SEEK_SET) != 0) {
        fclose(archivo);
        return 0;
    }

    if (fread(bloque, sizeof(BloqueMonitoreo), 1, archivo) != 1) {
        fclose(archivo);
        return 0;
    }

    fclose(archivo);

    if (memcmp(bloque->tag, "MON1", 4) != 0) return 0;
    return 1;
}

// 6.Bloque de estadisticas opcional
// puede llamar el Modulo 5 analyzer.c al terminar su analisis central, para dejar constancia del resumen dentro del .rep del equipo analizado.

void agregar_bloque_estadisticas(const char *nombre_archivo, double promedio_ram_libre,
                                  double promedio_disco_libre, uint32_t categoria_final,
                                  const char *resumen) {
    FILE *archivo = fopen(nombre_archivo, "ab");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo abrir el .rep para anexar el bloque de estadisticas.");
        return;
    }

    BloqueEstadisticas bloque;
    memset(&bloque, 0, sizeof(bloque));
    memcpy(bloque.tag, "STA1", 4);
    bloque.promedio_ram_libre = promedio_ram_libre;
    bloque.promedio_disco_libre = promedio_disco_libre;
    bloque.categoria_final = categoria_final;
    if (resumen != NULL) {
        strncpy(bloque.resumen, resumen, sizeof(bloque.resumen) - 1);
    }

    if (fwrite(&bloque, sizeof(BloqueEstadisticas), 1, archivo) != 1) {
        registrar_log("ERROR: Fallo al escribir el bloque de estadisticas.");
        fclose(archivo);
        return;
    }

    fclose(archivo);
    registrar_log("OK: Bloque de estadisticas anexado al reporte.");
}