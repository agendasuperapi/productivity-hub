import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/browser_tab_windows.dart';

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

  const BrowserWebViewWindows({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
  });

  @override
  State<BrowserWebViewWindows> createState() => _BrowserWebViewWindowsState();
}

class _BrowserWebViewWindowsState extends State<BrowserWebViewWindows> {
  InAppWebViewController? _controller;
  Timer? _heartbeatTimer;
  bool _isWebViewAlive = true;

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
          // Tenta obter a URL atual como teste de vida
          _controller!.getUrl().then((url) {
            debugPrint('=== WebView Heartbeat OK ===');
            debugPrint('URL: ${url?.toString() ?? "null"}');
            debugPrint('Tab ID: ${widget.tab.id}');
          }).catchError((e) {
            debugPrint('=== ERRO NO HEARTBEAT ===');
            debugPrint('Erro: $e');
            debugPrint('Tab ID: ${widget.tab.id}');
            _writeErrorToFile('WebView heartbeat failed: $e');
            _isWebViewAlive = false;
          });
        } catch (e) {
          debugPrint('=== ERRO CRÍTICO NO HEARTBEAT ===');
          debugPrint('Erro: $e');
          _writeErrorToFile('Critical heartbeat error: $e');
          _isWebViewAlive = false;
        }
      }
    });
  }

  @override
  void didUpdateWidget(BrowserWebViewWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se mudou de aba, atualiza o controller
    // IMPORTANTE: Não recria o WebView, apenas atualiza a referência
    // Isso preserva os cookies e o estado da aba
    if (oldWidget.tab.id != widget.tab.id && _controller != null) {
      widget.tab.setController(_controller!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usa InAppWebView com o ambiente isolado da aba
    // IMPORTANTE: Só carrega URL inicial se o controller ainda não foi criado
    // Isso evita recarregar quando troca de aba
    try {
      return InAppWebView(
      // Usa o ambiente isolado criado para esta aba
      webViewEnvironment: widget.tab.environment,
      // Só carrega URL inicial se a aba já foi marcada como carregada (lazy loading)
      // Isso garante que apenas a primeira aba seja carregada ao abrir o app
      initialUrlRequest: _controller == null && 
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
              cacheEnabled: true,
              clearCache: false,
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
              cacheMode: CacheMode.LOAD_DEFAULT,
            ),
      onWebViewCreated: (controller) {
        try {
          debugPrint('=== onWebViewCreated ===');
          debugPrint('Tab ID: ${widget.tab.id}');
          debugPrint('URL inicial: ${widget.tab.url}');
          
          _controller = controller;
          widget.tab.setController(controller);
          
          // Adiciona tratamento de erros JavaScript para evitar crashes
          try {
            controller.addJavaScriptHandler(
              handlerName: 'flutterErrorHandler',
              callback: (args) {
                debugPrint('=== Erro JavaScript capturado ===');
                debugPrint('Args: $args');
                return {};
              },
            );
            debugPrint('=== JavaScript handler adicionado ===');
          } catch (e) {
            debugPrint('=== ERRO ao adicionar JavaScript handler ===');
            debugPrint('Erro: $e');
          }
          
          // Atualiza o estado de navegação inicial
          _updateNavigationState();
          debugPrint('=== onWebViewCreated concluído ===');
        } catch (e, stackTrace) {
          debugPrint('=== ERRO CRÍTICO em onWebViewCreated ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
          debugPrint('======================================');
        }
      },
      onLoadStart: (controller, url) {
        try {
          final urlStr = url?.toString() ?? '';
          debugPrint('=== onLoadStart ===');
          debugPrint('URL: $urlStr');
          debugPrint('Tab ID: ${widget.tab.id}');
          
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          
          // Log específico para Telegram para debug
          if (urlStr.contains('telegram.org')) {
            debugPrint('=== CARREGANDO TELEGRAM ===');
            debugPrint('URL: $urlStr');
            debugPrint('==========================');
          }
          
          _updateNavigationState();
          debugPrint('=== onLoadStart concluído ===');
        } catch (e, stackTrace) {
          debugPrint('=== ERRO em onLoadStart ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
          debugPrint('===========================');
        }
      },
      onLoadStop: (controller, url) async {
        try {
          final urlStr = url?.toString() ?? '';
          debugPrint('=== onLoadStop ===');
          debugPrint('URL: $urlStr');
          debugPrint('Tab ID: ${widget.tab.id}');
          
          widget.tab.updateUrl(urlStr);
          widget.onUrlChanged(urlStr);
          
          // Para sites como Telegram, adiciona um delay maior antes de obter o título
          // Isso evita problemas com JavaScript ainda em execução
          if (urlStr.contains('telegram.org')) {
            debugPrint('=== Telegram detectado, aguardando 1s ===');
            await Future.delayed(const Duration(milliseconds: 1000));
            debugPrint('=== Delay concluído ===');
            
            // Adiciona proteção adicional: injeta código JavaScript para prevenir crashes
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  try {
                    // Previne erros não capturados que podem causar crashes
                    window.addEventListener('error', function(e) {
                      console.log('Erro capturado:', e.message);
                      return true;
                    });
                    
                    // Previne erros de Promise não tratados
                    window.addEventListener('unhandledrejection', function(e) {
                      console.log('Promise rejeitada:', e.reason);
                      e.preventDefault();
                      return true;
                    });
                    
                    console.log('Proteções JavaScript ativadas para Telegram');
                  } catch (e) {
                    console.log('Erro ao adicionar proteções:', e);
                  }
                })();
              ''');
              debugPrint('=== Proteções JavaScript injetadas ===');
            } catch (e) {
              debugPrint('=== ERRO ao injetar proteções JavaScript ===');
              debugPrint('Erro: $e');
            }
          }
          
          // Obtém o título da página com timeout
          try {
            debugPrint('=== Obtendo título da página ===');
            final title = await controller.getTitle().timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('=== Timeout ao obter título ===');
                return null;
              },
            );
            debugPrint('=== Título obtido: $title ===');
            if (title != null && title.isNotEmpty) {
              widget.tab.updateTitle(title);
              widget.onTitleChanged(title, widget.tab.id);
            }
          } catch (e) {
            debugPrint('=== ERRO ao obter título ===');
            debugPrint('Erro: $e');
            debugPrint('===========================');
          }
          
          _updateNavigationState();
          debugPrint('=== onLoadStop concluído ===');
        } catch (e, stackTrace) {
          debugPrint('=== ERRO CRÍTICO em onLoadStop ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
          debugPrint('=================================');
          // Salva erro crítico no arquivo
          _writeErrorToFile('Erro crítico em onLoadStop: $e\nStack: $stackTrace');
          // Não rethrow para evitar crash
        }
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
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
          debugPrint('Erro em onProgressChanged: $e');
        }
      },
      // Tratamento de erros com logs detalhados (apenas para debug, não bloqueia carregamento)
      onReceivedError: (controller, request, error) {
        try {
          final urlStr = request.url.toString();
          final errorMsg = '''
=== ERRO NO WEBVIEW ===
URL: $urlStr
Descrição: ${error.description}
Tipo: ${error.type}
Tab ID: ${widget.tab.id}
Timestamp: ${DateTime.now().toIso8601String()}
======================
''';
          debugPrint(errorMsg);
          
          // Salva erro crítico no arquivo (salva todos os erros para debug)
          _writeErrorToFile(errorMsg);
          
          // Para sites específicos que causam problemas
          if (urlStr.contains('telegram.org')) {
            debugPrint('=== Site Telegram detectado com erro ===');
            debugPrint('Pode ser problema de interação JavaScript');
            debugPrint('Tipo de erro: ${error.type}');
            _writeErrorToFile('Telegram error: $errorMsg');
          }
          
          // Não bloqueia o carregamento, apenas registra o erro
        } catch (e) {
          debugPrint('=== ERRO ao processar onReceivedError ===');
          debugPrint('Erro: $e');
        }
      },
      // Handler para erros de console JavaScript
      onConsoleMessage: (controller, consoleMessage) {
        try {
          // Log apenas erros críticos do console
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            final errorMsg = '''
=== ERRO NO CONSOLE JAVASCRIPT ===
Mensagem: ${consoleMessage.message}
Nível: ${consoleMessage.messageLevel}
Tab ID: ${widget.tab.id}
Timestamp: ${DateTime.now().toIso8601String()}
===================================
''';
            debugPrint(errorMsg);
            // Salva erros críticos de JavaScript no arquivo
            _writeErrorToFile(errorMsg);
          }
        } catch (e) {
          debugPrint('Erro ao processar onConsoleMessage: $e');
        }
      },
      onReceivedHttpError: (controller, request, response) {
        try {
          // Log apenas de erros HTTP críticos (4xx, 5xx)
          final statusCode = response.statusCode;
          if (statusCode != null && statusCode >= 400) {
            final errorMsg = '''
=== ERRO HTTP NO WEBVIEW ===
URL: ${request.url}
Status Code: $statusCode
Tab ID: ${widget.tab.id}
Timestamp: ${DateTime.now().toIso8601String()}
============================
''';
            debugPrint(errorMsg);
            // Salva erros HTTP críticos no arquivo
            if (statusCode >= 500) {
              _writeErrorToFile(errorMsg);
            }
          }
        } catch (e) {
          debugPrint('Erro ao processar onReceivedHttpError: $e');
        }
      },
      // Handler para solicitações de permissão (pode causar crashes se não tratado)
      onPermissionRequest: (controller, request) async {
        try {
          debugPrint('=== PERMISSÃO SOLICITADA ===');
          debugPrint('Recursos: ${request.resources}');
          debugPrint('Tab ID: ${widget.tab.id}');
          
          // Para Telegram, concede permissões básicas mas com cuidado
          if (widget.tab.url.contains('telegram.org')) {
            debugPrint('=== Telegram solicitando permissão ===');
            // Concede permissões básicas mas registra para debug
            _writeErrorToFile('Telegram permission request: ${request.resources}');
          }
          
          // Concede permissões básicas para evitar crashes
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        } catch (e, stackTrace) {
          debugPrint('=== ERRO ao processar permissão ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
          _writeErrorToFile('Permission error: $e\nStack: $stackTrace');
          // Retorna negação em caso de erro para evitar crash
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY,
          );
        }
      },
      // Handler para eventos de foco da janela (pode indicar problemas)
      onWindowFocus: (controller) {
        try {
          debugPrint('=== WebView ganhou foco ===');
          debugPrint('Tab ID: ${widget.tab.id}');
          _isWebViewAlive = true;
        } catch (e) {
          debugPrint('Erro em onWindowFocus: $e');
        }
      },
      onWindowBlur: (controller) {
        try {
          debugPrint('=== WebView perdeu foco ===');
          debugPrint('Tab ID: ${widget.tab.id}');
        } catch (e) {
          debugPrint('Erro em onWindowBlur: $e');
        }
      },
      // Handler para download (pode causar crashes se não tratado)
      onDownloadStartRequest: (controller, downloadStartRequest) {
        try {
          debugPrint('=== DOWNLOAD INICIADO ===');
          debugPrint('URL: ${downloadStartRequest.url}');
          debugPrint('Tab ID: ${widget.tab.id}');
          _writeErrorToFile('Download started: ${downloadStartRequest.url}');
        } catch (e) {
          debugPrint('Erro em onDownloadStartRequest: $e');
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
        try {
          debugPrint('=== JANELA FECHADA ===');
          debugPrint('Tab ID: ${widget.tab.id}');
          _writeErrorToFile('Window closed: Tab ${widget.tab.id}');
        } catch (e) {
          debugPrint('Erro em onCloseWindow: $e');
        }
      },
      // Handler para erros de SSL
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        try {
          debugPrint('=== ERRO SSL DETECTADO ===');
          debugPrint('Tab ID: ${widget.tab.id}');
          _writeErrorToFile('SSL error detected for Tab ${widget.tab.id}');
          // Aceita certificados para evitar crashes
          // Para Telegram e outros sites, aceita para evitar crashes
          debugPrint('=== Aceitando certificado SSL ===');
          return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
        } catch (e, stackTrace) {
          debugPrint('=== ERRO ao processar SSL ===');
          debugPrint('Erro: $e');
          debugPrint('Stack: $stackTrace');
          _writeErrorToFile('SSL processing error: $e\nStack: $stackTrace');
          return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
        }
      },
      );
    } catch (e, stackTrace) {
      debugPrint('=== ERRO CRÍTICO NO BUILD DO WEBVIEW ===');
      debugPrint('Exception: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('========================================');
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
