#!/bin/bash
# Script para construir o aplicativo Flutter e criar o instalador DMG para macOS
# Requer: Flutter SDK, Xcode Command Line Tools

set -e  # Parar em caso de erro

echo "========================================"
echo "  Gerencia Zap - Build e Instalador macOS"
echo "========================================"
echo ""

# Verificar se Flutter está instalado
if ! command -v flutter &> /dev/null; then
    echo "ERRO: Flutter não encontrado no PATH"
    echo "Por favor, instale o Flutter SDK e adicione ao PATH"
    exit 1
fi

# Verificar se estamos no macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "ERRO: Este script só pode ser executado no macOS"
    exit 1
fi

# Obter versão do pubspec.yaml
VERSION=$(grep '^version:' ../pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_NUMBER=$(grep '^version:' ../pubspec.yaml | sed 's/.*+//')
APP_NAME="Gerencia Zap"
APP_BUNDLE_NAME="gerencia_zap"
DMG_NAME="GerenciaZap-${VERSION}.dmg"

echo "[1/5] Limpando build anterior..."
cd "$(dirname "$0")/.."
flutter clean

echo ""
echo "[2/5] Obtendo dependências..."
flutter pub get

echo ""
echo "[3/5] Construindo aplicativo macOS (Release)..."
flutter build macos --release

if [ $? -ne 0 ]; then
    echo "ERRO ao construir aplicativo"
    exit 1
fi

echo ""
echo "[4/5] Preparando estrutura do DMG..."

# Criar diretório temporário para o DMG
DMG_TEMP_DIR="installer/dmg_temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copiar o app para o diretório temporário
APP_PATH="build/macos/Build/Products/Release/${APP_BUNDLE_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERRO: App não encontrado em $APP_PATH"
    exit 1
fi

cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Criar link simbólico para Applications
ln -s /Applications "$DMG_TEMP_DIR/Applications"

echo ""
echo "[5/5] Criando DMG..."

# Criar diretório de output se não existir
mkdir -p "installer/output"

# Remover DMG anterior se existir
if [ -f "installer/output/${DMG_NAME}" ]; then
    rm "installer/output/${DMG_NAME}"
fi

# Criar DMG usando hdiutil
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov -format UDZO \
    "installer/output/${DMG_NAME}"

# Limpar diretório temporário
rm -rf "$DMG_TEMP_DIR"

echo ""
echo "========================================"
echo "  Build concluído com sucesso!"
echo "========================================"
echo ""
echo "O instalador DMG foi criado em: installer/output/${DMG_NAME}"
echo ""
echo "Para criar um DMG com layout personalizado, execute:"
echo "  ./installer/create_dmg.sh"
echo ""




