@echo off
setlocal EnableExtensions

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
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
echo [1/3] Enabling WinRE (if disabled)...
reagentc /enable
echo.

echo [2/3] Triggering MDM_RemoteWipe as SYSTEM...
schtasks /Create /TN "CleanWindowsReset" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABuAHMAIAA9ACAAIgByAG8AbwB0AFwAYwBpAG0AdgAyAFwAbQBkAG0AXABkAG0AbQBhAHAAIgAKACQAaQBuAHMAdAAgAD0AIABHAGUAdAAtAEMAaQBtAEkAbgBzAHQAYQBuAGMAZQAgAC0ATgBhAG0AZQBzAHAAYQBjAGUAIAAkAG4AcwAgAC0AQwBsAGEAcwBzAE4AYQBtAGUAIAAiAE0ARABNAF8AUgBlAG0AbwB0AGUAVwBpAHAAZQAiACAALQBGAGkAbAB0AGUAcgAgACIAUABhAHIAZQBuAHQASQBEAD0AJwAuAC8AVgBlAG4AZABvAHIALwBNAFMARgBUACcAIABhAG4AZAAgAEkAbgBzAHQAYQBuAGMAZQBJAEQAPQAnAFIAZQBtAG8AdABlAFcAaQBwAGUAJwAiACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlAAoAaQBmACAAKAAkAGkAbgBzAHQAKQAgAHsACgAgACAAIAAgACQAcwBlAHMAcwBpAG8AbgAgAD0AIABOAGUAdwAtAEMAaQBtAFMAZQBzAHMAaQBvAG4ACgAgACAAIAAgACQAcABhAHIAYQBtAHMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAE0AaQBjAHIAbwBzAG8AZgB0AC4ATQBhAG4AYQBnAGUAbQBlAG4AdAAuAEkAbgBmAHIAYQBzAHQAcgB1AGMAdAB1AHIAZQAuAEMAaQBtAE0AZQB0AGgAbwBkAFAAYQByAGEAbQBlAHQAZQByAHMAQwBvAGwAbABlAGMAdABpAG8AbgAKACAAIAAgACAAJABwACAAPQAgAFsATQBpAGMAcgBvAHMAbwBmAHQALgBNAGEAbgBhAGcAZQBtAGUAbgB0AC4ASQBuAGYAcgBhAHMAdAByAHUAYwB0AHUAcgBlAC4AQwBpAG0ATQBlAHQAaABvAGQAUABhAHIAYQBtAGUAdABlAHIAXQA6ADoAQwByAGUAYQB0AGUAKAAiAHAAYQByAGEAbQAiACwAIAAiACIALAAgACIAUwB0AHIAaQBuAGcAIgAsACAAIgBJAG4AIgApAAoAIAAgACAAIAAkAHAAYQByAGEAbQBzAC4AQQBkAGQAKAAkAHAAKQAKACAAIAAgACAAJABzAGUAcwBzAGkAbwBuAC4ASQBuAHYAbwBrAGUATQBlAHQAaABvAGQAKAAkAG4AcwAsACAAJABpAG4AcwB0ACwAIAAiAGQAbwBXAGkAcABlAE0AZQB0AGgAbwBkACIALAAgACQAcABhAHIAYQBtAHMAKQAgAHwAIABPAHUAdAAtAE4AdQBsAGwACgB9AAoA" /SC ONCE /ST 00:00 /RU SYSTEM /F
if %errorlevel% equ 0 (
    schtasks /Run /TN "CleanWindowsReset"
    echo Waiting 10 seconds for Windows to start rebooting...
    timeout /t 10 /nobreak
    schtasks /Delete /TN "CleanWindowsReset" /F >nul 2>&1
) else (
    echo [!] Failed to create SYSTEM task.
)

echo.
echo [3/3] If PC did not reboot automatically, trying built-in reset tools...
if exist "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" (
    echo Launching SystemSettingsAdminFlows.exe FeaturedResetPC...
    start "" "%SystemRoot%\System32\SystemSettingsAdminFlows.exe" FeaturedResetPC
)
if exist "%SystemRoot%\System32\systemreset.exe" (
    echo Launching systemreset.exe -factoryreset...
    start "" "%SystemRoot%\System32\systemreset.exe" -factoryreset
)

echo.
echo Opening Settings - Recovery...
start "" "ms-settings:recovery"
echo.
set /p "REBOOT_RE=Type Y and press Enter to reboot straight into Recovery Menu (Troubleshoot - Reset this PC): "
if /i "%REBOOT_RE%"=="Y" (
    shutdown /r /o /f /t 3
)
pause
exit /b 0
