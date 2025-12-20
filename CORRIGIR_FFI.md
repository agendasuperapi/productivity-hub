# 🔧 Corrigir Erro FFI no CocoaPods

O CocoaPods está instalado, mas há um erro com a gem `ffi` (arquitetura incorreta).

## ⚡ Solução Rápida

Execute estes comandos no Terminal (um por vez):

### 1. Desinstalar a gem ffi incorreta
```bash
sudo gem uninstall ffi
```

Quando perguntar qual versão remover, escolha **todas** (digite `a` ou `all`).

### 2. Reinstalar ffi para ARM64
```bash
sudo gem install ffi
```

### 3. Verificar se funcionou
```bash
pod install
```

Se funcionar, você verá "Pod installation complete!"

### 4. Executar o app
```bash
flutter run -d macos
```

---

## 🔄 Solução Alternativa (Se a anterior não funcionar)

### Opção 1: Reinstalar ffi com arquitetura específica

```bash
sudo gem uninstall ffi
sudo gem install ffi --platform=ruby
```

### Opção 2: Atualizar o Ruby (Solução Definitiva)

O problema é que o Ruby 2.6 é muito antigo. A melhor solução é atualizar:

1. **Instalar Homebrew** (se não tiver):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Instalar Ruby atualizado**:
   ```bash
   brew install ruby
   ```

3. **Adicionar ao PATH**:
   ```bash
   echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. **Verificar versão**:
   ```bash
   ruby --version
   ```
   Deve mostrar Ruby 3.x

5. **Reinstalar CocoaPods**:
   ```bash
   gem install cocoapods
   ```

6. **Executar o app**:
   ```bash
   flutter run -d macos
   ```

---

## 📝 Explicação do Erro

O erro `cannot load such file -- ffi_c` acontece porque:
- A gem `ffi` foi compilada para x86_64 (Intel)
- Seu Mac é ARM64 (Apple Silicon)
- A gem precisa ser recompilada para ARM64

---

## ✅ Verificação

Após corrigir, verifique:

```bash
pod --version
ruby --version
gem list | grep ffi
```

Depois execute:
```bash
cd macos
pod install
```

Se `pod install` funcionar sem erros, você está pronto! 🎉

