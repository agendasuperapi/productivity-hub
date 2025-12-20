# Instalador Gerencia Zap - macOS

Este diretório contém os arquivos necessários para criar um instalador DMG para macOS do aplicativo Gerencia Zap.

## Pré-requisitos

1. **macOS** - Este script só funciona no macOS
2. **Flutter SDK** - Instalado e configurado no PATH
3. **Xcode Command Line Tools** - Instalado via:
   ```bash
   xcode-select --install
   ```

## Métodos de Instalação

### Método 1: DMG Simples (Recomendado para início rápido)

Execute o script automatizado:

```bash
cd installer
chmod +x build_installer_macos.sh
./build_installer_macos.sh
```

Este script irá:
1. Limpar o build anterior
2. Obter dependências
3. Construir o aplicativo em modo Release
4. Criar um DMG básico com o app e link para Applications

O DMG será criado em: `installer/output/GerenciaZap-{VERSION}.dmg`

### Método 2: DMG com Layout Personalizado (Recomendado para distribuição)

Para criar um DMG com layout visual melhorado e ícone personalizado:

```bash
cd installer
chmod +x build_installer_macos.sh create_dmg.sh

# Primeiro, construa o app
./build_installer_macos.sh

# Depois, crie o DMG personalizado
./create_dmg.sh
```

O DMG personalizado terá:
- Layout visual organizado
- Ícone personalizado (se `logo.png` existir)
- Posicionamento otimizado dos itens
- Tamanho de janela ajustado

## Personalização

### Alterar Versão

Edite `pubspec.yaml` na raiz do projeto:

```yaml
version: 1.0.3+1
```

A versão será automaticamente extraída pelos scripts.

### Adicionar Ícone Personalizado ao DMG

1. Coloque uma imagem PNG chamada `logo.png` na pasta `installer/`
2. Execute `create_dmg.sh` - o script tentará converter para ícone do DMG

### Alterar Informações do Aplicativo

Edite `macos/Runner/Configs/AppInfo.xcconfig`:

```xcconfig
PRODUCT_NAME = Gerencia Zap
PRODUCT_BUNDLE_IDENTIFIER = com.example.gerenciaZap
PRODUCT_COPYRIGHT = Copyright © 2025 Sua Empresa. All rights reserved.
```

## Estrutura de Arquivos

```
installer/
├── build_installer_macos.sh    # Script principal de build
├── create_dmg.sh               # Script para DMG personalizado
├── README_MACOS.md             # Este arquivo
├── logo.png                    # Logo para ícone do DMG (opcional)
└── output/                     # Diretório onde o DMG será gerado
    └── GerenciaZap-1.0.3.dmg
```

## Distribuição

### Assinatura de Código (Opcional, mas Recomendado)

Para distribuir o app fora da App Store, você precisará assinar o código:

1. Obtenha um certificado de desenvolvedor Apple
2. Configure o código de assinatura no Xcode:
   - Abra `macos/Runner.xcworkspace` no Xcode
   - Selecione o target Runner
   - Vá em "Signing & Capabilities"
   - Selecione seu time de desenvolvimento

3. O Flutter build já assinará automaticamente se configurado

### Notarização (Requisito do macOS)

Após criar o DMG, você pode notarizar o app para evitar avisos de segurança:

```bash
# Notarizar o app
xcrun notarytool submit installer/output/GerenciaZap-1.0.3.dmg \
    --apple-id seu-email@exemplo.com \
    --team-id SEU-TEAM-ID \
    --password senha-do-app \
    --wait

# Ou usar stapler para anexar o ticket
xcrun stapler staple installer/output/GerenciaZap-1.0.3.dmg
```

## Resolução de Problemas

### Erro: "Flutter não encontrado"
- Certifique-se de que o Flutter está instalado e no PATH
- Execute: `flutter doctor`

### Erro: "App não encontrado"
- Execute primeiro `build_installer_macos.sh` para construir o app
- Verifique se o build foi bem-sucedido

### Erro de Permissões
- Certifique-se de que os scripts têm permissão de execução:
  ```bash
  chmod +x build_installer_macos.sh create_dmg.sh
  ```

### DMG não abre no macOS
- Verifique se o app está assinado corretamente
- Tente abrir via Terminal: `open installer/output/GerenciaZap-1.0.3.dmg`
- Verifique os logs do Console.app para erros específicos

## Notas

- O DMG criado é compatível com macOS 10.13+ (configurado no projeto)
- O instalador não requer privilégios de administrador
- Usuários podem simplesmente arrastar o app para a pasta Applications
- O link simbólico para Applications facilita a instalação

## Próximos Passos

Para distribuição profissional, considere:

1. **App Store**: Configure o app para distribuição via App Store
2. **Sparkle**: Adicione atualizações automáticas usando Sparkle
3. **Assinatura**: Configure assinatura de código para evitar avisos
4. **Notarização**: Notarize o app para compatibilidade com Gatekeeper




