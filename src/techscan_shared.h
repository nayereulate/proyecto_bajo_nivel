#ifndef TECHSCAN_SHARED_H
#define TECHSCAN_SHARED_H

#include <stddef.h>
#include <stdint.h>

#define TECHSCAN_REP_SIGNATURE "SCAN"
#define TECHSCAN_REP_VERSION   1

#define TECHSCAN_MAX_TOP_PROC  5

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

typedef struct {
    char firma[4];
    uint32_t version;
    char fecha_creacion[12];
    uint32_t cant_registros;
} ReporteHeader;

typedef struct {
    char tag[4];
    double uso_ram_pct;
    double uso_cpu_pct;
    uint64_t disco_libre;
    char timestamp[24];
} BloqueMonitoreo;

typedef struct {
    char tag[4];
    double promedio_ram_libre;
    double promedio_disco_libre;
    uint32_t categoria_final;
    char resumen[64];
} BloqueEstadisticas;

typedef struct {
    char tag[4];                 /* "HWX1" */
    char gpu_nombre[96];
    char placa_fabricante[48];
    char placa_modelo[48];
    char placa_serial[48];
    char bios_fabricante[48];
    char bios_version[64];
    char bios_fecha[24];
    char cpu_generacion[32];
    char cpu_clasificacion[16];  /* ANTIGUO, VIGENTE, MODERNO */
    uint32_t nucleos_fisicos;
    uint32_t nucleos_logicos;
} BloqueHardwareAvanzado;

typedef struct {
    char nombre[32];
    uint64_t memoria_mb;
} ProcesoTop;

typedef struct {
    char tag[4];                 /* "PRC1" */
    uint32_t total_procesos;
    char presion_memoria[16];    /* BAJA, MEDIA, ALTA, CRITICA */
    ProcesoTop top[TECHSCAN_MAX_TOP_PROC];
} BloqueProcesos;

typedef struct {
    char tag[4];                 /* "ANX1" */
    double promedio_ram_total;
    double promedio_uso_cpu;
    double promedio_procesos;
    uint32_t porcentaje_cat[4];
    char laboratorio[32];
} BloqueAnalisisExtendido;

#pragma pack(pop)

void techscan_copy_text(char *dst, size_t dst_sz, const char *src);
const char *techscan_nombre_categoria(uint32_t cat);
uint32_t techscan_clasificar_equipo(uint64_t ram_total, uint64_t ram_libre);
const char *techscan_clasificar_presion_memoria(uint64_t ram_total,
                                                uint64_t ram_libre,
                                                uint32_t procesos);
const char *techscan_clasificar_cpu(const char *cpu_modelo,
                                    char *generacion,
                                    size_t generacion_sz);
void techscan_barra_ascii(double pct, char *dst, size_t dst_sz);

int techscan_crear_directorio_si_falta(const char *ruta);
int techscan_obtener_gpu(char *destino, size_t tam);
void techscan_obtener_bios_y_placa(BloqueHardwareAvanzado *hw);
uint32_t techscan_contar_nucleos_fisicos(void);
uint32_t techscan_contar_procesos_top(BloqueProcesos *procesos,
                                      uint64_t ram_total,
                                      uint64_t ram_libre);
double techscan_obtener_uso_cpu_instantaneo(void);

int guardar_reporte(const char *nombre_archivo, const EquipoInfo *equipo);
int leer_reporte(const char *nombre_archivo, EquipoInfo *equipo);
void registrar_log(const char *mensaje);
void exportar_csv(const char *nombre_csv, const EquipoInfo *equipo);
void agregar_bloque_monitoreo(const char *nombre_archivo, double uso_ram_pct,
                              double uso_cpu_pct, uint64_t disco_libre);
int leer_bloque_monitoreo(const char *nombre_archivo, BloqueMonitoreo *bloque);
void agregar_bloque_estadisticas(const char *nombre_archivo,
                                 double promedio_ram_libre,
                                 double promedio_disco_libre,
                                 uint32_t categoria_final,
                                 const char *resumen);
int agregar_bloque_hardware(const char *nombre_archivo,
                            const BloqueHardwareAvanzado *hw);
int leer_bloque_hardware(const char *nombre_archivo,
                         BloqueHardwareAvanzado *hw);
int agregar_bloque_procesos(const char *nombre_archivo,
                            const BloqueProcesos *procesos);
int leer_bloque_procesos(const char *nombre_archivo, BloqueProcesos *procesos);
int agregar_bloque_analisis_extendido(const char *nombre_archivo,
                                      const BloqueAnalisisExtendido *analisis);

#endif
