# Script para verificar se o WebView2 Runtime está instalado
Write-Host "=== Verificação do WebView2 Runtime ===" -ForegroundColor Cyan
Write-Host ""

# Método 1: Verifica no registro do Windows
Write-Host "1. Verificando no registro do Windows..." -ForegroundColor Yellow
$regPath1 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
$regPath2 = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

$found = $false
$version = ""

if (Test-Path $regPath1) {
    try {
        $version = (Get-ItemProperty -Path $regPath1 -Name pv -ErrorAction SilentlyContinue).pv
        if ($version) {
            Write-Host "   ✅ WebView2 encontrado (WOW6432Node)" -ForegroundColor Green
            Write-Host "   Versão: $version" -ForegroundColor White
            $found = $true
        }
    } catch {
        # Ignora erros
    }
}

if (-not $found -and (Test-Path $regPath2)) {
    try {
        $version = (Get-ItemProperty -Path $regPath2 -Name pv -ErrorAction SilentlyContinue).pv
        if ($version) {
            Write-Host "   ✅ WebView2 encontrado (x64)" -ForegroundColor Green
            Write-Host "   Versão: $version" -ForegroundColor White
            $found = $true
        }
    } catch {
        # Ignora erros
    }
}

if (-not $found) {
    Write-Host "   ❌ WebView2 NÃO encontrado no registro" -ForegroundColor Red
}

Write-Host ""

# Método 2: Verifica no diretório de instalação
Write-Host "2. Verificando no diretório de instalação..." -ForegroundColor Yellow
$webviewPath = "$env:LOCALAPPDATA\Microsoft\EdgeWebView\Application"
if (Test-Path $webviewPath) {
    $versions = Get-ChildItem $webviewPath -Directory -ErrorAction SilentlyContinue
    if ($versions -and $versions.Count -gt 0) {
        Write-Host "   ✅ WebView2 encontrado em: $webviewPath" -ForegroundColor Green
        $latestVersion = $versions | Sort-Object Name -Descending | Select-Object -First 1
        Write-Host "   Versão mais recente: $($latestVersion.Name)" -ForegroundColor White
        $found = $true
    } else {
        Write-Host "   ⚠️ Diretório existe mas está vazio" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Diretório não encontrado: $webviewPath" -ForegroundColor Red
}

Write-Host ""

# Método 3: Verifica via AppX (Windows 10/11)
Write-Host "3. Verificando pacotes AppX..." -ForegroundColor Yellow
try {
    $appxPackages = Get-AppxPackage -Name "*WebView*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        Write-Host "   ✅ WebView2 encontrado via AppX:" -ForegroundColor Green
        $appxPackages | ForEach-Object {
            Write-Host "   - $($_.Name) v$($_.Version)" -ForegroundColor White
        }
        $found = $true
    } else {
        Write-Host "   ❌ Nenhum pacote WebView encontrado via AppX" -ForegroundColor Red
    }
} catch {
    Write-Host "   ⚠️ Não foi possível verificar pacotes AppX" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Resultado Final ===" -ForegroundColor Cyan
if ($found) {
    Write-Host "✅ WebView2 Runtime ESTÁ INSTALADO" -ForegroundColor Green
    Write-Host ""
    Write-Host "Se as janelas nativas não estão abrindo, pode ser:" -ForegroundColor Yellow
    Write-Host "  • Limitação do flutter_inappwebview no Windows" -ForegroundColor White
    Write-Host "  • Configuração incorreta do onCreateWindow" -ForegroundColor White
    Write-Host "  • Versão incompatível do WebView2 Runtime" -ForegroundColor White
} else {
    Write-Host "❌ WebView2 Runtime NÃO ESTÁ INSTALADO" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para instalar o WebView2 Runtime:" -ForegroundColor Yellow
    Write-Host "  1. Acesse: https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor White
    Write-Host "  2. Baixe o 'Evergreen Standalone Installer'" -ForegroundColor White
    Write-Host "  3. Escolha a versão adequada (x64, x86 ou ARM64)" -ForegroundColor White
    Write-Host "  4. Execute o instalador e reinicie o aplicativo" -ForegroundColor White
}

Write-Host ""
Write-Host "Pressione qualquer tecla para fechar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


