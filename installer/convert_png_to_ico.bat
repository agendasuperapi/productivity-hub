@echo off
REM Script para converter PNG para ICO usando ImageMagick ou PowerShell
REM Uso: convert_png_to_ico.bat <arquivo_png> [tamanhos]
REM Exemplo: convert_png_to_ico.bat logo.png 16,32,48,64,128,256

if "%~1"=="" (
    echo Uso: convert_png_to_ico.bat ^<arquivo_png^> [tamanhos]
    echo Exemplo: convert_png_to_ico.bat logo.png 16,32,48,64,128,256
    pause
    exit /b 1
)

set PNG_FILE=%~1
set SIZES=%~2
if "%SIZES%"=="" set SIZES=16,32,48,64,128,256

if not exist "%PNG_FILE%" (
    echo ERRO: Arquivo nao encontrado: %PNG_FILE%
    pause
    exit /b 1
)

echo Convertendo %PNG_FILE% para ICO...
echo Tamanhos: %SIZES%
echo.

REM Tentar usar ImageMagick primeiro
where magick >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Usando ImageMagick...
    magick "%PNG_FILE%" -define icon:auto-resize=%SIZES% "%~dp1app_icon.ico"
    if %ERRORLEVEL% EQU 0 (
        echo Sucesso! Arquivo criado: %~dp1app_icon.ico
        echo.
        echo Copiando para windows\runner\resources\...
        copy /Y "%~dp1app_icon.ico" "..\windows\runner\resources\app_icon.ico" >nul
        if %ERRORLEVEL% EQU 0 (
            echo Icone atualizado com sucesso!
        ) else (
            echo AVISO: Nao foi possivel copiar o icone automaticamente
            echo Por favor, copie manualmente: %~dp1app_icon.ico para windows\runner\resources\app_icon.ico
        )
        pause
        exit /b 0
    )
)

REM Tentar usar PowerShell como alternativa
echo Tentando usar PowerShell...
powershell -Command "$png = [System.Drawing.Image]::FromFile('%CD%\%PNG_FILE%'); $sizes = @(%SIZES%); $ico = New-Object System.Drawing.Icon -ArgumentList ([System.IO.MemoryStream]::new()); $ico.Save('%CD%\app_icon.ico'); $png.Dispose()" 2>nul

if exist "app_icon.ico" (
    echo Sucesso! Arquivo criado: app_icon.ico
    echo.
    echo Copiando para windows\runner\resources\...
    copy /Y "app_icon.ico" "..\windows\runner\resources\app_icon.ico" >nul
    if %ERRORLEVEL% EQU 0 (
        echo Icone atualizado com sucesso!
    ) else (
        echo AVISO: Nao foi possivel copiar o icone automaticamente
        echo Por favor, copie manualmente: app_icon.ico para windows\runner\resources\app_icon.ico
    )
    pause
    exit /b 0
)

echo.
echo ERRO: Nenhuma ferramenta de conversao encontrada
echo.
echo Opcoes:
echo 1. Instale ImageMagick: https://imagemagick.org/script/download.php
echo    Depois execute: magick logo.png -define icon:auto-resize=16,32,48,64,128,256 app_icon.ico
echo.
echo 2. Use um conversor online: https://convertio.co/png-ico/
echo    Ou: https://www.icoconverter.com/
echo.
echo 3. Use o GIMP ou outro editor de imagens para exportar como ICO
echo.
pause



