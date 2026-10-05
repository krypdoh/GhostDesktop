@echo off
setlocal

cd /d "%~dp0"

set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set "BASE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
set "SCRIPT=ghostdesktop-v0.9.6.ahk"
set "OUTPUT=ghostdesktop-v0.9.6.exe"
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
rem /compress 0: UPX/MPRESS-packed exes trigger many AV heuristics.
"%AHK2EXE%" /in "%SCRIPT%" /out "%OUTPUT%" /base "%BASE%" /icon "%ICON%" /compress 0 /silent verbose

if not exist "%OUTPUT%" (
    echo BUILD FAILED.
    exit /b 1
)

echo Build complete: %OUTPUT%

set "SIGNTOOL=C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
set "SIGN_THUMBPRINT=B5118570A93600AD1094E1CD06FF1A95E6BCF933"

if not exist "%SIGNTOOL%" (
    echo ERROR: signtool not found at "%SIGNTOOL%".
    exit /b 1
)

echo Signing %OUTPUT% ...
"%SIGNTOOL%" sign /sha1 %SIGN_THUMBPRINT% /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com /d "GhostDesktop" "%OUTPUT%"
if errorlevel 1 (
    echo SIGNING FAILED.
    exit /b 1
)

echo Signed: %OUTPUT%
endlocal
