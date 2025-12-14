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
import '../services/download_history_service.dart';
import '../services/page_download_history_service.dart';
import '../services/quick_message_usage_service.dart';
import '../services/zoom_service.dart';
import '../utils/compact_logger.dart';
import 'page_navigation_bar.dart';
import 'collapsible_navigation_bar.dart';
import 'download_history_dialog.dart';

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
  final bool enableQuickMessages; // ✅ Se true, permite usar atalhos rápidos nesta aba
  final Function(String, String?)? onQuickMessageHint; // ✅ Callback para notificações de hint (type, shortcut)
  final String? iconUrl; // ✅ URL do ícone da página
  final String? pageName; // ✅ Nome da página
  final Function(String)? onNewTabRequested; // ✅ Callback para criar nova aba com URL
  final bool isPdfWindow; // ✅ Indica se esta é uma janela de PDF (não deve interceptar PDFs)
  final bool isAlwaysOnTop; // ✅ Indica se a janela está fixada (alwaysOnTop)
  final bool? externalNavBarVisibility; // ✅ Controle externo da visibilidade da barra de navegação

  const BrowserWebViewWindows({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
    this.quickMessages = const [], // ✅ Default vazio
    this.enableQuickMessages = true, // ✅ Por padrão, atalhos rápidos estão habilitados
    this.onQuickMessageHint, // ✅ Callback opcional para hints
    this.iconUrl, // ✅ Ícone opcional
    this.pageName, // ✅ Nome opcional
    this.onNewTabRequested, // ✅ Callback opcional para criar nova aba
    this.isPdfWindow = false, // ✅ Por padrão, não é uma janela de PDF
    this.isAlwaysOnTop = false, // ✅ Por padrão, não está fixada
    this.externalNavBarVisibility, // ✅ Controle externo opcional da visibilidade
  });

  @override
  State<BrowserWebViewWindows> createState() => _BrowserWebViewWindowsState();
}

class _BrowserWebViewWindowsState extends State<BrowserWebViewWindows> {
  InAppWebViewController? _controller;
  Timer? _heartbeatTimer;
  bool _isWebViewAlive = true;
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
      debugPrint('[BrowserWebViewWindows] ✅ Zoom carregado para ${widget.tab.id}: $_currentZoom');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao carregar zoom: $e');
    }
  }

  /// ✅ Aplica zoom usando JavaScript (afeta apenas o conteúdo, mantém container ocupando toda tela)
  /// ✅ Funciona igual para janelas com uma única página e múltiplas páginas
  /// ✅ Mesma implementação usada em abas que funciona corretamente
  Future<void> _applyZoom(double zoom) async {
    if (_controller == null) return;
    try {
      // ✅ Aguarda um pouco para garantir que o WebView está totalmente inicializado
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Usa JavaScript para aplicar zoom no conteúdo da página
      // A página continua ocupando toda a tela, mas o conteúdo interno tem zoom aplicado
      final zoomValue = zoom.toString();
      await _controller!.evaluateJavascript(source: '''
        (function() {
          try {
            // Verifica se document está disponível
            if (!document) {
              console.warn('Document não disponível para aplicar zoom');
              return;
            }
            
            // Remove zoom anterior se existir
            var existingZoom = document.getElementById('flutter-zoom-style');
            if (existingZoom) {
              existingZoom.remove();
            }
            
            // Remove estilos inline anteriores do html e body
            if (document.documentElement) {
              document.documentElement.style.zoom = '';
              document.documentElement.style.transform = '';
              document.documentElement.style.transformOrigin = '';
              document.documentElement.style.width = '';
              document.documentElement.style.height = '';
            }
            if (document.body) {
              document.body.style.zoom = '';
              document.body.style.transform = '';
              document.body.style.transformOrigin = '';
              document.body.style.width = '';
              document.body.style.height = '';
            }
            
            // Se zoom for 1.0, não precisa aplicar nada
            var zoomValue = parseFloat('$zoomValue');
            if (zoomValue === 1.0 || isNaN(zoomValue)) {
              return;
            }
            
            // ✅ Aplica zoom usando CSS zoom no html e body
            // ✅ IMPORTANTE: O zoom CSS afeta apenas o conteúdo renderizado, não o tamanho do container
            // ✅ O WebView continua ocupando toda a tela, mas o conteúdo interno tem zoom aplicado
            // ✅ Usa zoom CSS que escala o conteúdo sem afetar o layout do container
            
            // ✅ Aplica zoom diretamente no html (elemento raiz)
            // ✅ Isso garante que todo o conteúdo seja escalado, mas o container do WebView mantém seu tamanho
            if (document.documentElement) {
              document.documentElement.style.zoom = zoomValue;
              // Garante que o html ocupe toda a largura e altura disponível
              document.documentElement.style.width = '100%';
              document.documentElement.style.height = '100%';
              document.documentElement.style.margin = '0';
              document.documentElement.style.padding = '0';
              document.documentElement.style.boxSizing = 'border-box';
            }
            
            // ✅ Também aplica no body para garantir compatibilidade
            if (document.body) {
              document.body.style.zoom = zoomValue;
              // Garante que o body ocupe toda a largura e altura disponível
              document.body.style.width = '100%';
              document.body.style.height = '100%';
              document.body.style.margin = '0';
              document.body.style.padding = '0';
              document.body.style.boxSizing = 'border-box';
            }
            
            // ✅ Cria um estilo CSS como backup para garantir que o zoom seja aplicado
            // ✅ E que os elementos ocupem toda a tela mesmo com zoom aplicado
            if (document.head) {
              var style = document.createElement('style');
              style.id = 'flutter-zoom-style';
              style.textContent = 'html { zoom: ' + zoomValue + ' !important; width: 100% !important; height: 100% !important; margin: 0 !important; padding: 0 !important; box-sizing: border-box !important; } body { zoom: ' + zoomValue + ' !important; width: 100% !important; height: 100% !important; margin: 0 !important; padding: 0 !important; box-sizing: border-box !important; }';
              document.head.appendChild(style);
            }
            
            // ✅ Força um reflow para garantir que o zoom seja aplicado corretamente
            // ✅ Isso força o navegador a recalcular o layout e aplicar o zoom
            void(0);
            document.documentElement.offsetHeight;
          } catch (e) {
            console.error('Erro ao aplicar zoom:', e);
          }
        })();
      ''');
      debugPrint('[BrowserWebViewWindows] ✅ Zoom aplicado via JavaScript: $zoom');
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
      debugPrint('[BrowserWebViewWindows] ✅ Zoom aumentado para: $newZoom');
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
      debugPrint('[BrowserWebViewWindows] ✅ Zoom diminuído para: $newZoom');
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
      debugPrint('[BrowserWebViewWindows] ✅ Zoom restaurado para padrão: $defaultZoom');
    } catch (e) {
      debugPrint('[BrowserWebViewWindows] ❌ Erro ao restaurar zoom: $e');
    }
  }

  /// ✅ Aplica o zoom salvo na página
  /// ✅ Mesma implementação usada em abas e janelas com múltiplas páginas
  Future<void> _applySavedZoom() async {
    if (_controller == null) return;
    
    // ✅ Se o zoom é 1.0 (padrão), não precisa aplicar nada
    if (_currentZoom == 1.0) {
      debugPrint('[BrowserWebViewWindows] ✅ Zoom padrão (1.0), não precisa aplicar');
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
              debugPrint('[BrowserWebViewWindows] ✅ Zoom salvo aplicado após ${attempts * 200}ms: $_currentZoom');
            }
            return; // Sai do loop se aplicou com sucesso
          }
        } catch (e) {
          // Se der erro, pode ser que o WebView ainda não esteja pronto
          // Não loga erro a cada tentativa para não poluir o log
          if (attempts % 5 == 0) {
            debugPrint('[BrowserWebViewWindows] ⚠️ Aguardando WebView ficar pronto (tentativa ${attempts + 1}/$maxAttempts)');
          }
        }
        
        // Aguarda antes de tentar novamente
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      
      // ✅ Se não conseguiu aplicar após todas as tentativas, tenta aplicar mesmo assim
      if (attempts >= maxAttempts && _controller != null && mounted) {
        debugPrint('[BrowserWebViewWindows] ⚠️ Timeout ao aplicar zoom salvo, tentando aplicar mesmo assim...');
        try {
          await _applyZoom(_currentZoom);
          debugPrint('[BrowserWebViewWindows] ✅ Zoom aplicado após timeout');
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
      // ✅ Prioriza widget.quickMessages (passado como parâmetro) para janelas secundárias
      // ✅ Se widget.quickMessages estiver vazio, usa mensagens do serviço global (para abas da janela principal)
      final currentMessages = widget.quickMessages.isNotEmpty 
          ? widget.quickMessages 
          : _globalQuickMessages.messages;
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
      
      // Atualiza os scripts com as novas mensagens
      await _quickMessagesInjector.injectQuickMessagesSupport(
        _controller!,
        activationKey: activationKey,
        messages: currentMessages,
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
              supportZoom: false, // Desabilita zoom que pode causar problemas
              builtInZoomControls: false,
              displayZoomControls: false,
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
                      
                      // Intercepta TODOS os cliques ANTES do download começar (incluindo links com atributo download)
                      document.addEventListener('click', function(e) {
                        var target = e.target;
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
                      }, true);
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
          // ✅ Prioriza widget.quickMessages (passado como parâmetro) para janelas secundárias
          // ✅ Se widget.quickMessages estiver vazio, usa mensagens do serviço global (para abas da janela principal)
          final currentMessages = widget.quickMessages.isNotEmpty 
              ? widget.quickMessages 
              : _globalQuickMessages.messages;
          debugPrint('[QuickMessages] 🔍 Verificando condições para injeção:');
          debugPrint('[QuickMessages]   └─ Mensagens do widget: ${widget.quickMessages.length}');
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
              
              // Aguarda a página carregar completamente antes de injetar
              await Future.delayed(const Duration(milliseconds: 1000));
              debugPrint('[QuickMessages] 🔄 Injetando script (primeira tentativa)...');
              await _quickMessagesInjector.injectQuickMessagesSupport(
                controller,
                activationKey: activationKey, // ✅ Passa a tecla de ativação
                messages: currentMessages, // ✅ Usa mensagens do serviço global (sempre atualizadas)
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
                  
                  // Intercepta TODOS os cliques ANTES do download começar (incluindo links com atributo download)
                  document.addEventListener('click', function(e) {
                    var target = e.target;
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
                  }, true);
                  
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
                            }, true);
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
                                }, true);
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
      // Handler para novas janelas (pode causar crashes)
      onCreateWindow: (controller, createWindowAction) async {
        try {
          CompactLogger.log('=== NOVA JANELA ===');
          final url = createWindowAction.request.url?.toString() ?? 'null';
          CompactLogger.logUrl('URL', url);
          CompactLogger.log('Tab', widget.tab.id);
          _writeErrorToFile('New window requested: ${createWindowAction.request.url}');
          // Cancela criação de nova janela para evitar crashes
          return false;
        } catch (e, stackTrace) {
          CompactLogger.log('❌ Erro ao criar janela: $e');
          _writeErrorToFile('Create window error: $e\nStack: $stackTrace');
          return false;
        }
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

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    // ✅ Remove listener quando o widget é descartado
    _globalQuickMessages.removeListener(_onQuickMessagesChanged);
    // Não dispose o controller aqui, o TabManager faz isso
    super.dispose();
  }
}
