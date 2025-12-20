# 🚀 Comandos Rápidos - Instalar CocoaPods

## ⚡ Solução Rápida (Tente Agora)

Abra o Terminal e execute **UM** destes comandos (em ordem de preferência):

### Opção 1: Versão muito antiga (Compatível com Ruby 2.6)
```bash
sudo gem install cocoapods -v 1.8.4
```

### Opção 2: Se a Opção 1 falhar
```bash
sudo gem install cocoapods -v 1.9.3
```

### Opção 3: Se as anteriores falharem
```bash
sudo gem install cocoapods -v 1.10.2
```

**Você precisará inserir sua senha de administrador quando solicitado.**

---

## ✅ Verificar se Funcionou

Após instalar, execute:

```bash
pod --version
```

Se mostrar uma versão (ex: `1.8.4`), está funcionando! 🎉

---

## 🎯 Executar o App

Depois que o CocoaPods estiver instalado:

```bash
flutter run -d macos
```

---

## ❌ Se Nada Funcionar

Se todas as versões antigas falharem, você precisa atualizar o Ruby:

### 1. Instalar Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Instalar Ruby
```bash
brew install ruby
```

### 3. Adicionar ao PATH
```bash
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 4. Instalar CocoaPods
```bash
gem install cocoapods
```

---

## 📝 Nota Importante

O CocoaPods é **OBRIGATÓRIO** para executar apps Flutter no macOS. Sem ele, o Flutter não consegue compilar os plugins nativos necessários.

