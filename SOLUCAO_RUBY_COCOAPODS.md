# Solução: Ruby 2.6 e CocoaPods

Seu Ruby 2.6.10 é muito antigo e não é compatível com versões recentes do CocoaPods. Aqui estão as soluções:

## ⚠️ Problema

Mesmo o CocoaPods 1.11.3 requer dependências que precisam de Ruby 3.2+. Seu Ruby 2.6.10 não é compatível.

## ✅ Solução 1: Instalar versão muito antiga do CocoaPods (Funciona com Ruby 2.6)

Execute no terminal:

```bash
sudo gem install cocoapods -v 1.10.2
```

Se ainda der erro, tente versões ainda mais antigas:

```bash
sudo gem install cocoapods -v 1.9.3
```

Ou:

```bash
sudo gem install cocoapods -v 1.8.4
```

## ✅ Solução 2: Atualizar o Ruby (RECOMENDADO - Melhor a longo prazo)

### Opção A: Usar Homebrew (Mais fácil)

1. Instalar Homebrew (se não tiver):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Instalar Ruby mais recente:
   ```bash
   _brew install ruby_
   ```

3. Adicionar ao PATH no `~/.zshrc`:
   ```bash
   echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. Verificar versão:
   ```bash
   ruby --version
   ```
   Deve mostrar Ruby 3.x

5. Instalar CocoaPods:
   ```bash
   gem install cocoapods
   ```

### Opção B: Usar rbenv (Gerenciador de versões Ruby)

1. Instalar rbenv via Homebrew:
   ```bash
   brew install rbenv ruby-build
   ```

2. Instalar Ruby 3.2:
   ```bash
   rbenv install 3.2.0
   rbenv global 3.2.0
   ```

3. Adicionar ao PATH no `~/.zshrc`:
   ```bash
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
   echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. Instalar CocoaPods:
   ```bash
   gem install cocoapods
   ```

## ✅ Solução 3: Usar Homebrew para instalar CocoaPods diretamente

Se você tiver Homebrew instalado:

```bash
brew install cocoapods
```

Isso instala uma versão do CocoaPods que pode funcionar melhor.

## 🎯 Recomendação

**Para desenvolvimento Flutter no macOS, recomendo atualizar o Ruby para 3.x usando Homebrew (Solução 2 - Opção A).**

Isso resolve o problema de forma permanente e permite usar versões mais recentes de todas as ferramentas.

## Verificar Instalação

Após qualquer solução, verifique:

```bash
pod --version
ruby --version
```

## Executar o App

Depois de resolver, execute:

```bash
flutter run -d macos
```

