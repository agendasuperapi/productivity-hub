# Script para resolver erro LNK1108 no build do Flutter Windows
# Execute: .\fix_linker_error.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resolvendo erro LNK1108" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar e fechar processos do aplicativo
Write-Host "[1/7] Verificando processos em execucao..." -ForegroundColor Yellow
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
    Start-Sleep -Seconds 3
} else {
    Write-Host "  Nenhum processo encontrado." -ForegroundColor Green
}

# 2. Verificar processos do Visual Studio / MSBuild
Write-Host ""
Write-Host "[2/7] Verificando processos de build..." -ForegroundColor Yellow
$buildProcesses = Get-Process | Where-Object {
    $_.ProcessName -like "*MSBuild*" -or 
    $_.ProcessName -like "*devenv*" -or
    $_.ProcessName -like "*cl.exe*" -or
    $_.ProcessName -like "*link.exe*"
}

if ($buildProcesses) {
    Write-Host "  Encontrados processos de build:" -ForegroundColor Yellow
    foreach ($proc in $buildProcesses) {
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
    Write-Host "  Nenhum processo de build encontrado." -ForegroundColor Green
}

# 3. Limpar build anterior
Write-Host ""
Write-Host "[3/7] Limpando build anterior..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERRO ao limpar projeto" -ForegroundColor Red
    exit 1
}
Write-Host "  Build limpo com sucesso." -ForegroundColor Green

# 4. Remover diretório build manualmente
Write-Host ""
Write-Host "[4/7] Removendo diretorio build..." -ForegroundColor Yellow
if (Test-Path "build\windows") {
    try {
        # Tentar remover arquivos individuais primeiro
        Get-ChildItem -Path "build\windows" -Recurse -File | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignorar erros de arquivos bloqueados
            }
        }
        Start-Sleep -Seconds 1
        Remove-Item -Path "build\windows" -Recurse -Force -ErrorAction Stop
        Write-Host "  Diretorio build removido." -ForegroundColor Green
    } catch {
        Write-Host "  AVISO: Nao foi possivel remover completamente o diretorio build." -ForegroundColor Yellow
        Write-Host "  Tente:" -ForegroundColor Yellow
        Write-Host "    1. Feche o Visual Studio Code completamente" -ForegroundColor Yellow
        Write-Host "    2. Feche o Visual Studio (se estiver aberto)" -ForegroundColor Yellow
        Write-Host "    3. Execute este script novamente" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Diretorio build nao existe." -ForegroundColor Green
}

# 5. Remover arquivos temporários do Visual Studio
Write-Host ""
Write-Host "[5/7] Limpando arquivos temporarios..." -ForegroundColor Yellow
$tempPaths = @(
    "build\windows\x64\runner\Debug\gerencia_zap.exe",
    "build\windows\x64\runner\Debug\gerencia_zap.pdb",
    "build\windows\x64\runner\Release\gerencia_zap.exe",
    "build\windows\x64\runner\Release\gerencia_zap.pdb"
)

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        try {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-Host "  Removido: $path" -ForegroundColor Green
        } catch {
            Write-Host "  Nao foi possivel remover: $path" -ForegroundColor Yellow
        }
    }
}

# 6. Obter dependências
Write-Host ""
Write-Host "[6/7] Obtendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERRO ao obter dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "  Dependencias obtidas com sucesso." -ForegroundColor Green

# 7. Tentar build novamente
Write-Host ""
Write-Host "[7/7] Tentando build novamente..." -ForegroundColor Yellow
Write-Host ""
Write-Host "DICA: Se o erro persistir, tente:" -ForegroundColor Cyan
Write-Host "  1. Executar como Administrador" -ForegroundColor Cyan
Write-Host "  2. Desativar temporariamente o antivirus" -ForegroundColor Cyan
Write-Host "  3. Executar: flutter build windows --release" -ForegroundColor Cyan
Write-Host ""
Write-Host "Iniciando build..." -ForegroundColor Yellow
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
    Write-Host "  Build falhou. Solucoes adicionais:" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "OPCAO 1: Build em modo Release (mais estavel)" -ForegroundColor Yellow
    Write-Host "  flutter build windows --release" -ForegroundColor White
    Write-Host ""
    Write-Host "OPCAO 2: Limpar cache do Flutter" -ForegroundColor Yellow
    Write-Host "  flutter clean" -ForegroundColor White
    Write-Host "  flutter pub cache repair" -ForegroundColor White
    Write-Host "  flutter pub get" -ForegroundColor White
    Write-Host ""
    Write-Host "OPCAO 3: Verificar permiscoes" -ForegroundColor Yellow
    Write-Host "  Execute o PowerShell como Administrador" -ForegroundColor White
    Write-Host ""
    Write-Host "OPCAO 4: Verificar antivirus" -ForegroundColor Yellow
    Write-Host "  Adicione uma excecao para a pasta do projeto no antivirus" -ForegroundColor White
}




