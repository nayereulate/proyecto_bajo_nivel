#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

// Forzamos a GCC a no dejar espacios vacios (padding) en la memoria,
// garantizando que los offsets coincidan exactamente con el codigo .asm de tus companeros.
#pragma pack(push, 1)

// Estructura de Datos Oficial 
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
} EquipoInfo;

// Formato de Encabezado Oficial
typedef struct {
    char firma[4];            // 4 bytes: "SCAN"
    uint32_t version;         // Version del reporte (ej. 1)
    char fecha_creacion[12];  // Fecha corta de creacion
    uint32_t cant_registros;  // Cantidad de registros en el archivo
} ReporteHeader;

#pragma pack(pop)

// Declaracion de la funcion log antes de usarse
void registrar_log(const char *mensaje);

// 1. FUNCION PARA GUARDAR REPORTE BINARIO 
void guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo) {
    FILE *archivo = fopen(nombre_archivo, "wb");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo crear el archivo de reporte binario.");
        return;
    }

    // Construccion del encabezado segun la especificacion del PDF
    ReporteHeader header;
    memcpy(header.firma, "SCAN", 4);
    header.version = 1;
    header.cant_registros = 1;
    
    // Obtener fecha del sistema para el encabezado
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(header.fecha_creacion, sizeof(header.fecha_creacion), "%Y-%m-%d", tm_info);

    // Escribir Encabezado 
    fwrite(&header, sizeof(ReporteHeader), 1, archivo);

    // Escribir Registro Principal
    fwrite(equipo, sizeof(EquipoInfo), 1, archivo);

    fclose(archivo);
    registrar_log("OK: Reporte binario .rep guardado con exito.");
}

// 2. FUNCION PARA LEER REPORTE BINARIO 
int leer_reporte(const char *nombre_archivo, EquipoInfo *equipo) {
    FILE *archivo = fopen(nombre_archivo, "rb");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo abrir el archivo .rep para lectura.");
        return 0;
    }

    // Leer y validar encabezado
    ReporteHeader header;
    if (fread(&header, sizeof(ReporteHeader), 1, archivo) != 1) {
        registrar_log("ERROR: Estructura de encabezado ilegible.");
        fclose(archivo);
        return 0;
    }

    // Validacion estricta de la firma "SCAN"
    if (memcmp(header.firma, "SCAN", 4) != 0) {
        registrar_log("ERROR: Firma de archivo invalida (No es un archivo TechScan64).");
        fclose(archivo);
        return 0;
    }

    // Leer el registro de datos
    fread(equipo, sizeof(EquipoInfo), 1, archivo);

    fclose(archivo);
    return 1; // Exito
}

// 3. ARCHIVO .LOG CON MARCAS DE TIEMPO REALES 
void registrar_log(const char *mensaje) {
    FILE *log = fopen("events.log", "a");
    if (log != NULL) {
        time_t t = time(NULL);
        struct tm *tm_info = localtime(&t);
        char timestamp[26];
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

        // Imprime en el archivo: [2026-06-12 11:14:30] [LOG]: Mensaje
        fprintf(log, "[%s] %s\n", timestamp, mensaje);
        fclose(log);
    }
}

// 4. EXPORTACION OPCIONAL A .CSV 
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