@echo off
:: Change to the folder this .bat file lives in
cd /d "%~dp0"

echo Current folder: %CD%
echo.
echo Files here:
dir /b
echo.

:: Check project file exists
if not exist "default.project.json" (
    echo ERROR: default.project.json not found in this folder!
    echo Make sure START_ROJO.bat and default.project.json are in the same folder.
    pause
    exit
)

echo Found default.project.json - good!
echo.

:: Find rojo
set ROJO_EXE=

where rojo >nul 2>&1
if %errorlevel%==0 (set ROJO_EXE=rojo && goto :found)
if exist "%~dp0rojo.exe" (set ROJO_EXE="%~dp0rojo.exe" && goto :found)
if exist "%USERPROFILE%\Downloads\rojo.exe" (set ROJO_EXE="%USERPROFILE%\Downloads\rojo.exe" && goto :found)

echo ERROR: rojo.exe not found!
echo Put rojo.exe in the same folder as this .bat file.
pause
exit

:found
echo Found Rojo: %ROJO_EXE%
echo.
echo ================================
echo  Rojo is running!
echo  Go to Studio: Plugins - Rojo - Connect
echo  Keep this window open!
echo ================================
echo.
%ROJO_EXE% serve default.project.json
echo.
echo Rojo stopped. Press any key to close.
pause
