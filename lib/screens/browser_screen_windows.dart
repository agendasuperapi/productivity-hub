import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:window_manager/window_manager.dart';
import 'dart:math' as math;
import '../services/tab_manager_windows.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../widgets/save_tab_dialog.dart';
import '../services/saved_tabs_service.dart';
import '../services/quick_messages_service.dart';
import '../services/global_quick_messages_service.dart';
import '../models/saved_tab.dart';
import '../models/quick_message.dart';
import '../models/browser_tab_windows.dart';
import '../services/local_tab_settings_service.dart';
import '../services/profile_service.dart';
import 'browser_window_screen.dart';
import 'quick_messages_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import '../utils/window_manager_helper.dart';

/// Tela principal do navegador para Windows
class BrowserScreenWindows extends StatefulWidget {
  const BrowserScreenWindows({super.key});

  @override
  State<BrowserScreenWindows> createState() => _BrowserScreenWindowsState();
}

class _BrowserScreenWindowsState extends State<BrowserScreenWindows> {
  late TabManagerWindows _tabManager;
  final _localTabSettingsService = LocalTabSettingsService();
  final ProfileService _profileService = ProfileService();
  final GlobalQuickMessagesService _globalQuickMessages = GlobalQuickMessagesService();
  Map<String, dynamic>? _userProfile;
  // ✅ Cache de widgets para evitar recriação e descarte dos WebViews
  final Map<String, Widget> _widgetCache = {};
  bool _isInitializing = true; // ✅ Flag para rastrear inicialização
  // ✅ Cache para cálculos de notificações (evita recalcular a cada build)
  int _cachedTotalNotifications = 0;
  bool _cachedHasMultiplePages = false;
  int _lastTabCount = 0;
  // ✅ Map para armazenar notificações das páginas filhas (MultiPageWebView)
  // Chave: tabId da página filha (ex: "tab123_page_0"), Valor: quantidade de notificações
  final Map<String, int> _childPageNotifications = {};
  // ✅ Flag para controlar modo de edição (permite arrastar e reordenar abas)
  bool _isEditMode = false;
  // ✅ Controller para scroll horizontal da barra de abas
  final ScrollController _tabScrollController = ScrollController();
  // ✅ Variáveis para controlar arraste horizontal
  double _dragStartPosition = 0.0;
  double _dragStartScrollOffset = 0.0;
  bool _isDragging = false;
  // ✅ GlobalKey para acessar o Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // ✅ Estado para controlar o hint de mensagens rápidas
  String? _quickMessageHintText;
  Color? _quickMessageHintColor;
  Timer? _quickMessageHintTimer;
  // ✅ Estado para controlar se a janela está maximizada
  bool _isMaximized = false;

  /// ✅ Minimiza a janela
  Future<void> _minimizeWindow() async {
    if (Platform.isWindows) {
      try {
        await windowManager.minimize();
      } catch (e) {
        debugPrint('Erro ao minimizar janela: $e');
      }
    }
  }

  /// ✅ Maximiza ou restaura a janela
  Future<void> _toggleMaximizeWindow() async {
    if (Platform.isWindows) {
      try {
        if (_isMaximized) {
          await windowManager.restore();
          setState(() {
            _isMaximized = false;
          });
        } else {
          await windowManager.maximize();
          setState(() {
            _isMaximized = true;
          });
        }
      } catch (e) {
        debugPrint('Erro ao maximizar/restaurar janela: $e');
      }
    }
  }

  // ✅ Listener para detectar mudanças no estado da janela
  _WindowStateListener? _windowStateListener;

  /// ✅ Inicializa listener para detectar mudanças no estado da janela
  Future<void> _initWindowStateListener() async {
    if (Platform.isWindows) {
      try {
        _isMaximized = await windowManager.isMaximized();
        // Listener para detectar quando a janela é maximizada/restaurada externamente
        final listener = _WindowStateListener(
          onMaximize: () {
            if (mounted) {
              setState(() {
                _isMaximized = true;
              });
            }
          },
          onRestore: () {
            if (mounted) {
              setState(() {
                _isMaximized = false;
              });
            }
          },
        );
        _windowStateListener = listener;
        windowManager.addListener(listener);
      } catch (e) {
        debugPrint('Erro ao inicializar listener de janela: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // ✅ Listener de fechamento foi movido para GerenciaZapApp
    // Não precisa mais configurar aqui
    _initializeTabManager();
    _loadUserProfile();
    _initWindowStateListener();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    }
  }

  Future<void> _initializeTabManager() async {
    _tabManager = TabManagerWindows();
    _tabManager.addListener(_onTabManagerChanged);
    
    // ✅ Aguarda apenas a criação da aba Home antes de permitir o build
    // Isso garante que currentTab não seja null na primeira renderização
    await _tabManager.waitForHomeTab();
    
    // ✅ NÃO aguarda o carregamento completo das abas salvas
    // As abas serão carregadas em background e aparecerão quando prontas
    // Isso melhora muito a velocidade de inicialização
    
    // ✅ Inicializa cache de notificações
    _updateNotificationCache();
    _lastTabCount = _tabManager.tabs.length;
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
    
    // ✅ Aguarda o carregamento das abas salvas em background (sem bloquear UI)
    // As abas aparecerão na barra de abas quando estiverem prontas
    // O TabManager já chama loadSavedTabs() no construtor, então apenas aguardamos
    // que termine em background sem bloquear a UI inicial
    Future.microtask(() async {
      while (_tabManager.isLoadingSavedTabs) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (mounted) {
        _updateNotificationCache();
        _lastTabCount = _tabManager.tabs.length;
        setState(() {});
      }
    });
  }

  void _onTabManagerChanged() {
    // ✅ Durante a inicialização, sempre atualiza para mostrar a aba Home
    if (_isInitializing) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    
    // ✅ Atualiza cache de notificações quando o número de abas muda
    final currentTabCount = _tabManager.tabs.length;
    if (currentTabCount != _lastTabCount) {
      _updateNotificationCache();
      _lastTabCount = currentTabCount;
    }
    
    // ✅ Se a aba atual for Home, não faz rebuild para evitar descartar WebViews
    // Mas só depois da inicialização estar completa
    if (_tabManager.isCurrentTabHome) {
      return; // Não executa nenhuma ação quando é Home (após inicialização)
    }
    
    // ✅ IMPORTANTE: Durante reorder, apenas atualiza a UI da barra de abas
    // O IndexedStack não precisa ser reconstruído porque usa keys estáveis baseadas no ID
    // Isso evita recarregamento desnecessário das páginas
    if (mounted) {
      setState(() {});
    }
  }

  /// ✅ Constrói a lista de children do IndexedStack de forma estável
  /// A lista é sempre construída na ordem atual das abas, mas os widgets são reutilizados do cache
  /// Isso evita recarregamento das páginas durante reorder de abas
  List<Widget> _buildIndexedStackChildren() {
    // ✅ Constrói a lista na ordem atual das abas
    // ✅ IMPORTANTE: Só cria widgets WebView quando a aba foi carregada (isLoaded = true)
    // Isso evita criar 16+ WebViews na inicialização, melhorando muito a performance
    return _tabManager.tabs.map((tab) {
        // ✅ Se for a aba Home, mostra tela de boas-vindas
        if (_tabManager.isHomeTab(tab.id)) {
          if (!_widgetCache.containsKey('home_${tab.id}')) {
            _widgetCache['home_${tab.id}'] = WelcomeScreen(
              key: ValueKey('home_${tab.id}'),
            );
          }
          return _widgetCache['home_${tab.id}']!;
        }
        
        // ✅ Se a aba ainda não foi carregada, retorna um placeholder vazio
        // Isso evita criar WebViews desnecessários na inicialização
        if (!tab.isLoaded) {
          // Retorna um Container vazio - será substituído quando a aba for clicada
          return Container(key: ValueKey('placeholder_${tab.id}'));
        }
        
        // Verifica se a aba tem múltiplas páginas
        final savedTab = _tabManager.getSavedTab(tab.id);
        final enableQuickMessages = savedTab?.enableQuickMessages ?? true; // ✅ Obtém configuração de atalhos rápidos
        // ✅ Inclui enableQuickMessages na chave do cache para garantir recriação quando a configuração mudar
        final cacheKeySuffix = '_qm_$enableQuickMessages';
        if (savedTab != null && savedTab.hasMultiplePages) {
          final urls = savedTab.urlList;
          final columns = savedTab.columns ?? 2;
          final rows = savedTab.rows ?? 2;
          
          if (!_widgetCache.containsKey('multipage_${tab.id}$cacheKeySuffix')) {
            _widgetCache['multipage_${tab.id}$cacheKeySuffix'] = _KeepAliveWebView(
              key: ValueKey('keepalive_multipage_${tab.id}$cacheKeySuffix'),
              child: MultiPageWebView(
                key: ValueKey('multipage_${tab.id}$cacheKeySuffix'),
                urls: urls,
                columns: columns,
                rows: rows,
                tabId: tab.id,
                onUrlChanged: (url) {
                  if (tab.id == _tabManager.currentTab?.id) {
                    _onUrlChanged(url);
                  }
                },
                onTitleChanged: (title, tabId) {
                  _onTitleChanged(title, tabId);
                },
                onNavigationStateChanged: (isLoading, canGoBack, canGoForward) {
                  if (tab.id == _tabManager.currentTab?.id) {
                    _onNavigationStateChanged(isLoading, canGoBack, canGoForward);
                  }
                },
                quickMessages: _globalQuickMessages.messages, // ✅ Usa mensagens rápidas globais
                enableQuickMessages: enableQuickMessages, // ✅ Passa configuração de atalhos rápidos
                onQuickMessageHint: _showQuickMessageHint, // ✅ Callback para hints
              ),
            );
          }
          return _widgetCache['multipage_${tab.id}$cacheKeySuffix']!;
        } else {
          // Aba normal com uma única página
          if (!_widgetCache.containsKey('webview_${tab.id}$cacheKeySuffix')) {
            _widgetCache['webview_${tab.id}$cacheKeySuffix'] = _KeepAliveWebView(
              key: ValueKey('keepalive_webview_${tab.id}$cacheKeySuffix'),
              child: BrowserWebViewWindows(
                key: ValueKey('webview_${tab.id}$cacheKeySuffix'),
                tab: tab,
                onUrlChanged: (url) {
                  if (tab.id == _tabManager.currentTab?.id) {
                    _onUrlChanged(url);
                  }
                },
                onTitleChanged: (title, tabId) {
                  _onTitleChanged(title, tabId);
                },
                onNavigationStateChanged: (isLoading, canGoBack, canGoForward) {
                  if (tab.id == _tabManager.currentTab?.id) {
                    _onNavigationStateChanged(isLoading, canGoBack, canGoForward);
                  }
                },
                quickMessages: _globalQuickMessages.messages, // ✅ Usa mensagens rápidas globais
                enableQuickMessages: enableQuickMessages, // ✅ Passa configuração de atalhos rápidos
                onQuickMessageHint: _showQuickMessageHint, // ✅ Callback para hints
              ),
            );
          }
          return _widgetCache['webview_${tab.id}$cacheKeySuffix']!;
        }
      }).toList();
  }

  /// ✅ Calcula o total de notificações de uma aba específica
  /// Se a aba tem múltiplas páginas, soma as notificações de todas as páginas dessa aba
  int _getTabNotificationCount(BrowserTabWindows tab) {
    final savedTab = _tabManager.getSavedTab(tab.id);
    
    // Se a aba tem múltiplas páginas, soma as notificações de todas as páginas dessa aba
    if (savedTab != null && savedTab.hasMultiplePages) {
      int totalNotifications = 0;
      
      // Soma as notificações das páginas filhas armazenadas no Map
      _childPageNotifications.forEach((pageTabId, notificationCount) {
        // Verifica se esta página filha pertence a esta aba
        if (pageTabId.startsWith('${tab.id}_page_')) {
          totalNotifications += notificationCount;
        }
      });
      
      // ✅ Log para debug
      if (totalNotifications > 0) {
        debugPrint('📊 Total de notificações para aba "${tab.id}" com múltiplas páginas: $totalNotifications');
      }
      
      return totalNotifications;
    }
    
    // Se não tem múltiplas páginas, retorna apenas as notificações dessa aba
    return tab.notificationCount;
  }

  /// ✅ Atualiza o cache de notificações (chamado quando necessário)
  /// NOTA: Não é mais usado para calcular notificações entre abas, apenas mantido para compatibilidade
  void _updateNotificationCache() {
    final nonHomeTabs = _tabManager.tabs.where((t) => !_tabManager.isHomeTab(t.id)).toList();
    _cachedTotalNotifications = nonHomeTabs.fold<int>(0, (sum, tab) => sum + tab.notificationCount);
    _cachedHasMultiplePages = nonHomeTabs.length > 1;
  }

  /// Mostra o hint de mensagem rápida
  void _showQuickMessageHint(String type, String? shortcut) {
    setState(() {
      if (type == 'activated') {
        // Quando ativa, mostra o hint mas NÃO inicia o timer
        // O hint permanecerá visível enquanto o atalho estiver ativo
        _quickMessageHintText = 'Atalho ativado';
        _quickMessageHintColor = Colors.blue;
        // Cancela qualquer timer anterior, pois o hint deve permanecer visível
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = null;
      } else if (type == 'typing' && shortcut != null) {
        // Quando está digitando, atualiza o hint com as teclas digitadas
        // O shortcut vem no formato "teclas|keyCount|maxKeys"
        final parts = shortcut.split('|');
        if (parts.length == 3) {
          final typedKeys = parts[0];
          final keyCount = int.tryParse(parts[1]) ?? 0;
          final maxKeys = int.tryParse(parts[2]) ?? 5;
          if (typedKeys.isEmpty) {
            _quickMessageHintText = 'Atalho ativado';
          } else {
            _quickMessageHintText = 'Atalho ativado: /$typedKeys ($keyCount/$maxKeys)';
          }
          _quickMessageHintColor = Colors.blue;
          // Cancela qualquer timer anterior, pois o hint deve permanecer visível enquanto digita
          _quickMessageHintTimer?.cancel();
          _quickMessageHintTimer = null;
        }
      } else if (type == 'found' && shortcut != null) {
        // Quando encontra o atalho, atualiza o hint e inicia o timer de 10 segundos
        _quickMessageHintText = 'Atalho localizado: $shortcut';
        _quickMessageHintColor = Colors.green;
        // Cancela timer anterior e inicia novo timer de 10 segundos
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _quickMessageHintText = null;
              _quickMessageHintColor = null;
            });
          }
        });
      } else if (type == 'notFound') {
        // Quando não encontra o atalho, atualiza o hint e inicia o timer de 10 segundos
        _quickMessageHintText = 'Atalho não localizado';
        _quickMessageHintColor = Colors.red;
        // Cancela timer anterior e inicia novo timer de 10 segundos
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _quickMessageHintText = null;
              _quickMessageHintColor = null;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // ✅ Listener de fechamento foi movido para GerenciaZapApp
    // Não precisa mais remover aqui
    // ✅ Remove listener de estado da janela
    if (Platform.isWindows && _windowStateListener != null) {
      try {
        windowManager.removeListener(_windowStateListener!);
      } catch (e) {
        // Ignora erros ao remover listener
      }
    }
    // ✅ Cancela timer apenas (operação rápida)
    _quickMessageHintTimer?.cancel();
    // ✅ Não faz dispose de outros recursos para fechar mais rápido
    // Os recursos serão limpos automaticamente quando o aplicativo fechar
    // _tabScrollController.dispose(); // Não faz dispose para evitar demora
    // _tabManager.removeListener(_onTabManagerChanged); // Não remove listener para evitar demora
    // _tabManager.dispose(); // Não faz dispose para evitar demora (pode levar vários segundos)
    super.dispose();
  }

  // ✅ Métodos de fechamento removidos - agora estão em GerenciaZapApp

  /// Fecha o aplicativo mostrando diálogo de confirmação
  Future<void> _handleExitApp() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Fechar aplicativo'),
        content: const Text('Deseja realmente sair do Gerencia Zap?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      // ✅ Fecha o aplicativo
      if (Platform.isWindows) {
        try {
          await windowManager.setPreventClose(false);
          await windowManager.close();
        } catch (e) {
          // Se close falhar, usa exit como fallback
          exit(0);
        }
      } else {
        exit(0);
      }
    }
  }

  void _onUrlSubmitted(String url) async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      // ✅ Se a aba não foi carregada ainda, inicializa o ambiente primeiro
      if (!currentTab.isLoaded) {
        await currentTab.initializeEnvironment();
        currentTab.isLoaded = true; // ✅ Marca como carregada para que o WebView seja criado
        // ✅ Atualiza a URL antes de criar o WebView
        currentTab.updateUrl(url);
        // ✅ Força rebuild para criar o WebView
        if (mounted) {
          setState(() {});
        }
        // ✅ Aguarda o WebView ser criado (até 2 segundos)
        int attempts = 0;
        while (currentTab.controller == null && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        
        // ✅ Se o controller está disponível, carrega a URL
        if (currentTab.controller != null) {
          await currentTab.loadUrl(url);
        } else {
          // ✅ Se ainda não está disponível, a URL será carregada quando o WebView for criado
          // (o onWebViewCreated já trata isso)
          debugPrint('⚠️ Controller ainda não disponível, URL será carregada quando WebView for criado');
        }
      } else {
        // ✅ Se já está carregada, apenas carrega a URL normalmente
        currentTab.updateUrl(url);
        await currentTab.loadUrl(url);
      }
      
      // Força atualização da UI
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onBackPressed() async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.canGoBack && currentTab.controller != null) {
      await currentTab.controller!.goBack();
    }
  }

  void _onForwardPressed() async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.canGoForward && currentTab.controller != null) {
      await currentTab.controller!.goForward();
    }
  }

  void _onRefreshPressed() async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.controller != null) {
      await currentTab.controller!.reload();
    }
  }

  void _onNewTabPressed() async {
    // ✅ Abre o diálogo de salvar aba primeiro
    // Só cria a aba depois que o usuário salvar
    final result = await showDialog<SavedTab>(
      context: context,
      builder: (context) => SaveTabDialog(
        currentUrl: '', // ✅ String vazia para aparecer em branco
        currentTitle: 'Nova Aba',
        existingTab: null, // Nova aba
      ),
    );
    
    // ✅ Se o usuário salvou, cria a aba/janela com os dados salvos
    if (result != null && mounted) {
      // ✅ Verifica se deve abrir como janela consultando o armazenamento local
      // (openAsWindow é salvo localmente, não no SavedTab)
      // Aguarda um pouco para garantir que o SharedPreferences foi atualizado
      if (result.id != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        final openAsWindow = await _localTabSettingsService.getOpenAsWindow(result.id!);
        
        if (openAsWindow) {
          // ✅ Abre imediatamente em nova janela sem criar aba
          await _openInExternalWindow(result);
          
          // ✅ IMPORTANTE: Adiciona a aba salva à lista do TabManager para aparecer na barra de abas
          // Cria uma aba leve (sem WebViewEnvironment) apenas para exibição na barra
          final tab = BrowserTabWindows.createLightweight(
            id: result.id!,
            initialUrl: result.url,
          );
          tab.updateTitle(result.name);
          tab.updateUrl(result.url);
          tab.isLoaded = false; // Não marca como carregada pois não será usada
          
          // Adiciona à lista de abas do TabManager
          _tabManager.tabs.add(tab);
          _tabManager.associateSavedTab(tab.id, result);
          _tabManager.notifyListeners();
          
          // Força atualização da UI
          if (mounted) {
            setState(() {});
          }
          
          return; // ✅ Retorna imediatamente para não criar aba ativa
        }
      }
      
      // ✅ Se não é para abrir como janela, cria como aba normal
      // ✅ Cria nova aba usando o ID do SavedTab salvo (se disponível)
      // Isso garante que a aba criada já esteja associada ao SavedTab
      final tabId = result.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Cria a aba diretamente usando o ID do SavedTab
      final newTab = await BrowserTabWindows.createAsync(
        id: tabId,
        initialUrl: result.url,
      );
      
      // Adiciona a aba à lista do TabManager manualmente
      // (não usa createNewTab para poder usar o ID do SavedTab)
      _tabManager.tabs.add(newTab);
      _tabManager.selectTab(_tabManager.tabs.length - 1);
      
      // ✅ IMPORTANTE: Associa o SavedTab à aba criada ANTES de atualizar a UI
      // Isso garante que a aba apareça como salva imediatamente
      _tabManager.associateSavedTab(newTab.id, result);
      
      // Atualiza título e URL da aba
      newTab.updateTitle(result.name);
      newTab.updateUrl(result.url);
      newTab.isLoaded = true; // Marca como carregada
      
      // Carrega a URL salva
      if (newTab.controller != null) {
        await newTab.loadUrl(result.url);
      }
      
      // ✅ Notifica o TabManager para atualizar a UI
      _tabManager.notifyListeners();
      
      // ✅ Força atualização da UI para mostrar o ícone de salvo
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onTabSelected(int index) async {
    // ✅ Validação rápida para evitar cliques duplicados
    if (index < 0 || index >= _tabManager.tabs.length) {
      debugPrint('⚠️ _onTabSelected: índice inválido $index (total: ${_tabManager.tabs.length})');
      return;
    }
    
    final tab = _tabManager.tabs[index];
    
    // ✅ Se já está selecionada, apenas garante que o estado está correto
    if (index == _tabManager.currentTabIndex) {
      // Força atualização visual caso o estado esteja dessincronizado
      if (mounted) {
        setState(() {});
      }
      return;
    }
    
    // ✅ Garante que o método não seja bloqueado por problemas de estado
    try {
      // ✅ Se for a aba Home, seleciona e retorna sem executar mais nada
      if (_tabManager.isHomeTab(tab.id)) {
        _tabManager.selectTab(index);
        if (mounted) {
          setState(() {});
        }
        return; // ✅ Retorna imediatamente sem executar mais nada
      }
      
      // ✅ CRÍTICO: Verifica se a aba deve ser aberta como janela ANTES de selecionar/carregar
      // ✅ Agora usa configuração local ao invés do Supabase
      final savedTab = _tabManager.getSavedTab(tab.id);
      if (savedTab?.id != null) {
        final openAsWindow = await _localTabSettingsService.getOpenAsWindow(savedTab!.id!);
        if (openAsWindow) {
          // Verifica se a janela já está aberta e a ativa
          final windowManager = WindowManagerHelper();
          final wasActivated = await windowManager.activateWindowIfOpen(savedTab.id ?? '');
          
          if (!wasActivated) {
            // Se a janela não estava aberta, abre uma nova janela
            await _openInExternalWindow(savedTab);
          }
          // Se a janela já estava aberta, ela foi ativada acima
          // ✅ IMPORTANTE: NÃO seleciona a aba na janela principal, retorna imediatamente
          return;
        }
      }
      
      // ✅ Agora sim, seleciona a aba para abas normais (não Home, não janela)
      _tabManager.selectTab(index);
      
      // ✅ Se a aba não foi carregada ainda (lazy loading), inicializa ambiente e marca como carregada
      if (!tab.isLoaded && savedTab != null && savedTab.url.isNotEmpty) {
        // ✅ IMPORTANTE: Inicializa o ambiente ANTES de marcar como carregada
        // Isso garante que o WebView tenha o ambiente pronto quando for criado
        await tab.initializeEnvironment();
        
        // ✅ Marca como carregada ANTES de fazer rebuild
        // Isso faz com que o widget WebView seja criado no próximo build
        tab.isLoaded = true;
        
        // ✅ Força rebuild para criar o widget WebView
        if (mounted) {
          setState(() {});
        }
        
        // ✅ Aguarda o WebView ser criado antes de tentar carregar
        await Future.delayed(const Duration(milliseconds: 200));
        
        // ✅ Tenta carregar a URL - se o controller ainda não estiver pronto, tenta novamente
        int attempts = 0;
        while (attempts < 3 && tab.controller == null) {
          await Future.delayed(const Duration(milliseconds: 150));
          attempts++;
        }
        
        if (tab.controller != null) {
          await tab.loadUrl(savedTab.url);
          tab.updateTitle(savedTab.name);
          tab.updateUrl(savedTab.url);
          // ✅ Atualiza cache de notificações após carregar
          _updateNotificationCache();
        } else {
          debugPrint('⚠️ WebView controller não está pronto para aba ${tab.id}');
        }
        
        // ✅ Força atualização final após carregar
        if (mounted) {
          setState(() {});
        }
      } else {
        // ✅ Se já está carregada, apenas atualiza a UI
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, stackTrace) {
      // ✅ Log de erro mas não bloqueia a UI
      debugPrint('❌ Erro ao selecionar aba $index: $e');
      debugPrint('Stack trace: $stackTrace');
      // Tenta pelo menos selecionar a aba visualmente mesmo com erro
      if (mounted && index < _tabManager.tabs.length) {
        _tabManager.selectTab(index);
        setState(() {});
      }
    }
  }

  Future<void> _openInExternalWindow(SavedTab savedTab) async {
    try {
      if (!Platform.isWindows || savedTab.id == null) {
        // Fallback para outras plataformas ou se não tem ID - usa dialog
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BrowserWindowScreen(
                  savedTab: savedTab,
                  quickMessages: _globalQuickMessages.messages, // ✅ Passa mensagens rápidas globais
                ),
              ),
            ),
          );
        }
        return;
      }

      // ✅ Usa mensagens rápidas do serviço global
      final quickMessages = _globalQuickMessages.messages;
      final quickMessagesData = quickMessages.map((m) => m.toMap()).toList();
      
      // Usa o WindowManagerHelper para criar ou ativar a janela
      // ✅ Passa os dados do SavedTab e mensagens rápidas como parâmetros para evitar dependência do Supabase
      final windowManager = WindowManagerHelper();
      final window = await windowManager.createOrActivateWindow(
        tabId: savedTab.id!,
        windowTitle: savedTab.name,
        savedTabData: savedTab.toJson(), // Passa dados completos
        quickMessagesData: quickMessagesData, // ✅ Passa mensagens rápidas
      );

      if (window == null) {
        // ✅ Apenas loga erros críticos
        debugPrint('Erro: Não foi possível criar ou ativar a janela para tabId: ${savedTab.id}');
      }
      // ✅ O listener de fechamento da janela principal é re-registrado periodicamente
      // através do timer em _initWindowCloseHandlerPrincipal(), então não precisa
      // fazer nada aqui quando uma janela secundária é criada
    } catch (e) {
      // ✅ Apenas loga erros críticos
      debugPrint('Erro ao criar nova janela: $e');
    }
  }

  void _onTabClosed(int index) {
    final tab = _tabManager.tabs[index];
    // ✅ Remove do cache quando a aba é fechada (inclui variações com enableQuickMessages)
    _widgetCache.removeWhere((key, value) => 
      key.startsWith('webview_${tab.id}') || 
      key.startsWith('multipage_${tab.id}') || 
      key.startsWith('home_${tab.id}')
    );
    
    // ✅ Remove as notificações das páginas filhas dessa aba
    _childPageNotifications.removeWhere((pageTabId, _) => pageTabId.startsWith('${tab.id}_page_'));
    
    _tabManager.removeTab(index);
  }

  void _onUrlChanged(String url) {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      setState(() {
        currentTab.updateUrl(url);
      });
    }
  }

  void _onTitleChanged(String title, String tabId) {
    // Verifica se é uma página filha (MultiPageWebView) - IDs têm formato "tabId_page_X"
    if (tabId.contains('_page_')) {
      // Extrai o número de notificações do título
      final notificationCount = _extractNotificationCount(title);
      
      // Armazena a notificação da página filha
      _childPageNotifications[tabId] = notificationCount;
      
      // ✅ Log para debug
      if (notificationCount > 0) {
        debugPrint('🔔 Notificação detectada na página filha $tabId: $notificationCount');
      }
      
      // Atualiza a UI para refletir as mudanças
      if (mounted) {
        setState(() {});
      }
      return;
    }
    
    // Encontra a aba específica pelo ID e atualiza apenas ela
    try {
      final tab = _tabManager.tabs.firstWhere((t) => t.id == tabId);
      
      // Atualiza o título e detecta notificações para a aba específica
      tab.updateTitle(title);
      
      // ✅ Log para debug de notificações
      if (tab.notificationCount > 0) {
        debugPrint('🔔 Notificação detectada na aba ${tab.title}: ${tab.notificationCount} (tabId: $tabId)');
      }
      
      // ✅ Atualiza cache de notificações sempre que o título muda (mesmo se a contagem não mudou)
      // Isso garante que o badge seja atualizado corretamente
      _updateNotificationCache();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Aba não encontrada, ignora
      debugPrint('⚠️ Aba não encontrada para tabId: $tabId');
    }
  }

  /// ✅ Extrai o número de notificações do título da página
  /// Usa a mesma lógica do BrowserTabWindows para consistência
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
      if (count > 0) return count;
    }
    
    return 0;
  }

  void _onNavigationStateChanged(bool isLoading, bool canGoBack, bool canGoForward) {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      setState(() {
        currentTab.updateNavigationState(
          isLoading: isLoading,
          canGoBack: canGoBack,
          canGoForward: canGoForward,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Mostra loading apenas durante a inicialização
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final currentTab = _tabManager.currentTab;
    
    // ✅ Se não há aba atual (não deveria acontecer após inicialização), mostra loading
    if (currentTab == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // ✅ Se a aba atual é a Home, mostra tela de boas-vindas
    if (_tabManager.isCurrentTabHome) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: _DraggableAppBar(
          child: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            title: _quickMessageHintText != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _quickMessageHintColor?.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _quickMessageHintColor ?? Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _quickMessageHintText!,
                      style: TextStyle(
                        color: _quickMessageHintColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
            actions: [
              // Botão Nova Aba
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _onNewTabPressed,
                tooltip: 'Nova Aba',
                color: Colors.blue,
              ),
              // Botão Mensagens Rápidas
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const QuickMessagesScreen(),
                    ),
                  );
                },
                tooltip: 'Mensagens Rápidas',
              ),
              // ✅ Ícone de perfil com foto ou ícone padrão
              GestureDetector(
                onTap: () async {
                  final screenSize = MediaQuery.of(context).size;
                  final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;
                  
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => isSmallScreen
                        ? Dialog(
                            backgroundColor: Colors.white,
                            insetPadding: EdgeInsets.zero,
                            child: SizedBox(
                              width: screenSize.width,
                              height: screenSize.height,
                              child: const ProfileScreen(),
                            ),
                          )
                        : Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 500,
                              ),
                              child: const ProfileScreen(),
                            ),
                          ),
                  );
                  // ✅ Não executa nenhuma ação após fechar - fecha imediatamente
                  // ✅ Não aguarda resultado do diálogo para fechar mais rápido
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: _userProfile?['avatar_url'] != null && _userProfile!['avatar_url'].toString().isNotEmpty
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: NetworkImage(_userProfile!['avatar_url'] as String),
                          onBackgroundImageError: (exception, stackTrace) {
                            // Se erro ao carregar, remove a URL
                            setState(() {
                              _userProfile?['avatar_url'] = null;
                            });
                          },
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
              // ✅ Botão Minimizar
              IconButton(
                icon: const Icon(Icons.minimize),
                onPressed: _minimizeWindow,
                tooltip: 'Minimizar',
                color: Colors.grey[700],
              ),
              // ✅ Botão Maximizar/Restaurar
              IconButton(
                icon: Icon(_isMaximized ? Icons.filter_none : Icons.crop_free),
                onPressed: _toggleMaximizeWindow,
                tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                color: Colors.grey[700],
              ),
              // ✅ Botão Sair
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: _handleExitApp,
                tooltip: 'Sair',
                color: Colors.red,
              ),
            ],
          ),
        ),
        drawer: _buildTabsDrawer(),
        body: Column(
          children: [
            // Barra de abas
            _buildTabBar(),
            // Tela de boas-vindas
            Expanded(
              child: WelcomeScreen(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildCustomAppBar(),
      drawer: _buildTabsDrawer(),
      body: Column(
        children: [
          // Barra de abas (precisa adaptar para usar BrowserTabWindows)
          _buildTabBar(),
          
          // WebView - Usa IndexedStack para manter todos os WebViews vivos
          // ✅ Usa cache de widgets para evitar recriação e descarte dos WebViews
          // ✅ A barra de navegação agora está dentro de cada WebView individual
          Expanded(
            child: IndexedStack(
              index: _tabManager.currentTabIndex,
              // ✅ Usa método auxiliar que mantém a lista estável durante reorder
              // A lista só é recriada quando o número de abas ou seus IDs mudam
              children: _buildIndexedStackChildren(),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Constrói o AppBar customizado para abas normais (não Home)
  PreferredSizeWidget _buildCustomAppBar() {
    return _DraggableAppBar(
      child: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: _quickMessageHintText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _quickMessageHintColor?.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _quickMessageHintColor ?? Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  _quickMessageHintText!,
                  style: TextStyle(
                    color: _quickMessageHintColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null, // ✅ A barra de navegação está dentro de cada WebView individual
        actions: [
          // Botão Nova Aba
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _onNewTabPressed,
            tooltip: 'Nova Aba',
            color: Colors.blue,
          ),
          // Botão Mensagens Rápidas
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QuickMessagesScreen(),
                ),
              );
            },
            tooltip: 'Mensagens Rápidas',
          ),
          // ✅ Ícone de perfil com foto ou ícone padrão
          GestureDetector(
            onTap: () async {
              final screenSize = MediaQuery.of(context).size;
              final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;
              
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => isSmallScreen
                    ? Dialog(
                        backgroundColor: Colors.white,
                        insetPadding: EdgeInsets.zero,
                        child: SizedBox(
                          width: screenSize.width,
                          height: screenSize.height,
                          child: const ProfileScreen(),
                        ),
                      )
                    : Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 500,
                          ),
                          child: const ProfileScreen(),
                        ),
                      ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: _userProfile?['avatar_url'] != null && _userProfile!['avatar_url'].toString().isNotEmpty
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: NetworkImage(_userProfile!['avatar_url'] as String),
                      onBackgroundImageError: (exception, stackTrace) {
                        setState(() {
                          _userProfile?['avatar_url'] = null;
                        });
                      },
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
          // ✅ Botão Minimizar
          IconButton(
            icon: const Icon(Icons.minimize),
            onPressed: _minimizeWindow,
            tooltip: 'Minimizar',
            color: Colors.grey[700],
          ),
          // ✅ Botão Maximizar/Restaurar
          IconButton(
            icon: Icon(_isMaximized ? Icons.filter_none : Icons.crop_free),
            onPressed: _toggleMaximizeWindow,
            tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
            color: Colors.grey[700],
          ),
          // ✅ Botão Sair
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _handleExitApp,
            tooltip: 'Sair',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    // ✅ Usa cache de notificações para melhor performance
    // Atualiza cache apenas se o número de abas mudou
    final currentTabCount = _tabManager.tabs.length;
    if (currentTabCount != _lastTabCount) {
      _updateNotificationCache();
      _lastTabCount = currentTabCount;
    }
    
    // ✅ Filtra abas: oculta Home se houver outras abas abertas
    final visibleTabs = _tabManager.tabs.where((tab) {
      // Se é Home e há outras abas (além da Home), oculta
      if (_tabManager.isHomeTab(tab.id)) {
        return _tabManager.tabs.length <= 1; // Mostra Home apenas se for a única aba
      }
      return true; // Mostra todas as outras abas
    }).toList();
    
    // ✅ Se não há abas visíveis, mostra mensagem ou botão para criar
    if (visibleTabs.isEmpty) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            bottom: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
          ),
        ),
        // ✅ Botão removido - agora está no AppBar ao lado do botão de mensagens rápidas
        child: const SizedBox.shrink(),
      );
    }
    
    // ✅ Cria mapa de índices visíveis para índices originais
    final visibleToOriginalIndex = <int, int>{};
    int visibleIndex = 0;
    for (int i = 0; i < _tabManager.tabs.length; i++) {
      if (!_tabManager.isHomeTab(_tabManager.tabs[i].id) || _tabManager.tabs.length <= 1) {
        visibleToOriginalIndex[visibleIndex] = i;
        visibleIndex++;
      }
    }
    
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ✅ Lista de abas (com scroll ou reordenação dependendo do modo)
          Expanded(
            child: _isEditMode
                ? _buildReorderableTabList(visibleTabs, visibleToOriginalIndex)
                : _buildScrollableTabList(visibleTabs, visibleToOriginalIndex),
          ),
          // ✅ Botão de menu drawer
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          // ✅ Botão de editar no final da barra
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isEditMode ? Colors.blue[100] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isEditMode ? Icons.check : Icons.edit,
                    size: 20,
                    color: _isEditMode ? Colors.blue[700] : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Constrói lista de abas com scroll horizontal (modo normal)
  Widget _buildScrollableTabList(List<BrowserTabWindows> visibleTabs, Map<int, int> visibleToOriginalIndex) {
    return Builder(
      builder: (context) => GestureDetector(
        // ✅ Detecta arraste horizontal para scroll
        // Usa onPanStart/Update/End para detectar gestos de arraste
        onPanStart: (details) {
          _isDragging = true;
          _dragStartPosition = details.globalPosition.dx;
          _dragStartScrollOffset = _tabScrollController.hasClients 
              ? _tabScrollController.offset 
              : 0.0;
        },
        onPanUpdate: (details) {
          if (_isDragging && _tabScrollController.hasClients) {
            final delta = _dragStartPosition - details.globalPosition.dx;
            final newOffset = _dragStartScrollOffset + delta;
            _tabScrollController.jumpTo(
              newOffset.clamp(
                0.0,
                _tabScrollController.position.maxScrollExtent,
              ),
            );
          }
        },
        onPanEnd: (details) {
          _isDragging = false;
        },
        onPanCancel: () {
          _isDragging = false;
        },
        // ✅ Permite que cliques passem através para as abas
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          controller: _tabScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(), // ✅ Scroll suave com bounce
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(visibleTabs.length, (visibleIndex) {
                return _buildTabItem(context, visibleIndex, visibleTabs, visibleToOriginalIndex, false);
              }),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ Constrói lista de abas com reordenação (modo edição)
  Widget _buildReorderableTabList(List<BrowserTabWindows> visibleTabs, Map<int, int> visibleToOriginalIndex) {
    return Builder(
      builder: (context) => ReorderableListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(), // ✅ Permite scroll mesmo quando não há overflow
        onReorder: (oldIndex, newIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Converte índices visíveis para índices originais
              final originalOldIndex = visibleToOriginalIndex[oldIndex] ?? oldIndex;
              final originalNewIndex = visibleToOriginalIndex[newIndex] ?? newIndex;
              _tabManager.reorderTabs(originalOldIndex, originalNewIndex);
            }
          });
        },
        buildDefaultDragHandles: false,
        onReorderStart: (index) {
          // Permite que cliques sejam processados mesmo durante o início do arrasto
        },
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        children: List.generate(visibleTabs.length, (visibleIndex) {
          return _buildTabItem(context, visibleIndex, visibleTabs, visibleToOriginalIndex, true);
        }),
      ),
    );
  }

  /// ✅ Constrói um item de aba (reutilizável para ambos os modos)
  Widget _buildTabItem(BuildContext context, int visibleIndex, List<BrowserTabWindows> visibleTabs, Map<int, int> visibleToOriginalIndex, bool isEditMode) {
    // ✅ Obtém o índice original da aba
    final originalIndex = visibleToOriginalIndex[visibleIndex] ?? visibleIndex;
    final tab = _tabManager.tabs[originalIndex];
    final isSelected = originalIndex == _tabManager.currentTabIndex;
    final isSaved = _tabManager.isTabSaved(tab.id);
    final savedTab = _tabManager.getSavedTab(tab.id);
    final isHome = _tabManager.isHomeTab(tab.id);
    
    // ✅ Para a aba Home, sempre mostra "Home" ou ícone de casinha
    String displayName = isHome 
        ? 'Home' 
        : (savedTab?.name ?? 
            ((tab.title.isNotEmpty && tab.title != 'Nova Aba' && !tab.title.startsWith('http'))
                ? tab.title 
                : _getShortUrl(tab.url)));
    
    // ✅ Calcula notificações para mostrar no badge
    int notificationCountToShow = 0;
    if (!isHome) {
      notificationCountToShow = _getTabNotificationCount(tab);
    }
    
    const minTabWidth = 120.0;
    
    Widget tabWidget = Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: minTabWidth, // ✅ Largura fixa para garantir scroll horizontal
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : Border.all(color: Colors.grey[300] ?? Colors.grey, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onTabSelected(originalIndex);
            });
          },
          onSecondaryTapDown: (isSaved && !isHome)
              ? (details) => _showTabContextMenu(context, originalIndex, details.globalPosition)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isHome
                          ? Icon(
                              Icons.home,
                              size: 18,
                              color: isSelected ? Colors.blue : Colors.grey[600],
                            )
                          : (savedTab?.iconUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    savedTab!.iconUrl!,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.language,
                                        size: 18,
                                        color: isSelected ? Colors.blue : Colors.grey[600],
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  isSaved ? Icons.bookmark : Icons.language,
                                  size: 18,
                                  color: isSelected ? Colors.blue : Colors.grey[600],
                                )),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.blue[900] : Colors.black87,
                                ),
                              ),
                            ),
                            if (!isHome && notificationCountToShow > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  notificationCountToShow > 99 ? '99+' : '$notificationCountToShow',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSaved && !isHome)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _onSaveTab(originalIndex),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.bookmark_border,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  if (!isSaved && !isHome) ...[
                    const SizedBox(width: 2),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _onTabClosed(originalIndex),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // ✅ Se está em modo de edição, envolve com ReorderableDragStartListener
    if (isEditMode) {
      return ReorderableDragStartListener(
        index: visibleIndex,
        key: ValueKey('tab_${tab.id}_$originalIndex'),
        child: tabWidget,
      );
    } else {
      return Container(
        key: ValueKey('tab_${tab.id}_$originalIndex'),
        child: tabWidget,
      );
    }
  }

  /// ✅ Constrói o drawer com todas as abas e seus ícones
  Widget _buildTabsDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Cabeçalho do drawer
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue[700],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.tab,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Todas as Abas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Lista de abas
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _tabManager.tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabManager.tabs[index];
                final isSelected = index == _tabManager.currentTabIndex;
                final isHome = _tabManager.isHomeTab(tab.id);
                final isSaved = _tabManager.isTabSaved(tab.id);
                final savedTab = _tabManager.getSavedTab(tab.id);
                
                // Nome da aba
                String displayName = isHome 
                    ? 'Home' 
                    : (savedTab?.name ?? 
                        ((tab.title.isNotEmpty && tab.title != 'Nova Aba' && !tab.title.startsWith('http'))
                            ? tab.title 
                            : _getShortUrl(tab.url)));
                
                // Calcula notificações
                int notificationCount = 0;
                if (!isHome) {
                  notificationCount = _getTabNotificationCount(tab);
                }
                
                return ListTile(
                  leading: isHome
                      ? const Icon(Icons.home, color: Colors.blue)
                      : (savedTab?.iconUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                savedTab!.iconUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.language,
                                    color: isSelected ? Colors.blue : Colors.grey[600],
                                  );
                                },
                              ),
                            )
                          : Icon(
                              isSaved ? Icons.bookmark : Icons.language,
                              color: isSelected ? Colors.blue : Colors.grey[600],
                            )),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue[700] : Colors.black87,
                    ),
                  ),
                  trailing: notificationCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            notificationCount > 99 ? '99+' : '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  selected: isSelected,
                  selectedTileColor: Colors.blue[50],
                  onTap: () {
                    Navigator.of(context).pop(); // Fecha o drawer
                    _onTabSelected(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Widget wrapper que mantém o WebView vivo mesmo quando não está visível
  /// Evita que os WebViews sejam descartados quando muda para a aba Home
}

/// ✅ Listener para detectar mudanças no estado da janela
class _WindowStateListener extends WindowListener {
  final VoidCallback onMaximize;
  final VoidCallback onRestore;

  _WindowStateListener({
    required this.onMaximize,
    required this.onRestore,
  });

  @override
  void onWindowMaximize() {
    onMaximize();
  }

  @override
  void onWindowRestore() {
    onRestore();
  }
}

/// ✅ Widget que torna o AppBar arrastável usando a API nativa do sistema
class _DraggableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  const _DraggableAppBar({
    required this.child,
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
          } catch (e) {
            debugPrint('Erro ao maximizar/restaurar: $e');
          }
        },
        child: child,
      ),
    );
  }
}

class _KeepAliveWebView extends StatefulWidget {
  final Widget child;

  const _KeepAliveWebView({
    super.key,
    required this.child,
  });

  @override
  State<_KeepAliveWebView> createState() => _KeepAliveWebViewState();
}

class _KeepAliveWebViewState extends State<_KeepAliveWebView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ Mantém o widget vivo sempre

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Necessário para AutomaticKeepAliveClientMixin funcionar
    return widget.child;
  }
}

extension _BrowserScreenWindowsExtension on _BrowserScreenWindowsState {
  /// Retorna uma versão curta da URL para exibição
  String _getShortUrl(String url) {
    if (url.isEmpty || url == 'about:blank') {
      return 'Nova Aba';
    }
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) {
        return url.length > 30 ? '${url.substring(0, 27)}...' : url;
      }
      return host.replaceFirst('www.', '');
    } catch (e) {
      return url.length > 30 ? '${url.substring(0, 27)}...' : url;
    }
  }

  Future<void> _onSaveTab(int index) async {
    if (!mounted) return;
    
    final tab = _tabManager.tabs[index];
    final savedTab = _tabManager.getSavedTab(tab.id);
    
    // Aguarda o próximo frame para garantir que não há operações pendentes
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) return;
    
    final result = await showDialog<SavedTab?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SaveTabDialog(
        currentUrl: tab.url,
        currentTitle: tab.title,
        existingTab: savedTab,
      ),
    );

    if (result != null && mounted) {
      // Associa o SavedTab criado/atualizado à aba atual
      _tabManager.associateSavedTab(tab.id, result);
      
      // Atualiza o título da aba se mudou
      if (result.name != tab.title) {
        tab.updateTitle(result.name);
      }
      
      // Atualiza a URL da aba se mudou
      if (result.url != tab.url) {
        tab.updateUrl(result.url);
        await tab.loadUrl(result.url);
      }
      
      // Força atualização da UI para mostrar o ícone
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Mostra o menu de contexto ao clicar com botão direito em uma aba salva
  void _showTabContextMenu(BuildContext context, int index, Offset position) {
    final tab = _tabManager.tabs[index];
    final savedTab = _tabManager.getSavedTab(tab.id);

    if (savedTab == null) return;

    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        _onSaveTab(index);
      } else if (value == 'delete') {
        _onDeleteTab(index);
      }
    });
  }

  /// Deleta uma aba salva
  Future<void> _onDeleteTab(int index) async {
    final tab = _tabManager.tabs[index];
    final savedTab = _tabManager.getSavedTab(tab.id);

    if (savedTab == null) return;

    // Confirma antes de deletar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Aba'),
        content: Text('Tem certeza que deseja excluir a aba "${savedTab.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final savedTabsService = SavedTabsService();
        await savedTabsService.deleteTab(savedTab.id!);
        
        // ✅ Remove a associação da aba salva
        _tabManager.removeSavedTabAssociation(tab.id);
        
        // ✅ IMPORTANTE: Fecha a aba automaticamente após deletar
        // Remove do cache quando a aba é fechada
        _widgetCache.removeWhere((key, value) => 
          key.startsWith('webview_${tab.id}') || 
          key.startsWith('multipage_${tab.id}') || 
          key.startsWith('home_${tab.id}')
        );
        
        // Remove as notificações das páginas filhas dessa aba
        _childPageNotifications.removeWhere((pageTabId, _) => pageTabId.startsWith('${tab.id}_page_'));
        
        // Fecha a aba removendo-a do TabManager
        _tabManager.removeTab(index);
        
        // Força atualização da UI
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aba excluída com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir aba: $e')),
          );
        }
      }
    }
  }

}

