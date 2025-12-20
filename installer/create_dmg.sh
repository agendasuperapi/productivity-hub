#!/bin/bash
# Script para criar um DMG com layout personalizado para macOS
# Este script cria um DMG com ícone e layout visual melhorado

set -e

# Mudar para o diretório raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Obter versão do pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
APP_NAME="Gerencia Zap"
APP_BUNDLE_NAME="gerencia_zap"
DMG_NAME="GerenciaZap-${VERSION}.dmg"

echo "========================================"
echo "  Criando DMG Personalizado"
echo "========================================"
echo ""

# Verificar se o app foi construído
APP_PATH="build/macos/Build/Products/Release/${APP_BUNDLE_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERRO: App não encontrado em $APP_PATH"
    echo "Por favor, execute primeiro: ./installer/build_installer_macos.sh"
    exit 1
fi

# Limpar diretórios temporários
DMG_TEMP_DIR="installer/dmg_temp"
DMG_TEMP_DMG="installer/dmg_temp.dmg"
OUTPUT_DIR="installer/output"

rm -rf "$DMG_TEMP_DIR"
rm -f "$DMG_TEMP_DMG"
mkdir -p "$DMG_TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# Copiar app para diretório temporário
echo "[1/6] Copiando aplicativo..."
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Criar link simbólico para Applications
echo "[2/6] Criando link para Applications..."
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Criar DMG temporário
echo "[3/6] Criando DMG temporário..."
hdiutil create -srcfolder "$DMG_TEMP_DIR" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200m \
    "$DMG_TEMP_DMG"

# Montar DMG
echo "[4/6] Montando DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP_DMG" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# Obter caminho do volume montado
VOLUME_PATH="/Volumes/${APP_NAME}"

# Configurar layout do DMG
echo "[5/6] Configurando layout do DMG..."

# Ajustar tamanho da janela
echo '
   tell application "Finder"
     tell disk "'"${APP_NAME}"'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 920, 420}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           delay 1
           set position of item "'"${APP_BUNDLE_NAME}.app"'" of container window to {160, 205}
           set position of item "Applications" of container window to {360, 205}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript

# Definir ícone do DMG (se existir logo)
if [ -f "$SCRIPT_DIR/logo.png" ]; then
    echo "Aplicando ícone personalizado..."
    # Converter PNG para ICNS (requer sips ou iconutil)
    ICON_TEMP="$SCRIPT_DIR/.VolumeIcon.icns"
    if command -v iconutil &> /dev/null; then
        # Criar estrutura de ícone
        ICONSET="$SCRIPT_DIR/icon.iconset"
        mkdir -p "$ICONSET"
        
        # Gerar diferentes tamanhos do ícone
        sips -z 16 16 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_16x16.png" 2>/dev/null || true
        sips -z 32 32 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_16x16@2x.png" 2>/dev/null || true
        sips -z 32 32 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_32x32.png" 2>/dev/null || true
        sips -z 64 64 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_32x32@2x.png" 2>/dev/null || true
        sips -z 128 128 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_128x128.png" 2>/dev/null || true
        sips -z 256 256 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_128x128@2x.png" 2>/dev/null || true
        sips -z 256 256 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_256x256.png" 2>/dev/null || true
        sips -z 512 512 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
        sips -z 512 512 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_512x512.png" 2>/dev/null || true
        sips -z 1024 1024 "$SCRIPT_DIR/logo.png" --out "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
        
        # Criar arquivo .icns
        iconutil -c icns "$ICONSET" -o "$ICON_TEMP" 2>/dev/null || true
        
        if [ -f "$ICON_TEMP" ]; then
            cp "$ICON_TEMP" "$VOLUME_PATH/.VolumeIcon.icns"
            SetFile -a C "$VOLUME_PATH" 2>/dev/null || true
        fi
        
        # Limpar
        rm -rf "$ICONSET" "$ICON_TEMP" 2>/dev/null || true
    fi
fi

# Desmontar DMG
echo "[6/6] Finalizando DMG..."
hdiutil detach "$DEVICE"

# Converter para formato comprimido final
hdiutil convert "$DMG_TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT_DIR/${DMG_NAME}"

# Limpar arquivos temporários
rm -rf "$DMG_TEMP_DIR"
rm -f "$DMG_TEMP_DMG"

echo ""
echo "========================================"
echo "  DMG criado com sucesso!"
echo "========================================"
echo ""
echo "O instalador DMG foi criado em: $OUTPUT_DIR/${DMG_NAME}"
echo ""

