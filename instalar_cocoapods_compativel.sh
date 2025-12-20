#!/bin/bash
# Script para instalar CocoaPods compatível com Ruby 2.6

echo "========================================"
echo "  Instalando CocoaPods (versão compatível)"
echo "========================================"
echo ""

# Verificar versão do Ruby
RUBY_VERSION=$(ruby --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
echo "Ruby version: $RUBY_VERSION"
echo ""

# Para Ruby 2.6, usar versões mais antigas do CocoaPods
if [[ "$RUBY_VERSION" == "2.6"* ]]; then
    echo "Ruby 2.6 detectado. Tentando instalar CocoaPods 1.10.2 (compatível)..."
    echo "NOTA: Você precisará inserir sua senha de administrador"
    echo ""
    echo "Se falhar, tente versões mais antigas: 1.9.3 ou 1.8.4"
    echo ""
    
    sudo gem install cocoapods -v 1.10.2 || {
        echo ""
        echo "Tentando versão 1.9.3..."
        sudo gem install cocoapods -v 1.9.3 || {
            echo ""
            echo "Tentando versão 1.8.4..."
            sudo gem install cocoapods -v 1.8.4
        }
    }
    
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
        echo "Tente atualizar o Ruby primeiro:"
        echo "  brew install ruby"
        echo "  # Depois adicione ao PATH:"
        echo "  echo 'export PATH=\"/opt/homebrew/opt/ruby/bin:\$PATH\"' >> ~/.zshrc"
    fi
else
    echo "Instalando versão mais recente do CocoaPods..."
    sudo gem install cocoapods
fi

