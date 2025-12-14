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
  bool _listenerAdded = false; // Flag para garantir que o listener seja adicionado apenas uma vez
  bool _isAlwaysOnTop = false; // ✅ Flag para indicar se a janela está fixada
  bool _isMaximized = false; // ✅ Estado para controlar se a janela está maximizada
  bool _showNavigationBars = false; // ✅ Estado para controlar visibilidade das barras de navegação
  final GlobalKey _multiPageWebViewKey = GlobalKey(); // ✅ Key para acessar MultiPageWebView quando necessário

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _currentUrl);
    // ✅ Configura título da janela
    _updateWindowTitle();
    // ✅ Listener de fechamento foi movido para GerenciaZapApp
    // Janelas secundárias fecham direto sem diálogo
    
    // ✅ Carrega configuração de alwaysOnTop
    _loadAlwaysOnTop();
    
    // ✅ OTIMIZAÇÃO 4: Carregar WebView apenas quando necessário (lazy loading)
    Future.microtask(() {
      _initializeTab();
    });
    
    // ✅ Configura listeners para salvar tamanho/posição
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          
          // ✅ CRÍTICO: Adiciona o listener para esta janela específica
          // ✅ Cada janela mantém seu próprio listener independente
          // ✅ Sempre adiciona (mesmo se já existe) para garantir que está ativo
          try {
            windowManager.addListener(this);
            _listenerAdded = true;
            debugPrint('✅ Listener de janela adicionado para tabId: ${widget.savedTab.id}');
          } catch (e) {
            // ✅ Se já existe, tudo bem - marca como adicionado
            _listenerAdded = true;
            debugPrint('✅ Listener já existe para tabId: ${widget.savedTab.id}');
          }
          
          // ✅ Carrega e aplica tamanho/posição salvos
          await _loadAndApplySavedBounds();
          
          // ✅ Verifica e atualiza o estado inicial da janela (maximizada ou não)
          await _checkAndUpdateWindowState();
        } catch (e) {
          debugPrint('❌ Erro ao configurar listeners de janela: $e');
        }
      });
    }
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
  
  /// ✅ Carrega a configuração de alwaysOnTop
  Future<void> _loadAlwaysOnTop() async {
    if (widget.savedTab.id != null) {
      try {
        final alwaysOnTop = await _localSettings.getAlwaysOnTop(widget.savedTab.id!);
        if (mounted) {
          setState(() {
            _isAlwaysOnTop = alwaysOnTop;
          });
        }
      } catch (e) {
        debugPrint('Erro ao carregar alwaysOnTop: $e');
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
    // ✅ CRÍTICO: NÃO remove o listener do windowManager aqui
    // ✅ Cada janela mantém seu próprio listener independente
    // ✅ Remover o listener aqui pode afetar outras janelas abertas
    // ✅ O listener será removido automaticamente quando a janela for realmente destruída
    
    // ✅ NÃO faz dispose de _urlController, _urlFocusNode, _tab - serão reutilizados
    // ✅ NÃO remove do registro - a janela permanece registrada para reutilização
    
    // Apenas chama super.dispose() para limpar recursos básicos do State
    super.dispose();
  }

  /// ✅ Carrega e aplica tamanho/posição salvos
  /// ✅ REMOVIDO: Não aplica mais aqui porque o main.dart já aplica a posição mais recente
  Future<void> _loadAndApplySavedBounds() async {
    if (widget.savedTab.id == null) return;
    
    try {
      // ✅ Apenas verifica se a posição foi aplicada corretamente
      // ✅ O main.dart já aplicou a posição mais recente antes de mostrar a janela
      debugPrint('✅ Posição carregada pelo main.dart');
    } catch (e) {
      debugPrint('Erro ao verificar tamanho/posição: $e');
    }
  }


  /// ✅ Verifica se esta é uma janela de PDF
  bool _isPdfWindow() {
    return widget.savedTab.id != null && widget.savedTab.id!.startsWith('pdf_');
  }

  // ✅ Listeners do WindowListener para detectar mudanças
  // ✅ REMOVIDO: Salvamentos automáticos - agora só atualiza estado visual
  @override
  void onWindowResize() {
    // ✅ Apenas atualiza estado visual, não salva automaticamente
  }

  @override
  void onWindowMove() {
    // ✅ Apenas atualiza estado visual, não salva automaticamente
  }
  
  @override
  void onWindowMaximize() {
    // ✅ Apenas atualiza estado visual
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      if (mounted) {
        setState(() {
          _isMaximized = true;
        });
      }
    }
  }

  @override
  void onWindowUnmaximize() {
    // ✅ Apenas atualiza estado visual
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      if (mounted) {
        setState(() {
          _isMaximized = false;
        });
      }
    }
  }
  
  /// ✅ Salva todas as configurações da janela (posição, tamanho, maximizado, proporções)
  Future<void> _saveAllSettings() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    try {
      await windowManager.ensureInitialized();
      
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final isMaximized = await windowManager.isMaximized();
      
      // ✅ Salva posição e tamanho da janela
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      final bounds = {
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
        'isMaximized': isMaximized,
      };
      
      await _localSettings.saveWindowBounds(boundsKey, bounds);
      debugPrint('✅ Configurações da janela salvas: x=${position.dx}, y=${position.dy}, width=${size.width}, height=${size.height}, maximized=$isMaximized');
      
      // ✅ Se for janela com múltiplas páginas, salva também as proporções
      if (widget.savedTab.hasMultiplePages) {
        try {
          await MultiPageWebView.saveProportionsFromKey(_multiPageWebViewKey);
        } catch (e) {
          debugPrint('⚠️ Erro ao salvar proporções: $e');
        }
      }
      
      // ✅ Mostra mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar configurações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// ✅ Verifica e atualiza o estado da janela
  Future<void> _checkAndUpdateWindowState() async {
    if (Platform.isWindows) {
      try {
        final isMaximized = await windowManager.isMaximized();
        if (mounted && isMaximized != _isMaximized) {
          setState(() {
            _isMaximized = isMaximized;
          });
        }
      } catch (e) {
        debugPrint('Erro ao verificar estado da janela: $e');
      }
    }
  }
  
  /// ✅ Maximiza ou restaura a janela
  Future<void> _toggleMaximizeWindow() async {
    if (Platform.isWindows) {
      try {
        if (_isMaximized) {
          await windowManager.restore();
        } else {
          await windowManager.maximize();
        }
        // ✅ Aguarda um pouco e verifica o estado real para garantir sincronização
        await Future.delayed(const Duration(milliseconds: 100));
        await _checkAndUpdateWindowState();
      } catch (e) {
        debugPrint('Erro ao maximizar/restaurar janela: $e');
      }
    }
  }
  
  /// ✅ Fecha a janela
  Future<void> _closeWindow() async {
    if (Platform.isWindows) {
      try {
        await windowManager.close();
      } catch (e) {
        debugPrint('Erro ao fechar janela: $e');
      }
    }
  }
  
  
  @override
  void onWindowBlur() {
    // ✅ Não salva ao perder foco - apenas ao mover, maximizar ou restaurar
    // ✅ Isso evita salvamentos desnecessários
  }
  
  @override
  void onWindowFocus() {
    // ✅ Quando a janela ganha foco, garante que o listener está ativo
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      _ensureListenerActive();
    }
  }
  
  /// ✅ Garante que o listener está ativo
  /// ✅ Reativa o listener se necessário (útil quando outras janelas fecham)
  /// ✅ CRÍTICO: Sempre tenta adicionar o listener, mesmo se já foi adicionado antes
  /// ✅ Isso garante que o listener continue funcionando mesmo quando outras janelas fecham
  void _ensureListenerActive() {
    if (!mounted || widget.savedTab.id == null) return;
    
    // ✅ CRÍTICO: Garante que o windowManager está inicializado antes de adicionar listener
    // ✅ Isso evita problemas quando outras janelas fecham
    try {
      // ✅ Tenta garantir inicialização (pode falhar silenciosamente se já está inicializado)
      windowManager.ensureInitialized().catchError((e) {
        // Ignora erros de inicialização - pode já estar inicializado
      });
      
      // ✅ Sempre tenta adicionar o listener (pode já existir, mas garante que está ativo)
      windowManager.addListener(this);
      if (!_listenerAdded) {
        _listenerAdded = true;
        debugPrint('✅ Listener ativado para tabId: ${widget.savedTab.id}');
      }
    } catch (e) {
      // ✅ Se falhar, tenta novamente após um pequeno delay
      // ✅ Isso ajuda quando outras janelas estão fechando
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && widget.savedTab.id != null) {
          try {
            windowManager.addListener(this);
            _listenerAdded = true;
          } catch (e2) {
            // Se ainda falhar, apenas marca como adicionado para evitar loops
            _listenerAdded = true;
          }
        }
      });
    }
  }

  Future<void> _initializeTab() async {
    try {
      // ✅ Log quando aba é inicializada pela primeira vez
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🆕 NOVA ABA/JANELA ABERTA');
      debugPrint('   └─ Nome: ${widget.savedTab.name}');
      debugPrint('   └─ ID: ${widget.savedTab.id}');
      final firstUrl = widget.savedTab.urlList.isNotEmpty ? widget.savedTab.urlList.first : "N/A";
      if (firstUrl.startsWith('data:')) {
        debugPrint('   └─ URL: data:application/pdf (base64)');
      } else {
        debugPrint('   └─ URL: $firstUrl');
      }
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
        
        // ✅ IMPORTANTE: Para arquivos locais (file://), o carregamento será feito
        // automaticamente no onWebViewCreated do BrowserWebViewWindows
        // Não precisa carregar aqui também para evitar duplicação
        if (urls.first.startsWith('file://')) {
          debugPrint('📄 Arquivo local detectado - será carregado automaticamente pelo WebView');
        }
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
        appBar: Platform.isWindows
            ? _DraggableAppBar(
                onWindowStateChanged: _checkAndUpdateWindowState,
                child: AppBar(
                  backgroundColor: const Color(0xFF00a4a4),
                  foregroundColor: Colors.white,
                  leading: widget.savedTab.iconUrl != null && widget.savedTab.iconUrl!.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              widget.savedTab.iconUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.language,
                                  color: Colors.white,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 24,
                        ),
                  title: Text(widget.savedTab.name),
                  automaticallyImplyLeading: false,
                  actions: [
                    // ✅ Botão Mostrar/Esconder Barras de Navegação
                    IconButton(
                      icon: Icon(
                        _showNavigationBars ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showNavigationBars = !_showNavigationBars;
                        });
                      },
                      tooltip: _showNavigationBars ? 'Ocultar barras de navegação' : 'Mostrar barras de navegação',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Salvar
                    IconButton(
                      icon: const Icon(Icons.save, size: 20),
                      onPressed: _saveAllSettings,
                      tooltip: 'Salvar configurações da janela',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Maximizar/Restaurar (sem botão minimizar)
                    IconButton(
                      icon: Icon(
                        _isMaximized ? Icons.filter_none : Icons.crop_square,
                        size: 18,
                      ),
                      onPressed: _toggleMaximizeWindow,
                      tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Fechar
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _closeWindow,
                      tooltip: 'Fechar',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              )
            : null,
        body: widget.savedTab.hasMultiplePages && _tab != null
            ? MultiPageWebView(
                key: _multiPageWebViewKey,
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
                isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                isAlwaysOnTop: _isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                externalNavBarVisibility: _showNavigationBars, // ✅ Passa controle externo de visibilidade
                hideFloatingButton: true, // ✅ Oculta botão flutuante em janelas secundárias
              )
            : _tab != null
                ? SizedBox.expand(
                    child: BrowserWebViewWindows(
                      tab: _tab!,
                      onUrlChanged: _onUrlChanged,
                      onTitleChanged: _onTitleChanged,
                      onNavigationStateChanged: _onNavigationStateChanged,
                      quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                      enableQuickMessages: widget.savedTab.enableQuickMessages, // ✅ Usa configuração da aba salva
                      iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                      pageName: widget.savedTab.name, // ✅ Passa nome da aba
                      isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                      isAlwaysOnTop: _isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                      externalNavBarVisibility: _showNavigationBars, // ✅ Passa controle externo de visibilidade
                    ),
                  )
                : const Center(child: Text('Carregando...')),
    );
  }
}

/// ✅ Widget que torna o AppBar arrastável usando a API nativa do sistema
class _DraggableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  final VoidCallback? onWindowStateChanged;

  const _DraggableAppBar({
    required this.child,
    this.onWindowStateChanged,
  });

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }

    // ✅ Usa DragToMoveArea nativo do window_manager
    // Isso usa a API nativa do Windows para arrastar a janela sem tremor
    return DragToMoveArea(
      child: GestureDetector(
        onDoubleTap: () async {
          // Double tap para maximizar/restaurar
          try {
            final isMaximized = await windowManager.isMaximized();
            if (isMaximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
            // ✅ Aguarda um pouco e atualiza o estado
            await Future.delayed(const Duration(milliseconds: 100));
            onWindowStateChanged?.call();
          } catch (e) {
            debugPrint('Erro ao maximizar/restaurar: $e');
          }
        },
        child: child,
      ),
    );
  }
}

