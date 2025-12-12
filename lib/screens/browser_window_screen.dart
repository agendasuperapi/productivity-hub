import 'package:flutter/material.dart';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import '../models/saved_tab.dart';
import '../models/quick_message.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../models/browser_tab_windows.dart';
import '../utils/window_manager_helper.dart';
import '../services/local_tab_settings_service.dart';
import 'dart:async';

/// Tela de navegador para uma janela separada (aberta a partir de uma aba salva)
class BrowserWindowScreen extends StatefulWidget {
  final SavedTab savedTab;
  final List<QuickMessage> quickMessages; // ✅ Mensagens rápidas obrigatórias (passadas como parâmetro)

  const BrowserWindowScreen({
    super.key,
    required this.savedTab,
    required this.quickMessages, // ✅ Obrigatório - sempre passado como parâmetro
  });

  @override
  State<BrowserWindowScreen> createState() => _BrowserWindowScreenState();
}

class _BrowserWindowScreenState extends State<BrowserWindowScreen> with WindowListener {
  BrowserTabWindows? _tab;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isPageLoading = false;
  late TextEditingController _urlController;
  final FocusNode _urlFocusNode = FocusNode();
  WindowController? _windowController;
  final LocalTabSettingsService _localSettings = LocalTabSettingsService();
  Timer? _saveBoundsTimer; // Timer para debounce ao salvar bounds

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _currentUrl);
    // ✅ Configura título da janela
    _updateWindowTitle();
    // ✅ Listener de fechamento foi movido para GerenciaZapApp
    // Janelas secundárias fecham direto sem diálogo
    // ✅ Configura listeners para salvar tamanho/posição
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          windowManager.addListener(this);
          // ✅ Carrega e aplica tamanho/posição salvos
          await _loadAndApplySavedBounds();
        } catch (e) {
          debugPrint('Erro ao configurar listeners de janela: $e');
        }
      });
    }
    // ✅ OTIMIZAÇÃO 4: Carregar WebView apenas quando necessário (lazy loading)
    Future.microtask(() {
    _initializeTab();
    });
  }

  Future<void> _updateWindowTitle() async {
    if (Platform.isWindows) {
      try {
        // O título é definido no MaterialApp, mas vamos garantir que está atualizado
        // O MaterialApp title já está configurado com widget.savedTab.name
        debugPrint('Título da janela: ${widget.savedTab.name}');
      } catch (e) {
        debugPrint('Erro ao atualizar título: $e');
      }
    }
  }

  @override
  void didUpdateWidget(BrowserWindowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedTab.id != oldWidget.savedTab.id) {
      _urlController.text = _currentUrl;
    }
  }

  @override
  void dispose() {
    _saveBoundsTimer?.cancel();
    if (Platform.isWindows) {
      try {
        windowManager.removeListener(this);
      } catch (e) {
        debugPrint('Erro ao remover listener: $e');
      }
    }
    _urlController.dispose();
    _urlFocusNode.dispose();
    _tab?.dispose();
    // Remove a janela do registro quando ela for fechada
    if (widget.savedTab.id != null) {
      WindowManagerHelper().unregisterWindow(widget.savedTab.id!);
    }
    super.dispose();
  }

  /// ✅ Carrega e aplica tamanho/posição salvos
  Future<void> _loadAndApplySavedBounds() async {
    if (widget.savedTab.id == null) return;
    
    try {
      final bounds = await _localSettings.getWindowBounds(widget.savedTab.id!);
      if (bounds != null && bounds['x'] != null && bounds['y'] != null) {
        final x = bounds['x'] as double;
        final y = bounds['y'] as double;
        final width = bounds['width'] as double?;
        final height = bounds['height'] as double?;
        final isMaximized = bounds['isMaximized'] as bool? ?? false;
        
        if (width != null && height != null) {
          await windowManager.setSize(Size(width, height));
        }
        await windowManager.setPosition(Offset(x, y));
        
        if (isMaximized) {
          await Future.delayed(const Duration(milliseconds: 100));
          await windowManager.maximize();
        }
        
        debugPrint('Tamanho/posição restaurados: x=$x, y=$y, width=$width, height=$height, maximized=$isMaximized');
      }
    } catch (e) {
      debugPrint('Erro ao carregar tamanho/posição: $e');
    }
  }

  /// ✅ Salva tamanho e posição da janela (com debounce)
  Future<void> _saveWindowBounds() async {
    if (widget.savedTab.id == null) return;
    
    // Cancela timer anterior se existir
    _saveBoundsTimer?.cancel();
    
    // Cria novo timer com debounce de 500ms
    _saveBoundsTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final position = await windowManager.getPosition();
        final size = await windowManager.getSize();
        final isMaximized = await windowManager.isMaximized();
        
        await _localSettings.saveWindowBounds(widget.savedTab.id!, {
          'x': position.dx,
          'y': position.dy,
          'width': size.width,
          'height': size.height,
          'isMaximized': isMaximized,
        });
        
        debugPrint('Tamanho/posição salvos: x=${position.dx}, y=${position.dy}, width=${size.width}, height=${size.height}, maximized=$isMaximized');
      } catch (e) {
        debugPrint('Erro ao salvar tamanho/posição: $e');
      }
    });
  }

  // ✅ Listeners do WindowListener para detectar mudanças
  @override
  void onWindowResize() {
    _saveWindowBounds();
  }

  @override
  void onWindowMove() {
    _saveWindowBounds();
  }

  @override
  void onWindowMaximize() {
    _saveWindowBounds();
  }

  @override
  void onWindowUnmaximize() {
    _saveWindowBounds();
  }

  Future<void> _initializeTab() async {
    try {
      // ✅ Log quando aba é inicializada pela primeira vez
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🆕 NOVA ABA/JANELA ABERTA');
      debugPrint('   └─ Nome: ${widget.savedTab.name}');
      debugPrint('   └─ ID: ${widget.savedTab.id}');
      debugPrint('   └─ URL: ${widget.savedTab.urlList.isNotEmpty ? widget.savedTab.urlList.first : "N/A"}');
      // ✅ Usa mensagens rápidas passadas como parâmetro (não acessa Supabase)
      debugPrint('   └─ Mensagens rápidas: ${widget.quickMessages.length}');
      if (widget.quickMessages.isNotEmpty) {
        debugPrint('   └─ Atalhos disponíveis: ${widget.quickMessages.map((m) => m.shortcut).join(", ")}');
      } else {
        debugPrint('   └─ ⚠️ NENHUMA MENSAGEM RÁPIDA DISPONÍVEL!');
    }
      debugPrint('═══════════════════════════════════════════════════════════');
      
      final urls = widget.savedTab.urlList;
      
      if (urls.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ OTIMIZAÇÃO 4: Cria WebView de forma assíncrona e não bloqueante
      // ✅ Carrega URL automaticamente para janelas secundárias (elas são abertas por demanda)
      final tab = await BrowserTabWindows.createAsync(
        id: 'window_${widget.savedTab.id}_${DateTime.now().millisecondsSinceEpoch}',
        initialUrl: urls.first, // ✅ Janelas secundárias carregam imediatamente
      );

      tab.updateTitle(widget.savedTab.name);
      tab.updateUrl(urls.first);
      tab.isLoaded = true;

      if (mounted) {
        setState(() {
          _tab = tab;
          _currentUrl = urls.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ✅ OTIMIZAÇÃO 4: Apenas logar erros críticos
      debugPrint('Erro ao inicializar aba na janela: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUrlSubmitted(String url) async {
    if (_tab != null) {
      _tab!.updateUrl(url);
      await _tab!.loadUrl(url);
      setState(() {
        _currentUrl = url;
      });
    }
  }

  void _onBackPressed() async {
    if (_tab != null && _tab!.canGoBack && _tab!.controller != null) {
      await _tab!.controller!.goBack();
    }
  }

  void _onForwardPressed() async {
    if (_tab != null && _tab!.canGoForward && _tab!.controller != null) {
      await _tab!.controller!.goForward();
    }
  }

  void _onRefreshPressed() async {
    if (_tab != null && _tab!.controller != null) {
      await _tab!.controller!.reload();
    }
  }

  void _onUrlChanged(String url) {
    setState(() {
      _currentUrl = url;
      _urlController.text = url;
    });
  }

  void _handleUrlSubmitted(String value) {
    String url = value.trim();
    
    // Adiciona https:// se não tiver protocolo
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Verifica se parece ser um domínio ou IP
      if (url.contains('.') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(url)) {
        url = 'https://$url';
      } else {
        // Se não parecer URL, faz busca no Google
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    
    _onUrlSubmitted(url);
    _urlFocusNode.unfocus();
  }

  void _onTitleChanged(String title, String tabId) async {
    // ✅ O título da janela é definido no MaterialApp (main.dart)
    // Não é possível atualizar dinamicamente em janelas secundárias do desktop_multi_window
  }

  void _onNavigationStateChanged(bool isLoading, bool canGoBack, bool canGoForward) {
    setState(() {
      _isPageLoading = isLoading;
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Se ainda está carregando, mostra indicador
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Carregando: ${widget.savedTab.name}'),
            ],
          ),
        ),
      );
    }
    
    // Se não tem tab, mostra erro
    if (_tab == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao carregar aba'),
              Text('Aba: ${widget.savedTab.name}'),
            ],
          ),
        ),
      );
    }
    
    // ✅ OTIMIZAÇÃO 4: Renderiza WebView apenas quando visível
    // ✅ Janelas secundárias fecham direto sem diálogo (configurado no GerenciaZapApp)
    // ✅ Barra de navegação do topo foi removida - apenas as barras dentro das páginas são exibidas
    return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
                  children: [
                    // Conteúdo WebView (sem barra de navegação no topo)
                    Expanded(
                      child: widget.savedTab.hasMultiplePages && _tab != null
                          ? MultiPageWebView(
                              urls: widget.savedTab.urlList,
                              columns: widget.savedTab.columns ?? 2,
                              rows: widget.savedTab.rows ?? 2,
                              tabId: widget.savedTab.id ?? _tab!.id, // ✅ Usa o ID do savedTab para salvar proporções corretamente
                              onUrlChanged: _onUrlChanged,
                              onTitleChanged: _onTitleChanged,
                              onNavigationStateChanged: _onNavigationStateChanged,
                    quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                    enableQuickMessages: widget.savedTab.enableQuickMessages, // ✅ Usa configuração da aba salva
                    iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                    pageName: widget.savedTab.name, // ✅ Passa nome da aba
                            )
                          : _tab != null
                              ? BrowserWebViewWindows(
                                  tab: _tab!,
                                  onUrlChanged: _onUrlChanged,
                                  onTitleChanged: _onTitleChanged,
                                  onNavigationStateChanged: _onNavigationStateChanged,
                        quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                        enableQuickMessages: widget.savedTab.enableQuickMessages, // ✅ Usa configuração da aba salva
                        iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                        pageName: widget.savedTab.name, // ✅ Passa nome da aba
                                )
                              : const Center(child: Text('Carregando...')),
                    ),
                  ],
                ),
    );
  }
}

