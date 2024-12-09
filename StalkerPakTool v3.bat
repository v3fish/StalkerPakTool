@echo off
cd /d "%~dp0"
setlocal EnableDelayedExpansion

set "VERSION=3.1"
set "AES_KEY=0x33A604DF49A07FFD4A4C919962161F5C35A134D37EFA98DB37A34F6450D7D386"

:: Set your game directory here if you don't want to use the INI file
:: Example: "CUSTOM_GAME_DIR=D:\SteamLibrary\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl"
set "CUSTOM_GAME_DIR=D:\SteamLibrary\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl"

set "REPAK_PATH=%~dp0repak\repak.exe"

if not exist "!REPAK_PATH!" (
    echo Error: repak.exe not found in repak folder. Please ensure it's properly installed.
    pause
    exit /b 1
)

:: Check if files/folders were dragged onto script
if not "%~1"=="" (
    set "HAS_ERROR=0"
    
    :: Process all dragged items
    for %%i in (%*) do (
        set "input_path=%%~fi"
        if /i "%%~xi"==".pak" (
            :: Remove existing folder before unpacking
            if exist "%%~dpni" (
                rmdir /s /q "%%~dpni"
            )
            "!REPAK_PATH!" -a !AES_KEY! unpack "!input_path!" >nul 2>&1 || (
                echo Error unpacking file: !input_path!
                set "HAS_ERROR=1"
            )
        ) else if exist "!input_path!\*" (
            "!REPAK_PATH!" pack "!input_path!" >nul 2>&1 || (
                echo Error packing folder: !input_path!
                set "HAS_ERROR=1"
            )
        ) else (
            echo Invalid file or folder: !input_path!
            set "HAS_ERROR=1"
        )
    )
    if !HAS_ERROR! equ 1 (
        pause
    )
    exit /b !HAS_ERROR!
)

echo StalkerPakTool v%VERSION% by v3fish
echo repak by Truman Kilen (github.com/trumank/repak) - MIT and Apache-2.0 licensed
echo.
echo Ensure the 'repak' folder exists in the same directory as this script and contains repak.exe
echo.
echo To pack/unpack files, drag and drop multiple .pak files or folders onto this script.
echo.
echo To check for mod conflicts, type 'y' or 'yes'.
echo.
set /p "CHECK_CONFLICTS=Check for mod conflicts? (y/n): "
if /i "!CHECK_CONFLICTS!"=="y" goto start_conflict_check
if /i "!CHECK_CONFLICTS!"=="yes" goto start_conflict_check
exit /b

:start_conflict_check
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%stalker2_location.ini"
set "TEMP_DIR=!SCRIPT_DIR!temp_mod_analysis"
set "FILE_LIST=!TEMP_DIR!\filelist.txt"

:check_game_dir
:: Check for custom directory first
if not "!CUSTOM_GAME_DIR!"=="" (
    set "GAME_DIR=!CUSTOM_GAME_DIR!"
    if not exist "!GAME_DIR!\Stalker2\Content\Paks" (
        echo Invalid path in CUSTOM_GAME_DIR: !GAME_DIR!
        echo Please check the path in the batch file.
        if exist "!CONFIG_FILE!" (
            echo.
            echo Found existing INI configuration.
            set /p "USE_INI=Use INI settings instead? (y/n): "
            if /i "!USE_INI!"=="y" (
                for /f "tokens=1* delims==" %%a in ('type "!CONFIG_FILE!"') do (
                    if /i "%%a"=="gamedir" set "GAME_DIR=%%b"
                )
                goto verify_path
            )
        )
        goto show_examples
    )
) else if exist "!CONFIG_FILE!" (
    for /f "tokens=1* delims==" %%a in ('type "!CONFIG_FILE!"') do (
        if /i "%%a"=="gamedir" set "GAME_DIR=%%b"
    )
)

:verify_path
if not exist "!GAME_DIR!\Stalker2\Content\Paks" goto show_examples
goto continue_script

:show_examples
echo Invalid Stalker 2 directory: !GAME_DIR!
echo.
echo Example Steam Location:
echo D:\SteamLibrary\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl
echo Example Gamepass Location:
echo C:\XboxGames\S.T.A.L.K.E.R. 2- Heart of Chornobyl (Windows^)\Content
echo.
echo Enter the correct Stalker 2 folder location:
set /p "GAME_DIR="
echo gamedir=!GAME_DIR!>"!CONFIG_FILE!"
goto verify_path

:continue_script
set "MODS_DIR=!GAME_DIR!\Stalker2\Content\Paks\~mods"

if not exist "!MODS_DIR!" (
    echo ~mods folder not found. Please create !MODS_DIR! and add your mods, then run this script again.
    pause
    exit /b
)

set "MOD_COUNT=0"
for %%f in ("!MODS_DIR!\*.pak") do set /a "MOD_COUNT+=1"
for /d %%d in ("!MODS_DIR!\*") do (
    for %%f in ("%%d\*.pak") do set /a "MOD_COUNT+=1"
)

if !MOD_COUNT! equ 0 (
    echo No mods detected in !MODS_DIR!
    echo Add your mods and try again.
    pause
    exit /b
)

if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!" 2>nul
mkdir "!TEMP_DIR!" 2>nul

echo Processing mods...
echo.

type nul > "!FILE_LIST!"

:: For root mods
for %%f in ("!MODS_DIR!\*.pak") do (
    echo [%%~nxf]
    "!REPAK_PATH!" unpack "%%f" -o "!TEMP_DIR!\%%~nf" >nul 2>&1
    for /f "delims=" %%i in ('dir /s /b /a-d "!TEMP_DIR!\%%~nf\*.*" 2^>nul') do (
        echo %%~nxi^|%%~nxf>> "!FILE_LIST!"
    )
)

:: For Vortex mods
for /d %%d in ("!MODS_DIR!\*") do (
    for %%f in ("%%d\*.pak") do (
        echo [%%~nxf]
        "!REPAK_PATH!" unpack "%%f" -o "!TEMP_DIR!\%%~nf" >nul 2>&1
        for /f "delims=" %%i in ('dir /s /b /a-d "!TEMP_DIR!\%%~nf\*.*" 2^>nul') do (
            echo %%~nxi^|%%~nxd\%%~nxf>> "!FILE_LIST!"
        )
    )
)

echo.
echo Checking for conflicts...
echo.

set "PREV_FILE="
set "PREV_PAK="
set "CONFLICT_COUNT=0"
for /f "tokens=1,* delims=|" %%a in ('sort "!FILE_LIST!"') do (
    if /i "%%a"=="!PREV_FILE!" (
        set /a "CONFLICT_COUNT+=1"
        echo Conflict found: %%a
        echo   - In mod: !PREV_PAK!
        echo   - In mod: %%b
        echo.
    )
    set "PREV_FILE=%%a"
    set "PREV_PAK=%%b"
)

echo Total conflicts found: !CONFLICT_COUNT!
if !CONFLICT_COUNT! equ 0 echo Good hunting, Stalker.
if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!" 2>nul

pause
exit /b 0