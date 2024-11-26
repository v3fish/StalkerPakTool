@echo off

echo Script made by v3fish
echo Credits: repak.exe by github.com/trumank
echo.

cd /d "%~dp0"

if not exist "repak.exe" (
    echo repak.exe not found. Download from: https://github.com/trumank/repak/releases
    echo Extract repak.exe from repak_cli-x86_64-pc-windows-msvc.zip to this directory.
    pause
    exit /b
)

if "%~1"=="" (
    echo Please drag and drop a .pak file or folder onto this script.
    pause
    exit /b
)

set "input_path=%~f1"

if exist "%input_path%" (
    if /i "%~x1"==".pak" (
        echo Unpacking "%input_path%"...
        repak.exe -a 0x33A604DF49A07FFD4A4C919962161F5C35A134D37EFA98DB37A34F6450D7D386 unpack "%input_path%" || (
            echo Error unpacking file.
            pause
            exit /b
        )
        exit /b
    )
)

if exist "%input_path%" (
    if exist "%input_path%\*" (
        echo Packing "%input_path%"...
        repak.exe pack "%input_path%" || (
            echo Error packing folder.
            pause
            exit /b
        )
        exit /b
    )
)

echo Invalid file or folder.
pause
exit /b