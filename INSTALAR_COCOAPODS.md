# Como Instalar CocoaPods no macOS

O CocoaPods é necessário para que os plugins Flutter funcionem no macOS.

## Método 1: Instalação com sudo (Recomendado)

Abra o Terminal e execute:

```bash
sudo gem install cocoapods
```

Você precisará inserir sua senha de administrador quando solicitado.

## Método 2: Instalar versão compatível com Ruby 2.6 ⚠️ RECOMENDADO PARA SEU CASO

Se você tiver Ruby 2.6 (como parece ser o caso), você **DEVE** instalar uma versão mais antiga do CocoaPods:

```bash
sudo gem install cocoapods -v 1.11.3
```

**OU use o script automatizado:**

```bash
./instalar_cocoapods_compativel.sh
```

Este script detecta automaticamente sua versão do Ruby e instala a versão correta do CocoaPods.

## Método 3: Usar Homebrew (Alternativa)

Se você tiver o Homebrew instalado:

```bash
brew install cocoapods
```

## Verificar Instalação

Após instalar, verifique se funcionou:

```bash
pod --version
```

Você deve ver algo como: `1.11.3` ou similar.

## Executar o App

Depois de instalar o CocoaPods, execute:

```bash
flutter run -d macos
```

## Solução de Problemas

### Erro: "Ruby version too old"

Se você receber erro sobre versão do Ruby, tente:

```bash
# Instalar versão específica compatível
sudo gem install cocoapods -v 1.11.3

# Ou atualizar o Ruby (requer Homebrew)
brew install ruby
```

### Erro: "Permission denied"

Certifique-se de usar `sudo`:

```bash
sudo gem install cocoapods
```

## Nota Importante

O CocoaPods é **obrigatório** para executar apps Flutter no macOS quando o projeto usa plugins nativos. Sem ele, o Flutter não consegue compilar os plugins necessários.

