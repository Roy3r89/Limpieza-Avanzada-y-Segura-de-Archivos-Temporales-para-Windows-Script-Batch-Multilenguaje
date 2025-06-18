@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: Limpieza Avanzada de Archivos Temporales - Versión Documentada
:: Descripción: Este script limpia archivos temporales y otros 
:: caches comunes, genera reportes y solicita confirmación 
:: antes de cada acción para evitar borrados accidentales.
:: ============================================================

:: --- Variables Globales ---
set "ScriptVersion=5.0"
set "LogFolder=%USERPROFILE%\Documents\LimpiezaLogs"
set "TempDetail=%TEMP%\detalle_limpieza.tmp"
set "TempError=%TEMP%\errores_limpieza.tmp"
set "TotalFilesDeleted=0"
set "TotalSizeFreed=0"
set "ErrorCount=0"

:: Limpiar logs temporales previos
if exist "%TempDetail%" del "%TempDetail%"
if exist "%TempError%" del "%TempError%"

:: Crear carpeta para logs si no existe
if not exist "%LogFolder%" mkdir "%LogFolder%"

echo ===========================================
echo     Limpieza Avanzada de Archivos Temporales
echo          Versión %ScriptVersion%
echo ===========================================
echo.

:: Verificar si tiene permisos de administrador
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [ERROR] Debes ejecutar este script como ADMINISTRADOR.
    echo Cierra esta ventana y ejecútalo como administrador.
    pause
    exit /b 1
) else (
    echo [OK] Permisos administrativos detectados.
)

echo.
echo Se limpiarán las siguientes carpetas temporales por defecto:
echo  - %%TEMP%%
echo  - %%LOCALAPPDATA%%\Temp
echo.

:: Preguntar si desea cambiar las carpetas a limpiar
set /p "ChangeFolders=¿Quieres modificar las carpetas a limpiar? (S/N): "
if /i "%ChangeFolders%"=="S" (
    echo Ingresa las carpetas separadas por comas (ejemplo: C:\Temp,%TEMP%,D:\OtrosTemp)
    set /p "FoldersInput=Carpetas: "
    set "SelectedFolders=%FoldersInput%"
) else (
    set "SelectedFolders=%TEMP%,%LOCALAPPDATA%\Temp"
)

:: Confirmar cada carpeta y eliminar si existe
for %%F in (%SelectedFolders%) do (
    if exist "%%F" (
        set /p "ConfirmFolder=¿Limpiar carpeta %%F? (S/N): "
        if /i "!ConfirmFolder!"=="S" (
            call :CleanFolder "%%F"
        ) else (
            echo [INFO] Carpeta %%F omitida por el usuario.
        )
    ) else (
        echo [WARN] Carpeta %%F no existe o no accesible.
    )
)

:: Otras limpiezas adicionales, preguntar antes de ejecutar cada una

echo.
set /p "CleanLogs=¿Eliminar logs antiguos del sistema (más de 30 días)? (S/N): "
if /i "%CleanLogs%"=="S" (
    call :CleanOldLogs
) else (
    echo [INFO] Limpieza de logs omitida.
)

echo.
set /p "CleanNuGet=¿Limpiar cache de NuGet? (S/N): "
if /i "%CleanNuGet%"=="S" (
    call :CleanNuGetCache
) else (
    echo [INFO] Limpieza de NuGet omitida.
)

echo.
set /p "CleanBrowser=¿Limpiar caché de navegadores Chrome y Firefox? (S/N): "
if /i "%CleanBrowser%"=="S" (
    call :CleanBrowserCache
) else (
    echo [INFO] Limpieza de caché de navegadores omitida.
)

echo.
set /p "CleanStore=¿Limpiar caché de Microsoft Store? (S/N): "
if /i "%CleanStore%"=="S" (
    call :CleanWindowsStoreCache
) else (
    echo [INFO] Limpieza de Microsoft Store omitida.
)

echo.
set /p "CleanDISM=¿Ejecutar limpieza avanzada con DISM? (S/N): "
if /i "%CleanDISM%"=="S" (
    call :RunDISMCleanup
) else (
    echo [INFO] Limpieza DISM omitida.
)

:: Mostrar resumen y generar reporte

echo.
echo =================================
echo       Resumen de limpieza
echo =================================
echo Archivos eliminados: %TotalFilesDeleted%
echo Espacio liberado (aprox.): %TotalSizeFreed% bytes
if %ErrorCount% NEQ 0 (
    echo Errores ocurridos: %ErrorCount% (revisar log)
) else (
    echo No se detectaron errores.
)
echo.

call :GenerateReport

echo Limpieza finalizada.
pause
exit /b 0

:: =================================================
:: FUNCIONES
:: =================================================

:CleanFolder
:: Limpia los archivos de la carpeta pasada como argumento
setlocal enabledelayedexpansion
set "folder=%~1"
set /a deletedFiles=0
set /a sizeFreed=0

echo Limpiando carpeta: %folder%
for /r "%folder%" %%A in (*) do (
    del /f /q "%%A" >nul 2>&1
    if !errorlevel! EQU 0 (
        set /a deletedFiles+=1
        for %%S in ("%%A") do set /a sizeFreed+=%%~zS
        echo [DEL] %%A >> "%TempDetail%"
    ) else (
        echo [ERR] No se pudo eliminar %%A >> "%TempError%"
        set /a ErrorCount+=1
    )
)
endlocal & (
    set /a TotalFilesDeleted+=deletedFiles
    set /a TotalSizeFreed+=sizeFreed
)
echo [OK] Carpeta %folder% limpiada: !deletedFiles! archivos borrados.
exit /b 0

:CleanOldLogs
echo Eliminando logs antiguos en %WINDIR%\Logs (más de 30 días)...
forfiles /p "%WINDIR%\Logs" /s /m *.log /d -30 /c "cmd /c del @path" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se pudieron eliminar algunos logs. >> "%TempError%"
    set /a ErrorCount+=1
) else (
    echo [OK] Logs antiguos eliminados. >> "%TempDetail%"
)
exit /b 0

:CleanNuGetCache
echo Limpiando cache de NuGet en %USERPROFILE%\.nuget\packages ...
set "NugetCache=%USERPROFILE%\.nuget\packages"
if exist "%NugetCache%" (
    for /d %%i in ("%NugetCache%\*") do rmdir /q /s "%%i" >nul 2>&1
    echo [OK] Cache de NuGet eliminado. >> "%TempDetail%"
) else (
    echo [INFO] No se encontró cache de NuGet. >> "%TempDetail%"
)
exit /b 0

:CleanBrowserCache
echo Limpiando caché de navegadores Chrome y Firefox...
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
    rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache"
    echo [OK] Caché de Chrome eliminado. >> "%TempDetail%"
) else (
    echo [INFO] Caché de Chrome no encontrado. >> "%TempDetail%"
)
if exist "%APPDATA%\Mozilla\Firefox\Profiles" (
    for /d %%d in ("%APPDATA%\Mozilla\Firefox\Profiles\*") do (
        rmdir /s /q "%%d\cache2" >nul 2>&1
        echo [OK] Caché de Firefox eliminado para perfil %%~nd >> "%TempDetail%"
    )
) else (
    echo [INFO] Perfiles de Firefox no encontrados. >> "%TempDetail%"
)
exit /b 0

:CleanWindowsStoreCache
echo Limpiando caché de Microsoft Store...
wsreset.exe >nul 2>&1
echo [OK] Caché de Microsoft Store limpiado. >> "%TempDetail%"
exit /b 0

:RunDISMCleanup
echo Ejecutando limpieza avanzada con DISM...
dism /online /cleanup-image /startcomponentcleanup /quiet /norestart
if errorlevel 1 (
    echo [ERROR] Limpieza DISM fallida. >> "%TempError%"
    set /a ErrorCount+=1
) else (
    echo [OK] Limpieza DISM completada. >> "%TempDetail%"
)
exit /b 0

:GenerateReport
set "ReportDate=%date:/=-%"
set "ReportTime=%time::=-%"
set "ReportTime=%ReportTime: =0%"
set "LogFileName=%LogFolder%\Limpieza_%ReportDate%_%ReportTime%.log"

(
    echo ========================================
    echo     REPORTE DE LIMPIEZA DE SISTEMA
    echo ========================================
    echo Fecha: %date%  Hora: %time%
    echo Usuario: %USERNAME%
    echo Archivos eliminados: %TotalFilesDeleted%
    echo Espacio liberado (aprox.): %TotalSizeFreed% bytes
    echo Errores: %ErrorCount%
    echo ----------------------------------------
    echo DETALLE DE OPERACIONES:
    echo ----------------------------------------
    type "%TempDetail%"
    if %ErrorCount% NEQ 0 (
        echo ----------------------------------------
        echo ERRORES DETECTADOS:
        echo ----------------------------------------
        type "%TempError%"
    )
) > "%LogFileName%"

echo Reporte guardado en: %LogFileName%
exit /b 0
