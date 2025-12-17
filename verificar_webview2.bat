@echo off
echo ========================================
echo Verificacao do WebView2 Runtime
echo ========================================
echo.

echo Verificando no registro do Windows...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] WebView2 encontrado no registro
    reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv
) else (
    echo [ERRO] WebView2 NAO encontrado no registro
)
echo.

echo Verificando no diretorio de instalacao...
if exist "%LOCALAPPDATA%\Microsoft\EdgeWebView\Application" (
    echo [OK] Diretorio encontrado: %LOCALAPPDATA%\Microsoft\EdgeWebView\Application
    dir "%LOCALAPPDATA%\Microsoft\EdgeWebView\Application" /b
) else (
    echo [ERRO] Diretorio nao encontrado
)
echo.

echo ========================================
echo Verifique tambem em:
echo Programas e Recursos (appwiz.cpl)
echo Procure por: Microsoft Edge WebView2 Runtime
echo ========================================
echo.
pause


