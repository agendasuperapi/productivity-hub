import 'dart:io';
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
    if (controller == null) return;
    // Atualiza a URL antes de carregar
    updateUrl(url);
    await controller!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  /// Atualiza o título da aba
  void updateTitle(String newTitle) {
    title = newTitle.isEmpty ? 'Nova Aba' : newTitle;
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
