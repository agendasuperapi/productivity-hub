# Início Rápido - Criar Instalador

## Passos Rápidos

### 1. Configurar o Ícone

**IMPORTANTE:** Antes de criar o instalador, você precisa configurar o ícone do aplicativo.

1. Coloque sua imagem PNG do logo (GZ) na pasta `installer/`
2. Execute:
   ```batch
   cd installer
   convert_png_to_ico.bat logo.png
   ```
   (Substitua `logo.png` pelo nome real do seu arquivo)

   OU use um conversor online (https://convertio.co/png-ico/) e copie o arquivo `.ico` para:
   ```
   windows\runner\resources\app_icon.ico
   ```

### 2. Criar o Instalador

Execute o script automatizado:
```batch
installer\build_installer.bat
```

Este script irá:
- ✅ Limpar builds anteriores
- ✅ Obter dependências
- ✅ Construir o aplicativo em modo Release
- ✅ Criar o instalador com Inno Setup

### 3. Resultado

O instalador será criado em:
```
installer\output\GerenciaZap-Setup-1.0.0.exe
```

## Requisitos

- ✅ Flutter SDK instalado
- ✅ Inno Setup instalado (https://jrsoftware.org/isdl.php)
- ✅ Windows 10/11 (64-bit)

## Personalização

Para alterar a versão, edite:
- `pubspec.yaml` (versão do app)
- `installer/setup.iss` (versão do instalador)

## Problemas?

Consulte `installer/README.md` para documentação completa.



