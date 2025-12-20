# Instalador Gerencia Zap

Este diretório contém os arquivos necessários para criar instaladores para o aplicativo Gerencia Zap.

## Plataformas Suportadas

- **Windows**: Instalador .exe usando Inno Setup
- **macOS**: Instalador DMG (veja [README_MACOS.md](README_MACOS.md))

---

## Windows

Este diretório contém os arquivos necessários para criar um instalador Windows para o aplicativo Gerencia Zap.

## Pré-requisitos

1. **Flutter SDK** - Instalado e configurado no PATH
2. **Inno Setup** - Baixe e instale de: https://jrsoftware.org/isdl.php
   - Durante a instalação, certifique-se de instalar o "Inno Setup Compiler"
3. **ImageMagick** (opcional) - Para converter PNG para ICO
   - Baixe de: https://imagemagick.org/script/download.php

## Configuração do Ícone

### Opção 1: Usando ImageMagick (Recomendado)

1. Coloque sua imagem PNG (logo) na pasta `installer/`
2. Execute:
   ```batch
   cd installer
   convert_png_to_ico.bat logo.png
   ```

### Opção 2: Conversão Manual

1. Use um conversor online como:
   - https://convertio.co/png-ico/
   - https://www.icoconverter.com/
2. Converta sua imagem PNG para ICO com múltiplos tamanhos (16x16, 32x32, 48x48, 64x64, 128x128, 256x256)
3. Salve o arquivo como `windows/runner/resources/app_icon.ico`

## Criando o Instalador

### Método Automatizado (Recomendado)

Execute o script batch:
```batch
installer\build_installer.bat
```

Este script irá:
1. Limpar o build anterior
2. Obter dependências
3. Construir o aplicativo em modo Release
4. Criar o instalador usando Inno Setup

### Método Manual

1. Construa o aplicativo:
   ```batch
   flutter build windows --release
   ```

2. Compile o script Inno Setup:
   ```batch
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup.iss
   ```

O instalador será criado em: `installer\output\GerenciaZap-Setup-1.0.0.exe`

## Personalização

### Alterar Versão

Edite `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

E atualize `installer/setup.iss`:
```iss
#define AppVersion "1.0.0"
```

### Alterar Informações do Aplicativo

Edite `installer/setup.iss`:
```iss
#define AppName "Gerencia Zap"
#define AppPublisher "Gerencia Zap"
#define AppURL "https://github.com/agendasuperapi/gerenciazap"
```

### Alterar Informações de Versão no Executável

Edite `windows/runner/Runner.rc`:
```rc
VALUE "CompanyName", "Sua Empresa" "\0"
VALUE "FileDescription", "Gerencia Zap" "\0"
VALUE "LegalCopyright", "Copyright (C) 2025 Sua Empresa. All rights reserved." "\0"
```

## macOS

Para criar um instalador DMG para macOS, consulte o [README_MACOS.md](README_MACOS.md).

Resumo rápido:
```bash
cd installer
./build_installer_macos.sh
```

## Estrutura de Arquivos

```
installer/
├── setup.iss                  # Script principal do Inno Setup (Windows)
├── build_installer.bat        # Script automatizado de build (Windows)
├── build_installer_macos.sh   # Script automatizado de build (macOS)
├── create_dmg.sh              # Script para DMG personalizado (macOS)
├── convert_png_to_ico.bat     # Script para converter PNG para ICO
├── README.md                  # Este arquivo
├── README_MACOS.md            # Documentação para macOS
└── output/                    # Diretório onde os instaladores serão gerados
    ├── GerenciaZap-Setup-1.0.0.exe  (Windows)
    └── GerenciaZap-1.0.3.dmg         (macOS)
```

## Notas

- O instalador requer privilégios de administrador para instalação
- O instalador suporta apenas arquitetura x64
- O instalador inclui opção para criar atalho na área de trabalho
- O instalador cria entradas no menu Iniciar e no Painel de Controle




