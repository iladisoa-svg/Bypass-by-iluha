@echo off
chcp 65001 >nul
setlocal EnableExtensions

:: Auto-elevate to Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title Windows Clean Factory Reset
cls
echo ============================================================================
echo   ПОЛНЫЙ СБРОС WINDOWS ДО ПЕРВОНАЧАЛЬНОГО СОСТОЯНИЯ (ЧИСТАЯ УСТАНОВКА)
echo ============================================================================
echo.
echo   ВНИМАНИЕ! Это действие безвозвратно удалит:
echo     - Все личные файлы, документы, загрузки и рабочий стол
echo     - Все установленные программы, игры, драйверы и настройки
echo     - Все учётные записи пользователей
echo.
echo   Сама Windows останется на диске и запустится с экрана первоначальной
echo   настройки (как сразу после покупки/установки).
echo.
echo ============================================================================
echo.
set /p "CONFIRM=Для запуска сброса введите RESET и нажмите Enter (или закройте окно для отмены): "
if /i not "%CONFIRM%"=="RESET" (
    echo.
    echo Отменено пользователем. Никаких изменений не внесено.
    pause
    exit /b 0
)

echo.
echo [1/3] Проверка и включение среды восстановления Windows (WinRE)...
reagentc /enable >nul 2>&1
reagentc /info | findstr /i "Enabled" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Внимание: WinRE не удалось автоматически включить (возможно, отсутствует Winre.wim).
    echo     Попытка запуска стандартного мастера сброса...
)

echo [2/3] Подготовка автоматического сброса через MDM_RemoteWipe...
set "PS_SCRIPT=%TEMP%\win_clean_wipe.ps1"
(
    echo $namespaceName = "root\cimv2\mdm\dmmap"
    echo $className = "MDM_RemoteWipe"
    echo $methodName = "doWipeMethod"
    echo $session = New-CimSession
    echo $params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
    echo $param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In"^)
    echo $params.Add($param^)
    echo try {
    echo     $instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
    echo     if ($instance^) {
    echo         $session.InvokeMethod($namespaceName, $instance, $methodName, $params^)
    echo     }
    echo } catch {
    echo     exit 1
    echo }
) > "%PS_SCRIPT%"

echo [3/3] Запуск сброса от имени SYSTEM...
schtasks /Create /TN "CleanWindowsReset" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%PS_SCRIPT%\"" /SC ONCE /ST 00:00 /RU SYSTEM /F >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /Run /TN "CleanWindowsReset" >nul 2>&1
    timeout /t 8 /nobreak >nul
    schtasks /Delete /TN "CleanWindowsReset" /F >nul 2>&1
)

if exist "%PS_SCRIPT%" del /f /q "%PS_SCRIPT%" >nul 2>&1

:: Fallback if MDM_RemoteWipe did not initiate an automatic reboot
echo.
echo Если автоматический перезапуск не начался, запускаем встроенный мастер сброса...
if exist "%SystemRoot%\System32\systemreset.exe" (
    start "" "%SystemRoot%\System32\systemreset.exe" -factoryreset
    exit /b 0
)

if exist "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" (
    start "" "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" FeaturedResetPC
    exit /b 0
)

start "" "ms-settings:recovery"
echo Открыт раздел Параметры -^> Восстановление. Нажмите "Вернуть компьютер в исходное состояние" -^> "Удалить всё".
pause
exit /b 0
