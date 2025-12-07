# Gerencia Zap - Navegador Multi-Aba

Um navegador web Flutter com suporte a múltiplas abas e **isolamento completo de cookies** entre abas. Isso permite que você abra múltiplas contas do WhatsApp, Google, ou qualquer outro serviço web simultaneamente, cada uma em sua própria aba isolada.

## 🚀 Funcionalidades

- ✅ **Múltiplas Abas**: Adicione e gerencie várias abas de navegação
- ✅ **Isolamento de Cookies**: Cada aba tem seu próprio contexto de cookies completamente isolado
- ✅ **Navegação Web Completa**: Suporte completo a navegação web com histórico
- ✅ **Multi-Plataforma**: Funciona no Windows, Android, macOS e iOS
- ✅ **Interface Moderna**: UI limpa e intuitiva

## 🎯 Casos de Uso

- Abrir múltiplas contas do WhatsApp Web simultaneamente
- Gerenciar várias contas do Google em abas diferentes
- Testar aplicações web com diferentes sessões de usuário
- Qualquer situação onde você precise de sessões web isoladas

## 🔧 Como Funciona o Isolamento de Cookies

Cada aba do navegador cria uma instância separada de WebView com seu próprio contexto de cookies:

- **Android**: Cada WebView tem cookies isolados por padrão quando criamos instâncias separadas
- **iOS/macOS**: WKWebView isola cookies automaticamente quando criamos WebViewControllers separados
- **Windows**: Cada WebView tem seu próprio contexto de cookies isolado

Isso significa que quando você faz login em uma conta do WhatsApp em uma aba, essa sessão não interfere com outras abas. Você pode ter quantas contas quiser, cada uma em sua própria aba.

## 📦 Instalação

1. Clone o repositório:
```bash
git clone https://github.com/agendasuperapi/gerenciazap.git
cd gerencia-zap
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
# Windows
flutter run -d windows

# Android
flutter run -d android

# macOS
flutter run -d macos

# iOS
flutter run -d ios
```

## 🛠️ Desenvolvimento

### Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada da aplicação
├── models/
│   └── browser_tab.dart     # Modelo de aba do navegador
├── services/
│   └── tab_manager.dart     # Gerenciador de abas
├── screens/
│   └── browser_screen.dart   # Tela principal do navegador
└── widgets/
    ├── browser_tab_bar.dart      # Barra de abas
    ├── browser_address_bar.dart   # Barra de endereço
    └── browser_webview.dart       # Widget WebView
```

### Adicionar Novas Funcionalidades

O projeto está estruturado de forma modular, facilitando a adição de novas funcionalidades:

- **Favoritos**: Adicione um sistema de favoritos
- **Histórico**: Implemente histórico de navegação
- **Downloads**: Adicione suporte a downloads
- **Modo Privado**: Implemente modo de navegação privada
- **Extensões**: Sistema de extensões do navegador

## 📱 Plataformas Suportadas

- ⚠️ Windows (suporte limitado - webview_flutter não tem suporte oficial ainda)
- ✅ Android (suporte completo)
- ✅ macOS (suporte completo)
- ✅ iOS (suporte completo)

**Nota sobre Windows**: O pacote `webview_flutter` ainda não tem suporte oficial para Windows. Quando você executar o app no Windows, verá uma tela informativa explicando isso. O suporte completo para Windows será adicionado quando o `webview_flutter` adicionar suporte oficial para essa plataforma.

## 🔒 Privacidade e Segurança

- Cada aba mantém seus cookies isolados
- Nenhum dado é compartilhado entre abas
- Sessões são completamente independentes

## 📝 Licença

Este projeto é privado e pertence à Agenda Super API.

## 🤝 Contribuindo

Este é um projeto privado. Para sugestões ou problemas, abra uma issue no repositório.
