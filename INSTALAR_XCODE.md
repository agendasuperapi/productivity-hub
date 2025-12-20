# Como Instalar Xcode no macOS

Para compilar e executar apps Flutter no macOS, é necessário instalar o **Xcode completo** (não apenas os Command Line Tools).

## Passo a Passo

### 1. Instalar Xcode

1. Abra a **App Store** no seu Mac
2. Procure por **"Xcode"**
3. Clique em **"Obter"** ou **"Instalar"**
   - O Xcode é gratuito, mas é grande (~15GB)
   - A instalação pode levar bastante tempo dependendo da sua internet

### 2. Configurar o Xcode

Após a instalação:

1. **Abra o Xcode** (encontre-o em `/Applications/Xcode.app`)
2. Na primeira abertura, aceite os termos de licença
3. Aguarde a instalação dos componentes adicionais (pode levar alguns minutos)

### 3. Configurar o Caminho do Desenvolvedor

Abra o Terminal e execute:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 4. Instalar CocoaPods (Opcional mas Recomendado)

O CocoaPods é necessário para alguns plugins Flutter:

```bash
sudo gem install cocoapods
```

### 5. Verificar Instalação

Execute:

```bash
flutter doctor
```

Você deve ver ✓ ao lado de "Xcode - develop for iOS and macOS"

### 6. Executar o App

Agora você pode executar:

```bash
flutter run -d macos
```

## Alternativa Temporária: Executar no Chrome

Enquanto o Xcode não é instalado, você pode testar o app no navegador:

```bash
flutter run -d chrome
```

**Nota:** Algumas funcionalidades nativas do macOS não estarão disponíveis no Chrome.

## Tempo de Instalação

- **Download:** 15-30 minutos (dependendo da velocidade da internet)
- **Instalação:** 10-20 minutos
- **Total:** Aproximadamente 30-50 minutos

## Requisitos

- macOS 10.15 ou superior
- Pelo menos 20GB de espaço livre em disco
- Conexão com internet estável


