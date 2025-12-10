import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import '../services/webview_quick_messages_injector.dart';

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

  const BrowserWebViewWindows({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
    this.quickMessages = const [], // ✅ Default vazio
  });

  @override
  State<BrowserWebViewWindows> createState() => _BrowserWebViewWindowsState();
}

class _BrowserWebViewWindowsState extends State<BrowserWebViewWindows> {
  InAppWebViewController? _controller;
  Timer? _heartbeatTimer;
  bool _isWebViewAlive = true;
  bool _hasInitialized = false; // ✅ Flag para rastrear se o WebView já foi inicializado
  final WebViewQuickMessagesInjector _quickMessagesInjector = WebViewQuickMessagesInjector();

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
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
    
    return _buildWebView();
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
          
          // ✅ Se a aba não foi carregada ainda e tem URL, carrega agora que o controller está pronto
          // ✅ Só carrega se ainda não foi carregada antes
          if (!widget.tab.isLoaded && widget.tab.url.isNotEmpty && widget.tab.url != 'about:blank') {
            Future.microtask(() async {
              try {
                await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
                widget.tab.isLoaded = true;
                debugPrint('✅ URL carregada após criação do WebView: ${widget.tab.url}');
              } catch (e) {
                debugPrint('⚠️ Erro ao carregar URL após criação do WebView: $e');
              }
            });
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
          
          // Atualiza o estado de navegação inicial
          _updateNavigationState();
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro crítico em onWebViewCreated: $e\nStack: $stackTrace');
        }
      },
      onLoadStart: (controller, url) {
        try {
          final urlStr = url?.toString() ?? '';
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          _updateNavigationState();
        } catch (e, stackTrace) {
          // ✅ Apenas loga erros críticos
          _writeErrorToFile('Erro em onLoadStart: $e\nStack: $stackTrace');
        }
      },
      onLoadStop: (controller, url) async {
        try {
          final urlStr = url?.toString() ?? '';
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          
          // ✅ Injeta suporte a mensagens rápidas APENAS se houver mensagens
          // ✅ NÃO injeta automaticamente - só quando o usuário abrir a aba/janela
          if (widget.quickMessages.isNotEmpty) {
            try {
              debugPrint('[QuickMessages] 📍 onLoadStop - Preparando para injetar script');
              debugPrint('[QuickMessages]   └─ URL: $urlStr');
              debugPrint('[QuickMessages]   └─ Aba: ${widget.tab.title}');
              debugPrint('[QuickMessages]   └─ Mensagens disponíveis: ${widget.quickMessages.length}');
              
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
                messages: widget.quickMessages, // ✅ Passa mensagens como parâmetro
                tabName: widget.tab.title, // ✅ Nome da aba para logs
                url: urlStr, // ✅ URL para logs
              );
              // Reinjeta após mais um delay para garantir que funciona em SPAs como WhatsApp
              await Future.delayed(const Duration(milliseconds: 2000));
              debugPrint('[QuickMessages] 🔄 Reinjetando script (segunda tentativa para SPAs)...');
              await _quickMessagesInjector.injectQuickMessagesSupport(
                controller,
                activationKey: activationKey, // ✅ Passa a tecla de ativação
                messages: widget.quickMessages, // ✅ Passa mensagens como parâmetro
                tabName: widget.tab.title, // ✅ Nome da aba para logs
                url: urlStr, // ✅ URL para logs
              );
            } catch (e) {
              debugPrint('[QuickMessages] ❌ Erro ao injetar mensagens rápidas: $e');
            }
          } else {
            debugPrint('[QuickMessages] ⚠️ Nenhuma mensagem rápida disponível para injetar');
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
          // ✅ Apenas loga erros críticos (ignora erros de rede comuns)
          // Loga apenas se não for um erro de rede comum
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
      onDownloadStartRequest: (controller, downloadStartRequest) {
        // ✅ Sem logs - download é evento normal
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
    // Não dispose o controller aqui, o TabManager faz isso
    super.dispose();
  }
}
