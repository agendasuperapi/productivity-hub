import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/compact_logger.dart';

/// Representa uma aba do navegador para Windows com WebView isolado
class BrowserTabWindows {
  final String id;
  String title;
  String url;
  InAppWebViewController? controller;
  WebViewEnvironment? environment; // ✅ Nullable - criado apenas quando necessário
  bool isLoading;
  bool canGoBack;
  bool canGoForward;
  String? userDataFolder; // ✅ Nullable - criado apenas quando necessário
  int notificationCount; // Quantidade de notificações detectadas no título
  bool isLoaded; // Indica se a aba já foi carregada (lazy loading)
  bool _environmentInitialized = false; // ✅ Flag para rastrear se o ambiente foi inicializado
  bool _isLoadingUrl = false; // ✅ Flag para evitar carregamentos duplicados

  BrowserTabWindows({
    required this.id,
    required this.title,
    required this.url,
    this.controller,
    this.environment,
    this.userDataFolder,
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.notificationCount = 0,
    this.isLoaded = false,
  });

  /// Cria uma nova aba SEM WebViewEnvironment (rápido - apenas para mostrar na barra)
  /// O ambiente será criado apenas quando necessário (quando a aba for clicada)
  static BrowserTabWindows createLightweight({
    required String id,
    String? initialUrl,
  }) {
    final url = initialUrl ?? 'about:blank';
    
    return BrowserTabWindows(
      id: id,
      title: 'Nova Aba',
      url: url,
      environment: null, // ✅ Não cria ambiente ainda
      userDataFolder: null, // ✅ Não cria pasta ainda
    );
  }

  /// Cria uma nova aba com WebView isolado para Windows (com ambiente)
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
        // ✅ Permite acesso a arquivos locais (necessário para carregar PDFs via file://)
        additionalBrowserArguments: '--allow-file-access-from-files --allow-file-access',
      ),
    );
    
    final tab = BrowserTabWindows(
      id: id,
      title: 'Nova Aba',
      url: url,
      environment: environment,
      userDataFolder: userDataFolder,
    );
    
    tab._environmentInitialized = true;
    
    return tab;
  }

  /// ✅ Inicializa o WebViewEnvironment quando necessário (lazy initialization)
  Future<void> initializeEnvironment() async {
    if (_environmentInitialized || environment != null) {
      return; // Já foi inicializado
    }
    
    // Cria um diretório único para os dados do usuário desta aba
    final appDataDir = await getApplicationSupportDirectory();
    userDataFolder = path.join(
      appDataDir.path,
      'gerencia_zap',
      'tabs',
      'tab_$id',
    );
    
    // Cria o diretório se não existir
    final userDataDir = Directory(userDataFolder!);
    if (!await userDataDir.exists()) {
      await userDataDir.create(recursive: true);
    }
    
    // Cria um WebViewEnvironment isolado com userDataFolder único
    environment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: userDataFolder!,
        // ✅ Permite acesso a arquivos locais (necessário para carregar PDFs via file://)
        additionalBrowserArguments: '--allow-file-access-from-files --allow-file-access',
      ),
    );
    
    _environmentInitialized = true;
  }

  /// Carrega uma URL na aba
  Future<void> loadUrl(String url) async {
    try {
      // ✅ Evita carregamentos duplicados
      if (_isLoadingUrl) {
        CompactLogger.logWarning('loadUrl já está em execução, ignorando chamada duplicada');
        CompactLogger.logUrl('   URL', url);
        return;
      }
      
      // ✅ Aguarda o ambiente estar inicializado antes de tentar usar o controller
      if (!_environmentInitialized && environment == null) {
        await initializeEnvironment();
      }
      
      _isLoadingUrl = true; // Marca como carregando
      
      // Logs compactos removidos para reduzir verbosidade
      
      // ✅ Aguarda o controller estar disponível (até 10 segundos com verificações mais robustas)
      if (controller == null) {
        // Aguardando controller...
        int attempts = 0;
        while (controller == null && attempts < 100) { // Aumentado para 10 segundos
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
          
          // ✅ Verifica se o ambiente foi inicializado corretamente
          if (attempts > 20 && environment == null && !_environmentInitialized) {
            debugPrint('⚠️ Ambiente não inicializado após 2 segundos, tentando inicializar...');
            await initializeEnvironment();
          }
        }
        
        if (controller == null) {
          debugPrint('❌ Controller ainda é null após ${attempts * 100}ms para aba $id');
          // ✅ Atualiza a URL mesmo sem controller para que seja carregada quando o WebView for criado
          updateUrl(url);
          isLoaded = false; // Marca como não carregada para que seja carregada quando o WebView for criado
          _isLoadingUrl = false; // ✅ Reseta flag antes de retornar
          return;
        }
      }

      // Validação da URL antes de carregar
      if (url.isEmpty || url == 'about:blank') {
        debugPrint('⚠️ URL inválida ou vazia');
        return;
      }

      // Validação de formato de URL
      try {
        final uri = Uri.parse(url);
        // ✅ Permite http, https e file:// (para PDFs locais)
        final isValidScheme = uri.hasScheme && (
          uri.scheme.startsWith('http') || 
          uri.scheme == 'https' || 
          uri.scheme == 'file'
        );
        
        if (!isValidScheme) {
          debugPrint('⚠️ URL com esquema inválido: ${uri.scheme}');
          return;
        }
      } catch (e) {
        debugPrint('❌ Erro ao validar URL: $e');
        return;
      }

      // Iniciando carregamento...
      CompactLogger.logUrl('Carregando URL', url);
      
      // ✅ Verifica novamente se o controller ainda está disponível antes de usar
      if (controller == null) {
        debugPrint('❌ Controller se tornou null durante o carregamento para aba $id');
        updateUrl(url);
        isLoaded = false;
        _isLoadingUrl = false; // ✅ Reseta flag antes de retornar
        return;
      }
      
      // Atualiza a URL antes de carregar
      updateUrl(url);
      isLoaded = true; // Marca como carregada
      
      // ✅ Para arquivos locais (file://), usa abordagem especial
      if (url.startsWith('file://')) {
        try {
          // Converte file:// URL para caminho de arquivo para validação
          final uri = Uri.parse(url);
          String filePath = uri.toFilePath(windows: true);
          
          // ✅ Verifica se o arquivo existe
          final file = File(filePath);
          if (!await file.exists()) {
            debugPrint('❌ Arquivo não encontrado: $filePath');
            return;
          }
          
          CompactLogger.logFile('📄 Carregando arquivo local', filePath);
          CompactLogger.logUrl('   URL original', url);
          
          // ✅ Constrói a URL file:// corretamente codificada para Windows
          // No Windows, file:// URLs devem ter 3 barras e o caminho deve estar codificado
          String correctedUrl;
          if (url.startsWith('file:///')) {
            // Já tem 3 barras, mas precisa garantir que o caminho está codificado
            final pathPart = url.substring(7); // Remove "file:///"
            // Reconstrói a URL com codificação adequada
            correctedUrl = 'file:///' + Uri.encodeComponent(pathPart).replaceAll('%3A', ':').replaceAll('%2F', '/');
          } else if (url.startsWith('file://')) {
            // Adiciona barra extra e codifica
            final pathPart = url.substring(7); // Remove "file://"
            correctedUrl = 'file:///' + Uri.encodeComponent(pathPart).replaceAll('%3A', ':').replaceAll('%2F', '/');
          } else {
            correctedUrl = url;
          }
          
          // ✅ Alternativa: Tenta construir a URL diretamente do caminho do arquivo
          // Isso garante que espaços e caracteres especiais sejam tratados corretamente
          final fileUri = Uri.file(filePath);
          final alternativeUrl = fileUri.toString();
          
          CompactLogger.logUrl('📄 URL corrigida', correctedUrl);
          CompactLogger.logUrl('📄 URL alternativa', alternativeUrl);
          
          // ✅ Tenta primeiro com a URL alternativa (mais confiável)
          try {
            await controller!.loadUrl(
              urlRequest: URLRequest(
                url: WebUri(alternativeUrl),
              ),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('=== TIMEOUT ao carregar arquivo (alternativa) ===');
                throw TimeoutException('Timeout ao carregar arquivo após 30 segundos', const Duration(seconds: 30));
              },
            );
            
            CompactLogger.log('✅ Arquivo local carregado com sucesso (alternativa)');
            CompactLogger.logUrl('   URL', alternativeUrl);
            return;
          } catch (e1) {
            debugPrint('⚠️ Erro com URL alternativa, tentando corrigida: $e1');
            
            // ✅ Se falhar, tenta com a URL corrigida
            await controller!.loadUrl(
              urlRequest: URLRequest(
                url: WebUri(correctedUrl),
              ),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('=== TIMEOUT ao carregar arquivo ===');
                throw TimeoutException('Timeout ao carregar arquivo após 30 segundos', const Duration(seconds: 30));
              },
            );
            
            CompactLogger.log('✅ Arquivo local carregado com sucesso');
            CompactLogger.logUrl('   URL', correctedUrl);
            return;
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Erro ao carregar arquivo local: $e');
          debugPrint('Stack: $stackTrace');
          // Se falhar completamente, tenta com loadUrl normal como último recurso
          debugPrint('⚠️ Tentando carregar URL original como último recurso...');
        }
      }
      
      // ✅ Para URLs HTTP/HTTPS ou fallback de file://, usa loadUrl normal
      final Map<String, String> headers = {};
      if (!url.startsWith('file://')) {
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }
      
      // Adiciona timeout para evitar travamentos
      await controller!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(url),
          headers: headers.isEmpty ? null : headers,
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          CompactLogger.logWarning('TIMEOUT ao carregar URL');
          CompactLogger.logUrl('   URL', url);
          CompactLogger.log('   Tab ID: $id');
          throw TimeoutException('Timeout ao carregar página após 30 segundos', const Duration(seconds: 30));
        },
      );
      
      CompactLogger.log('✅ URL carregada com sucesso');
      CompactLogger.logUrl('   URL', url);
    } catch (e, stackTrace) {
      CompactLogger.logError('ERRO CRÍTICO ao carregar URL', e, stackTrace);
      CompactLogger.logUrl('   URL', url);
      CompactLogger.log('   Tab ID: $id');
      debugPrint('Erro: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('===================================');
      // Não rethrow para evitar crash, apenas loga o erro
    } finally {
      // ✅ Libera a flag de carregamento
      _isLoadingUrl = false;
    }
  }

  /// Atualiza o título da aba e detecta notificações
  void updateTitle(String newTitle) {
    // ✅ Sempre detecta notificações primeiro, mesmo em títulos temporários
    final detectedCount = _extractNotificationCount(newTitle);
    
    // ✅ Ignora títulos temporários durante o carregamento
    if (newTitle.isEmpty || 
        newTitle == 'about:blank' || 
        newTitle == 'Carregando...' ||
        newTitle.startsWith('http://') ||
        newTitle.startsWith('https://')) {
      // Mantém o título anterior se o novo for inválido/temporário
      if (title.isNotEmpty && title != 'Nova Aba' && !title.startsWith('http')) {
        // ✅ Mas atualiza a contagem de notificações se detectada
        if (detectedCount > 0) {
          notificationCount = detectedCount;
        }
        return; // Não atualiza o título se já tem um título válido
      }
    }
    
    title = newTitle.isEmpty ? 'Nova Aba' : newTitle;
    // Detecta notificações no título (padrões como "(3)", "3 notificações", etc.)
    notificationCount = detectedCount;
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
  /// ✅ IMPORTANTE: NÃO limpa cookies, cache ou dados ao fechar
  /// Os dados são preservados no userDataFolder para permitir:
  /// - Carregamento rápido na próxima abertura
  /// - Persistência de sessões (login mantido)
  /// - Cache de páginas visitadas
  Future<void> dispose() async {
    // ✅ Não faz nenhuma operação de limpeza para fechar mais rápido
    // Os recursos serão limpos automaticamente quando o aplicativo fechar
    // await environment.dispose(); // Não faz dispose para evitar demora
  }
}
