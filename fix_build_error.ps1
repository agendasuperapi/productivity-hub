# Script para resolver erro LNK1108 no build do Flutter Windows
# Execute: .\fix_build_error.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resolvendo erro de build LNK1108" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar e fechar processos do aplicativo
Write-Host "[1/5] Verificando processos em execucao..." -ForegroundColor Yellow
$processes = Get-Process | Where-Object {
    $_.ProcessName -like "*gerencia*" -or 
    $_.Path -like "*gerencia_zap*" -or
    $_.MainWindowTitle -like "*Gerencia Zap*"
}

if ($processes) {
    Write-Host "  Encontrados processos em execucao:" -ForegroundColor Yellow
    foreach ($proc in $processes) {
        Write-Host "    - $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Yellow
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Host "      Processo finalizado." -ForegroundColor Green
        } catch {
            Write-Host "      Nao foi possivel finalizar o processo." -ForegroundColor Red
        }
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "  Nenhum processo encontrado." -ForegroundColor Green
}

# 2. Limpar build anterior
Write-Host ""
Write-Host "[2/5] Limpando build anterior..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERRO ao limpar projeto" -ForegroundColor Red
    exit 1
}
Write-Host "  Build limpo com sucesso." -ForegroundColor Green

# 3. Remover diretório build manualmente se existir
Write-Host ""
Write-Host "[3/5] Removendo diretorio build..." -ForegroundColor Yellow
if (Test-Path "build\windows") {
    try {
        Remove-Item -Path "build\windows" -Recurse -Force -ErrorAction Stop
        Write-Host "  Diretorio build removido." -ForegroundColor Green
    } catch {
        Write-Host "  AVISO: Nao foi possivel remover completamente o diretorio build." -ForegroundColor Yellow
        Write-Host "  Tente fechar o Visual Studio Code e outros editores e execute novamente." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Diretorio build nao existe." -ForegroundColor Green
}

# 4. Obter dependências
Write-Host ""
Write-Host "[4/5] Obtendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERRO ao obter dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "  Dependencias obtidas com sucesso." -ForegroundColor Green

# 5. Tentar build novamente
Write-Host ""
Write-Host "[5/5] Tentando build novamente..." -ForegroundColor Yellow
Write-Host ""
flutter run -d windows

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Build concluido com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Build falhou. Tente:" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "1. Feche o Visual Studio Code completamente" -ForegroundColor Yellow
    Write-Host "2. Feche o Visual Studio (se estiver aberto)" -ForegroundColor Yellow
    Write-Host "3. Desative temporariamente o antivirus" -ForegroundColor Yellow
    Write-Host "4. Execute como Administrador" -ForegroundColor Yellow
    Write-Host "5. Execute: flutter clean && flutter pub get && flutter run -d windows" -ForegroundColor Yellow
}


