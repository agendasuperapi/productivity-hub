#!/bin/bash
# Script para instalar CocoaPods no macOS

echo "========================================"
echo "  Instalando CocoaPods"
echo "========================================"
echo ""

# Verificar se já está instalado
if command -v pod &> /dev/null; then
    echo "CocoaPods já está instalado!"
    pod --version
    exit 0
fi

echo "Instalando CocoaPods..."
echo "NOTA: Você precisará inserir sua senha de administrador"
echo ""

# Instalar CocoaPods usando sudo
sudo gem install cocoapods

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "  CocoaPods instalado com sucesso!"
    echo "========================================"
    echo ""
    echo "Verificando instalação..."
    pod --version
    
    echo ""
    echo "Agora você pode executar:"
    echo "  flutter run -d macos"
else
    echo ""
    echo "ERRO: Falha ao instalar CocoaPods"
    echo ""
    echo "Alternativa: Instale via Homebrew:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "  brew install cocoapods"
fi

