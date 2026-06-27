// ==========================================
// TECHSCAN64 - Lanzador del Monitor Grafico
// Invoca bin\monitor_gui.exe (FASM/RadASM)
// y espera a que el usuario lo cierre.
// ==========================================

#include <windows.h>

void monitoreo_local(void) {
    STARTUPINFOA        si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    // Buscar el ejecutable relativo al directorio de trabajo
    if (!CreateProcessA(
            "bin\\monitor_gui.exe",   // ejecutable
            NULL,                      // sin argumentos adicionales
            NULL, NULL,                // atributos de proceso/hilo
            FALSE,                     // no heredar handles
            0,                         // flags
            NULL,                      // entorno del padre
            NULL,                      // directorio de trabajo del padre
            &si, &pi)) {

        MessageBoxA(NULL,
            "No se encontro bin\\monitor_gui.exe.\n"
            "Verifique que el proyecto fue compilado correctamente.",
            "TechScan64 - Error",
            MB_ICONERROR | MB_OK);
        return;
    }

    // Esperar a que el usuario cierre la ventana de monitoreo
    WaitForSingleObject(pi.hProcess, INFINITE);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
}
