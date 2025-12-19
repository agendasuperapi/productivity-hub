import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import '../models/download_item.dart';
import '../services/webview_quick_messages_injector.dart';
import '../services/global_quick_messages_service.dart';
import '../services/keywords_service.dart';
import '../services/download_history_service.dart';
import '../services/page_download_history_service.dart';
import '../services/quick_message_usage_service.dart';
import '../services/zoom_service.dart';
import '../utils/compact_logger.dart';
import '../utils/window_manager_helper.dart';
import '../utils/window_registry.dart';
import '../models/saved_tab.dart';
import 'page_navigation_bar.dart';
import 'collapsible_navigation_bar.dart';
import 'download_history_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

// Função auxiliar para escrever erros no arquivo de log
Future<void> _writeErrorToFile(String error) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/gerencia_zap_errors.log');
    final timestamp = DateTime.now().toIso8601String();
    await file.writeAsString(
      '[$timestamp] $error\n',
      mode: FileMode.append,
    );
  } catch (e) {
    debugPrint('Erro ao escrever log: $e');
  }
}

/// Widget WebView para Windows usando flutter_inappwebview
class BrowserWebViewWindows extends StatefulWidget {
  final BrowserTabWindows tab;
  final Function(String) onUrlChanged;
  final Function(String, String) onTitleChanged; // Agora recebe (title, tabId)
  final Function(bool, bool, bool) onNavigationStateChanged;
  final List<QuickMessage> quickMessages; // ✅ Mensagens rápidas passadas como parâmetro
  final Map<String, String> keywords; // ✅ Palavras-chave customizadas passadas como parâmetro
  final bool enableQuickMessages; // ✅ Se true, permite usar atalhos rápidos nesta aba
  final Function(String, String?)? onQuickMessageHint; // ✅ Callback para notificações de hint (type, shortcut)
  final String? iconUrl; // ✅ URL do ícone da página
  final String? pageName; // ✅ Nome da página
  final Function(String)? onNewTabRequested; // ✅ Callback para criar nova aba com URL
  final bool isPdfWindow; // ✅ Indica se esta é uma janela de PDF (não deve interceptar PDFs)
  final bool isAlwaysOnTop; // ✅ Indica se a janela está fixada (alwaysOnTop)
  final bool? externalNavBarVisibility; // ✅ Controle externo da visibilidade da barra de navegação
  final Function(bool)? onNavBarVisibilityChanged; // ✅ Callback quando a visibilidade da barra mudar
  final String openLinksMode; // ✅ 'same_page' = própria página, 'external_browser' = navegador externo, 'webview_window' = janela nativa do WebView2

  const BrowserWebViewWindows({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
    this.quickMessages = const [], // ✅ Default vazio
    this.keywords = const {}, // ✅ Default vazio - palavras-chave passadas como parâmetro
    this.enableQuickMessages = true, // ✅ Por padrão, atalhos rápidos estão habilitados
    this.onQuickMessageHint, // ✅ Callback opcional para hints
    this.iconUrl, // ✅ Ícone opcional
    this.pageName, // ✅ Nome opcional
    this.onNewTabRequested, // ✅ Callback opcional para criar nova aba
    this.isPdfWindow = false, // ✅ Por padrão, não é uma janela de PDF
    this.isAlwaysOnTop = false, // ✅ Por padrão, não está fixada
    this.externalNavBarVisibility, // ✅ Controle externo opcional da visibilidade
    this.onNavBarVisibilityChanged, // ✅ Callback opcional para mudanças de visibilidade
    this.openLinksMode = 'same_page', // ✅ Por padrão, abre na própria página
  });

  @override
  State<BrowserWebViewWindows> createState() => _BrowserWebViewWindowsState();
}

class _BrowserWebViewWindowsState extends State<BrowserWebViewWindows> {
  InAppWebViewController? _controller;
  Timer? _heartbeatTimer;
  bool _isWebViewAlive = true;
  final Set<String> _externalBrowserUrls = {}; // ✅ URLs que devem ser abertas no navegador externo
  final Set<String> _webviewWindowUrls = {}; // ✅ URLs que devem ser abertas em uma nova janela WebView2
  final Set<String> _popupTabIds = {}; // ✅ TabIds das popups criadas a partir desta janela (para sincronizar cookies quando fecharem)
  final Set<String> _popupUrls = {}; // ✅ URLs que foram interceptadas como popups e devem ser bloqueadas na navegação principal
  Timer? _cookieSyncTimer; // ✅ Timer para sincronizar cookies periodicamente enquanto popups estão abertas
  bool _hasInitialized = false; // ✅ Flag para rastrear se o WebView já foi inicializado
  bool _isLoadingLocalFile = false; // ✅ Flag para evitar carregamentos duplicados de arquivos locais
  final WebViewQuickMessagesInjector _quickMessagesInjector = WebViewQuickMessagesInjector();
  final GlobalQuickMessagesService _globalQuickMessages = GlobalQuickMessagesService();
  final DownloadHistoryService _downloadHistoryService = DownloadHistoryService();
  final QuickMessageUsageService _usageService = QuickMessageUsageService();
  String? _clipboardBackup; // ✅ Backup do clipboard antes de usar atalho rápido
  final ZoomService _zoomService = ZoomService(); // ✅ Serviço de zoom
  double _currentZoom = 1.0; // ✅ Zoom atual da página

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
    // ✅ Se inscreve para receber notificações quando as mensagens mudarem
    _globalQuickMessages.addListener(_onQuickMessagesChanged);
    // ✅ Carrega o zoom salvo para esta página
    _loadSavedZoom();
  }

  /// ✅ Carrega o zoom salvo para esta página
  Future<void> _loadSavedZoom() async {
    try {
      final savedZoom = await _zoomService.getZoom(widget.tab.id);
      _currentZoom = savedZoom;
      // ✅ Atualiza a UI para mostrar zoom carregado no tooltip
      if (mounted) {
        setState(() {});
      }
      debugPrint('[BrowserWebViewWindows] ✅ Zoom carregado para ${widget.tab.id}: $_currentZoom (${(savedZoom * 100).toStringAsFixed(1)}%)');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao carregar zoom: $e');
    }
  }

  /// ✅ Aplica zoom usando JavaScript (simula o zoom nativo do WebView2)
  /// ✅ Usa CSS zoom que funciona igual ao zoom nativo (Ctrl + roda do mouse)
  /// ✅ IMPORTANTE: Não interfere com o zoom nativo - apenas aplica quando chamado pelos controles personalizados
  Future<void> _applyZoom(double zoom) async {
    if (_controller == null) return;
    try {
      // ✅ Aguarda um pouco para garantir que o WebView está totalmente inicializado
      await Future.delayed(const Duration(milliseconds: 100));
      
      final zoomPercent = (zoom * 100).toStringAsFixed(1);
      await _controller!.evaluateJavascript(source: '''
        (function() {
          try {
            var zoomValue = parseFloat('$zoom');
            
            // ✅ Remove apenas o zoom CSS que aplicamos (não interfere com zoom nativo)
            var existingZoom = document.getElementById('flutter-zoom-style');
            if (existingZoom) {
              existingZoom.remove();
            }
            
            // ✅ Remove estilos inline que aplicamos (não interfere com zoom nativo)
            if (document.documentElement && document.documentElement.hasAttribute('data-flutter-zoom')) {
              document.documentElement.style.zoom = '';
              document.documentElement.removeAttribute('data-flutter-zoom');
            }
            if (document.body && document.body.hasAttribute('data-flutter-zoom')) {
              document.body.style.zoom = '';
              document.body.removeAttribute('data-flutter-zoom');
            }
            
            // Se zoom for 1.0, não precisa aplicar nada
            if (zoomValue === 1.0) {
              return;
            }
            
            // ✅ Aplica zoom CSS apenas nos elementos (marca para identificar que foi aplicado por nós)
            if (document.documentElement) {
              document.documentElement.style.zoom = zoomValue;
              document.documentElement.setAttribute('data-flutter-zoom', 'true');
            }
            if (document.body) {
              document.body.style.zoom = zoomValue;
              document.body.setAttribute('data-flutter-zoom', 'true');
            }
            
            // ✅ Cria um estilo CSS como backup (marca para identificar)
            if (document.head) {
              var style = document.createElement('style');
              style.id = 'flutter-zoom-style';
              style.setAttribute('data-flutter-zoom', 'true');
              style.textContent = 'html { zoom: ' + zoomValue + ' !important; } body { zoom: ' + zoomValue + ' !important; }';
              document.head.appendChild(style);
            }
            
            // ✅ Força reflow para aplicar mudanças
            void(0);
            if (document.documentElement) {
              document.documentElement.offsetHeight;
            }
          } catch (e) {
            console.error('Erro ao aplicar zoom:', e);
          }
        })();
      ''');
      
      debugPrint('[BrowserWebViewWindows] ✅ Zoom aplicado: $zoom (${zoomPercent}%)');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao aplicar zoom: $e');
      // Não relança o erro para não quebrar o fluxo de inicialização
    }
  }

  /// ✅ Aumenta o zoom da página
  Future<void> _zoomIn() async {
    if (_controller == null) return;
    try {
      final newZoom = _zoomService.increaseZoom(_currentZoom);
      await _applyZoom(newZoom);
      _currentZoom = newZoom;
      await _zoomService.saveZoom(widget.tab.id, newZoom);
      // ✅ Atualiza a UI para mostrar novo zoom no tooltip
      if (mounted) {
        setState(() {});
      }
      debugPrint('[BrowserWebViewWindows] ✅ Zoom aumentado para: $newZoom (${(newZoom * 100).toStringAsFixed(1)}%)');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao aumentar zoom: $e');
    }
  }

  /// ✅ Diminui o zoom da página
  Future<void> _zoomOut() async {
    if (_controller == null) return;
    try {
      final newZoom = _zoomService.decreaseZoom(_currentZoom);
      await _applyZoom(newZoom);
      _currentZoom = newZoom;
      await _zoomService.saveZoom(widget.tab.id, newZoom);
      // ✅ Atualiza a UI para mostrar novo zoom no tooltip
      if (mounted) {
        setState(() {});
      }
      debugPrint('[BrowserWebViewWindows] ✅ Zoom diminuído para: $newZoom (${(newZoom * 100).toStringAsFixed(1)}%)');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao diminuir zoom: $e');
    }
  }

  /// ✅ Restaura o zoom padrão
  Future<void> _zoomReset() async {
    if (_controller == null) return;
    try {
      final defaultZoom = _zoomService.defaultZoom;
      await _applyZoom(defaultZoom);
      _currentZoom = defaultZoom;
      await _zoomService.saveZoom(widget.tab.id, defaultZoom);
      // ✅ Atualiza a UI para mostrar novo zoom no tooltip
      if (mounted) {
        setState(() {});
      }
      debugPrint('[BrowserWebViewWindows] ✅ Zoom restaurado para padrão: $defaultZoom');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao restaurar zoom: $e');
    }
  }

  /// ✅ Aplica o zoom salvo na página
  /// ✅ Aplica tanto zoom de controles personalizados quanto zoom nativo salvo
  Future<void> _applySavedZoom() async {
    if (_controller == null) return;
    
    // ✅ Se o zoom é 1.0 (padrão), não precisa aplicar nada
    if (_currentZoom == 1.0) {
      return;
    }
    
    try {
      // ✅ Aguarda o WebView estar totalmente pronto antes de aplicar zoom
      // Isso evita erros ao tentar aplicar zoom antes do WebView estar inicializado
      int attempts = 0;
      const maxAttempts = 20; // Máximo de 4 segundos (20 * 200ms)
      
      while (attempts < maxAttempts && _controller != null && mounted) {
        try {
          // Verifica se o WebView está pronto e se o documento está carregado
          final isReady = await _controller!.evaluateJavascript(source: '''
            (function() {
              try {
                return document && document.documentElement && document.body && document.readyState === 'complete';
              } catch (e) {
                return false;
              }
            })();
          ''');
          
          if (isReady == true) {
            // WebView está pronto e documento está completo, aplica o zoom
            if (_controller != null && mounted) {
              await _applyZoom(_currentZoom);
            }
            return; // Sai do loop se aplicou com sucesso
          }
        } catch (e) {
          // Se der erro, pode ser que o WebView ainda não esteja pronto
        }
        
        // Aguarda antes de tentar novamente
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      
      // ✅ Se não conseguiu aplicar após todas as tentativas, tenta aplicar mesmo assim
      if (attempts >= maxAttempts && _controller != null && mounted) {
        try {
          await _applyZoom(_currentZoom);
        } catch (e) {
          debugPrint('[BrowserWebViewWindows] ❌ Erro ao aplicar zoom após timeout: $e');
        }
      }
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao aplicar zoom salvo: $e');
      // Não relança o erro para não quebrar o fluxo de inicialização
    }
  }

  /// ✅ Callback chamado quando as mensagens rápidas mudam
  void _onQuickMessagesChanged() {
    // ✅ Atualiza os scripts nos webviews abertos quando as mensagens mudarem
    if (_controller != null && widget.enableQuickMessages) {
      _updateQuickMessagesScripts();
    }
  }

  /// ✅ Atualiza os scripts de mensagens rápidas no webview atual
  Future<void> _updateQuickMessagesScripts() async {
    if (_controller == null || !widget.enableQuickMessages || !_isWebViewAlive) return;
    
    try {
      // ✅ SEMPRE usa mensagens do serviço global (sempre atualizadas)
      // ✅ Isso garante que mudanças em tempo real sejam refletidas em todas as abas/janelas
      final currentMessages = _globalQuickMessages.messages;
      if (currentMessages.isEmpty) {
        debugPrint('[QuickMessages] ⚠️ Nenhuma mensagem disponível para atualizar');
        return;
      }

      // Tenta obter a URL atual do webview
      String? urlStr;
      try {
        final url = await _controller!.getUrl();
        urlStr = url?.toString();
        if (urlStr == null || urlStr.isEmpty || urlStr == 'about:blank') {
          debugPrint('[QuickMessages] ⚠️ WebView ainda não tem URL carregada, aguardando...');
          return;
        }
      } catch (e) {
        debugPrint('[QuickMessages] ⚠️ Erro ao obter URL do webview: $e');
        return;
      }

      CompactLogger.log('[QuickMessages] Atualizando scripts');
      CompactLogger.logUrl('[QuickMessages] URL', urlStr);
      CompactLogger.log('[QuickMessages] Mensagens', '${currentMessages.length}');
      
      // Carrega a tecla de ativação do SharedPreferences
      String activationKey = '/';
      try {
        final prefs = await SharedPreferences.getInstance();
        activationKey = prefs.getString('quick_messages_activation_key') ?? '/';
      } catch (e) {
        // Usa padrão se houver erro
      }
      
      // ✅ Usa palavras-chave passadas como parâmetro (não busca do Supabase)
      final keywordsMap = widget.keywords;
      
      // Atualiza os scripts com as novas mensagens
      await _quickMessagesInjector.injectQuickMessagesSupport(
        _controller!,
        activationKey: activationKey,
        messages: currentMessages,
        keywords: keywordsMap,
        tabName: widget.tab.title,
        url: urlStr,
      );
      
      debugPrint('[QuickMessages] ✅ Scripts atualizados com sucesso em: ${widget.tab.title}');
    } catch (e) {
      debugPrint('[QuickMessages] ❌ Erro ao atualizar scripts: $e');
    }
  }

  /// Inicia um timer que verifica se o WebView ainda está respondendo
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // ✅ Verifica se o widget ainda está montado antes de executar
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_controller != null && _isWebViewAlive) {
        try {
          // ✅ Tenta obter a URL atual como teste de vida (sem log de sucesso)
          // ✅ Usa timeout para evitar bloqueios
          _controller!.getUrl().timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              // Timeout silencioso - não marca como morto para não cancelar prematuramente
            },
          ).then((url) {
            // ✅ Removido log de sucesso - apenas verifica silenciosamente
          }).catchError((e) {
            // ✅ Ignora erros silenciosamente para não bloquear thread principal
            // Não marca como morto para evitar cancelamento prematuro
          });
        } catch (e) {
          // ✅ Ignora erros silenciosamente para não bloquear thread principal
        }
      }
    });
  }
  
  /// ✅ Pausa o heartbeat timer (útil quando janela está oculta)
  void _pauseHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// ✅ Retoma o heartbeat timer (útil quando janela é mostrada novamente)
  void _resumeHeartbeat() {
    if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
      _startHeartbeat();
    }
  }

  @override
  void didUpdateWidget(BrowserWebViewWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Se mudou de aba, atualiza o controller
    // ✅ IMPORTANTE: Não recria o WebView, apenas atualiza a referência
    // ✅ Isso preserva os cookies e o estado da aba
    if (oldWidget.tab.id != widget.tab.id && _controller != null) {
      widget.tab.setController(_controller!);
      // ✅ Reseta a flag de inicialização quando muda de aba
      _hasInitialized = false;
    }
    // ✅ Se é a mesma aba, preserva o estado de inicialização
    // ✅ Isso evita recarregar quando volta da Home
    if (oldWidget.tab.id == widget.tab.id && _controller != null) {
      // Mantém _hasInitialized = true para evitar recarregamento
      // O controller já existe, então não precisa recarregar
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Se o ambiente não foi inicializado, mostra loading enquanto inicializa
    if (widget.tab.environment == null) {
      return FutureBuilder<void>(
        future: widget.tab.initializeEnvironment(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao inicializar: ${snapshot.error}'));
          }
          // ✅ Ambiente inicializado, reconstrói o widget
          return _buildWebView();
        },
      );
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // WebView (ocupa toda a tela)
        Positioned.fill(
          child: _buildWebView(),
        ),
        // Barra de navegação colapsável no topo (oculta por padrão)
        CollapsibleNavigationBar(
          currentUrl: widget.tab.url,
          isLoading: widget.tab.isLoading,
          canGoBack: widget.tab.canGoBack,
          canGoForward: widget.tab.canGoForward,
          iconUrl: widget.iconUrl, // ✅ Passa ícone
          pageName: widget.pageName ?? widget.tab.title, // ✅ Passa nome (usa título da aba como fallback)
          isPdfWindow: widget.isPdfWindow, // ✅ Indica se é janela de PDF
          isAlwaysOnTop: widget.isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
          externalVisibility: widget.externalNavBarVisibility, // ✅ Passa controle externo de visibilidade
          onVisibilityChanged: widget.onNavBarVisibilityChanged, // ✅ Passa callback para mudanças de visibilidade
          onUrlSubmitted: (url) async {
            await widget.tab.loadUrl(url);
          },
          onBackPressed: () async {
            if (widget.tab.canGoBack && _controller != null) {
              await _controller!.goBack();
              // ✅ A URL será atualizada automaticamente em onLoadStart/onLoadStop
              // Mas forçamos uma atualização imediata também
              Future.delayed(const Duration(milliseconds: 100), () async {
                if (_controller != null && mounted) {
                  try {
                    final currentUrl = await _controller!.getUrl();
                    if (currentUrl != null) {
                      final urlStr = currentUrl.toString();
                      widget.tab.updateUrl(urlStr);
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  } catch (e) {
                    // Ignora erros silenciosamente
                  }
                }
              });
            }
          },
          onForwardPressed: () async {
            if (widget.tab.canGoForward && _controller != null) {
              await _controller!.goForward();
              // ✅ A URL será atualizada automaticamente em onLoadStart/onLoadStop
              // Mas forçamos uma atualização imediata também
              Future.delayed(const Duration(milliseconds: 100), () async {
                if (_controller != null && mounted) {
                  try {
                    final currentUrl = await _controller!.getUrl();
                    if (currentUrl != null) {
                      final urlStr = currentUrl.toString();
                      widget.tab.updateUrl(urlStr);
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  } catch (e) {
                    // Ignora erros silenciosamente
                  }
                }
              });
            }
          },
          onRefreshPressed: () async {
            if (_controller != null) {
              await _controller!.reload();
            }
          },
          onDownloadHistoryPressed: widget.isPdfWindow ? null : () {
            _showDownloadHistory();
          },
          onZoomInPressed: _zoomIn,
          onZoomOutPressed: _zoomOut,
          onZoomResetPressed: _zoomReset,
          currentZoom: _currentZoom, // ✅ Passa zoom atual para exibir no tooltip
        ),
      ],
    );
  }

  Widget _buildWebView() {
    // Usa InAppWebView com o ambiente isolado da aba
    // IMPORTANTE: Só carrega URL inicial se o controller ainda não foi criado
    // Isso evita recarregar quando troca de aba
    try {
      return InAppWebView(
      // Usa o ambiente isolado criado para esta aba
      webViewEnvironment: widget.tab.environment!,
      // ✅ Só carrega URL inicial na primeira vez que o WebView é criado
      // ✅ Usa _hasInitialized para evitar recarregar quando volta da Home
      initialUrlRequest: !_hasInitialized && 
                         _controller == null && 
                         widget.tab.isLoaded &&
                         widget.tab.url != 'about:blank' && 
                         widget.tab.url.isNotEmpty
          ? URLRequest(url: WebUri(widget.tab.url))
          : null,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              // Configurações adicionais para melhor compatibilidade com sites complexos
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              iframeAllowFullscreen: true,
              // Limita recursos para evitar crashes
              resourceCustomSchemes: const [],
              // ✅ Configurações para permitir acesso a arquivos locais (PDFs)
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              // Configurações de segurança
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              // Configurações de cache
              // ✅ IMPORTANTE: Cache habilitado e NÃO limpa ao fechar
              // Isso permite carregamento rápido na próxima abertura do app
              cacheEnabled: true,
              clearCache: false, // ✅ false = preserva cache entre sessões
              // Configurações adicionais para evitar crashes em sites interativos
              useHybridComposition: false, // Desabilita composição híbrida que pode causar problemas
              useShouldInterceptRequest: false, // Desabilita interceptação de requisições que pode causar problemas
              // Configurações de performance
              supportZoom: true, // ✅ Habilita zoom nativo do WebView
              builtInZoomControls: false, // ✅ Desabilita controles nativos (usamos nossos botões)
              displayZoomControls: false, // ✅ Desabilita controles nativos (usamos nossos botões)
              // Configurações de segurança adicional
              thirdPartyCookiesEnabled: true,
              // Limita o número de recursos simultâneos
              minimumLogicalFontSize: 8,
              // Configurações de renderização
              verticalScrollBarEnabled: true,
              horizontalScrollBarEnabled: true,
              // Configurações de cache e performance
              // ✅ LOAD_DEFAULT: Usa cache quando disponível, mas também busca atualizações
              // Isso garante carregamento rápido mantendo dados atualizados
              cacheMode: CacheMode.LOAD_DEFAULT,
              // ✅ Habilita suporte a múltiplas janelas (necessário para pop-ups nativos do WebView2)
              // ✅ IMPORTANTE: Deve estar sempre habilitado para permitir janelas nativas quando necessário
              supportMultipleWindows: true,
              // ✅ Permite que JavaScript abra janelas automaticamente (necessário para pop-ups)
              // ✅ IMPORTANTE: Deve estar sempre habilitado para permitir janelas nativas quando necessário
              javaScriptCanOpenWindowsAutomatically: true,
            ),
      onWebViewCreated: (controller) {
        try {
          _controller = controller;
          widget.tab.setController(controller);
          
          // ✅ Log para debug
          debugPrint('✅ WebView criado para aba ${widget.tab.id}');
          
          // ✅ Marca como inicializado para evitar recarregamento quando volta da Home
          _hasInitialized = true;
          
          // ✅ NÃO aplica zoom aqui - será aplicado em onLoadStop quando a página estiver totalmente carregada
          
          // ✅ Se a aba tem URL válida (não vazia e não about:blank), carrega agora que o controller está pronto
          // ✅ Isso cobre tanto URLs iniciais quanto URLs pendentes (quando loadUrl foi chamado antes do controller existir)
          // ✅ Verifica se a URL atual é diferente de about:blank para garantir que há algo para carregar
          if (widget.tab.url.isNotEmpty && widget.tab.url != 'about:blank') {
            // ✅ Para arquivos locais (file://), usa o método loadUrl da aba que tem validações especiais
            if (widget.tab.url.startsWith('file://')) {
              // ✅ Evita carregamento duplicado
              if (_isLoadingLocalFile) {
                debugPrint('⚠️ Arquivo local já está sendo carregado, ignorando chamada duplicada');
                return;
              }
              
              _isLoadingLocalFile = true; // Marca como carregando
              debugPrint('📄 Arquivo local detectado no onWebViewCreated, aguardando antes de carregar...');
              // Aguarda um pouco para garantir que o WebView está totalmente inicializado
              Future.delayed(const Duration(milliseconds: 300), () async {
                if (mounted && _controller != null && _isLoadingLocalFile) {
                  try {
                    debugPrint('📄 Carregando arquivo local via método loadUrl da aba...');
                    await widget.tab.loadUrl(widget.tab.url);
                    debugPrint('✅ Arquivo local carregado via método da aba');
                  } catch (e, stackTrace) {
                    debugPrint('❌ Erro ao carregar arquivo local via método da aba: $e');
                    // Stack trace omitido para logs compactos
                  } finally {
                    _isLoadingLocalFile = false; // Libera a flag
                  }
                } else {
                  _isLoadingLocalFile = false; // Libera a flag se não carregou
                }
              });
            } else {
              // ✅ Para URLs HTTP/HTTPS, usa o método direto do controller
              Future.microtask(() async {
                try {
                  final currentUrl = await controller.getUrl();
                  final currentUrlStr = currentUrl?.toString() ?? '';
                  
                  // ✅ Se a URL atual é about:blank ou vazia, e a aba tem uma URL válida, carrega
                  if ((currentUrlStr.isEmpty || currentUrlStr == 'about:blank') && widget.tab.url != 'about:blank') {
                    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
                    widget.tab.isLoaded = true; // ✅ Marca como carregada após carregar
                    CompactLogger.logUrl('✅ URL carregada', widget.tab.url);
                  }
                } catch (e) {
                  debugPrint('⚠️ Erro ao carregar URL após criação do WebView: $e');
                  // ✅ Se falhar, tenta usar o método loadUrl da aba (que tem mais validações)
                  try {
                    await widget.tab.loadUrl(widget.tab.url);
                  } catch (e2) {
                    debugPrint('⚠️ Erro ao carregar URL usando método da aba: $e2');
                  }
                }
              });
            }
          }
          
          // Adiciona tratamento de erros JavaScript para evitar crashes
          try {
            controller.addJavaScriptHandler(
              handlerName: 'flutterErrorHandler',
              callback: (args) {
                // ✅ Apenas loga erros críticos de JavaScript
                _writeErrorToFile('JavaScript error: $args');
                return {};
              },
            );
          } catch (e) {
            // ✅ Apenas loga erros críticos
            _writeErrorToFile('Erro ao adicionar JavaScript handler: $e');
          }
          
          // ✅ Adiciona handler para interceptar cliques em PDFs
          try {
            controller.addJavaScriptHandler(
              handlerName: 'onPdfLinkClicked',
              callback: (args) {
                if (args.isNotEmpty && widget.onNewTabRequested != null) {
                  try {
                    final url = args[0] as String;
                    final urlLower = url.toLowerCase();
                    
                    // ✅ Verifica se é realmente um arquivo PDF antes de abrir
                    // Aceita URLs que terminam com .pdf OU blob URLs (serão verificadas no download)
                    final isPdfFile = urlLower.endsWith('.pdf') || 
                                     urlLower.contains('.pdf?') || 
                                     urlLower.contains('.pdf#') ||
                                     urlLower.startsWith('blob:'); // Blob URLs podem ser PDFs
                    
                    if (isPdfFile) {
                      CompactLogger.logUrl('📄 PDF detectado', url);
                      
                      // ✅ Extrai o nome do arquivo - prioriza o atributo download, depois tenta da URL
                      String fileName = 'arquivo.pdf';
                      
                      // ✅ 1. Usa o nome do atributo download se disponível (args[1])
                      final downloadFileName = args.length > 1 ? args[1] as String? : null;
                      if (downloadFileName != null && downloadFileName.isNotEmpty) {
                        fileName = downloadFileName;
                        if (!fileName.toLowerCase().endsWith('.pdf')) {
                          fileName = '$fileName.pdf';
                        }
                      } 
                      // ✅ 2. Tenta extrair da URL
                      else if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf?')) {
                        fileName = url.split('/').last.split('?').first;
                        if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.pdf')) {
                          fileName = 'arquivo.pdf';
                        }
                      }
                      
                      CompactLogger.logFile('   Nome do arquivo', fileName);
                      
                      // ✅ Para blob URLs, NÃO salva ainda - aguarda a conversão para data URL
                      // ✅ Para URLs normais, salva imediatamente
                      if (!urlLower.startsWith('blob:')) {
                        _saveDownloadToHistory(fileName, url, 0);
                      }
                      
                      // ✅ Para blob URLs, usa JavaScript para converter e chamar handler de callback
                      if (urlLower.startsWith('blob:')) {
                        CompactLogger.log('📄 Convertendo blob para data URL...');
                        // Injeta código JavaScript que converte e chama um handler de callback
                        controller.evaluateJavascript(source: '''
                          (function() {
                            try {
                              var xhr = new XMLHttpRequest();
                              xhr.open('GET', '$url', true);
                              xhr.responseType = 'blob';
                              xhr.onload = function() {
                                if (xhr.status === 200) {
                                  var reader = new FileReader();
                                  reader.onloadend = function() {
                                    // Chama handler de callback com a data URL e nome do arquivo
                                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                      window.flutter_inappwebview.callHandler('onPdfDataUrlReady', reader.result, '$fileName');
                                    }
                                  };
                                  reader.onerror = function() {
                                    console.error('Erro ao ler blob');
                                  };
                                  reader.readAsDataURL(xhr.response);
                                }
                              };
                              xhr.onerror = function() {
                                console.error('Erro na requisição blob');
                              };
                              xhr.send();
                            } catch (e) {
                              console.error('Erro ao converter blob:', e);
                            }
                          })();
                        ''');
                        // Não abre ainda - espera o callback onPdfDataUrlReady
                      } else {
                        // ✅ Para URLs normais, já salvou acima, apenas abre diretamente
                        widget.onNewTabRequested!(url);
                      }
                    } else {
                      CompactLogger.logWarning('URL não é um arquivo PDF real (ignorando)');
                      CompactLogger.logUrl('   URL', url);
                    }
                  } catch (e) {
                    debugPrint('Erro ao processar clique em PDF: $e');
                  }
                }
                return {};
              },
            );
            
            // ✅ Handler para receber a data URL convertida do blob
            controller.addJavaScriptHandler(
              handlerName: 'onPdfDataUrlReady',
              callback: (args) {
                if (args.isNotEmpty && widget.onNewTabRequested != null) {
                  try {
                    final dataUrl = args[0] as String;
                    final fileName = args.length > 1 ? args[1] as String? : null;
                    
                    if (dataUrl.isNotEmpty && dataUrl.startsWith('data:')) {
                      CompactLogger.log('✅ Blob convertido para data URL');
                      final pageId = widget.tab.id;
                      final finalFileName = fileName != null && fileName.isNotEmpty ? fileName : 'arquivo.pdf';
                      
                      // ✅ Salva no histórico com a data URL (não a blob URL)
                      _saveDownloadToHistory(finalFileName, dataUrl, 0);
                      
                      CompactLogger.logFile('   Arquivo', finalFileName);
                      debugPrint('📥 PDF convertido e salvo no histórico: $finalFileName');
                      
                      widget.onNewTabRequested!(dataUrl);
                    } else {
                      CompactLogger.log('⚠️ Data URL inválida');
                    }
                  } catch (e) {
                    debugPrint('Erro ao processar data URL: $e');
                  }
                }
                return {};
              },
            );
          } catch (e) {
            debugPrint('Erro ao adicionar handler de PDF: $e');
          }
          
          // Adiciona handler para notificações de hint de mensagens rápidas
          try {
            controller.addJavaScriptHandler(
              handlerName: 'quickMessageHint',
              callback: (args) {
                if (widget.onQuickMessageHint != null && args.isNotEmpty) {
                  try {
                    final data = args[0] as Map<String, dynamic>;
                    final type = data['type'] as String?;
                    final shortcut = data['shortcut'] as String?;
                    final keyCount = data['keyCount'] as int?;
                    final maxKeys = data['maxKeys'] as int?;
                    if (type != null) {
                      // Para tipo 'typing', passa informações adicionais no shortcut
                      if (type == 'typing' && shortcut != null && keyCount != null && maxKeys != null) {
                        widget.onQuickMessageHint!(type, '$shortcut|$keyCount|$maxKeys');
                      } else {
                        widget.onQuickMessageHint!(type, shortcut);
                      }
                    }
                  } catch (e) {
                    debugPrint('[QuickMessages] Erro ao processar hint: $e');
                  }
                }
                return {};
              },
            );
            
            // ✅ Handler para fazer backup do clipboard antes de usar atalho rápido
            controller.addJavaScriptHandler(
              handlerName: 'backupClipboard',
              callback: (args) async {
                try {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                  _clipboardBackup = clipboardData?.text;
                  debugPrint('[QuickMessages] 📋 Clipboard backup criado: ${_clipboardBackup != null ? "${_clipboardBackup!.substring(0, _clipboardBackup!.length > 50 ? 50 : _clipboardBackup!.length)}..." : "vazio"}');
                  return {'success': true, 'backedUp': _clipboardBackup != null};
                } catch (e) {
                  debugPrint('[QuickMessages] ❌ Erro ao fazer backup do clipboard: $e');
                  return {'success': false, 'error': e.toString()};
                }
              },
            );
            
            // ✅ Handler para restaurar o clipboard após usar atalho rápido
            controller.addJavaScriptHandler(
              handlerName: 'restoreClipboard',
              callback: (args) async {
                try {
                  if (_clipboardBackup != null) {
                    await Clipboard.setData(ClipboardData(text: _clipboardBackup!));
                    debugPrint('[QuickMessages] 📋 Clipboard restaurado: ${_clipboardBackup!.substring(0, _clipboardBackup!.length > 50 ? 50 : _clipboardBackup!.length)}...');
                    _clipboardBackup = null; // Limpa o backup após restaurar
                    return {'success': true};
                  } else {
                    debugPrint('[QuickMessages] ⚠️ Nenhum backup do clipboard para restaurar');
                    return {'success': false, 'error': 'No backup available'};
                  }
                } catch (e) {
                  debugPrint('[QuickMessages] ❌ Erro ao restaurar clipboard: $e');
                  return {'success': false, 'error': e.toString()};
                }
              },
            );
            
            // ✅ Handler para incrementar contador de uso quando mensagem for usada
            controller.addJavaScriptHandler(
              handlerName: 'incrementMessageUsage',
              callback: (args) async {
                try {
                  if (args.isNotEmpty) {
                    final data = args[0] as Map<String, dynamic>;
                    final messageId = data['messageId'] as String?;
                    final shortcut = data['shortcut'] as String?;
                    
                    if (messageId != null) {
                      // ✅ Incrementa contador local (salva no banco quando chegar a 10)
                      await _usageService.incrementUsage(messageId);
                      debugPrint('[QuickMessages] 📊 Uso incrementado: $messageId (atalho: ${shortcut ?? "N/A"})');
                      return {'success': true};
                    } else {
                      debugPrint('[QuickMessages] ⚠️ messageId não fornecido');
                      return {'success': false, 'error': 'messageId required'};
                    }
                  } else {
                    return {'success': false, 'error': 'No arguments provided'};
                  }
                } catch (e) {
                  debugPrint('[QuickMessages] ❌ Erro ao incrementar uso: $e');
                  return {'success': false, 'error': e.toString()};
                }
              },
            );
          } catch (e) {
            debugPrint('[QuickMessages] Erro ao adicionar handler de hint: $e');
          }
          
          // Atualiza o estado de navegação inicial
          _updateNavigationState();
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro crítico em onWebViewCreated: $e\nStack: $stackTrace');
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        try {
          final url = navigationAction.request.url?.toString() ?? '';
          
          // ✅ CRÍTICO: Se a URL está na lista de URLs que devem ser abertas no navegador externo,
          // cancela a navegação para evitar que carregue na página atual
          if (_externalBrowserUrls.contains(url)) {
            CompactLogger.log('🚫 Bloqueando navegação - URL será aberta no navegador externo');
            CompactLogger.logUrl('   URL', url);
            return NavigationActionPolicy.CANCEL;
          }
          
          // ✅ CRÍTICO: Se a URL está na lista de popups interceptados,
          // cancela a navegação para evitar que a página principal navegue para a URL do popup
          if (_popupUrls.contains(url)) {
            CompactLogger.log('🚫 Bloqueando navegação - URL será aberta em dialog popup');
            CompactLogger.logUrl('   URL', url);
            return NavigationActionPolicy.CANCEL;
          }
          
          // ✅ NOTA: Não bloqueia navegação para webview_window - permite que o WebView2 crie janela nativa
          // Se o onCreateWindow retornar true, o WebView2 criará a janela nativa automaticamente
          
          // ✅ IMPORTANTE: Se já estamos em uma janela de PDF, permite carregar PDFs normalmente
          // Não intercepta para evitar que a janela fique em branco
          if (widget.isPdfWindow) {
            CompactLogger.log('📄 Janela de PDF - permitindo carregamento normal');
            CompactLogger.logUrl('   URL', url);
            return NavigationActionPolicy.ALLOW;
          }
          
          // ✅ Detecta APENAS downloads reais de arquivos PDF (não apenas URLs com "pdf" no texto)
          final urlLower = url.toLowerCase();
          final contentType = navigationAction.request.headers?['content-type']?.toString().toLowerCase() ?? '';
          
          // ✅ Verifica se é realmente um arquivo PDF:
          // 1. URL termina com .pdf (não apenas contém)
          // 2. Content-Type é application/pdf
          final isPdf = (urlLower.endsWith('.pdf') || urlLower.contains('.pdf?')) ||
                       contentType == 'application/pdf' ||
                       contentType == 'application/x-pdf';
          
          if (isPdf) {
            // ✅ IMPORTANTE: Se a aba atual já está carregando um arquivo local (file://),
            // não intercepta - permite que o PDF seja carregado normalmente
            final currentTabUrl = widget.tab.url.toLowerCase();
            if (currentTabUrl.startsWith('file://') && urlLower.startsWith('file://')) {
              // Está tentando carregar um arquivo local na mesma aba que já tem um arquivo local
              // Permite a navegação para que o PDF seja exibido
              CompactLogger.log('📄 PDF local detectado - permitindo carregamento na janela atual');
              CompactLogger.logUrl('   URL', url);
              return NavigationActionPolicy.ALLOW;
            }
            
            // ✅ Se é uma URL HTTP/HTTPS apontando para PDF, intercepta e abre em nova janela
            CompactLogger.logUrl('📄 PDF detectado', url);
            CompactLogger.log('   Content-Type', contentType);
            
            // ✅ Abre o PDF em uma nova janela automaticamente (sem delay)
            if (widget.onNewTabRequested != null) {
              // Executa imediatamente para abrir antes do menu de downloads aparecer
              widget.onNewTabRequested!(url);
            }
            
            // ✅ Cancela a navegação atual para evitar download e menu de downloads
            return NavigationActionPolicy.CANCEL;
          }
          
          // ✅ Permite navegação normal para outros tipos de conteúdo
          return NavigationActionPolicy.ALLOW;
        } catch (e) {
          debugPrint('Erro ao processar shouldOverrideUrlLoading: $e');
          return NavigationActionPolicy.ALLOW;
        }
      },
      onLoadStart: (controller, url) {
        try {
          // ✅ Ativa a página imediatamente quando começa a carregar
          // Isso garante que o primeiro clique já funcione corretamente
          try {
            controller.evaluateJavascript(source: '''
              (function() {
                try {
                  // ✅ Ativa o documento quando a página começa a carregar
                  if (document.body) {
                    document.body.focus();
                  }
                  // ✅ Também tenta focar no window
                  if (window) {
                    window.focus();
                  }
                } catch (e) {
                  // Ignora erros silenciosamente
                }
              })();
            ''');
          } catch (e) {
            // Ignora erros silenciosamente
          }
          
          final urlStr = url?.toString() ?? '';
          final urlLower = urlStr.toLowerCase();
          
          // ✅ Verifica se é realmente um arquivo PDF (termina com .pdf ou contém .pdf?)
          final isPdfFile = urlLower.endsWith('.pdf') || 
                           urlLower.contains('.pdf?') || 
                           urlLower.contains('.pdf#');
          
          // ✅ Para arquivos PDF locais, não intercepta no onLoadStart
          // Deixa o shouldOverrideUrlLoading tratar isso
          if (isPdfFile && urlLower.startsWith('file://')) {
            CompactLogger.log('📄 PDF local detectado no onLoadStart');
            CompactLogger.logUrl('   URL', urlStr);
            // Não intercepta - permite que seja carregado normalmente
          } else if (isPdfFile && !urlLower.startsWith('file://')) {
            // Apenas intercepta PDFs HTTP/HTTPS reais, não arquivos locais
            CompactLogger.log('📄 PDF HTTP detectado no onLoadStart');
            CompactLogger.logUrl('   URL', urlStr);
            if (widget.onNewTabRequested != null) {
              // Aguarda um pouco para garantir que a aba atual não carregue o PDF
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.onNewTabRequested!(urlStr);
              });
            }
          }
          
          // ✅ Injeta script de interceptação de PDFs ANTES da página carregar completamente
          // Isso garante que downloads iniciados imediatamente sejam capturados
          if (!widget.isPdfWindow) {
            Future.microtask(() async {
              try {
                await controller.evaluateJavascript(source: '''
                  (function() {
                    try {
                      // Função auxiliar para verificar se é realmente um arquivo PDF
                      function isPdfFile(url) {
                        if (!url) return false;
                        var urlLower = url.toLowerCase();
                        return urlLower.endsWith('.pdf') || urlLower.indexOf('.pdf?') !== -1 || urlLower.indexOf('.pdf#') !== -1;
                      }
                      
                      // Intercepta cliques em links PDF (não interfere com campos de texto)
                      document.addEventListener('click', function(e) {
                        // ✅ PRIMEIRO: Verifica se é campo de texto ou elemento editável e retorna IMEDIATAMENTE
                        var clickedElement = e.target;
                        var tagName = clickedElement.tagName ? clickedElement.tagName.toUpperCase() : '';
                        
                        // ✅ Verifica se é campo de texto ANTES de qualquer outra coisa
                        if (tagName === 'INPUT' || tagName === 'TEXTAREA') {
                          return; // Deixa o evento prosseguir normalmente SEM interferência
                        }
                        
                        // ✅ Verifica se é elemento editável
                        if (clickedElement.isContentEditable) {
                          return; // Deixa o evento prosseguir normalmente SEM interferência
                        }
                        
                        // ✅ Verifica se está dentro de um campo de texto (pode ter labels ou divs envolvendo)
                        // ✅ Verifica também se o elemento tem role='textbox' ou type='text'
                        var currentElement = clickedElement;
                        var depth = 0;
                        while (currentElement && depth < 10) { // ✅ Aumentado profundidade para capturar mais casos
                          var tag = currentElement.tagName ? currentElement.tagName.toUpperCase() : '';
                          var role = currentElement.getAttribute ? currentElement.getAttribute('role') : null;
                          var type = currentElement.type ? currentElement.type.toLowerCase() : '';
                          
                          // ✅ Verifica tag, role, type e contentEditable
                          if (tag === 'INPUT' || tag === 'TEXTAREA' || 
                              role === 'textbox' || 
                              type === 'text' || type === 'email' || type === 'password' || type === 'search' || type === 'tel' || type === 'url' ||
                              currentElement.isContentEditable) {
                            return; // Está dentro de um campo de texto, deixa prosseguir SEM interferência
                          }
                          currentElement = currentElement.parentElement;
                          depth++;
                        }
                        
                        // Busca por link na hierarquia
                        var target = clickedElement;
                        while (target && target.tagName !== 'A') {
                          target = target.parentElement;
                        }
                        if (target && target.href) {
                          var href = target.href;
                          var downloadAttr = target.getAttribute('download');
                          var isPdf = isPdfFile(href) || (downloadAttr && isPdfFile(downloadAttr));
                          
                          // ✅ IMPORTANTE: Se é blob URL mas tem atributo download com .pdf, também intercepta
                          if (!isPdf && href.startsWith('blob:') && downloadAttr && downloadAttr.toLowerCase().endsWith('.pdf')) {
                            isPdf = true;
                          }
                          
                          if (isPdf) {
                            e.preventDefault();
                            e.stopPropagation();
                            e.stopImmediatePropagation();
                            // ✅ Passa também o atributo download se disponível
                            var fileName = downloadAttr || '';
                            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                              window.flutter_inappwebview.callHandler('onPdfLinkClicked', href, fileName);
                            }
                            return false;
                          }
                        }
                      }, false); // ✅ Usa capture: false para não interferir com eventos normais
                    } catch (e) {
                      console.error('Erro ao interceptar PDFs no onLoadStart:', e);
                    }
                  })();
                ''');
              } catch (e) {
                debugPrint('⚠️ Erro ao injetar script de interceptação no onLoadStart: $e');
              }
            });
          }
          
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          // ✅ Força reconstrução do widget para atualizar a barra de endereço
          if (mounted) {
            setState(() {});
          }
          _updateNavigationState();
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro em onLoadStart: $e\nStack: $stackTrace');
        }
      },
      onLoadStop: (controller, url) async {
        try {
          final urlStr = url?.toString() ?? '';
          
          // ✅ Aplica o zoom salvo quando a página carrega
          // ✅ Aguarda um pouco para garantir que a página está totalmente renderizada
          Future.delayed(const Duration(milliseconds: 300), () async {
            try {
              await _applySavedZoom();
            } catch (e) {
              debugPrint('[BrowserWebViewWindows] ⚠️ Erro ao aplicar zoom salvo: $e');
            }
          });
          
          // ✅ Para arquivos PDF locais, verifica se o conteúdo foi carregado
          final urlLower = urlStr.toLowerCase();
          final isPdfFile = urlLower.endsWith('.pdf') || 
                           urlLower.contains('.pdf?') || 
                           urlLower.contains('.pdf#');
          
          if (urlLower.startsWith('file://') && isPdfFile) {
            CompactLogger.log('📄 PDF local - onLoadStop chamado');
            CompactLogger.logUrl('   URL', urlStr);
            // Aguarda um pouco e verifica se há conteúdo na página
            Future.delayed(const Duration(milliseconds: 1000), () async {
              try {
                final title = await controller.getTitle();
                final currentUrl = await controller.getUrl();
                debugPrint('📄 Verificação pós-carregamento do PDF:');
                debugPrint('   Título: $title');
                debugPrint('   URL atual: $currentUrl');
                
                // Se o título está vazio ou é "about:blank", pode indicar que o PDF não foi renderizado
                final currentUrlLower = currentUrl?.toString().toLowerCase() ?? '';
                final currentIsPdf = currentUrlLower.endsWith('.pdf') || 
                                    currentUrlLower.contains('.pdf?') || 
                                    currentUrlLower.contains('.pdf#');
                
                if ((title == null || title.isEmpty || title == 'about:blank') && currentIsPdf) {
                  debugPrint('⚠️ ATENÇÃO: PDF pode não ter sido renderizado pelo WebView2');
                  debugPrint('   O WebView2 pode não ter suporte nativo para renderizar PDFs via file:// URLs');
                  debugPrint('   Considere usar um visualizador de PDF externo ou converter para data URI');
                } else if (title != null && title.isNotEmpty) {
                  debugPrint('✅ PDF parece ter sido carregado - título: $title');
                }
              } catch (e) {
                debugPrint('⚠️ Erro ao verificar título do PDF: $e');
              }
            });
          }
          
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          
          // ✅ Força reconstrução do widget para atualizar a barra de endereço
          if (mounted) {
            setState(() {});
          }
          
          // ✅ Injeta suporte a mensagens rápidas APENAS se houver mensagens E enableQuickMessages estiver habilitado
          // ✅ SEMPRE usa mensagens do serviço global (sempre atualizadas)
          // ✅ Isso garante que mudanças em tempo real sejam refletidas em todas as abas/janelas
          final currentMessages = _globalQuickMessages.messages;
          debugPrint('[QuickMessages] 🔍 Verificando condições para injeção:');
          debugPrint('[QuickMessages]   └─ Mensagens do serviço global: ${_globalQuickMessages.messages.length}');
          debugPrint('[QuickMessages]   └─ Mensagens a usar: ${currentMessages.length}');
          debugPrint('[QuickMessages]   └─ enableQuickMessages: ${widget.enableQuickMessages}');
          debugPrint('[QuickMessages]   └─ URL atual: $urlStr');
          if (currentMessages.isNotEmpty && widget.enableQuickMessages) {
            try {
              CompactLogger.log('[QuickMessages] Preparando script');
              CompactLogger.logUrl('[QuickMessages] URL', urlStr);
              CompactLogger.log('[QuickMessages] Aba', widget.tab.title);
              CompactLogger.log('[QuickMessages] Mensagens', '${currentMessages.length}');
              
              // Carrega a tecla de ativação do SharedPreferences
              String activationKey = '/';
              try {
                final prefs = await SharedPreferences.getInstance();
                activationKey = prefs.getString('quick_messages_activation_key') ?? '/';
                debugPrint('[QuickMessages] 🔑 Tecla de ativação carregada: "$activationKey"');
              } catch (e) {
                debugPrint('[QuickMessages] ⚠️ Erro ao carregar tecla de ativação, usando padrão "/": $e');
              }
              
              // ✅ Usa palavras-chave passadas como parâmetro (não busca do Supabase)
              final keywordsMap = widget.keywords;
              
              // Aguarda a página carregar completamente antes de injetar
              await Future.delayed(const Duration(milliseconds: 1000));
              debugPrint('[QuickMessages] 🔄 Injetando script (primeira tentativa)...');
              await _quickMessagesInjector.injectQuickMessagesSupport(
                controller,
                activationKey: activationKey, // ✅ Passa a tecla de ativação
                messages: currentMessages, // ✅ Usa mensagens do serviço global (sempre atualizadas)
                keywords: keywordsMap, // ✅ Passa palavras-chave customizadas
                tabName: widget.tab.title, // ✅ Nome da aba para logs
                url: urlStr, // ✅ URL para logs
              );
              // Reinjeta após mais um delay para garantir que funciona em SPAs como WhatsApp
              await Future.delayed(const Duration(milliseconds: 2000));
              debugPrint('[QuickMessages] 🔄 Reinjetando script (segunda tentativa para SPAs)...');
              await _quickMessagesInjector.injectQuickMessagesSupport(
                controller,
                activationKey: activationKey, // ✅ Passa a tecla de ativação
                messages: currentMessages, // ✅ Usa mensagens do serviço global (sempre atualizadas)
                keywords: keywordsMap, // ✅ Passa palavras-chave customizadas
                tabName: widget.tab.title, // ✅ Nome da aba para logs
                url: urlStr, // ✅ URL para logs
              );
            } catch (e) {
              debugPrint('[QuickMessages] ❌ Erro ao injetar mensagens rápidas: $e');
            }
          } else {
            if (!widget.enableQuickMessages) {
              debugPrint('[QuickMessages] ⚠️ Atalhos rápidos desabilitados para esta aba');
            } else {
              debugPrint('[QuickMessages] ⚠️ Nenhuma mensagem rápida disponível para injetar');
            }
          }
          
          // ✅ Detecta e salva mudanças de zoom nativo (Ctrl + roda do mouse)
          // ✅ Não interfere com o zoom nativo - apenas detecta e salva
          try {
            controller.addJavaScriptHandler(
              handlerName: 'onNativeZoomChanged',
              callback: (args) async {
                if (args.isNotEmpty) {
                  try {
                    final zoomValue = (args[0] as num).toDouble();
                    debugPrint('[BrowserWebViewWindows] 🔍 Zoom detectado pelo JavaScript: $zoomValue (atual: $_currentZoom)');
                    // ✅ Só salva se o zoom mudou significativamente (evita salvamentos desnecessários)
                    if ((zoomValue - _currentZoom).abs() > 0.01) {
                      _currentZoom = zoomValue;
                      await _zoomService.saveZoom(widget.tab.id, zoomValue);
                      if (mounted) {
                        setState(() {});
                      }
                      debugPrint('[BrowserWebViewWindows] ✅ Zoom nativo detectado e salvo: $zoomValue (${(zoomValue * 100).toStringAsFixed(1)}%)');
                    } else {
                      debugPrint('[BrowserWebViewWindows] ⚠️ Zoom detectado mas não mudou significativamente: $zoomValue vs $_currentZoom');
                    }
                  } catch (e) {
                    debugPrint('[BrowserWebViewWindows] ❌ Erro ao salvar zoom nativo: $e');
                  }
                }
                return {};
              },
            );
            
            // ✅ Sincroniza zoom nativo (Ctrl + roda do mouse) aplicando também via JavaScript
            // ✅ Quando detecta Ctrl+wheel, aplica o mesmo zoom via JavaScript e salva
            await controller.evaluateJavascript(source: '''
              (function() {
                try {
                  var currentZoom = 1.0;
                  var isApplyingZoom = false;
                  
                  // ✅ Função para aplicar zoom via JavaScript
                  var applyZoomJS = function(zoom) {
                    if (isApplyingZoom) return;
                    isApplyingZoom = true;
                    
                    try {
                      // ✅ Remove zoom anterior aplicado por nós
                      var existingStyle = document.getElementById('flutter-zoom-style');
                      if (existingStyle) {
                        existingStyle.remove();
                      }
                      
                      if (document.documentElement && document.documentElement.hasAttribute('data-flutter-zoom')) {
                        document.documentElement.style.zoom = '';
                        document.documentElement.removeAttribute('data-flutter-zoom');
                      }
                      if (document.body && document.body.hasAttribute('data-flutter-zoom')) {
                        document.body.style.zoom = '';
                        document.body.removeAttribute('data-flutter-zoom');
                      }
                      
                      // ✅ Se zoom for 1.0, não aplica nada
                      if (zoom === 1.0) {
                        currentZoom = 1.0;
                        isApplyingZoom = false;
                        return;
                      }
                      
                      // ✅ Aplica zoom via JavaScript (sincroniza com zoom nativo)
                      if (document.documentElement) {
                        document.documentElement.style.zoom = zoom;
                        document.documentElement.setAttribute('data-flutter-zoom', 'true');
                      }
                      if (document.body) {
                        document.body.style.zoom = zoom;
                        document.body.setAttribute('data-flutter-zoom', 'true');
                      }
                      
                      // ✅ Cria estilo CSS como backup
                      if (document.head) {
                        var style = document.createElement('style');
                        style.id = 'flutter-zoom-style';
                        style.setAttribute('data-flutter-zoom', 'true');
                        style.textContent = 'html { zoom: ' + zoom + ' !important; } body { zoom: ' + zoom + ' !important; }';
                        document.head.appendChild(style);
                      }
                      
                      currentZoom = zoom;
                    } catch (e) {
                      // Ignora erros
                    } finally {
                      isApplyingZoom = false;
                    }
                  };
                  
                  // ✅ Detecta quando Ctrl + roda do mouse é usado
                  var lastWheelTime = 0;
                  var wheelZoomTimeout = null;
                  document.addEventListener('wheel', function(e) {
                    if (e.ctrlKey || e.metaKey) {
                      var now = Date.now();
                      lastWheelTime = now;
                      
                      // ✅ Cancela timeout anterior
                      if (wheelZoomTimeout) {
                        clearTimeout(wheelZoomTimeout);
                      }
                      
                      // ✅ Calcula novo zoom baseado na direção da roda (igual ao zoom nativo: 10% por vez)
                      var delta = e.deltaY;
                      var zoomChange = delta > 0 ? 0.909090909 : 1.1; // ~10% (1/1.1 ≈ 0.909)
                      var newZoom = currentZoom * zoomChange;
                      
                      // ✅ Limita zoom entre 0.5 e 3.0
                      newZoom = Math.max(0.5, Math.min(3.0, newZoom));
                      
                      // ✅ Arredonda para 2 casas decimais
                      newZoom = Math.round(newZoom * 100) / 100;
                      
                      // ✅ Aguarda um pouco para o zoom nativo ser aplicado primeiro
                      wheelZoomTimeout = setTimeout(function() {
                        // ✅ Aplica o mesmo zoom via JavaScript para sincronizar
                        applyZoomJS(newZoom);
                        
                        // ✅ Notifica Flutter sobre a mudança
                        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                          window.flutter_inappwebview.callHandler('onNativeZoomChanged', newZoom);
                        }
                        
                        wheelZoomTimeout = null;
                      }, 200);
                    }
                  }, { passive: true });
                  
                  // ✅ Inicializa zoom atual se houver zoom salvo aplicado
                  setTimeout(function() {
                    if (document.documentElement && document.documentElement.style.zoom) {
                      var savedZoom = parseFloat(document.documentElement.style.zoom);
                      if (savedZoom && savedZoom > 0 && savedZoom !== 1.0) {
                        currentZoom = savedZoom;
                      }
                    }
                  }, 500);
                } catch (e) {
                  console.error('Erro ao sincronizar zoom nativo:', e);
                }
              })();
            ''');
          } catch (e) {
            debugPrint('[BrowserWebViewWindows] ⚠️ Erro ao adicionar detecção de zoom nativo: $e');
          }
          
          // ✅ Injeta script para interceptar downloads e cliques em PDFs em TODAS as páginas
          // Isso garante que PDFs sejam abertos automaticamente sem mostrar menu de downloads
          // ✅ IMPORTANTE: Intercepta APENAS arquivos .pdf reais, não URLs que contenham "pdf" no texto
          try {
            await controller.evaluateJavascript(source: '''
              (function() {
                try {
                  // Função auxiliar para verificar se é realmente um arquivo PDF
                  function isPdfFile(url) {
                    if (!url) return false;
                    var urlLower = url.toLowerCase();
                    // Verifica se termina com .pdf ou contém .pdf? (com query params)
                    return urlLower.endsWith('.pdf') || urlLower.indexOf('.pdf?') !== -1 || urlLower.indexOf('.pdf#') !== -1;
                  }
                  
                  // Intercepta cliques em links PDF (não interfere com campos de texto)
                  document.addEventListener('click', function(e) {
                    // ✅ PRIMEIRO: Verifica se é campo de texto ou elemento editável e retorna IMEDIATAMENTE
                    var clickedElement = e.target;
                    var tagName = clickedElement.tagName ? clickedElement.tagName.toUpperCase() : '';
                    
                    // ✅ Verifica se é campo de texto ANTES de qualquer outra coisa
                    if (tagName === 'INPUT' || tagName === 'TEXTAREA') {
                      return; // Deixa o evento prosseguir normalmente SEM interferência
                    }
                    
                    // ✅ Verifica se é elemento editável
                    if (clickedElement.isContentEditable) {
                      return; // Deixa o evento prosseguir normalmente SEM interferência
                    }
                    
                    // ✅ Verifica se está dentro de um campo de texto (pode ter labels ou divs envolvendo)
                    // ✅ Verifica também se o elemento tem role='textbox' ou type='text'
                    var currentElement = clickedElement;
                    var depth = 0;
                    while (currentElement && depth < 10) { // ✅ Aumentado profundidade para capturar mais casos
                      var tag = currentElement.tagName ? currentElement.tagName.toUpperCase() : '';
                      var role = currentElement.getAttribute ? currentElement.getAttribute('role') : null;
                      var type = currentElement.type ? currentElement.type.toLowerCase() : '';
                      
                      // ✅ Verifica tag, role, type e contentEditable
                      if (tag === 'INPUT' || tag === 'TEXTAREA' || 
                          role === 'textbox' || 
                          type === 'text' || type === 'email' || type === 'password' || type === 'search' || type === 'tel' || type === 'url' ||
                          currentElement.isContentEditable) {
                        return; // Está dentro de um campo de texto, deixa prosseguir SEM interferência
                      }
                      currentElement = currentElement.parentElement;
                      depth++;
                    }
                    
                    // Busca por link na hierarquia
                    var target = clickedElement;
                    while (target && target.tagName !== 'A') {
                      target = target.parentElement;
                    }
                    if (target && target.href) {
                      var href = target.href;
                      // Verifica se é PDF ou se tem atributo download com .pdf
                      var downloadAttr = target.getAttribute('download');
                      var isPdf = isPdfFile(href) || (downloadAttr && isPdfFile(downloadAttr));
                      
                      // ✅ IMPORTANTE: Se é blob URL mas tem atributo download com .pdf, também intercepta
                      if (!isPdf && href.startsWith('blob:') && downloadAttr && downloadAttr.toLowerCase().endsWith('.pdf')) {
                        isPdf = true;
                      }
                      
                      if (isPdf) {
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        // ✅ Passa também o atributo download se disponível
                        var fileName = downloadAttr || '';
                        // Notifica o Flutter sobre o PDF imediatamente
                        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                          window.flutter_inappwebview.callHandler('onPdfLinkClicked', href, fileName);
                        }
                        return false;
                      }
                    }
                  }, false); // ✅ Usa capture: false para não interferir com eventos normais
                  
                  // Intercepta eventos de download iniciados via JavaScript
                  document.addEventListener('download', function(e) {
                    var url = e.detail?.url || e.target?.href;
                    if (url && isPdfFile(url)) {
                      e.preventDefault();
                      e.stopPropagation();
                      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                        window.flutter_inappwebview.callHandler('onPdfLinkClicked', url);
                      }
                      return false;
                    }
                  }, true);
                  
                  // Intercepta downloads iniciados via JavaScript fetch
                  var originalFetch = window.fetch;
                  window.fetch = function(url, options) {
                    var urlStr = typeof url === 'string' ? url : url.toString();
                    if (isPdfFile(urlStr)) {
                      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                        window.flutter_inappwebview.callHandler('onPdfLinkClicked', urlStr);
                      }
                      return Promise.reject(new Error('PDF download intercepted'));
                    }
                    return originalFetch.apply(this, arguments);
                  };
                  
                  // Intercepta XMLHttpRequest para PDFs
                  var originalOpen = XMLHttpRequest.prototype.open;
                  XMLHttpRequest.prototype.open = function(method, url) {
                    if (url && isPdfFile(url)) {
                      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                        window.flutter_inappwebview.callHandler('onPdfLinkClicked', url);
                      }
                      return;
                    }
                    return originalOpen.apply(this, arguments);
                  };
                  
                  // Intercepta criação de elementos <a> com href de PDF ou atributo download
                  var originalCreateElement = document.createElement;
                  document.createElement = function(tagName) {
                    var element = originalCreateElement.call(document, tagName);
                    if (tagName.toLowerCase() === 'a') {
                      var originalSetAttribute = element.setAttribute;
                      element.setAttribute = function(name, value) {
                        if (name === 'href' && value && isPdfFile(value)) {
                          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                            window.flutter_inappwebview.callHandler('onPdfLinkClicked', value);
                          }
                        } else if (name === 'download' && value && isPdfFile(value)) {
                          // Intercepta quando atributo download aponta para PDF
                          var href = element.href;
                          if (href && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                            window.flutter_inappwebview.callHandler('onPdfLinkClicked', href);
                          }
                        }
                        return originalSetAttribute.apply(this, arguments);
                      };
                    }
                    return element;
                  };
                  
                  // Intercepta MutationObserver para detectar links de PDF adicionados dinamicamente
                  var observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) { // Element node
                          if (node.tagName === 'A' && node.href && isPdfFile(node.href)) {
                            node.addEventListener('click', function(e) {
                              e.preventDefault();
                              e.stopPropagation();
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('onPdfLinkClicked', node.href);
                              }
                              return false;
                            }, false); // ✅ Usa capture: false para não interferir com eventos normais
                          }
                          // Verifica filhos também
                          var links = node.querySelectorAll && node.querySelectorAll('a[href*=".pdf"]');
                          if (links) {
                            links.forEach(function(link) {
                              if (isPdfFile(link.href)) {
                                link.addEventListener('click', function(e) {
                                  e.preventDefault();
                                  e.stopPropagation();
                                  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                    window.flutter_inappwebview.callHandler('onPdfLinkClicked', link.href);
                                  }
                                  return false;
                                }, false); // ✅ Usa capture: false para não interferir com eventos normais
                              }
                            });
                          }
                        }
                      });
                    });
                  });
                  
                  observer.observe(document.body || document.documentElement, {
                    childList: true,
                    subtree: true
                  });
                } catch (e) {
                  console.error('Erro ao interceptar PDFs:', e);
                }
              })();
            ''');
            debugPrint('✅ Script de interceptação de PDFs injetado');
          } catch (e) {
            debugPrint('⚠️ Erro ao injetar script de interceptação de PDF: $e');
          }
          
          // Para sites como Telegram, adiciona um delay maior antes de obter o título
          if (urlStr.contains('telegram.org')) {
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // Adiciona proteção adicional: injeta código JavaScript para prevenir crashes
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  try {
                    window.addEventListener('error', function(e) {
                      return true;
                    });
                    window.addEventListener('unhandledrejection', function(e) {
                      e.preventDefault();
                      return true;
                    });
                  } catch (e) {
                    // Ignora erros silenciosamente
                  }
                })();
              ''');
            } catch (e) {
              // ✅ Apenas loga erros críticos
              _writeErrorToFile('Erro ao injetar proteções JavaScript: $e');
            }
          }
          
          // Obtém o título da página com timeout
          try {
            final title = await controller.getTitle().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            );
            // ✅ Ignora títulos vazios ou temporários
            if (title != null && 
                title.isNotEmpty && 
                title != 'about:blank' && 
                title != 'Carregando...' &&
                !title.startsWith('http://') &&
                !title.startsWith('https://')) {
              widget.tab.updateTitle(title);
              widget.onTitleChanged(title, widget.tab.id);
            }
          } catch (e) {
            // ✅ Apenas loga erros críticos
            _writeErrorToFile('Erro ao obter título: $e');
          }
          
          _updateNavigationState();
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro crítico em onLoadStop: $e\nStack: $stackTrace');
        }
      },
      onTitleChanged: (controller, title) {
        // ✅ Ignora títulos vazios ou temporários
        if (title != null && 
            title.isNotEmpty && 
            title != 'about:blank' && 
            title != 'Carregando...' &&
            !title.startsWith('http://') &&
            !title.startsWith('https://')) {
          widget.tab.updateTitle(title);
          widget.onTitleChanged(title, widget.tab.id);
        }
      },
      onProgressChanged: (controller, progress) {
        try {
          widget.tab.updateNavigationState(
            isLoading: progress < 100,
            canGoBack: widget.tab.canGoBack,
            canGoForward: widget.tab.canGoForward,
          );
          widget.onNavigationStateChanged(
            progress < 100,
            widget.tab.canGoBack,
            widget.tab.canGoForward,
          );
        } catch (e) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro em onProgressChanged: $e');
        }
      },
      // Tratamento de erros - apenas loga erros críticos
      onReceivedError: (controller, request, error) {
        try {
          final urlStr = request.url.toString();
          // ✅ Loga TODOS os erros para debug (especialmente para PDFs)
          CompactLogger.log('❌ Erro no WebView');
          CompactLogger.logUrl('   URL', urlStr);
          CompactLogger.log('   Tipo', error.type.toString());
          CompactLogger.log('   Tab', widget.tab.id);
          
          // ✅ Se for um arquivo local ou PDF real, loga especialmente
          final urlLower = urlStr.toLowerCase();
          final isPdfFile = urlLower.endsWith('.pdf') || 
                           urlLower.contains('.pdf?') || 
                           urlLower.contains('.pdf#');
          
          if (urlLower.contains('file://') || isPdfFile) {
            debugPrint('⚠️ ERRO AO CARREGAR ARQUIVO LOCAL/PDF!');
            debugPrint('   Isso pode indicar que o WebView2 não consegue renderizar PDFs diretamente');
          }
          
          final shortUrl = CompactLogger.shortenUrl(urlStr);
          final errorMsg = '''
Erro no WebView:
URL: $shortUrl
Descrição: ${error.description}
Tipo: ${error.type}
Tab ID: ${widget.tab.id}
''';
          _writeErrorToFile(errorMsg);
        } catch (e) {
          _writeErrorToFile('Erro ao processar onReceivedError: $e');
        }
      },
      // Handler para erros de console JavaScript - apenas erros críticos
      onConsoleMessage: (controller, consoleMessage) {
        try {
          final message = consoleMessage.message ?? '';
          
          // ✅ Loga todas as mensagens relacionadas a QuickMessages
          if (message.contains('[QuickMessages]')) {
            debugPrint('🔵 [QuickMessages Console] ${consoleMessage.message}');
          }
          
          // ✅ Apenas loga erros críticos do console
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            _writeErrorToFile('Erro JavaScript: ${consoleMessage.message}');
          }
        } catch (e) {
          _writeErrorToFile('Erro ao processar onConsoleMessage: $e');
        }
      },
      onReceivedHttpError: (controller, request, response) {
        try {
          // ✅ Apenas loga erros HTTP críticos (5xx)
          final statusCode = response.statusCode;
          if (statusCode != null && statusCode >= 500) {
            _writeErrorToFile('Erro HTTP crítico: ${request.url} - Status: $statusCode');
          }
        } catch (e) {
          _writeErrorToFile('Erro ao processar onReceivedHttpError: $e');
        }
      },
      // Handler para solicitações de permissão
      onPermissionRequest: (controller, request) async {
        try {
          // Concede permissões básicas para evitar crashes
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Permission error: $e\nStack: $stackTrace');
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY,
          );
        }
      },
      // Handler para eventos de foco da janela (pode indicar problemas)
      onWindowFocus: (controller) {
        try {
          _isWebViewAlive = true;
        } catch (e) {
          _writeErrorToFile('Erro em onWindowFocus: $e');
        }
      },
      onWindowBlur: (controller) {
        // ✅ Sem logs - evento normal
      },
      // Handler para download (pode causar crashes se não tratado)
      onDownloadStartRequest: (controller, downloadStartRequest) async {
        try {
          final url = downloadStartRequest.url.toString();
          final contentDisposition = downloadStartRequest.contentDisposition ?? '';
          final suggestedFilename = downloadStartRequest.suggestedFilename ?? '';
          final mimeType = downloadStartRequest.mimeType?.toLowerCase() ?? '';
          
          CompactLogger.logUrl('📥 Download iniciado', url);
          CompactLogger.logFile('   Arquivo sugerido', suggestedFilename.isNotEmpty ? suggestedFilename : 'sem nome');
          CompactLogger.log('   MIME', mimeType.isNotEmpty ? mimeType : 'desconhecido');
          
          // ✅ Extrai nome do arquivo do Content-Disposition se disponível
          String fileNameFromDisposition = '';
          if (contentDisposition.isNotEmpty) {
            try {
              final contentDispositionLower = contentDisposition.toLowerCase();
              if (contentDispositionLower.contains('filename=')) {
                // Extrai o nome do arquivo do Content-Disposition
                final filenameIndex = contentDispositionLower.indexOf('filename=');
                if (filenameIndex != -1) {
                  var extractedName = contentDisposition.substring(filenameIndex + 9).trim();
                  // Remove até o primeiro ponto e vírgula ou fim da string
                  final semicolonIndex = extractedName.indexOf(';');
                  if (semicolonIndex != -1) {
                    extractedName = extractedName.substring(0, semicolonIndex).trim();
                  }
                  // Remove aspas se houver
                  if (extractedName.startsWith('"') && extractedName.endsWith('"')) {
                    extractedName = extractedName.substring(1, extractedName.length - 1);
                  } else if (extractedName.startsWith("'") && extractedName.endsWith("'")) {
                    extractedName = extractedName.substring(1, extractedName.length - 1);
                  }
                  fileNameFromDisposition = extractedName;
                  // Decodifica se estiver codificado
                  if (fileNameFromDisposition.contains('%')) {
                    fileNameFromDisposition = Uri.decodeComponent(fileNameFromDisposition);
                  }
                }
              }
            } catch (e) {
              // Ignora erros ao extrair
            }
          }
          
          // ✅ Detecta APENAS downloads reais de arquivos PDF:
          final urlLower = url.toLowerCase();
          final suggestedFilenameLower = suggestedFilename.toLowerCase();
          final fileNameFromDispositionLower = fileNameFromDisposition.toLowerCase();
          final isBlobUrl = urlLower.startsWith('blob:');
          final isPdf = (urlLower.endsWith('.pdf') || urlLower.contains('.pdf?')) ||
                        (isBlobUrl && suggestedFilenameLower.endsWith('.pdf')) ||
                        suggestedFilenameLower.endsWith('.pdf') ||
                        (fileNameFromDispositionLower.endsWith('.pdf')) ||
                        (contentDisposition.toLowerCase().contains('filename=') && contentDisposition.toLowerCase().contains('.pdf')) ||
                        mimeType == 'application/pdf' ||
                        mimeType == 'application/x-pdf';
          
          if (isPdf) {
            CompactLogger.logUrl('📄 PDF no download - cancelando', url);
            
            // ✅ Prioriza: Content-Disposition > suggestedFilename > URL > padrão
            String fileName = 'arquivo.pdf';
            if (fileNameFromDisposition.isNotEmpty && fileNameFromDispositionLower.endsWith('.pdf')) {
              fileName = fileNameFromDisposition; // ✅ Usa o nome original (não lowercase)
            } else if (suggestedFilename.isNotEmpty && suggestedFilenameLower.endsWith('.pdf')) {
              fileName = suggestedFilename; // ✅ Usa o nome original (não lowercase)
            } else if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf?')) {
              fileName = url.split('/').last.split('?').first;
              if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.pdf')) {
                fileName = 'arquivo.pdf';
              }
            }
            
            CompactLogger.logFile('   Arquivo final', fileName);
            
            // ✅ Para blob URLs, NÃO salva ainda - aguarda a conversão para data URL
            // ✅ Para URLs normais, salva imediatamente
            if (!isBlobUrl && fileName.isNotEmpty) {
              _saveDownloadToHistory(fileName, url, 0);
            }
            
            // ✅ Para blob URLs, precisamos converter para uma URL que possa ser aberta
            // Usa JavaScript para converter e chamar handler de callback
            if (isBlobUrl && widget.onNewTabRequested != null) {
              CompactLogger.log('📄 Convertendo blob para data URL...');
              // Injeta código JavaScript que converte e chama um handler de callback
              controller.evaluateJavascript(source: '''
                (function() {
                  try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', '$url', true);
                    xhr.responseType = 'blob';
                    xhr.onload = function() {
                      if (xhr.status === 200) {
                        var reader = new FileReader();
                        reader.onloadend = function() {
                          // Chama handler de callback com a data URL e nome do arquivo
                          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                            window.flutter_inappwebview.callHandler('onPdfDataUrlReady', reader.result, '$fileName');
                          }
                        };
                        reader.onerror = function() {
                          console.error('Erro ao ler blob');
                        };
                        reader.readAsDataURL(xhr.response);
                      }
                    };
                    xhr.onerror = function() {
                      console.error('Erro na requisição blob');
                    };
                    xhr.send();
                  } catch (e) {
                    console.error('Erro ao converter blob:', e);
                  }
                })();
              ''');
              // Cancela o download - a conversão será feita assincronamente e o handler abrirá a janela
              return; // Cancela o download
            } else {
              // ✅ Para URLs normais, já salvou acima, apenas abre diretamente
              if (widget.onNewTabRequested != null) {
                widget.onNewTabRequested!(url);
              }
              // Cancela o download - já foi salvo no histórico e será aberto em nova janela
              return;
            }
            
            // ✅ IMPORTANTE: Não retorna nada para cancelar o download
            // O download será cancelado porque não iniciamos o processo de download
            return;
          }
          
          // ✅ Para outros tipos de arquivo, salva no histórico e permite o download normal
          final fileName = suggestedFilename.isNotEmpty 
              ? suggestedFilename 
              : url.split('/').last.split('?').first;
          _saveDownloadToHistory(fileName, url, 0);
          CompactLogger.logUrl('📥 Download permitido', url);
        } catch (e) {
          debugPrint('Erro ao processar download: $e');
        }
      },
      // Handler para novas janelas (pop-ups)
      onCreateWindow: (controller, createWindowAction) async {
        final url = createWindowAction.request.url?.toString() ?? '';
        
        if (url.isNotEmpty && url != 'null') {
          try {
            // ✅ Verifica a configuração do usuário
            if (widget.openLinksMode == 'external_browser') {
              // ✅ Adiciona a URL à lista de URLs que devem ser abertas no navegador externo
              // Isso permite interceptar a navegação no shouldOverrideUrlLoading
              _externalBrowserUrls.add(url);
              
              // ✅ Abre no navegador externo padrão
              CompactLogger.log('=== POP-UP INTERCEPTADO - ABRINDO NO NAVEGADOR EXTERNO ===');
              CompactLogger.logUrl('URL', url);
              CompactLogger.log('Tab', widget.tab.id);
              
              Future.microtask(() async {
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication, // Abre no navegador padrão
                    );
                    CompactLogger.log('✅ Link aberto no navegador externo');
                    
                    // ✅ Remove a URL da lista após um delay para permitir interceptação
                    Future.delayed(const Duration(seconds: 2), () {
                      _externalBrowserUrls.remove(url);
                    });
                  } else {
                    CompactLogger.log('❌ Não foi possível abrir URL: $url');
                    _externalBrowserUrls.remove(url);
                  }
                } catch (e) {
                  CompactLogger.log('❌ Erro ao abrir no navegador externo: $e');
                  _externalBrowserUrls.remove(url);
                }
              });
              
              // ✅ Retorna false para não criar nova janela (já abriu no navegador externo)
              return false;
            } else {
              // ✅ CRÍTICO: Usa windowId para manter a ligação entre popup e janela principal
              // Isso é ESSENCIAL para OAuth funcionar corretamente - permite window.opener e postMessage
              final windowId = createWindowAction.windowId;
              
              if (windowId == null) {
                CompactLogger.log('⚠️ windowId não disponível, usando fallback...');
                // ✅ Fallback: se não tiver windowId, ainda abre no dialog mas sem a ligação
                _popupUrls.add(url);
                Future.delayed(const Duration(seconds: 5), () {
                  _popupUrls.remove(url);
                });
                
                Future.microtask(() {
                  if (mounted && context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (dialogContext) {
                        return Dialog(
                          insetPadding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 520,
                            height: 740,
                            child: InAppWebView(
                              initialUrlRequest: URLRequest(url: WebUri(url)),
                              initialSettings: InAppWebViewSettings(
                                supportMultipleWindows: true,
                                javaScriptCanOpenWindowsAutomatically: true,
                              ),
                              onCloseWindow: (controller) {
                                Navigator.of(dialogContext).pop();
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }
                });
                return false;
              }
              
              // ✅ SEMPRE abre popup em Dialog dentro da mesma janela usando windowId
              // Isso garante compartilhamento de cookies/sessão E comunicação OAuth (window.opener)
              CompactLogger.log('=== POP-UP INTERCEPTADO - ABRINDO EM DIALOG COM windowId ===');
              CompactLogger.logUrl('URL', url);
              CompactLogger.log('Tab', widget.tab.id);
              CompactLogger.log('WindowId', windowId.toString());
              CompactLogger.log('Modo configurado', widget.openLinksMode);
              
              // ✅ CRÍTICO: Adiciona a URL à lista de popups para bloquear navegação na página principal
              _popupUrls.add(url);
              // ✅ Remove a URL da lista após um delay para permitir navegação normal depois
              Future.delayed(const Duration(seconds: 5), () {
                _popupUrls.remove(url);
              });
              
              // ✅ Abre o popup em um Dialog na mesma janela do app usando windowId
              // O windowId mantém a ligação entre popup e opener, permitindo OAuth funcionar
              // ✅ Armazena a URL e windowId para uso no dialog
              final popupUrl = url;
              final popupWindowId = windowId;
              final popupRequestUrl = createWindowAction.request.url;
              
              Future.microtask(() {
                if (mounted && context.mounted) {
                  // ✅ Armazena o Future do dialog para detectar quando é fechado
                  bool _isDialogClosing = false; // ✅ Flag para evitar fechar múltiplas vezes
                  
                  final dialogFuture = showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (dialogContext) {
                      InAppWebViewController? popupController;
                      String currentTitle = 'Nova Janela';
                      
                      return StatefulBuilder(
                        builder: (context, setDialogState) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(20),
                          child: Container(
                            width: 520,
                            height: 700,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                // ✅ Barra de título personalizada
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          currentTitle,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[800],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () {
                                          _isDialogClosing = true;
                                          Navigator.of(dialogContext).pop();
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                  ),
                                ),
                                // ✅ WebView do popup COM windowId - CRÍTICO para OAuth
                                Expanded(
                                  child: InAppWebView(
                                    // ✅ CRÍTICO: Usa o mesmo ambiente WebView2 da aba principal
                                    // Isso é ESSENCIAL para windowId funcionar corretamente e manter a ligação
                                    webViewEnvironment: widget.tab.environment,
                                    // ✅ CRÍTICO: windowId mantém a ligação com a janela principal
                                    // Isso permite window.opener e postMessage funcionarem corretamente
                                    windowId: popupWindowId,
                                    initialSettings: InAppWebViewSettings(
                                      // ✅ IMPORTANTE: Mantém suporte a múltiplas janelas para OAuth funcionar
                                      supportMultipleWindows: true,
                                      javaScriptCanOpenWindowsAutomatically: true,
                                      javaScriptEnabled: true,
                                      domStorageEnabled: true,
                                      databaseEnabled: true,
                                      thirdPartyCookiesEnabled: true,
                                    ),
                                    onWebViewCreated: (controller) async {
                                      popupController = controller;
                                      // ✅ Com windowId, o WebView2 deve carregar automaticamente a URL do createWindowAction.request.url
                                      // Mas adiciona um fallback caso não carregue automaticamente após um tempo
                                      CompactLogger.log('✅ Popup WebView criado com windowId - aguardando carregamento automático...');
                                      
                                      // ✅ Fallback: se não carregar em 1 segundo, carrega manualmente
                                      Future.delayed(const Duration(milliseconds: 1000), () async {
                                        try {
                                          final currentUrl = await controller.getUrl();
                                          if (currentUrl == null || currentUrl.toString().isEmpty || currentUrl.toString() == 'about:blank') {
                                            CompactLogger.log('⚠️ Popup não carregou automaticamente, carregando manualmente...');
                                            final urlToLoad = popupRequestUrl ?? WebUri(popupUrl);
                                            await controller.loadUrl(urlRequest: URLRequest(url: urlToLoad));
                                          }
                                        } catch (e) {
                                          CompactLogger.log('⚠️ Erro ao verificar/carregar URL no popup: $e');
                                        }
                                      });
                                    },
                                    onLoadStart: (controller, popupUrl) {
                                      // ✅ Atualiza título do dialog
                                      try {
                                        final uri = Uri.parse(popupUrl?.toString() ?? '');
                                        if (uri.host.isNotEmpty) {
                                          setDialogState(() {
                                            currentTitle = uri.host;
                                          });
                                        }
                                      } catch (e) {
                                        // Ignora erros
                                      }
                                    },
                                    onTitleChanged: (controller, title) {
                                      // ✅ Atualiza título do dialog
                                      if (title != null && title.isNotEmpty) {
                                        setDialogState(() {
                                          currentTitle = title;
                                        });
                                      }
                                    },
                                    onLoadStop: (controller, popupUrl) async {
                                      // ✅ Quando a página carrega, apenas registra o evento
                                      final urlStr = popupUrl?.toString() ?? '';
                                      CompactLogger.log('📋 Popup carregou: $urlStr');
                                      
                                      // ✅ Detecta URLs de sucesso de login (Google OAuth) apenas para log
                                      // Com windowId, o OAuth deve funcionar automaticamente via window.opener
                                      if (urlStr.contains('/__/auth/handler') && urlStr.contains('code=')) {
                                        CompactLogger.log('✅ Login detectado como bem-sucedido (code presente)');
                                        // ✅ Com windowId, o site pode comunicar com a janela principal automaticamente
                                      }
                                    },
                                    onCloseWindow: (controller) {
                                      // ✅ Quando o site pede para fechar o popup, fecha o dialog
                                      // Com windowId, o OAuth já comunicou com a janela principal via window.opener
                                      // O site chamou window.opener.postMessage ou window.close() após processar o login
                                      if (!_isDialogClosing && mounted && dialogContext.mounted) {
                                        _isDialogClosing = true;
                                        CompactLogger.log('✅ Site solicitou fechamento do popup (onCloseWindow) - OAuth comunicou via window.opener');
                                        Navigator.of(dialogContext).pop();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                  
                  // ✅ Com windowId, o OAuth deve comunicar automaticamente com a janela principal
                  // Quando o dialog fecha, verifica se precisa navegar para redirect ou apenas recarregar
                  dialogFuture.then((_) async {
                    if (mounted) {
                      CompactLogger.log('🔄 Dialog fechado, verificando se precisa atualizar página principal...');
                      // ✅ Aguarda um pouco para garantir que o OAuth processou tudo via window.opener
                      await Future.delayed(const Duration(milliseconds: 1000));
                      
                      if (_controller != null) {
                        try {
                          final currentUrl = await _controller!.getUrl();
                          final currentUrlStr = currentUrl?.toString() ?? '';
                          
                          // ✅ Se está na página de login com redirect, navega para o redirect
                          if (currentUrlStr.contains('/login') && currentUrlStr.contains('redirect=')) {
                            try {
                              final uri = Uri.parse(currentUrlStr);
                              final redirectParam = uri.queryParameters['redirect'];
                              if (redirectParam != null && redirectParam.isNotEmpty) {
                                final redirectUrl = Uri.decodeComponent(redirectParam);
                                CompactLogger.log('🔄 Navegando para URL de redirect após login OAuth...');
                                CompactLogger.logUrl('   Redirect URL', redirectUrl);
                                await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(redirectUrl)));
                                return;
                              }
                            } catch (e) {
                              CompactLogger.log('⚠️ Erro ao processar redirect: $e');
                            }
                          }
                          
                          // ✅ Se não tem redirect, apenas recarrega para aplicar cookies/sessão
                          CompactLogger.log('🔄 Recarregando página principal para aplicar autenticação...');
                          await _controller!.reload();
                          CompactLogger.log('✅ Página principal atualizada');
                        } catch (e) {
                          CompactLogger.log('⚠️ Erro ao atualizar página: $e');
                        }
                      }
                    }
                  }).catchError((e) {
                    CompactLogger.log('⚠️ Erro ao fechar dialog: $e');
                  });
                }
              });
              
              // ✅ Retorna true para indicar que lidamos com a criação da janela
              // Com windowId, o popup está conectado à janela principal
              return true;
            }
          } catch (e) {
            CompactLogger.log('❌ Erro ao processar pop-up: $e');
            return false;
          }
        }
        
        // ✅ Retorna false por padrão para não criar nova janela
        return false;
      },
      // Handler para fechamento de janela
      onCloseWindow: (controller) {
        // ✅ Sem logs - fechamento de janela é evento normal
      },
      // Handler para erros de SSL
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        try {
          // Aceita certificados para evitar crashes
          return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('SSL processing error: $e\nStack: $stackTrace');
          return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
        }
      },
      );
    } catch (e, stackTrace) {
      // ✅ Apenas loga erros críticos
      _writeErrorToFile('Erro crítico no build do WebView: $e\nStack: $stackTrace');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Erro ao carregar página'),
            SizedBox(height: 8),
            Text('Tente recarregar ou abrir outra página'),
          ],
        ),
      );
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    
    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();
    
    widget.tab.updateNavigationState(
      isLoading: false,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
    );
    
    widget.onNavigationStateChanged(false, canGoBack, canGoForward);
  }

  /// Mostra o diálogo de histórico de downloads
  void _showDownloadHistory() {
    if (!mounted) return;
    
    // ✅ Gera um pageId único para esta página
    // Para páginas simples: usa apenas o tabId
    // Para multi-páginas: será passado pelo MultiPageWebView
    final pageId = widget.tab.id;
    
    showDialog(
      context: context,
      builder: (context) => DownloadHistoryDialog(
        pageId: pageId,
        onFileSelected: (filePath) {
          // Abre o arquivo em uma nova janela
          if (widget.onNewTabRequested != null) {
            widget.onNewTabRequested!(filePath);
          }
        },
      ),
    );
  }

  /// Salva um download no histórico da página
  void _saveDownloadToHistory(String fileName, String filePath, int fileSize) {
    try {
      // ✅ Garante que o fileName não está vazio
      final finalFileName = fileName.isNotEmpty ? fileName : 'arquivo.pdf';
      
      // ✅ Gera um pageId único para esta página
      final pageId = widget.tab.id;
      
      debugPrint('📥 ===== SALVANDO DOWNLOAD =====');
      debugPrint('   Nome: $finalFileName');
      debugPrint('   PageId: $pageId');
      debugPrint('   FilePath: ${filePath.startsWith('data:') ? 'data: (base64)' : CompactLogger.shortenUrl(filePath)}');
      
      final download = DownloadItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${finalFileName.hashCode}',
        fileName: finalFileName,
        filePath: filePath, // Pode ser URL ou data URL
        downloadDate: DateTime.now(),
        fileSize: fileSize,
      );
      
      // ✅ Salva no histórico da página específica (armazenado em memória)
      PageDownloadHistoryService.saveDownload(pageId, download);
      
      // ✅ Verifica se foi salvo corretamente
      final downloads = PageDownloadHistoryService.getDownloads(pageId);
      debugPrint('   ✅ Download salvo! Total na página: ${downloads.length}');
      debugPrint('📥 ===============================');
      
      CompactLogger.logFile('✅ Download salvo', finalFileName);
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao salvar download no histórico: $e');
      debugPrint('   Stack: ${stackTrace.toString().substring(0, stackTrace.toString().length > 200 ? 200 : stackTrace.toString().length)}...');
    }
  }

  /// ✅ Inicia monitoramento de cookies para sincronizar quando popups fecharem
  void _startCookieSyncMonitoring() {
    // ✅ Se já está monitorando, não inicia outro timer
    if (_cookieSyncTimer != null && _cookieSyncTimer!.isActive) {
      return;
    }
    
    // ✅ Monitora a cada 2 segundos se alguma popup fechou
    _cookieSyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _popupTabIds.isEmpty) {
        timer.cancel();
        _cookieSyncTimer = null;
        return;
      }
      
      // ✅ Verifica quais popups ainda estão abertas
      final closedPopups = <String>[];
      for (final tabId in _popupTabIds) {
        // ✅ Verifica se a janela ainda existe no registro
        final windowController = WindowRegistry.getController(tabId);
        if (windowController == null) {
          closedPopups.add(tabId);
        }
      }
      
      // ✅ Se alguma popup fechou, sincroniza cookies e recarrega
      if (closedPopups.isNotEmpty) {
        CompactLogger.log('📋 Popup fechada detectada, sincronizando cookies...');
        for (final tabId in closedPopups) {
          _popupTabIds.remove(tabId);
        }
        _syncCookiesAndReload();
      }
    });
  }
  
  /// ✅ Sincroniza cookies de todas as URLs relacionadas e recarrega a página principal
  Future<void> _syncCookiesAndReload() async {
    try {
      if (_controller == null || !mounted) return;
      
      final cookieManager = CookieManager.instance();
      final currentUrl = await _controller!.getUrl();
      final currentUrlStr = currentUrl?.toString() ?? '';
      
      if (currentUrlStr.isEmpty) return;
      
      CompactLogger.log('📋 Sincronizando cookies e recarregando página principal...');
      CompactLogger.logUrl('   URL atual', currentUrlStr);
      
      // ✅ Obtém todos os cookies atualizados do domínio atual
      final currentUri = Uri.parse(currentUrlStr);
      final cookies = await cookieManager.getCookies(url: WebUri(currentUrlStr));
      
      // ✅ Obtém cookies do domínio raiz também
      List<Cookie> allCookies = List.from(cookies);
      if (currentUri.host.isNotEmpty) {
        final parts = currentUri.host.split('.');
        if (parts.length >= 2) {
          final rootDomain = '.${parts.skip(parts.length - 2).join('.')}';
          try {
            final rootCookies = await cookieManager.getCookies(url: WebUri('https://$rootDomain'));
            allCookies.addAll(rootCookies);
            CompactLogger.log('📋 Cookies do domínio raiz ($rootDomain): ${rootCookies.length}');
          } catch (e) {
            // Ignora erros
          }
        }
      }
      
      // ✅ CRÍTICO: Também tenta obter cookies do domínio de autenticação (auth.lovable.dev)
      // Isso garante que cookies de autenticação sejam compartilhados
      try {
        final authCookies = await cookieManager.getCookies(url: WebUri('https://auth.lovable.dev'));
        allCookies.addAll(authCookies);
        CompactLogger.log('📋 Cookies do domínio de autenticação (auth.lovable.dev): ${authCookies.length}');
      } catch (e) {
        CompactLogger.log('⚠️ Erro ao obter cookies de autenticação: $e');
      }
      
      // ✅ Tenta obter cookies do domínio principal também (lovable.dev)
      try {
        final mainCookies = await cookieManager.getCookies(url: WebUri('https://lovable.dev'));
        allCookies.addAll(mainCookies);
        CompactLogger.log('📋 Cookies do domínio principal (lovable.dev): ${mainCookies.length}');
      } catch (e) {
        CompactLogger.log('⚠️ Erro ao obter cookies do domínio principal: $e');
      }
      
      CompactLogger.log('📋 Total de cookies sincronizados: ${allCookies.length}');
      
      // ✅ Aguarda um pouco mais para garantir que os cookies foram processados
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ✅ Recarrega a página para aplicar os novos cookies
      if (mounted && _controller != null) {
        CompactLogger.log('🔄 Recarregando página principal para aplicar cookies...');
        await _controller!.reload();
        CompactLogger.log('✅ Página principal recarregada com cookies sincronizados');
      }
    } catch (e) {
      CompactLogger.log('⚠️ Erro ao sincronizar cookies: $e');
      // ✅ Se houver erro na sincronização, ainda tenta recarregar
      if (mounted && _controller != null) {
        try {
          await _controller!.reload();
        } catch (e2) {
          CompactLogger.log('⚠️ Erro ao recarregar após falha na sincronização: $e2');
        }
      }
    }
  }

  /// ✅ Recarrega a página principal após login no popup
  void _reloadMainPage() {
    Future.microtask(() async {
      try {
        if (_controller != null && mounted) {
          CompactLogger.log('🔄 Recarregando página principal após login...');
          await _controller!.reload();
          CompactLogger.log('✅ Página principal recarregada');
        }
      } catch (e) {
        CompactLogger.log('⚠️ Erro ao recarregar página principal: $e');
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _cookieSyncTimer?.cancel();
    // ✅ Remove listener quando o widget é descartado
    _globalQuickMessages.removeListener(_onQuickMessagesChanged);
    // Não dispose o controller aqui, o TabManager faz isso
    super.dispose();
  }
}
