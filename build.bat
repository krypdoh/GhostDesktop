@echo off
setlocal

cd /d "%~dp0"

set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set "BASE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
set "SCRIPT=ghostdesktop-v0.9.5.ahk"
set "OUTPUT=ghostdesktop-v0.9.5.exe"
set "ICON=ghostdesktop.ico"

if not exist "%AHK2EXE%" (
    echo ERROR: Ahk2Exe not found at "%AHK2EXE%".
    exit /b 1
)
if not exist "%BASE%" (
    echo ERROR: AutoHotkey v2 base file not found at "%BASE%".
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo ERROR: Script not found: "%SCRIPT%".
    exit /b 1
)

echo Building %OUTPUT% ...
"%AHK2EXE%" /in "%SCRIPT%" /out "%OUTPUT%" /base "%BASE%" /icon "%ICON%" /silent verbose

if not exist "%OUTPUT%" (
    echo BUILD FAILED.
    exit /b 1
)

echo Build complete: %OUTPUT%
endlocal
