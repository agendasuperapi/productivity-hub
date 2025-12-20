#!/bin/bash
# Script para corrigir o problema da gem ffi no CocoaPods

echo "========================================"
echo "  Corrigindo gem FFI para ARM64"
echo "========================================"
echo ""

echo "Este script irá:"
echo "1. Remover todas as instalações da gem ffi (sistema e usuário)"
echo "2. Reinstalar ffi para ARM64"
echo ""
echo "NOTA: Você precisará inserir sua senha de administrador"
echo ""

# Remover ffi do sistema
echo "[1/3] Removendo gem ffi do sistema..."
sudo gem uninstall ffi --all --force 2>/dev/null || echo "Nenhuma instalação do sistema encontrada"

# Remover ffi do usuário
echo "[2/3] Removendo gem ffi do usuário..."
gem uninstall ffi --all --force --user-install 2>/dev/null || echo "Nenhuma instalação do usuário encontrada"

# Limpar cache
echo "Limpando cache..."
gem cleanup ffi 2>/dev/null || true

# Reinstalar ffi
echo "[3/3] Reinstalando gem ffi para ARM64..."
sudo gem install ffi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "  FFI corrigido com sucesso!"
    echo "========================================"
    echo ""
    echo "Verificando instalação..."
    gem list | grep ffi
    
    echo ""
    echo "Testando CocoaPods..."
    cd macos
    pod install --repo-update
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Tudo funcionando! Agora você pode executar:"
        echo "   flutter run -d macos"
    else
        echo ""
        echo "⚠️  Ainda há problemas. Considere atualizar o Ruby:"
        echo "   Ver arquivo: SOLUCAO_RUBY_COCOAPODS.md"
    fi
else
    echo ""
    echo "❌ ERRO: Falha ao reinstalar ffi"
    echo ""
    echo "Recomendação: Atualize o Ruby para 3.x"
    echo "   Ver arquivo: SOLUCAO_RUBY_COCOAPODS.md"
fi

