@echo off
setlocal EnableExtensions

:: Check Administrator rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    if %errorlevel% neq 0 (
        echo Failed to elevate. Right-click this file and choose "Run as administrator".
        pause
    )
    exit /b
)

title Windows 11 LTSC Clean Reset
cls
echo ============================================================================
echo   WINDOWS 11 LTSC - FULL FACTORY RESET (CLEAN OUT-OF-THE-BOX STATE)
echo ============================================================================
echo.
echo   WARNING! This will permanently delete:
echo     - All personal files, downloads, desktop, and user accounts
echo     - All installed programs, games, drivers, and settings
echo.
echo   Windows itself will stay on the PC and boot to initial setup (OOBE).
echo ============================================================================
echo.
echo [Info] Checking Windows Recovery Environment (WinRE)...
reagentc /info
echo.
set /p "CONFIRM=Type RESET and press Enter to continue (or close window to cancel): "
if /i not "%CONFIRM%"=="RESET" (
    echo Cancelled by user.
    pause
    exit /b 0
)

echo.
echo [1/4] Enabling WinRE (if disabled)...
reagentc /enable
echo.

echo [2/4] Preparing MDM_RemoteWipe PowerShell script...
set "PS_SCRIPT=%TEMP%\win_clean_wipe.ps1"
echo $namespaceName = "root\cimv2\mdm\dmmap" > "%PS_SCRIPT%"
echo $className = "MDM_RemoteWipe" >> "%PS_SCRIPT%"
echo $methodName = "doWipeMethod" >> "%PS_SCRIPT%"
echo $session = New-CimSession >> "%PS_SCRIPT%"
echo $params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection >> "%PS_SCRIPT%"
echo $param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In") >> "%PS_SCRIPT%"
echo $params.Add($param) >> "%PS_SCRIPT%"
echo $instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'" >> "%PS_SCRIPT%"
echo if ($instance) { $res = $session.InvokeMethod($namespaceName, $instance, $methodName, $params); $res | Out-File "$env:TEMP\wipe_log.txt" } else { "NO_INSTANCE" | Out-File "$env:TEMP\wipe_log.txt" } >> "%PS_SCRIPT%"

echo [3/4] Running wipe as SYSTEM...
schtasks /Create /TN "CleanWindowsReset" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%PS_SCRIPT%\"" /SC ONCE /ST 00:00 /RU SYSTEM /F
if %errorlevel% equ 0 (
    schtasks /Run /TN "CleanWindowsReset"
    echo Waiting 10 seconds for Windows to start rebooting...
    timeout /t 10 /nobreak
    schtasks /Delete /TN "CleanWindowsReset" /F >nul 2>&1
) else (
    echo [!] Failed to create SYSTEM task.
)

if exist "%TEMP%\wipe_log.txt" (
    echo [Log]:
    type "%TEMP%\wipe_log.txt"
    del /f /q "%TEMP%\wipe_log.txt" >nul 2>&1
)
if exist "%PS_SCRIPT%" del /f /q "%PS_SCRIPT%" >nul 2>&1

echo.
echo [4/4] If PC did not reboot automatically, trying built-in reset tools...
if exist "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" (
    echo Launching SystemSettingsAdminFlows.exe FeaturedResetPC...
    start "" "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" FeaturedResetPC
)
if exist "%SystemRoot%\System32\systemreset.exe" (
    echo Launching systemreset.exe -factoryreset...
    start "" "%SystemRoot%\System32\systemreset.exe" -factoryreset
)

echo.
echo Opening Settings -> Recovery (ms-settings:recovery)...
start "" "ms-settings:recovery"
echo.
set /p "REBOOT_RE=If nothing opened, type Y to reboot straight into Recovery Menu (Troubleshoot -> Reset this PC): "
if /i "%REBOOT_RE%"=="Y" (
    shutdown /r /o /f /t 3
)
pause
exit /b 0
