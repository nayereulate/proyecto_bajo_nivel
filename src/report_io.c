// Modulo 3: persistencia, formato de reportes, log y exportacion CSV.
// El registro principal de EquipoInfo conserva 200 bytes para compatibilidad.
// Los datos nuevos se anexan como bloques opcionales con firma propia.

#include "techscan_shared.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

static int escribir_bloque(const char *nombre_archivo,
                           const void *bloque,
                           size_t tam,
                           const char *msg_ok,
                           const char *msg_error) {
    FILE *archivo = fopen(nombre_archivo, "ab");
    if (archivo == NULL) {
        registrar_log(msg_error);
        return 0;
    }

    if (fwrite(bloque, tam, 1, archivo) != 1) {
        registrar_log(msg_error);
        fclose(archivo);
        return 0;
    }

    fclose(archivo);
    registrar_log(msg_ok);
    return 1;
}

static int buscar_bloque(const char *nombre_archivo,
                         const char tag[4],
                         void *bloque,
                         size_t tam) {
    FILE *archivo = fopen(nombre_archivo, "rb");
    char actual[4];

    if (archivo == NULL) return 0;

    if (fseek(archivo, (long)(sizeof(ReporteHeader) + sizeof(EquipoInfo)), SEEK_SET) != 0) {
        fclose(archivo);
        return 0;
    }

    while (fread(actual, sizeof(actual), 1, archivo) == 1) {
        size_t restante = 0;

        if (memcmp(actual, tag, 4) == 0) {
            memcpy(bloque, actual, 4);
            if (fread((char *)bloque + 4, tam - 4, 1, archivo) == 1) {
                fclose(archivo);
                return 1;
            }
            fclose(archivo);
            return 0;
        }

        if (memcmp(actual, "MON1", 4) == 0) restante = sizeof(BloqueMonitoreo) - 4;
        else if (memcmp(actual, "STA1", 4) == 0) restante = sizeof(BloqueEstadisticas) - 4;
        else if (memcmp(actual, "HWX1", 4) == 0) restante = sizeof(BloqueHardwareAvanzado) - 4;
        else if (memcmp(actual, "PRC1", 4) == 0) restante = sizeof(BloqueProcesos) - 4;
        else if (memcmp(actual, "ANX1", 4) == 0) restante = sizeof(BloqueAnalisisExtendido) - 4;
        else break;

        if (fseek(archivo, (long)restante, SEEK_CUR) != 0) break;
    }

    fclose(archivo);
    return 0;
}

int guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo) {
    FILE *archivo;
    ReporteHeader header;
    time_t t;
    struct tm *tm_info;

    techscan_crear_directorio_si_falta("reportes");

    archivo = fopen(nombre_archivo, "wb");
    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo crear el archivo de reporte binario.");
        return 0;
    }

    memset(&header, 0, sizeof(header));
    memcpy(header.firma, TECHSCAN_REP_SIGNATURE, 4);
    header.version = TECHSCAN_REP_VERSION;
    header.cant_registros = 1;

    t = time(NULL);
    tm_info = localtime(&t);
    strftime(header.fecha_creacion, sizeof(header.fecha_creacion), "%Y-%m-%d", tm_info);

    if (fwrite(&header, sizeof(header), 1, archivo) != 1 ||
        fwrite(equipo, sizeof(*equipo), 1, archivo) != 1) {
        registrar_log("ERROR: Fallo al escribir el reporte binario.");
        fclose(archivo);
        return 0;
    }

    fclose(archivo);
    registrar_log("OK: Reporte binario .rep guardado con exito.");
    return 1;
}

int leer_reporte(const char *nombre_archivo, EquipoInfo *equipo) {
    FILE *archivo = fopen(nombre_archivo, "rb");
    ReporteHeader header;

    if (archivo == NULL) {
        registrar_log("ERROR: No se pudo abrir el archivo .rep para lectura.");
        return 0;
    }

    if (fread(&header, sizeof(header), 1, archivo) != 1) {
        registrar_log("ERROR: Encabezado ilegible o archivo demasiado pequeno.");
        fclose(archivo);
        return 0;
    }

    if (memcmp(header.firma, TECHSCAN_REP_SIGNATURE, 4) != 0) {
        registrar_log("ERROR: Firma de archivo invalida.");
        fclose(archivo);
        return 0;
    }

    if (header.version != TECHSCAN_REP_VERSION) {
        registrar_log("ERROR: Version de formato .rep no soportada.");
        fclose(archivo);
        return 0;
    }

    if (fread(equipo, sizeof(*equipo), 1, archivo) != 1) {
        registrar_log("ERROR: Registro de datos ilegible o archivo .rep truncado.");
        fclose(archivo);
        return 0;
    }

    fclose(archivo);
    return 1;
}

void registrar_log(const char *mensaje) {
    FILE *log = fopen("events.log", "a");
    if (log != NULL) {
        time_t t = time(NULL);
        struct tm *tm_info = localtime(&t);
        char timestamp[26];
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
        fprintf(log, "[%s] %s\n", timestamp, mensaje);
        fclose(log);
    }
}

void exportar_csv(const char *nombre_csv, const EquipoInfo *equipo) {
    FILE *csv = fopen(nombre_csv, "w");
    if (csv == NULL) {
        registrar_log("ERROR: No se pudo exportar a formato CSV.");
        return;
    }

    fprintf(csv, "ID,Hostname,CPU,RAM_Total(MB),RAM_Libre(MB),Disco_Libre(MB),GPU,Placa,Uso_RAM(%%),Uso_CPU(%%),Procesos,Categoria,Timestamp\n");
    fprintf(csv, "%u,%s,%s,%llu,%llu,%llu,%s,%s,%.2f,%.2f,%u,%u,%s\n",
            equipo->id_equipo, equipo->nombre_equip, equipo->cpu_modelo,
            (unsigned long long)equipo->ram_total,
            (unsigned long long)equipo->ram_libre,
            (unsigned long long)equipo->disco_libre,
            equipo->gpu_modelo, equipo->placa_modelo,
            equipo->uso_ram_pct, equipo->uso_cpu_pct,
            equipo->procesos, equipo->categoria, equipo->timestamp);

    fclose(csv);
    registrar_log("OK: Evidencia adicional exportada a CSV.");
}

void agregar_bloque_monitoreo(const char *nombre_archivo, double uso_ram_pct,
                              double uso_cpu_pct, uint64_t disco_libre) {
    BloqueMonitoreo bloque;
    time_t t;
    struct tm *tm_info;

    memset(&bloque, 0, sizeof(bloque));
    memcpy(bloque.tag, "MON1", 4);
    bloque.uso_ram_pct = uso_ram_pct;
    bloque.uso_cpu_pct = uso_cpu_pct;
    bloque.disco_libre = disco_libre;

    t = time(NULL);
    tm_info = localtime(&t);
    strftime(bloque.timestamp, sizeof(bloque.timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

    (void)escribir_bloque(nombre_archivo, &bloque, sizeof(bloque),
                          "OK: Bloque de monitoreo anexado al reporte.",
                          "ERROR: No se pudo anexar el bloque de monitoreo.");
}

int leer_bloque_monitoreo(const char *nombre_archivo, BloqueMonitoreo *bloque) {
    return buscar_bloque(nombre_archivo, "MON1", bloque, sizeof(*bloque));
}

void agregar_bloque_estadisticas(const char *nombre_archivo,
                                 double promedio_ram_libre,
                                 double promedio_disco_libre,
                                 uint32_t categoria_final,
                                 const char *resumen) {
    BloqueEstadisticas bloque;

    memset(&bloque, 0, sizeof(bloque));
    memcpy(bloque.tag, "STA1", 4);
    bloque.promedio_ram_libre = promedio_ram_libre;
    bloque.promedio_disco_libre = promedio_disco_libre;
    bloque.categoria_final = categoria_final;
    techscan_copy_text(bloque.resumen, sizeof(bloque.resumen), resumen);

    (void)escribir_bloque(nombre_archivo, &bloque, sizeof(bloque),
                          "OK: Bloque de estadisticas anexado al reporte.",
                          "ERROR: No se pudo anexar el bloque de estadisticas.");
}

int agregar_bloque_hardware(const char *nombre_archivo,
                            const BloqueHardwareAvanzado *hw) {
    return escribir_bloque(nombre_archivo, hw, sizeof(*hw),
                           "OK: Bloque de hardware avanzado anexado.",
                           "ERROR: No se pudo anexar hardware avanzado.");
}

int leer_bloque_hardware(const char *nombre_archivo,
                         BloqueHardwareAvanzado *hw) {
    return buscar_bloque(nombre_archivo, "HWX1", hw, sizeof(*hw));
}

int agregar_bloque_procesos(const char *nombre_archivo,
                            const BloqueProcesos *procesos) {
    return escribir_bloque(nombre_archivo, procesos, sizeof(*procesos),
                           "OK: Bloque de procesos anexado.",
                           "ERROR: No se pudo anexar procesos.");
}

int leer_bloque_procesos(const char *nombre_archivo, BloqueProcesos *procesos) {
    return buscar_bloque(nombre_archivo, "PRC1", procesos, sizeof(*procesos));
}

int agregar_bloque_analisis_extendido(const char *nombre_archivo,
                                      const BloqueAnalisisExtendido *analisis) {
    return escribir_bloque(nombre_archivo, analisis, sizeof(*analisis),
                           "OK: Bloque de analisis extendido anexado.",
                           "ERROR: No se pudo anexar analisis extendido.");
}
