import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Representa uma aba do navegador para Windows com WebView isolado
class BrowserTabWindows {
  final String id;
  String title;
  String url;
  InAppWebViewController? controller;
  final WebViewEnvironment environment;
  bool isLoading;
  bool canGoBack;
  bool canGoForward;
  final String userDataFolder;
  int notificationCount; // Quantidade de notificações detectadas no título
  bool isLoaded; // Indica se a aba já foi carregada (lazy loading)

  BrowserTabWindows({
    required this.id,
    required this.title,
    required this.url,
    this.controller,
    required this.environment,
    required this.userDataFolder,
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.notificationCount = 0,
    this.isLoaded = false,
  });

  /// Cria uma nova aba com WebView isolado para Windows
  static Future<BrowserTabWindows> createAsync({
    required String id,
    String? initialUrl,
  }) async {
    // Cada aba começa com URL vazia ou a URL especificada
    final url = initialUrl ?? 'about:blank';
    
    // Cria um diretório único para os dados do usuário desta aba
    // Isso garante isolamento completo de cookies e dados de sessão
    final appDataDir = await getApplicationSupportDirectory();
    final userDataFolder = path.join(
      appDataDir.path,
      'gerencia_zap',
      'tabs',
      'tab_$id',
    );
    
    // Cria o diretório se não existir
    final userDataDir = Directory(userDataFolder);
    if (!await userDataDir.exists()) {
      await userDataDir.create(recursive: true);
    }
    
    // Cria um WebViewEnvironment isolado com userDataFolder único
    // Isso garante que cada aba tenha seu próprio contexto de cookies isolado
    final environment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: userDataFolder,
      ),
    );
    
    final tab = BrowserTabWindows(
      id: id,
      title: 'Nova Aba',
      url: url,
      environment: environment,
      userDataFolder: userDataFolder,
    );
    
    return tab;
  }

  /// Carrega uma URL na aba
  Future<void> loadUrl(String url) async {
    try {
      debugPrint('=== loadUrl chamado ===');
      debugPrint('URL: $url');
      debugPrint('Tab ID: $id');
      debugPrint('Controller existe: ${controller != null}');
      
      if (controller == null) {
        debugPrint('=== ERRO: Controller é null ===');
        return;
      }

      // Validação da URL antes de carregar
      if (url.isEmpty || url == 'about:blank') {
        debugPrint('=== URL inválida ou vazia ===');
        debugPrint('URL: $url');
        return;
      }

      // Validação de formato de URL
      try {
        final uri = Uri.parse(url);
        if (!uri.hasScheme || (!uri.scheme.startsWith('http') && uri.scheme != 'https')) {
          debugPrint('=== URL com esquema inválido ===');
          debugPrint('URL: $url');
          debugPrint('Esquema: ${uri.scheme}');
          return;
        }
      } catch (e) {
        debugPrint('=== ERRO ao validar URL ===');
        debugPrint('URL: $url');
        debugPrint('Erro: $e');
        return;
      }

      debugPrint('=== Iniciando carregamento da URL ===');
      
      // Atualiza a URL antes de carregar
      updateUrl(url);
      isLoaded = true; // Marca como carregada
      
      // Adiciona timeout para evitar travamentos
      await controller!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('=== TIMEOUT ao carregar URL ===');
          debugPrint('URL: $url');
          debugPrint('Tab ID: $id');
          throw TimeoutException('Timeout ao carregar página após 30 segundos', const Duration(seconds: 30));
        },
      );
      
      debugPrint('=== URL carregada com sucesso ===');
      debugPrint('URL: $url');
    } catch (e, stackTrace) {
      debugPrint('=== ERRO CRÍTICO ao carregar URL ===');
      debugPrint('URL: $url');
      debugPrint('Tab ID: $id');
      debugPrint('Erro: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('===================================');
      // Não rethrow para evitar crash, apenas loga o erro
    }
  }

  /// Atualiza o título da aba e detecta notificações
  void updateTitle(String newTitle) {
    // ✅ Ignora títulos temporários durante o carregamento
    if (newTitle.isEmpty || 
        newTitle == 'about:blank' || 
        newTitle == 'Carregando...' ||
        newTitle.startsWith('http://') ||
        newTitle.startsWith('https://')) {
      // Mantém o título anterior se o novo for inválido/temporário
      if (title.isNotEmpty && title != 'Nova Aba' && !title.startsWith('http')) {
        return; // Não atualiza se já tem um título válido
      }
    }
    
    title = newTitle.isEmpty ? 'Nova Aba' : newTitle;
    // Detecta notificações no título (padrões como "(3)", "3 notificações", etc.)
    notificationCount = _extractNotificationCount(newTitle);
  }

  /// Extrai a quantidade de notificações do título da página
  /// Suporta padrões como: "(3) WhatsApp", "Gmail (5)", "Inbox (2) - Gmail", etc.
  int _extractNotificationCount(String title) {
    if (title.isEmpty) return 0;
    
    // Padrão 1: (número) no início ou no meio
    final pattern1 = RegExp(r'\((\d+)\)');
    final match1 = pattern1.firstMatch(title);
    if (match1 != null) {
      final count = int.tryParse(match1.group(1) ?? '0') ?? 0;
      if (count > 0) return count;
    }
    
    // Padrão 2: número seguido de espaço e palavras como "notificações", "mensagens", etc.
    final pattern2 = RegExp(r'(\d+)\s+(notificações?|mensagens?|emails?|novas?)', caseSensitive: false);
    final match2 = pattern2.firstMatch(title);
    if (match2 != null) {
      final count = int.tryParse(match2.group(1) ?? '0') ?? 0;
      if (count > 0) return count;
    }
    
    // Padrão 3: número no início seguido de espaço
    final pattern3 = RegExp(r'^(\d+)\s');
    final match3 = pattern3.firstMatch(title);
    if (match3 != null) {
      final count = int.tryParse(match3.group(1) ?? '0') ?? 0;
      if (count > 0 && count < 1000) return count; // Limita a números razoáveis
    }
    
    return 0;
  }

  /// Atualiza a URL da aba
  void updateUrl(String newUrl) {
    url = newUrl;
  }

  /// Atualiza o estado de navegação
  void updateNavigationState({
    required bool isLoading,
    required bool canGoBack,
    required bool canGoForward,
  }) {
    this.isLoading = isLoading;
    this.canGoBack = canGoBack;
    this.canGoForward = canGoForward;
  }
  
  /// Define o controller quando o widget é criado
  void setController(InAppWebViewController controller) {
    this.controller = controller;
  }
  
  /// Limpa os dados da aba ao fechar
  Future<void> dispose() async {
    // IMPORTANTE: Não limpa cookies ou dados ao fechar a aba
    // Os dados são preservados para permitir persistência de sessões
    // O ambiente e os cookies são mantidos no userDataFolder
    // await environment.dispose(); // Comentado para preservar dados
  }
}
