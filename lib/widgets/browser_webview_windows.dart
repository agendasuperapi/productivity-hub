import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import '../services/webview_quick_messages_injector.dart';
import '../services/global_quick_messages_service.dart';
import 'page_navigation_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
    // ✅ Se inscreve para receber notificações quando as mensagens mudarem
    _globalQuickMessages.addListener(_onQuickMessagesChanged);
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

      debugPrint('[QuickMessages] 🔄 Atualizando scripts com novas mensagens...');
      debugPrint('[QuickMessages]   └─ URL: $urlStr');
      debugPrint('[QuickMessages]   └─ Total de mensagens: ${currentMessages.length}');
      debugPrint('[QuickMessages]   └─ Atalhos: ${currentMessages.map((m) => m.shortcut).join(", ")}');
      
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
      if (_controller != null && _isWebViewAlive) {
        try {
          // Tenta obter a URL atual como teste de vida (sem log de sucesso)
          _controller!.getUrl().then((url) {
            // ✅ Removido log de sucesso - apenas verifica silenciosamente
          }).catchError((e) {
            // ✅ Apenas loga erros críticos
            _writeErrorToFile('WebView heartbeat failed: $e');
            _isWebViewAlive = false;
          });
        } catch (e) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Critical heartbeat error: $e');
          _isWebViewAlive = false;
        }
      }
    });
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
    
    return Column(
      children: [
        // Barra de navegação individual para esta página
        PageNavigationBar(
          currentUrl: widget.tab.url,
          isLoading: widget.tab.isLoading,
          canGoBack: widget.tab.canGoBack,
          canGoForward: widget.tab.canGoForward,
          iconUrl: widget.iconUrl, // ✅ Passa ícone
          pageName: widget.pageName ?? widget.tab.title, // ✅ Passa nome (usa título da aba como fallback)
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
        ),
        // WebView
        Expanded(
          child: _buildWebView(),
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
          
          // ✅ Marca como inicializado para evitar recarregamento quando volta da Home
          _hasInitialized = true;
          
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
                    debugPrint('Stack: $stackTrace');
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
                    debugPrint('✅ URL carregada após criação do WebView: ${widget.tab.url}');
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
                    debugPrint('📄 PDF clicado via JavaScript: $url');
                    widget.onNewTabRequested!(url);
                  } catch (e) {
                    debugPrint('Erro ao processar clique em PDF: $e');
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
          
          // ✅ Detecta se é um arquivo PDF antes do download começar
          final urlLower = url.toLowerCase();
          final isPdf = urlLower.contains('.pdf') || 
                       urlLower.contains('application/pdf') ||
                       urlLower.contains('application/x-pdf') ||
                       (navigationAction.request.headers?['content-type']?.toString().toLowerCase().contains('application/pdf') ?? false);
          
          if (isPdf) {
            // ✅ IMPORTANTE: Se a aba atual já está carregando um arquivo local (file://),
            // não intercepta - permite que o PDF seja carregado normalmente
            final currentTabUrl = widget.tab.url.toLowerCase();
            if (currentTabUrl.startsWith('file://') && urlLower.startsWith('file://')) {
              // Está tentando carregar um arquivo local na mesma aba que já tem um arquivo local
              // Permite a navegação para que o PDF seja exibido
              debugPrint('📄 PDF local detectado - permitindo carregamento na janela atual: $url');
              return NavigationActionPolicy.ALLOW;
            }
            
            // ✅ Se é uma URL HTTP/HTTPS apontando para PDF, ou se a aba atual não é file://
            // então intercepta e abre em nova janela
            debugPrint('📄 PDF detectado na navegação (shouldOverrideUrlLoading): $url');
            
            // ✅ Abre o PDF em uma nova janela automaticamente
            if (widget.onNewTabRequested != null) {
              // Executa de forma assíncrona para não bloquear
              Future.microtask(() {
                widget.onNewTabRequested!(url);
              });
            }
            
            // ✅ Cancela a navegação atual para evitar download
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
          
          // ✅ Para arquivos PDF locais, não intercepta no onLoadStart
          // Deixa o shouldOverrideUrlLoading tratar isso
          final isLocalPdf = urlStr.toLowerCase().startsWith('file://') && 
                            urlStr.toLowerCase().contains('.pdf');
          
          if (isLocalPdf) {
            debugPrint('📄 PDF local detectado no onLoadStart: $urlStr');
            // Não intercepta - permite que seja carregado normalmente
          } else if (urlStr.toLowerCase().contains('.pdf') && !urlStr.toLowerCase().startsWith('file://')) {
            // Apenas intercepta PDFs HTTP/HTTPS, não arquivos locais
            debugPrint('📄 PDF HTTP detectado no onLoadStart: $urlStr');
            if (widget.onNewTabRequested != null) {
              // Aguarda um pouco para garantir que a aba atual não carregue o PDF
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.onNewTabRequested!(urlStr);
              });
            }
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
          
          // ✅ Para arquivos PDF locais, verifica se o conteúdo foi carregado
          if (urlStr.toLowerCase().startsWith('file://') && urlStr.toLowerCase().contains('.pdf')) {
            debugPrint('📄 PDF local - onLoadStop chamado: $urlStr');
            // Aguarda um pouco e verifica se há conteúdo na página
            Future.delayed(const Duration(milliseconds: 1000), () async {
              try {
                final title = await controller.getTitle();
                final currentUrl = await controller.getUrl();
                debugPrint('📄 Verificação pós-carregamento do PDF:');
                debugPrint('   Título: $title');
                debugPrint('   URL atual: $currentUrl');
                
                // Se o título está vazio ou é "about:blank", pode indicar que o PDF não foi renderizado
                if ((title == null || title.isEmpty || title == 'about:blank') && 
                    currentUrl?.toString().toLowerCase().contains('.pdf') == true) {
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
          // ✅ Usa mensagens do serviço global para sempre ter as mais recentes
          final currentMessages = _globalQuickMessages.messages;
          if (currentMessages.isNotEmpty && widget.enableQuickMessages) {
            try {
              debugPrint('[QuickMessages] 📍 onLoadStop - Preparando para injetar script');
              debugPrint('[QuickMessages]   └─ URL: $urlStr');
              debugPrint('[QuickMessages]   └─ Aba: ${widget.tab.title}');
              debugPrint('[QuickMessages]   └─ Mensagens disponíveis: ${currentMessages.length}');
              
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
            
            // ✅ Injeta script para interceptar cliques em links de PDF
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  try {
                    // Intercepta cliques em links
                    document.addEventListener('click', function(e) {
                      var target = e.target;
                      while (target && target.tagName !== 'A') {
                        target = target.parentElement;
                      }
                      if (target && target.href) {
                        var href = target.href.toLowerCase();
                        if (href.includes('.pdf') || href.includes('application/pdf')) {
                          e.preventDefault();
                          e.stopPropagation();
                          // Notifica o Flutter sobre o PDF
                          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                            window.flutter_inappwebview.callHandler('onPdfLinkClicked', target.href);
                          }
                          return false;
                        }
                      }
                    }, true);
                    
                    // Intercepta downloads de PDF
                    var originalCreateElement = document.createElement;
                    document.createElement = function(tagName) {
                      var element = originalCreateElement.call(document, tagName);
                      if (tagName.toLowerCase() === 'a') {
                        element.addEventListener('click', function(e) {
                          if (this.href && this.href.toLowerCase().includes('.pdf')) {
                            e.preventDefault();
                            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                              window.flutter_inappwebview.callHandler('onPdfLinkClicked', this.href);
                            }
                            return false;
                          }
                        });
                      }
                      return element;
                    };
                  } catch (e) {
                    console.error('Erro ao interceptar PDFs:', e);
                  }
                })();
              ''');
            } catch (e) {
              debugPrint('Erro ao injetar script de interceptação de PDF: $e');
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
          debugPrint('❌ Erro no WebView:');
          debugPrint('   URL: $urlStr');
          debugPrint('   Descrição: ${error.description}');
          debugPrint('   Tipo: ${error.type}');
          debugPrint('   Tab ID: ${widget.tab.id}');
          
          // ✅ Se for um arquivo local, loga especialmente
          if (urlStr.toLowerCase().contains('file://') || urlStr.toLowerCase().contains('.pdf')) {
            debugPrint('⚠️ ERRO AO CARREGAR ARQUIVO LOCAL/PDF!');
            debugPrint('   Isso pode indicar que o WebView2 não consegue renderizar PDFs diretamente');
          }
          
          final errorMsg = '''
Erro no WebView:
URL: $urlStr
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
          final contentDisposition = downloadStartRequest.contentDisposition?.toLowerCase() ?? '';
          final suggestedFilename = downloadStartRequest.suggestedFilename?.toLowerCase() ?? '';
          
          debugPrint('📥 Download iniciado: $url');
          debugPrint('   Content-Disposition: $contentDisposition');
          debugPrint('   Suggested Filename: $suggestedFilename');
          
          // ✅ Detecta se é um arquivo PDF
          final urlLower = url.toLowerCase();
          final isPdf = urlLower.contains('.pdf') || 
                        contentDisposition.contains('.pdf') ||
                        suggestedFilename.endsWith('.pdf') ||
                        contentDisposition.contains('application/pdf');
          
          if (isPdf) {
            debugPrint('📄 PDF detectado no download - abrindo em nova janela automaticamente: $url');
            
            // ✅ Abre o PDF em uma nova janela automaticamente
            if (widget.onNewTabRequested != null) {
              // Executa de forma assíncrona para não bloquear
              Future.microtask(() {
                widget.onNewTabRequested!(url);
              });
            }
            
            // ✅ IMPORTANTE: Não retorna nada para cancelar o download
            // O download será cancelado porque não iniciamos o processo de download
            return;
          }
          
          // ✅ Para outros tipos de arquivo, permite o download normal
          debugPrint('📥 Download permitido (não é PDF): $url');
        } catch (e) {
          debugPrint('Erro ao processar download: $e');
        }
      },
      // Handler para novas janelas (pode causar crashes)
      onCreateWindow: (controller, createWindowAction) async {
        try {
          debugPrint('=== NOVA JANELA SOLICITADA ===');
          debugPrint('URL: ${createWindowAction.request.url}');
          debugPrint('Tab ID: ${widget.tab.id}');
          _writeErrorToFile('New window requested: ${createWindowAction.request.url}');
          // Cancela criação de nova janela para evitar crashes
          return false;
        } catch (e, stackTrace) {
          debugPrint('=== ERRO ao criar nova janela ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
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

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    // ✅ Remove listener quando o widget é descartado
    _globalQuickMessages.removeListener(_onQuickMessagesChanged);
    // Não dispose o controller aqui, o TabManager faz isso
    super.dispose();
  }
}
