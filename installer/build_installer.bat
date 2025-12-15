@echo off
REM Script para construir o aplicativo Flutter e criar o instalador
REM Requer: Flutter SDK, Inno Setup Compiler

echo ========================================
echo   Gerencia Zap - Build e Instalador
echo ========================================
echo.

REM Verificar se Flutter está instalado
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERRO: Flutter nao encontrado no PATH
    echo Por favor, instale o Flutter SDK e adicione ao PATH
    pause
    exit /b 1
)

REM Verificar se Inno Setup está instalado
set INNO_SETUP_PATH="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %INNO_SETUP_PATH% (
    set INNO_SETUP_PATH="C:\Program Files\Inno Setup 6\ISCC.exe"
    if not exist %INNO_SETUP_PATH% (
        echo ERRO: Inno Setup Compiler nao encontrado
        echo Por favor, instale o Inno Setup de: https://jrsoftware.org/isdl.php
        pause
        exit /b 1
    )
)

echo [1/4] Limpando build anterior...
call flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ERRO ao limpar projeto
    pause
    exit /b 1
)

echo.
echo [2/4] Obtendo dependencias...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERRO ao obter dependencias
    pause
    exit /b 1
)

echo.
echo [3/4] Construindo aplicativo Windows (Release)...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo ERRO ao construir aplicativo
    pause
    exit /b 1
)

echo.
echo [4/4] Criando instalador...
cd installer
%INNO_SETUP_PATH% setup.iss
if %ERRORLEVEL% NEQ 0 (
    echo ERRO ao criar instalador
    cd ..
    pause
    exit /b 1
)
cd ..

echo.
echo ========================================
echo   Build concluido com sucesso!
echo ========================================
echo.
echo O instalador foi criado em: installer\output\GerenciaZap-Setup-1.0.0.exe
echo.
pause



