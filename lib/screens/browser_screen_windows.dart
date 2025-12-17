import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:window_manager/window_manager.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/tab_manager_windows.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../widgets/save_tab_dialog.dart';
import '../services/saved_tabs_service.dart';
import '../services/quick_messages_service.dart';
import '../services/global_quick_messages_service.dart';
import '../services/quick_message_usage_service.dart';
import '../models/saved_tab.dart';
import '../models/quick_message.dart';
import '../models/browser_tab_windows.dart';
import '../services/local_tab_settings_service.dart';
import '../services/profile_service.dart';
import 'browser_window_screen.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import '../utils/window_manager_helper.dart';
import '../utils/compact_logger.dart';
import '../services/page_download_history_service.dart';
import '../widgets/draggable_resizable_dialog.dart';
import '../services/tab_groups_service.dart';
import '../screens/tab_groups_screen.dart';

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
  // ✅ Estado para controlar visibilidade das barras de navegação
  bool _showNavigationBars = false;
  // ✅ Estado para controlar visibilidade do painel de mensagens rápidas
  bool _showQuickMessagesPanel = false;
  double _quickMessagesPanelWidth = 400.0; // Largura padrão do painel
  // ✅ Configurações de posição e estilo do painel
  String _quickMessagesPanelPosition = 'left'; // 'left', 'right', 'bottom'
  bool _quickMessagesPanelIsDrawer = false; // false = fixo, true = drawer flutuante
  // ✅ Configuração de como abrir links/pop-ups
  // 'same_page' = na própria página, 'external_browser' = navegador externo, 'webview_window' = janela nativa do WebView2
  String _openLinksMode = 'same_page'; // Padrão: na própria página
  // ✅ Map para armazenar GlobalKeys de MultiPageWebView por tabId
  final Map<String, GlobalKey> _multiPageWebViewKeys = {};
  // ✅ Map para rastrear quais abas têm mudanças não salvas
  final Map<String, bool> _unsavedChangesMap = {};
  // ✅ SnackBarController para controlar a exibição da barra de salvar
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _saveSnackBarController;
  // ✅ Estado para controlar o grupo de abas selecionado
  String? _selectedGroupId;
  final TabGroupsService _tabGroupsService = TabGroupsService();
  // ✅ Map para armazenar configuração de atalhos rápidos por URL por tabId
  final Map<String, Map<String, bool>?> _quickMessagesByUrlCache = {};
  // ✅ Set para rastrear quais tabs estão sendo carregadas (evita múltiplas chamadas simultâneas)
  final Set<String> _loadingQuickMessagesTabs = {};

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
  /// ✅ APENAS na tela principal: restaura com 70% do tamanho da tela primária e centraliza
  Future<void> _toggleMaximizeWindow() async {
    if (Platform.isWindows) {
      try {
        if (_isMaximized) {
          // ✅ CRÍTICO: Calcula o tamanho ANTES de restaurar para garantir que usa o tamanho da tela primária
          double? newWidth;
          double? newHeight;
          double? x;
          double? y;
          
          try {
            // ✅ Obtém o tamanho da tela primária usando dart:ui ANTES de restaurar
            // ✅ IMPORTANTE: Sempre usa o tamanho da tela primária, não o tamanho atual da janela
            final views = ui.PlatformDispatcher.instance.views;
            if (views.isNotEmpty) {
              // ✅ Encontra a view principal (primeira view disponível)
              final primaryView = views.first;
              final screenSize = primaryView.physicalSize;
              final devicePixelRatio = primaryView.devicePixelRatio;
              
              // ✅ Converte para coordenadas lógicas (sem considerar DPI)
              final screenWidth = screenSize.width / devicePixelRatio;
              final screenHeight = screenSize.height / devicePixelRatio;
              
              // ✅ SEMPRE calcula 70% do tamanho da tela primária (não do tamanho atual da janela)
              newWidth = screenWidth * 0.7;
              newHeight = screenHeight * 0.7;
              
              // ✅ Centraliza a janela na tela primária
              x = (screenWidth - newWidth) / 2;
              y = (screenHeight - newHeight) / 2;
              
              debugPrint('✅ Calculado tamanho para restaurar: ${newWidth.toInt()}x${newHeight.toInt()} (70% da tela primária: ${screenWidth.toInt()}x${screenHeight.toInt()})');
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao calcular tamanho da tela primária: $e');
          }
          
          // ✅ Restaura a janela
          await windowManager.restore();
          // ✅ Aguarda um pouco para garantir que a janela foi restaurada
          await Future.delayed(const Duration(milliseconds: 150));
          
          // ✅ Se calculou o tamanho corretamente, aplica
          if (newWidth != null && newHeight != null && x != null && y != null) {
            try {
              // ✅ Aplica o novo tamanho e posição
              await windowManager.setSize(Size(newWidth, newHeight));
              await windowManager.setPosition(Offset(x, y));
              debugPrint('✅ Janela restaurada e redimensionada: ${newWidth.toInt()}x${newHeight.toInt()}');
            } catch (e) {
              debugPrint('⚠️ Erro ao aplicar tamanho/posição: $e');
            }
          }
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

  // ✅ Listener para detectar mudanças no estado da janela
  _WindowStateListener? _windowStateListener;
  Timer? _windowStateCheckTimer;

  /// ✅ Verifica o estado atual da janela e atualiza se necessário
  Future<void> _checkAndUpdateWindowState() async {
    if (!Platform.isWindows || !mounted) return;
    
    try {
      final isMaximized = await windowManager.isMaximized();
      // ✅ Só atualiza se o estado realmente mudou para evitar rebuilds desnecessários
      if (isMaximized != _isMaximized && mounted) {
          setState(() {
            _isMaximized = isMaximized;
          });
      }
    } catch (e) {
      // ✅ Não loga erros para evitar spam no console
    }
  }

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
        
        // ✅ Verifica o estado periodicamente para garantir sincronização
        // Isso garante que mesmo se o listener não for chamado, o estado será atualizado
        // ✅ Aumentado intervalo para 2 segundos para reduzir overhead e evitar bloqueio de UI
        _windowStateCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (mounted) {
          _checkAndUpdateWindowState();
          } else {
            timer.cancel();
          }
        });
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
    _loadQuickMessagesPanelWidth();
    _loadQuickMessagesPanelSettings();
    _initializeDefaultGroup();
  }

  /// ✅ Inicializa o grupo padrão (primeiro grupo por ordem)
  Future<void> _initializeDefaultGroup() async {
    try {
      // Obtém o primeiro grupo por ordem (padrão)
      final defaultGroup = await _tabGroupsService.getDefaultGroup();
      if (mounted && defaultGroup != null) {
        setState(() {
          _selectedGroupId = defaultGroup.id;
        });
        // Verifica se é o grupo "Geral" para mostrar também abas sem grupo
        final isDefaultGroup = defaultGroup.name == 'Geral';
        // Carrega as abas do grupo padrão
        await _tabManager.loadSavedTabs(groupId: defaultGroup.id, isDefaultGroup: isDefaultGroup);
      }
    } catch (e) {
      debugPrint('Erro ao inicializar grupo padrão: $e');
    }
  }

  /// ✅ Carrega as abas do grupo selecionado
  Future<void> _loadTabsForSelectedGroup() async {
    // Remove todas as abas salvas (exceto Home)
    _tabManager.clearSavedTabs();
    
    // ✅ Seleciona a aba Home antes de carregar novas abas
    _tabManager.selectTab(0);
    
    // ✅ Verifica se é o grupo "Geral" para mostrar também abas sem grupo
    bool isDefaultGroup = false;
    if (_selectedGroupId != null) {
      try {
        final selectedGroup = await _tabGroupsService.getTabGroupById(_selectedGroupId!);
        isDefaultGroup = selectedGroup?.name == 'Geral';
      } catch (e) {
        debugPrint('Erro ao verificar grupo: $e');
      }
    }
    
    // Carrega as abas do grupo selecionado
    await _tabManager.loadSavedTabs(groupId: _selectedGroupId, isDefaultGroup: isDefaultGroup);
    
    if (mounted) {
      setState(() {});
    }
  }

  /// ✅ Callback quando um grupo é selecionado
  void _onGroupSelected(String? groupId) {
    setState(() {
      _selectedGroupId = groupId;
    });
    _loadTabsForSelectedGroup();
  }

  /// ✅ Carrega as configurações de posição e estilo do painel
  Future<void> _loadQuickMessagesPanelSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPosition = prefs.getString('quick_messages_panel_position');
      final savedIsDrawer = prefs.getBool('quick_messages_panel_is_drawer');
      final savedOpenLinksMode = prefs.getString('open_links_mode');
      
      if (mounted) {
        setState(() {
          if (savedPosition != null && ['left', 'right', 'bottom'].contains(savedPosition)) {
            _quickMessagesPanelPosition = savedPosition;
          }
          if (savedIsDrawer != null) {
            _quickMessagesPanelIsDrawer = savedIsDrawer;
          }
          if (savedOpenLinksMode != null && ['same_page', 'external_browser', 'webview_window'].contains(savedOpenLinksMode)) {
            _openLinksMode = savedOpenLinksMode;
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações do painel: $e');
    }
  }

  /// ✅ Salva as configurações de posição e estilo do painel
  Future<void> _saveQuickMessagesPanelSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quick_messages_panel_position', _quickMessagesPanelPosition);
      await prefs.setBool('quick_messages_panel_is_drawer', _quickMessagesPanelIsDrawer);
      await prefs.setString('open_links_mode', _openLinksMode);
    } catch (e) {
      debugPrint('Erro ao salvar configurações do painel: $e');
    }
  }

  /// ✅ Carrega a largura salva do painel de mensagens rápidas
  Future<void> _loadQuickMessagesPanelWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble('quick_messages_panel_width');
      if (savedWidth != null && savedWidth >= 150 && savedWidth <= 500) {
        // Valida que a largura está em um range razoável (reduzido ainda mais)
        if (mounted) {
          setState(() {
            _quickMessagesPanelWidth = savedWidth;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar largura do painel: $e');
    }
  }

  /// ✅ Salva a largura do painel de mensagens rápidas
  Future<void> _saveQuickMessagesPanelWidth(double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('quick_messages_panel_width', width);
    } catch (e) {
      debugPrint('Erro ao salvar largura do painel: $e');
    }
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
    // As abas serão carregadas após o grupo padrão ser inicializado
    
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
    
    // ✅ Verifica se a aba atual tem mudanças não salvas e atualiza a SnackBar
    // ✅ Usa Future.microtask para evitar chamar durante o build
    final currentTabId = _tabManager.currentTab?.id;
    if (currentTabId != null) {
      final hasUnsavedChanges = _unsavedChangesMap[currentTabId] ?? false;
      Future.microtask(() {
        if (mounted && _tabManager.currentTab?.id == currentTabId) {
          if (hasUnsavedChanges) {
            _showSaveSnackBar(currentTabId);
          } else {
            _saveSnackBarController?.close();
            _saveSnackBarController = null;
          }
        }
      });
    } else {
      // ✅ Se não há aba atual, fecha a SnackBar
      Future.microtask(() {
        if (mounted) {
          _saveSnackBarController?.close();
          _saveSnackBarController = null;
        }
      });
    }
    
    // ✅ Se a aba atual for Home, não faz rebuild para evitar descartar WebViews
    // Mas só depois da inicialização estar completa
    if (_tabManager.isCurrentTabHome) {
      return; // Não executa nenhuma ação quando é Home (após inicialização)
    }
    
    // ✅ IMPORTANTE: Durante reorder, apenas atualiza a UI da barra de abas
    // O IndexedStack não precisa ser reconstruído porque usa keys estáveis baseadas no ID
    // Isso evita recarregamento desnecessário das páginas
    // ✅ Só faz rebuild se realmente necessário (evita loops)
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
        final enableQuickMessages = savedTab?.enableQuickMessages ?? true; // ✅ DEPRECATED: Mantido para compatibilidade
        // ✅ Obtém configuração de atalhos rápidos por URL do cache (carregada assincronamente)
        final enableQuickMessagesByUrl = savedTab?.id != null 
            ? _quickMessagesByUrlCache[savedTab!.id!] 
            : null;
        // ✅ Carrega configuração assincronamente se ainda não estiver no cache (fora do build)
        // ✅ Evita múltiplas chamadas simultâneas usando flag
        if (savedTab?.id != null && 
            !_quickMessagesByUrlCache.containsKey(savedTab!.id!) &&
            !_loadingQuickMessagesTabs.contains(savedTab!.id!)) {
          // ✅ Usa Future.microtask para executar após o build atual
          _loadingQuickMessagesTabs.add(savedTab!.id!);
          Future.microtask(() {
            _loadQuickMessagesByUrlForTab(savedTab!.id!);
          });
        }
        // ✅ Inclui apenas enableQuickMessages na chave do cache (não inclui _showNavigationBars para evitar recarregar páginas)
        final cacheKeySuffix = '_qm_$enableQuickMessages';
        if (savedTab != null && savedTab.hasMultiplePages) {
          final urls = savedTab.urlList;
          final columns = savedTab.columns ?? 2;
          final rows = savedTab.rows ?? 2;
          
          // ✅ Cria ou obtém GlobalKey para este MultiPageWebView
          if (!_multiPageWebViewKeys.containsKey(tab.id)) {
            _multiPageWebViewKeys[tab.id] = GlobalKey();
          }
          final multiPageKey = _multiPageWebViewKeys[tab.id]!;
          
          // ✅ Sempre retorna um novo widget wrapper com o valor atual de _showNavigationBars
          // ✅ A Key do MultiPageWebView é a mesma, então o Flutter reutiliza o widget e chama didUpdateWidget
          return _KeepAliveWebView(
              key: ValueKey('keepalive_multipage_${tab.id}$cacheKeySuffix'),
              child: MultiPageWebView(
              key: multiPageKey,
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
              quickMessages: _globalQuickMessages.messages,
              enableQuickMessages: enableQuickMessages, // ✅ DEPRECATED: Mantido para compatibilidade
              enableQuickMessagesByUrl: enableQuickMessagesByUrl, // ✅ Configuração por URL
              onQuickMessageHint: _showQuickMessageHint,
              iconUrl: savedTab?.iconUrl,
              pageName: savedTab?.name,
              onNewTabRequested: _onNewTabRequested,
              externalNavBarVisibility: _showNavigationBars, // ✅ Sempre usa o valor atual
              openLinksMode: _openLinksMode, // ✅ Passa configuração de abrir links
              onNavBarVisibilityChanged: (isVisible) {
                // ✅ Atualiza o estado do toggle quando a barra é ocultada automaticamente
                if (mounted && _showNavigationBars != isVisible) {
                  setState(() {
                    _showNavigationBars = isVisible;
                  });
                }
              },
              hideFloatingButton: true,
              onUnsavedChangesChanged: (hasChanges) {
                _onUnsavedChangesChanged(tab.id, hasChanges);
              },
            ),
          );
        } else {
          // Aba normal com uma única página
          // ✅ Obtém configuração para o índice 0 (primeira e única URL)
          final indexKey = '_index_0';
          final enableQuickMessagesForUrl = enableQuickMessagesByUrl?[indexKey] ?? enableQuickMessages;
          
          // ✅ Sempre retorna um novo widget wrapper com o valor atual de _showNavigationBars
          // ✅ A Key do BrowserWebViewWindows é a mesma, então o Flutter reutiliza o widget e chama didUpdateWidget
          return _KeepAliveWebView(
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
              enableQuickMessages: enableQuickMessagesForUrl, // ✅ Usa configuração por URL se disponível
                onQuickMessageHint: _showQuickMessageHint, // ✅ Callback para hints
                iconUrl: savedTab?.iconUrl, // ✅ Passa ícone da aba salva
                pageName: savedTab?.name, // ✅ Passa nome da aba salva
                onNewTabRequested: _onNewTabRequested, // ✅ Callback para criar nova aba (PDFs)
              externalNavBarVisibility: _showNavigationBars, // ✅ Sempre usa o valor atual
              openLinksMode: _openLinksMode, // ✅ Passa configuração de abrir links
              onNavBarVisibilityChanged: (isVisible) {
                // ✅ Atualiza o estado do toggle quando a barra é ocultada automaticamente
                if (mounted && _showNavigationBars != isVisible) {
                  setState(() {
                    _showNavigationBars = isVisible;
                  });
                }
              },
            ),
          );
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
        _quickMessageHintColor = Colors.white;
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
    // ✅ Cancela timers
    _quickMessageHintTimer?.cancel();
    _windowStateCheckTimer?.cancel();
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

  /// ✅ Abre uma URL em uma nova janela externa (usado para PDFs e pop-ups)
  Future<void> _onNewTabRequested(String url) async {
    try {
      // ✅ Decodifica a URL se necessário (converte %20 para espaço, etc)
      String decodedUrl = url;
      try {
        decodedUrl = Uri.decodeFull(url);
      } catch (e) {
        CompactLogger.log('⚠️ Erro ao decodificar URL', e.toString());
      }
      
      // ✅ Verifica se é realmente um PDF
      final isPdf = decodedUrl.toLowerCase().endsWith('.pdf') ||
                    decodedUrl.toLowerCase().contains('.pdf?') ||
                    decodedUrl.startsWith('data:application/pdf') ||
                    decodedUrl.startsWith('data:application/x-pdf');
      
      String windowTitle = 'Nova Aba';
      
      if (isPdf) {
        CompactLogger.logUrl('📄 Abrindo PDF', url);
        
        // ✅ Extrai o nome do arquivo PDF
        String pdfName = 'PDF';
        
        // ✅ 1. Tenta obter do histórico de downloads da aba atual
        final currentTab = _tabManager.currentTab;
        if (currentTab != null) {
          final downloads = PageDownloadHistoryService.getDownloads(currentTab.id);
          // Procura o download mais recente que corresponde a esta URL
          for (var download in downloads) {
            if (download.filePath == url || download.filePath == decodedUrl) {
              pdfName = download.fileName;
              break;
            }
          }
        }
        
        // ✅ 2. Se não encontrou no histórico, tenta extrair da URL
        if (pdfName == 'PDF') {
          if (decodedUrl.toLowerCase().endsWith('.pdf') || decodedUrl.contains('.pdf?')) {
            pdfName = decodedUrl.split('/').last.split('?').first;
            if (pdfName.isEmpty || !pdfName.toLowerCase().endsWith('.pdf')) {
              pdfName = 'PDF';
            }
          }
        }
        
        windowTitle = pdfName;
      } else {
        CompactLogger.logUrl('🪟 Abrindo pop-up', url);
        // ✅ Para pop-ups, usa "Nova Aba" inicialmente - o título será atualizado quando a página carregar
        windowTitle = 'Nova Aba';
      }
      
      // ✅ Obtém o userId do usuário atual
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id ?? '';
      
      if (userId.isEmpty) {
        debugPrint('❌ Usuário não autenticado, não é possível abrir em nova janela');
        return;
      }
      
      // ✅ Cria um SavedTab temporário
      // Para PDFs: usa hash da URL para compartilhar posição/tamanho
      // Para pop-ups: usa timestamp para criar janela única
      final tabId = isPdf 
          ? 'pdf_${decodedUrl.hashCode.toString().replaceAll('-', 'n')}'
          : DateTime.now().millisecondsSinceEpoch.toString();
      
      final now = DateTime.now();
      
      final savedTab = SavedTab(
        id: tabId,
        userId: userId,
        name: windowTitle,
        url: decodedUrl,
        urls: [decodedUrl],
        columns: 1,
        rows: 1,
        enableQuickMessages: !isPdf, // ✅ Pop-ups podem usar mensagens rápidas, PDFs não
        tabOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      
      // ✅ Abre em uma nova janela externa usando o método existente
      // ✅ Executa de forma completamente assíncrona e não-bloqueante usando microtask
      // ✅ Isso garante que o WebView não trave e a janela atual não seja afetada
      Future.microtask(() {
        _openInExternalWindow(savedTab).catchError((e) {
          debugPrint('Erro ao abrir janela externa: $e');
        });
      });
      
      if (isPdf) {
        // ✅ Para data URLs, mostra apenas o tipo, não o conteúdo base64
        if (decodedUrl.startsWith('data:')) {
          CompactLogger.log('📄 PDF aberto: data:application/pdf (base64)');
        } else {
          CompactLogger.logUrl('📄 PDF aberto', decodedUrl);
        }
      } else {
        CompactLogger.logUrl('🪟 Pop-up aberto', decodedUrl);
      }
    } catch (e, stackTrace) {
      CompactLogger.log('❌ Erro ao abrir em nova janela', e.toString());
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
        selectedGroupId: _selectedGroupId, // Grupo selecionado no momento
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
      
      // ✅ Se a aba salva pertence ao grupo atual, recarrega as abas do grupo
      if (result.groupId == _selectedGroupId) {
        await _loadTabsForSelectedGroup();
      }
      
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
        await Future.delayed(const Duration(milliseconds: 300));
        
        // ✅ Tenta carregar a URL - se o controller ainda não estiver pronto, tenta novamente com mais tentativas
        int attempts = 0;
        const maxAttempts = 20; // Aumentado para 3 segundos (20 * 150ms)
        while (attempts < maxAttempts && tab.controller == null) {
          await Future.delayed(const Duration(milliseconds: 150));
          attempts++;
          
          // ✅ A cada 5 tentativas, verifica se o ambiente está inicializado
          if (attempts % 5 == 0 && tab.environment == null) {
            debugPrint('⚠️ Ambiente não inicializado após ${attempts * 150}ms, tentando inicializar...');
            try {
              await tab.initializeEnvironment();
            } catch (e) {
              debugPrint('❌ Erro ao inicializar ambiente: $e');
            }
          }
        }
        
        if (tab.controller != null) {
          try {
            await tab.loadUrl(savedTab.url);
            tab.updateTitle(savedTab.name);
            tab.updateUrl(savedTab.url);
            // ✅ Atualiza cache de notificações após carregar
            _updateNotificationCache();
          } catch (e) {
            debugPrint('❌ Erro ao carregar URL na aba ${tab.id}: $e');
            // ✅ Mesmo com erro, atualiza a URL para que seja carregada quando o controller estiver pronto
            tab.updateUrl(savedTab.url);
            tab.updateTitle(savedTab.name);
          }
        } else {
          debugPrint('⚠️ WebView controller não está pronto para aba ${tab.id} após ${maxAttempts * 150}ms');
          // ✅ Mesmo sem controller, atualiza a URL para que seja carregada quando o WebView for criado
          tab.updateUrl(savedTab.url);
          tab.updateTitle(savedTab.name);
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
      CompactLogger.log('❌ Erro ao selecionar aba $index', e.toString());
      // Tenta pelo menos selecionar a aba visualmente mesmo com erro
      if (mounted && index < _tabManager.tabs.length) {
        _tabManager.selectTab(index);
        setState(() {});
      }
    }
  }

  Future<void> _openInExternalWindow(SavedTab savedTab) async {
    // ✅ CRÍTICO: Executa TUDO em um isolate separado usando compute para não bloquear a thread principal
    // Isso garante que a criação da janela seja completamente isolada e não afete a janela atual
    if (!Platform.isWindows || savedTab.id == null) {
      // Fallback para outras plataformas ou se não tem ID - usa dialog de forma assíncrona
      Future.microtask(() async {
        if (mounted) {
          try {
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
                    quickMessages: _globalQuickMessages.messages,
                  ),
                ),
              ),
            );
          } catch (e) {
            debugPrint('Erro ao abrir dialog: $e');
          }
        }
      });
      return;
    }

    // ✅ Prepara dados ANTES de executar em isolate
    final quickMessages = _globalQuickMessages.messages;
    final quickMessagesData = quickMessages.map((m) => m.toMap()).toList();
    final savedTabJson = savedTab.toJson();
    
    final isTemporaryPopup = savedTab.name == 'Nova Aba' && 
                             !savedTab.url.toLowerCase().endsWith('.pdf') &&
                             !savedTab.url.toLowerCase().contains('.pdf?') &&
                             !savedTab.url.startsWith('data:application/pdf') &&
                             !savedTab.url.startsWith('data:application/x-pdf');
    
    final windowTitle = isTemporaryPopup ? '' : savedTab.name;
    
    // ✅ CRÍTICO: Executa a criação da janela em um microtask completamente isolado
    // Isso garante que não bloqueie a thread principal de forma alguma
    Future.microtask(() async {
      try {
        final windowManager = WindowManagerHelper();
        await windowManager.createOrActivateWindow(
          tabId: savedTab.id!,
          windowTitle: windowTitle,
          savedTabData: savedTabJson,
          quickMessagesData: quickMessagesData,
        );
      } catch (e) {
        debugPrint('❌ Erro ao criar janela: $e');
      }
    });
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
    
    // ✅ Remove dados relacionados a mudanças não salvas e GlobalKeys
    _unsavedChangesMap.remove(tab.id);
    _multiPageWebViewKeys.remove(tab.id);
    
    // ✅ Se a aba fechada era a atual e tinha SnackBar aberta, fecha ela
    if (_tabManager.currentTab?.id == tab.id) {
      _saveSnackBarController?.close();
      _saveSnackBarController = null;
    }
    
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
      // ✅ Conteúdo da página Home
      final homeContent = Scaffold(
        key: _scaffoldKey,
        appBar: _DraggableAppBar(
          onWindowStateChanged: _checkAndUpdateWindowState,
          child: AppBar(
            backgroundColor: const Color(0xFF00a4a4),
            foregroundColor: Colors.white,
            leadingWidth: 100, // ✅ Aumenta a largura para acomodar dois ícones
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Botão de menu de abas (primeiro)
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    // ✅ Se o drawer de mensagens estiver ativo na esquerda, abre o drawer de abas através de um diálogo
                    if (_quickMessagesPanelIsDrawer && _showQuickMessagesPanel && _quickMessagesPanelPosition == 'left') {
                      // Abre o drawer de abas através de um diálogo ou ação alternativa
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          alignment: Alignment.centerLeft,
                          insetPadding: EdgeInsets.zero,
                          child: SizedBox(
                            width: 300,
                            height: MediaQuery.of(context).size.height,
                            child: _buildTabsDrawer(),
                          ),
                        ),
                      );
                    } else {
                      _scaffoldKey.currentState?.openDrawer();
                    }
                  },
                  tooltip: 'Todas as Abas',
                  color: Colors.white,
                ),
                // ✅ Botão de grupos de abas (segundo)
                IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  tooltip: 'Grupos de Abas',
                  color: Colors.white,
                ),
              ],
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
                color: Colors.white,
              ),
              // Botão Mensagens Rápidas
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  _showAddQuickMessageDialog(context);
                },
                tooltip: 'Adicionar Mensagem Rápida',
                color: Colors.white,
              ),
              // Botão Configurações
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsDialog(context),
                tooltip: 'Configurações',
                color: Colors.white,
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
              // ✅ Botão Minimizar (ícone nativo: linha horizontal)
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: _minimizeWindow,
                tooltip: 'Minimizar',
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // ✅ Botão Maximizar/Restaurar (ícones nativos: quadrado vazio / restaurar)
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
              // ✅ Botão Fechar (ícone nativo: X)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _handleExitApp,
                tooltip: 'Fechar',
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
        drawer: _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'left'
            ? (_showQuickMessagesPanel
                ? Drawer(
                    width: _quickMessagesPanelWidth,
                    child: _QuickMessagesPanel(
                      width: _quickMessagesPanelWidth,
                      onClose: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _showQuickMessagesPanel = false;
                        });
                      },
                    ),
                  )
                : _buildTabsDrawer())
            : _buildTabsDrawer(),
        onDrawerChanged: (isOpened) {
          // ✅ Detecta quando o drawer é fechado (arrastando ou clicando fora)
          if (!isOpened && _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'left' && _showQuickMessagesPanel) {
            setState(() {
              _showQuickMessagesPanel = false;
            });
          }
        },
        endDrawer: _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'right'
            ? Drawer(
                width: _quickMessagesPanelWidth,
                child: _showQuickMessagesPanel
                    ? _QuickMessagesPanel(
                        width: _quickMessagesPanelWidth,
                        onClose: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _showQuickMessagesPanel = false;
                          });
                        },
                      )
                    : TabGroupsScreen(
                        selectedGroupId: _selectedGroupId,
                        onGroupSelected: _onGroupSelected,
                      ),
              )
            : TabGroupsScreen(
                selectedGroupId: _selectedGroupId,
                onGroupSelected: _onGroupSelected,
              ),
        onEndDrawerChanged: (isOpened) {
          // ✅ Detecta quando o endDrawer é fechado (arrastando ou clicando fora)
          if (!isOpened && _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'right' && _showQuickMessagesPanel) {
            setState(() {
              _showQuickMessagesPanel = false;
            });
          }
        },
        body: Column(
          children: [
            // Barra de abas
            _buildTabBar(),
            // ✅ Conteúdo principal com painel (se visível)
            Expanded(
              child: _quickMessagesPanelPosition == 'bottom'
                  ? Column(
                      children: [
                        // ✅ Conteúdo principal (página Home)
            Expanded(
              child: WelcomeScreen(),
                        ),
                        // ✅ Painel embaixo com mensagens lado a lado (apenas quando fixo)
                        if (_showQuickMessagesPanel && _quickMessagesPanelPosition == 'bottom' && !_quickMessagesPanelIsDrawer)
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!, width: 1),
                              ),
                            ),
                            child: _QuickMessagesPanel(
                              width: double.infinity,
                              isHorizontalLayout: true,
                              onClose: () {
                                setState(() {
                                  _showQuickMessagesPanel = false;
                                });
                              },
                            ),
                          ),
                      ],
                    )
                  : _showQuickMessagesPanel && 
                        _quickMessagesPanelPosition == 'left' && 
                        !_quickMessagesPanelIsDrawer
                      ? Row(
                          children: [
                            _buildQuickMessagesPanelWidget(),
                            Expanded(
                              child: WelcomeScreen(),
                            ),
                          ],
                        )
                      : _showQuickMessagesPanel && 
                            _quickMessagesPanelPosition == 'right' && 
                            !_quickMessagesPanelIsDrawer
                          ? Row(
                              children: [
                                Expanded(
                                  child: WelcomeScreen(),
                                ),
                                _buildQuickMessagesPanelWidget(),
                              ],
                            )
                          : WelcomeScreen(),
            ),
          ],
        ),
      );
    }

    // ✅ Constrói o conteúdo principal (abas e WebViews)
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildCustomAppBar(),
      drawer: _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'left'
          ? (_showQuickMessagesPanel
              ? Drawer(
                  width: _quickMessagesPanelWidth,
                  child: _QuickMessagesPanel(
                    width: _quickMessagesPanelWidth,
                    onClose: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _showQuickMessagesPanel = false;
                      });
                    },
                  ),
                )
              : _buildTabsDrawer())
          : _buildTabsDrawer(),
      onDrawerChanged: (isOpened) {
        // ✅ Detecta quando o drawer é fechado (arrastando ou clicando fora)
        if (!isOpened && _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'left' && _showQuickMessagesPanel) {
          setState(() {
            _showQuickMessagesPanel = false;
          });
        }
      },
      endDrawer: _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'right'
          ? Drawer(
              width: _quickMessagesPanelWidth,
              child: _showQuickMessagesPanel
                  ? _QuickMessagesPanel(
                      width: _quickMessagesPanelWidth,
                      onClose: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _showQuickMessagesPanel = false;
                        });
                      },
                    )
                  : TabGroupsScreen(
                      selectedGroupId: _selectedGroupId,
                      onGroupSelected: _onGroupSelected,
                    ),
            )
          : TabGroupsScreen(
              selectedGroupId: _selectedGroupId,
              onGroupSelected: _onGroupSelected,
            ),
      onEndDrawerChanged: (isOpened) {
        // ✅ Detecta quando o endDrawer é fechado (arrastando ou clicando fora)
        if (!isOpened && _quickMessagesPanelIsDrawer && _quickMessagesPanelPosition == 'right' && _showQuickMessagesPanel) {
          setState(() {
            _showQuickMessagesPanel = false;
          });
        }
      },
      body: Column(
        children: [
          // Barra de abas (precisa adaptar para usar BrowserTabWindows)
          _buildTabBar(),
          
          // ✅ Conteúdo principal com painel (se visível)
          Expanded(
            child: _quickMessagesPanelPosition == 'bottom'
                ? Column(
                    children: [
                      // ✅ Conteúdo principal (WebViews)
          Expanded(
            child: IndexedStack(
              index: _tabManager.currentTabIndex,
              children: _buildIndexedStackChildren(),
                        ),
                      ),
                      // ✅ Painel embaixo com mensagens lado a lado (apenas quando fixo)
                      if (_showQuickMessagesPanel && _quickMessagesPanelPosition == 'bottom' && !_quickMessagesPanelIsDrawer)
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                          ),
                          child: _QuickMessagesPanel(
                            width: double.infinity,
                            isHorizontalLayout: true,
                            onClose: () {
                              setState(() {
                                _showQuickMessagesPanel = false;
                              });
                            },
            ),
          ),
        ],
                  )
                : Row(
                    children: [
                      // ✅ Painel à esquerda (se configurado)
                      if (_showQuickMessagesPanel && 
                          _quickMessagesPanelPosition == 'left' && 
                          !_quickMessagesPanelIsDrawer)
                        _buildQuickMessagesPanelWidget(),
                      // ✅ Conteúdo principal (WebViews)
                      Expanded(
                        child: IndexedStack(
                          index: _tabManager.currentTabIndex,
                          children: _buildIndexedStackChildren(),
                        ),
                      ),
                      // ✅ Painel à direita (se configurado e não for drawer)
                      if (_showQuickMessagesPanel && 
                          _quickMessagesPanelPosition == 'right' && 
                          !_quickMessagesPanelIsDrawer)
                        _buildQuickMessagesPanelWidget(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// ✅ Constrói o widget do painel de mensagens rápidas baseado nas configurações
  Widget _buildQuickMessagesPanelWidget() {
    if (!_showQuickMessagesPanel) {
      return const SizedBox.shrink();
    }

    final panelWidget = _QuickMessagesPanel(
      width: _quickMessagesPanelWidth,
      onClose: () {
        setState(() {
          _showQuickMessagesPanel = false;
        });
      },
    );

    // ✅ Se for drawer flutuante, usa Drawer
    if (_quickMessagesPanelIsDrawer) {
      return const SizedBox.shrink(); // Drawer será gerenciado pelo Scaffold
    }

    // ✅ Se for fixo, retorna o painel com redimensionamento
    return Stack(
      children: [
        SizedBox(
          width: _quickMessagesPanelWidth,
          child: panelWidget,
        ),
        // ✅ Widget de arraste para redimensionar (apenas para posições laterais)
        if (_quickMessagesPanelPosition != 'bottom')
          Positioned(
            right: _quickMessagesPanelPosition == 'left' ? 0 : null,
            left: _quickMessagesPanelPosition == 'right' ? 0 : null,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final delta = _quickMessagesPanelPosition == 'left' 
                      ? details.delta.dx 
                      : -details.delta.dx;
                  final newWidth = _quickMessagesPanelWidth + delta;
                  _quickMessagesPanelWidth = newWidth.clamp(150.0, 500.0);
                });
              },
              onHorizontalDragEnd: (_) {
                _saveQuickMessagesPanelWidth(_quickMessagesPanelWidth);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 4,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ✅ Mostra diálogo para adicionar nova mensagem rápida
  Future<void> _showAddQuickMessageDialog(BuildContext context) async {
    final service = QuickMessagesService();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final shortcutController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: DraggableResizableDialog(
            initialWidth: 550,
            initialHeight: 450,
            minWidth: 400,
            minHeight: 350,
            titleBar: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00a4a4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(Icons.message, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Nova Mensagem Rápida',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Título',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.isEmpty ?? true ? 'Título obrigatório' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: shortcutController,
                                decoration: const InputDecoration(
                                  labelText: 'Atalho (sem /)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.isEmpty ?? true ? 'Atalho obrigatório' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: messageController,
                                decoration: const InputDecoration(
                                  labelText: 'Mensagem',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                                validator: (value) => value?.isEmpty ?? true ? 'Mensagem obrigatória' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              final previewText = messageController.text;
                              _showPreviewDialog(context, previewText);
                            },
                            child: const Text('Pre-Visualizar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final shortcut = shortcutController.text.trim().toLowerCase();
                  
                  // ✅ Verifica se o atalho já existe
                  final shortcutAlreadyExists = await service.shortcutExists(shortcut);
                  
                  if (shortcutAlreadyExists) {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.orange[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.orange, width: 2),
                        ),
                        title: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Atalho já cadastrado',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Este atalho já está cadastrado! Por favor, escolha outro atalho para esta mensagem.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'OK',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  
                  final newMessage = QuickMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    message: messageController.text,
                    shortcut: shortcut,
                    createdAt: DateTime.now(),
                  );
                  
                  await service.saveMessage(newMessage);
                  GlobalQuickMessagesService().refreshMessages();
                  
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
                            },
                            child: const Text('Salvar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// ✅ Mostra diálogo de pré-visualização da mensagem formatada como WhatsApp
  void _showPreviewDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[300],
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pre-Visualização da Mensagem',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[900]),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: message.isEmpty
                        ? Text(
                            'Digite uma mensagem para ver o preview',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _WhatsAppFormattedText(text: message),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Fechar',
                      style: TextStyle(color: Colors.grey[900]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Widget que formata texto conforme as regras do WhatsApp
  Widget _WhatsAppFormattedText({required String text}) {
    if (text.isEmpty) {
      return Text(
        'Digite uma mensagem para ver o preview',
        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
      );
    }

    return _buildFormattedText(text);
  }

  Widget _buildFormattedText(String text) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // Regex para encontrar formatações: *negrito*, _itálico_, ~tachado~, `inline`
    final patterns = [
      RegExp(r'\*([^*]+)\*'), // Negrito: *texto*
      RegExp(r'_([^_]+)_'),    // Itálico: _texto_
      RegExp(r'~([^~]+)~'),    // Tachado: ~texto~
      RegExp(r'`([^`]+)`'),    // Inline: `texto`
    ];

    final styles = [
      const TextStyle(fontWeight: FontWeight.bold),
      const TextStyle(fontStyle: FontStyle.italic),
      const TextStyle(decoration: TextDecoration.lineThrough),
      const TextStyle(fontFamily: 'monospace', fontSize: 14),
    ];

    while (currentIndex < text.length) {
      int? earliestMatchIndex;
      int? earliestMatchEnd;
      int? patternIndex;
      String? matchedText;

      // Encontra a primeira formatação
      for (int i = 0; i < patterns.length; i++) {
        final match = patterns[i].firstMatch(text.substring(currentIndex));
        if (match != null) {
          final matchStart = currentIndex + match.start;
          if (earliestMatchIndex == null || matchStart < earliestMatchIndex) {
            earliestMatchIndex = matchStart;
            earliestMatchEnd = currentIndex + match.end;
            patternIndex = i;
            matchedText = match.group(1);
          }
        }
      }

      if (earliestMatchIndex != null && matchedText != null) {
        // Adiciona texto antes da formatação
        if (earliestMatchIndex > currentIndex) {
          spans.add(TextSpan(text: text.substring(currentIndex, earliestMatchIndex)));
        }

        // Adiciona texto formatado
        spans.add(TextSpan(
          text: matchedText,
          style: styles[patternIndex!],
        ));

        currentIndex = earliestMatchEnd!;
      } else {
        // Adiciona o resto do texto
        spans.add(TextSpan(text: text.substring(currentIndex)));
        break;
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: spans,
      ),
    );
  }

  /// ✅ Constrói o AppBar customizado para abas normais (não Home)
  PreferredSizeWidget _buildCustomAppBar() {
    return _DraggableAppBar(
      onWindowStateChanged: _checkAndUpdateWindowState,
      child: AppBar(
        backgroundColor: const Color(0xFF00a4a4),
        foregroundColor: Colors.white,
        leadingWidth: 100, // ✅ Aumenta a largura para acomodar dois ícones
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Botão de menu de abas (primeiro)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                // ✅ Se o drawer de mensagens estiver ativo na esquerda, abre o drawer de abas através de um diálogo
                if (_quickMessagesPanelIsDrawer && _showQuickMessagesPanel && _quickMessagesPanelPosition == 'left') {
                  // Abre o drawer de abas através de um diálogo ou ação alternativa
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      alignment: Alignment.centerLeft,
                      insetPadding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 300,
                        height: MediaQuery.of(context).size.height,
                        child: _buildTabsDrawer(),
                      ),
                    ),
                  );
                } else {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
              tooltip: 'Todas as Abas',
              color: Colors.white,
            ),
            // ✅ Botão de grupos de abas (segundo)
            IconButton(
              icon: const Icon(Icons.folder),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
              tooltip: 'Grupos de Abas',
              color: Colors.white,
            ),
          ],
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
            color: Colors.white,
          ),
          // Botão Mensagens Rápidas
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              _showAddQuickMessageDialog(context);
            },
            tooltip: 'Adicionar Mensagem Rápida',
            color: Colors.white,
          ),
          // Botão Configurações
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Configurações',
            color: Colors.white,
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
          // ✅ Botão Minimizar (ícone nativo: linha horizontal)
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            onPressed: _minimizeWindow,
            tooltip: 'Minimizar',
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // ✅ Botão Maximizar/Restaurar (ícones nativos: quadrado vazio / restaurar)
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
          // ✅ Botão Fechar (ícone nativo: X)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _handleExitApp,
            tooltip: 'Fechar',
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
          // ✅ Aba especial para Mensagens Rápidas (primeira aba) - sempre visível
          _buildQuickMessagesTab(),
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
          // ✅ Botão Mostrar/Esconder Barras de Navegação (ao lado do menu drawer)
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _showNavigationBars = !_showNavigationBars;
                  });
                  debugPrint('✅ Toggle navigation bars: $_showNavigationBars');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _showNavigationBars ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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

  /// ✅ Constrói a aba especial de Mensagens Rápidas
  Widget _buildQuickMessagesTab() {
    final isSelected = _showQuickMessagesPanel;
    return Container(
      margin: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Material(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (_quickMessagesPanelIsDrawer) {
              // ✅ Se for drawer flutuante
              if (_quickMessagesPanelPosition == 'left') {
                // Drawer esquerdo
                if (_showQuickMessagesPanel) {
                  Navigator.of(context).pop();
                  setState(() {
                    _showQuickMessagesPanel = false;
                  });
                } else {
                  setState(() {
                    _showQuickMessagesPanel = true;
                  });
                  _scaffoldKey.currentState?.openDrawer();
                }
              } else if (_quickMessagesPanelPosition == 'right') {
                // Drawer direito
                if (_showQuickMessagesPanel) {
                  Navigator.of(context).pop();
                  setState(() {
                    _showQuickMessagesPanel = false;
                  });
                } else {
                  setState(() {
                    _showQuickMessagesPanel = true;
                  });
                  _scaffoldKey.currentState?.openEndDrawer();
                }
              } else if (_quickMessagesPanelPosition == 'bottom') {
                // ✅ Bottom sheet flutuante
                if (_showQuickMessagesPanel) {
                  Navigator.of(context).pop();
                  setState(() {
                    _showQuickMessagesPanel = false;
                  });
                } else {
                  setState(() {
                    _showQuickMessagesPanel = true;
                  });
                  _showQuickMessagesBottomSheet(context);
                }
              }
            } else {
              // ✅ Se for fixo, apenas alterna visibilidade
              setState(() {
                _showQuickMessagesPanel = !_showQuickMessagesPanel;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Icon(
              Icons.message,
              size: 18,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
          ),
        ),
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
              // ✅ CRÍTICO: Calcula o tamanho ANTES de restaurar para garantir que usa o tamanho da tela primária
              double? newWidth;
              double? newHeight;
              double? x;
              double? y;
              
              try {
                // ✅ Obtém o tamanho da tela primária usando dart:ui ANTES de restaurar
                final views = ui.PlatformDispatcher.instance.views;
                if (views.isNotEmpty) {
                  final primaryView = views.first;
                  final screenSize = primaryView.physicalSize;
                  final devicePixelRatio = primaryView.devicePixelRatio;
                  
                  final screenWidth = screenSize.width / devicePixelRatio;
                  final screenHeight = screenSize.height / devicePixelRatio;
                  
                  newWidth = screenWidth * 0.7;
                  newHeight = screenHeight * 0.7;
                  x = (screenWidth - newWidth) / 2;
                  y = (screenHeight - newHeight) / 2;
                }
              } catch (e) {
                debugPrint('⚠️ Erro ao calcular tamanho da tela primária: $e');
              }
              
              // ✅ Restaura a janela
              await windowManager.restore();
              await Future.delayed(const Duration(milliseconds: 150));
              
              // ✅ Se calculou o tamanho corretamente, aplica
              if (newWidth != null && newHeight != null && x != null && y != null) {
                try {
                  await windowManager.setSize(Size(newWidth, newHeight));
                  await windowManager.setPosition(Offset(x, y));
                  debugPrint('✅ Janela restaurada (double tap): ${newWidth.toInt()}x${newHeight.toInt()}');
                } catch (e) {
                  debugPrint('⚠️ Erro ao aplicar tamanho/posição: $e');
                }
              }
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
        selectedGroupId: _selectedGroupId, // Grupo selecionado no momento
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
        
        // ✅ Remove dados relacionados a mudanças não salvas e GlobalKeys
        _unsavedChangesMap.remove(tab.id);
        _multiPageWebViewKeys.remove(tab.id);
        
        // ✅ Se a aba removida era a atual e tinha SnackBar aberta, fecha ela
        if (_tabManager.currentTab?.id == tab.id) {
          _saveSnackBarController?.close();
          _saveSnackBarController = null;
        }
        
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

  /// ✅ Mostra o bottom sheet de mensagens rápidas quando configurado como drawer embaixo
  void _showQuickMessagesBottomSheet(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      constraints: BoxConstraints(
        maxWidth: screenWidth, // ✅ Limita a largura máxima à largura da tela
      ),
      builder: (context) => SizedBox(
        width: screenWidth, // ✅ Ocupa toda a largura do dispositivo
        child: DraggableScrollableSheet(
          initialChildSize: 0.18, // ✅ Altura inicial ainda mais reduzida
          minChildSize: 0.08, // ✅ Altura mínima muito reduzida
          maxChildSize: 0.9,
          builder: (context, scrollController) => SizedBox(
            width: screenWidth, // ✅ Garante que ocupa toda a largura
            child: Container(
              width: double.infinity, // ✅ Força ocupar toda a largura disponível
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // ✅ Handle para arrastar
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // ✅ Painel de mensagens rápidas
                  Expanded(
                    child: _QuickMessagesPanel(
                      width: double.infinity,
                      isHorizontalLayout: true,
                      onClose: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _showQuickMessagesPanel = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // ✅ Quando o bottom sheet é fechado, atualiza o estado
      if (mounted) {
        setState(() {
          _showQuickMessagesPanel = false;
        });
      }
    });
  }

  /// ✅ Mostra o diálogo de configurações
  void _showSettingsDialog(BuildContext context) {
    // ✅ Oculta a barra de mensagens rápidas se estiver visível
    if (_showQuickMessagesPanel) {
      setState(() {
        _showQuickMessagesPanel = false;
      });
    }
    
    // Estado local para os checkboxes
    bool clearWindowBounds = false;
    bool clearPageProportions = false;
    bool clearDownloadHistory = false;
    bool clearOpenAsWindow = false;
    
    // ✅ Variáveis locais para as configurações do painel (não salva imediatamente)
    String tempPanelPosition = _quickMessagesPanelPosition;
    bool tempPanelIsDrawer = _quickMessagesPanelIsDrawer;
    String tempOpenLinksMode = _openLinksMode;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue),
              SizedBox(width: 8),
              Text('Configurações'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Seção de configurações do painel de mensagens rápidas
                const Text(
                  'Painel de Mensagens Rápidas:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Posição do painel:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('Esquerda'),
                  value: 'left',
                  groupValue: tempPanelPosition,
                  onChanged: (value) {
                    setDialogState(() {
                      tempPanelPosition = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Direita'),
                  value: 'right',
                  groupValue: tempPanelPosition,
                  onChanged: (value) {
                    setDialogState(() {
                      tempPanelPosition = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Embaixo'),
                  value: 'bottom',
                  groupValue: tempPanelPosition,
                  onChanged: (value) {
                    setDialogState(() {
                      tempPanelPosition = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Estilo do painel:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                RadioListTile<bool>(
                  title: const Text('Fixo'),
                  subtitle: const Text('Painel fixo na lateral'),
                  value: false,
                  groupValue: tempPanelIsDrawer,
                  onChanged: (value) {
                    setDialogState(() {
                      tempPanelIsDrawer = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  title: const Text('Drawer flutuante'),
                  subtitle: const Text('Painel deslizante como menu lateral'),
                  value: true,
                  groupValue: tempPanelIsDrawer,
                  onChanged: (value) {
                    setDialogState(() {
                      tempPanelIsDrawer = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 32),
                const Text(
                  'Abrir Links/Pop-ups:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text('Na própria página'),
                  subtitle: const Text('Abre links na mesma aba'),
                  value: 'same_page',
                  groupValue: tempOpenLinksMode,
                  onChanged: (value) {
                    setDialogState(() {
                      tempOpenLinksMode = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('No navegador externo'),
                  subtitle: const Text('Abre links no navegador padrão do dispositivo'),
                  value: 'external_browser',
                  groupValue: tempOpenLinksMode,
                  onChanged: (value) {
                    setDialogState(() {
                      tempOpenLinksMode = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Em janela nativa do WebView2'),
                  subtitle: const Text('Abre links em uma janela nativa do WebView2'),
                  value: 'webview_window',
                  groupValue: tempOpenLinksMode,
                  onChanged: (value) {
                    setDialogState(() {
                      tempOpenLinksMode = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 32),
                const Text(
                  'Selecione o que deseja limpar:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Posições e tamanhos de janelas'),
                  subtitle: const Text('Restaura posições padrão das janelas'),
                  value: clearWindowBounds,
                  onChanged: (value) {
                    setDialogState(() {
                      clearWindowBounds = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Redimensionamento de páginas'),
                  subtitle: const Text('Restaura proporções padrão das páginas'),
                  value: clearPageProportions,
                  onChanged: (value) {
                    setDialogState(() {
                      clearPageProportions = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Histórico de downloads'),
                  subtitle: const Text('Remove todo o histórico de downloads'),
                  value: clearDownloadHistory,
                  onChanged: (value) {
                    setDialogState(() {
                      clearDownloadHistory = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Configurações de abrir como janela'),
                  subtitle: const Text('Remove preferências de abrir como janela'),
                  value: clearOpenAsWindow,
                  onChanged: (value) {
                    setDialogState(() {
                      clearOpenAsWindow = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta ação não pode ser desfeita.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // ✅ Salva as configurações do painel
                _quickMessagesPanelPosition = tempPanelPosition;
                _quickMessagesPanelIsDrawer = tempPanelIsDrawer;
                _openLinksMode = tempOpenLinksMode;
                await _saveQuickMessagesPanelSettings();
                Navigator.of(dialogContext).pop();
                
                // ✅ Atualiza o estado do widget principal
                if (mounted) {
                  setState(() {});
                }
                
                // ✅ Mostra mensagem de sucesso
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configurações salvas com sucesso!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar'),
            ),
            TextButton(
              onPressed: () async {
                final hasSelection = clearWindowBounds ||
                    clearPageProportions ||
                    clearDownloadHistory ||
                    clearOpenAsWindow;

                if (!hasSelection) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Selecione pelo menos uma opção'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();
                await _clearSelectedLocalSettings(
                  context,
                  clearWindowBounds: clearWindowBounds,
                  clearPageProportions: clearPageProportions,
                  clearDownloadHistory: clearDownloadHistory,
                  clearOpenAsWindow: clearOpenAsWindow,
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Limpar Selecionados'),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Limpa as configurações locais selecionadas
  Future<void> _clearSelectedLocalSettings(
    BuildContext context, {
    required bool clearWindowBounds,
    required bool clearPageProportions,
    required bool clearDownloadHistory,
    required bool clearOpenAsWindow,
  }) async {
    try {
      final clearedItems = <String>[];

      // ✅ Limpa posições e tamanhos de janelas
      if (clearWindowBounds) {
        await _localTabSettingsService.clearWindowBounds();
        clearedItems.add('Posições e tamanhos de janelas');
      }

      // ✅ Limpa redimensionamento de páginas
      if (clearPageProportions) {
        await _localTabSettingsService.clearPageProportions();
        clearedItems.add('Redimensionamento de páginas');
      }

      // ✅ Limpa histórico de downloads
      if (clearDownloadHistory) {
        PageDownloadHistoryService.clearAllHistory();
        clearedItems.add('Histórico de downloads');
      }

      // ✅ Limpa configurações de abrir como janela
      if (clearOpenAsWindow) {
        await _localTabSettingsService.clearOpenAsWindowSettings();
        clearedItems.add('Configurações de abrir como janela');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Configurações limpas: ${clearedItems.join(', ')}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao limpar configurações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Callback chamado quando há mudanças não salvas em uma aba
  void _onUnsavedChangesChanged(String tabId, bool hasChanges) {
    setState(() {
      _unsavedChangesMap[tabId] = hasChanges;
    });
    
    // ✅ Se a aba atual tem mudanças não salvas, mostra a SnackBar
    if (hasChanges && _tabManager.currentTab?.id == tabId) {
      _showSaveSnackBar(tabId);
    } else if (!hasChanges && _tabManager.currentTab?.id == tabId) {
      // ✅ Se não há mais mudanças, fecha a SnackBar
      _saveSnackBarController?.close();
      _saveSnackBarController = null;
    }
  }

  /// ✅ Mostra a SnackBar de salvar dimensionamento
  void _showSaveSnackBar(String tabId) {
    // ✅ Verifica se a aba tem múltiplas páginas antes de mostrar a SnackBar
    final savedTab = _tabManager.getSavedTab(tabId);
    if (savedTab == null || !savedTab.hasMultiplePages) {
      return; // ✅ Não mostra SnackBar para abas com uma única página
    }
    
    // ✅ Fecha a SnackBar anterior se existir
    _saveSnackBarController?.close();
    
    // ✅ Mostra nova SnackBar com opções de Salvar, Restaurar e Fechar
    _saveSnackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'As páginas foram redimensionadas.',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _restoreProportions(tabId);
              },
              child: const Text(
                'Restaurar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _saveProportions(tabId);
              },
              child: const Text(
                'Salvar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                _closeSaveSnackBar();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Fechar',
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(days: 1), // ✅ Permanece até ser fechada manualmente
      ),
    );
  }

  /// ✅ Salva as proporções da aba atual
  Future<void> _saveProportions(String tabId) async {
    try {
      final key = _multiPageWebViewKeys[tabId];
      if (key != null) {
        await MultiPageWebView.saveProportionsFromKey(key);
        
        // ✅ Fecha a SnackBar
        _closeSaveSnackBar();
        
        // ✅ Mostra mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dimensionamento salvo com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar proporções: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ✅ Restaura as proporções para o tamanho padrão
  Future<void> _restoreProportions(String tabId) async {
    try {
      final key = _multiPageWebViewKeys[tabId];
      if (key != null) {
        await MultiPageWebView.restoreProportionsFromKey(key);
        
        // ✅ Fecha a SnackBar
        _closeSaveSnackBar();
        
        // ✅ Mostra mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tamanhos restaurados para padrão'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao restaurar proporções: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ✅ Fecha a SnackBar de salvar sem fazer nenhuma ação
  void _closeSaveSnackBar() {
    _saveSnackBarController?.close();
    _saveSnackBarController = null;
  }

  /// ✅ Carrega configuração de atalhos rápidos por URL para uma aba específica
  Future<void> _loadQuickMessagesByUrlForTab(String tabId) async {
    try {
      final config = await _localTabSettingsService.getQuickMessagesByUrl(tabId);
      if (mounted) {
        setState(() {
          _quickMessagesByUrlCache[tabId] = config;
          _loadingQuickMessagesTabs.remove(tabId); // ✅ Remove flag após carregar
        });
      } else {
        _loadingQuickMessagesTabs.remove(tabId); // ✅ Remove flag se não estiver montado
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar configuração de atalhos rápidos por URL: $e');
      _loadingQuickMessagesTabs.remove(tabId); // ✅ Remove flag em caso de erro
    }
  }
}

/// ✅ Widget do painel lateral de mensagens rápidas
class _QuickMessagesPanel extends StatefulWidget {
  final VoidCallback onClose;
  final double width;
  final bool isHorizontalLayout; // ✅ Para layout embaixo com mensagens lado a lado

  const _QuickMessagesPanel({
    required this.onClose,
    required this.width,
    this.isHorizontalLayout = false,
  });

  @override
  State<_QuickMessagesPanel> createState() => _QuickMessagesPanelState();
}

class _QuickMessagesPanelState extends State<_QuickMessagesPanel> {
  final QuickMessagesService _service = QuickMessagesService();
  List<QuickMessage> _messages = [];
  List<QuickMessage> _filteredMessages = [];
  bool _isLoading = true;
  String _activationKey = '/';
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.name;
  final QuickMessageUsageService _usageService = QuickMessageUsageService();
  bool _isCompactLayout = true; // ✅ Modo compacto como padrão

  @override
  void initState() {
    super.initState();
    _loadActivationKey();
    _loadMessages();
    _loadLayoutPreference();
    _searchController.addListener(_filterMessages);
    // ✅ Escuta mudanças nas mensagens rápidas globais
    GlobalQuickMessagesService().addListener(_onQuickMessagesChanged);
  }

  /// ✅ Carrega a preferência de layout salva
  Future<void> _loadLayoutPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLayout = prefs.getBool('quick_messages_compact_layout');
      if (savedLayout != null) {
        if (mounted) {
          setState(() {
            _isCompactLayout = savedLayout;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar preferência de layout: $e');
    }
  }

  /// ✅ Salva a preferência de layout
  Future<void> _saveLayoutPreference(bool isCompact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('quick_messages_compact_layout', isCompact);
    } catch (e) {
      debugPrint('Erro ao salvar preferência de layout: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    GlobalQuickMessagesService().removeListener(_onQuickMessagesChanged);
    super.dispose();
  }

  void _onQuickMessagesChanged() {
    _loadMessages();
  }

  void _filterMessages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<QuickMessage> filtered;
      if (query.isEmpty) {
        filtered = List.from(_messages);
      } else {
        filtered = _messages.where((message) {
          return message.title.toLowerCase().contains(query) ||
                 message.shortcut.toLowerCase().contains(query) ||
                 message.message.toLowerCase().contains(query);
        }).toList();
      }
      _filteredMessages = _sortMessages(filtered);
    });
  }

  List<QuickMessage> _sortMessages(List<QuickMessage> messages) {
    final sorted = List<QuickMessage>.from(messages);
    switch (_sortOption) {
      case SortOption.name:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.shortcut:
        sorted.sort((a, b) => a.shortcut.toLowerCase().compareTo(b.shortcut.toLowerCase()));
        break;
      case SortOption.message:
        sorted.sort((a, b) => a.message.toLowerCase().compareTo(b.message.toLowerCase()));
        break;
      case SortOption.mostUsed:
        sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
        break;
    }
    return sorted;
  }

  Future<void> _loadActivationKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('quick_messages_activation_key');
      if (savedKey != null && savedKey.isNotEmpty) {
        setState(() {
          _activationKey = savedKey;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar tecla de ativação: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    final messages = await _service.getAllMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
        _filteredMessages = _sortMessages(messages);
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog({QuickMessage? message}) async {
    // ✅ Usa o mesmo método do QuickMessagesScreen
    final titleController = TextEditingController(text: message?.title ?? '');
    final separator = '|||MULTI_TEXT_SEPARATOR|||';
    final messageTexts = message?.message.split(separator) ?? [message?.message ?? ''];
    final initialMessageControllers = messageTexts.map((text) => TextEditingController(text: text)).toList();
    final shortcutController = TextEditingController(text: message?.shortcut ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        final messageControllers = List<TextEditingController>.from(initialMessageControllers);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(message == null ? 'Nova Mensagem Rápida' : 'Editar Mensagem Rápida'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Título'),
                          validator: (value) => value?.isEmpty ?? true ? 'Título obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: shortcutController,
                          decoration: const InputDecoration(labelText: 'Atalho (sem /)'),
                          validator: (value) => value?.isEmpty ?? true ? 'Atalho obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        ...messageControllers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controller = entry.value;
                          return Column(
                            children: [
                              TextFormField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: index == 0 ? 'Mensagem' : 'Mensagem ${index + 1}',
                                  hintText: 'Digite a mensagem',
                                ),
                                maxLines: 3,
                                validator: (value) => value?.isEmpty ?? true ? 'Mensagem obrigatória' : null,
                              ),
                              if (index < messageControllers.length - 1) const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              messageControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar outro texto'),
                        ),
                        if (messageControllers.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  messageControllers.removeLast();
                                });
                              },
                              icon: const Icon(Icons.remove),
                              label: const Text('Remover último texto'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final shortcut = shortcutController.text.trim().toLowerCase();
                      
                      // ✅ Verifica se o atalho já existe
                      final shortcutAlreadyExists = await _service.shortcutExists(
                        shortcut,
                        excludeId: message?.id, // Exclui o ID atual se estiver editando
                      );
                      
                      if (shortcutAlreadyExists) {
                        // ✅ Mostra mensagem de aviso no topo da tela
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.orange[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.orange, width: 2),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Atalho já cadastrado',
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              message == null
                                  ? 'Este atalho já está cadastrado! Por favor, escolha outro atalho para esta mensagem.'
                                  : 'Este atalho já está cadastrado em outra mensagem! Por favor, escolha outro atalho.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        return; // Não salva se houver duplicata
                      }
                      
                      final separator = '|||MULTI_TEXT_SEPARATOR|||';
                      final messageText = messageControllers.map((c) => c.text).join(separator);
                      
                      if (message == null) {
                        // ✅ Cria nova mensagem
                        final newMessage = QuickMessage(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text,
                          message: messageText,
                          shortcut: shortcut,
                          createdAt: DateTime.now(),
                        );
                        await _service.saveMessage(newMessage);
                      } else {
                        // ✅ Atualiza mensagem existente
                        final updated = QuickMessage(
                          id: message.id,
                          title: titleController.text,
                          message: messageText,
                          shortcut: shortcut,
                          createdAt: message.createdAt,
                          updatedAt: DateTime.now(),
                          usageCount: message.usageCount,
                        );
                        await _service.updateMessage(updated);
                      }
                      
                      GlobalQuickMessagesService().refreshMessages();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      _loadMessages();
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMessage(QuickMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "${message.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteMessage(message.id);
      GlobalQuickMessagesService().refreshMessages();
      _loadMessages();
    }
  }

  void _copyMessage(QuickMessage message) {
    Clipboard.setData(ClipboardData(text: message.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensagem copiada!')),
    );
  }

  /// ✅ Mostra menu de contexto com botão direito
  void showContextMenu(BuildContext context, Offset position, QuickMessage message) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Copiar mensagem'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _copyMessage(message);
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.edit, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('Editar'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _showAddEditDialog(message: message);
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Excluir'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _deleteMessage(message);
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Column(
              children: [
                // ✅ Conteúdo do painel (header removido)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // Campo de pesquisa e ordenação
                            Material(
                              color: Colors.grey[100],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // ✅ Padding vertical reduzido
                                color: Colors.grey[100],
                                child: widget.isHorizontalLayout
                                    ? // ✅ Layout horizontal: tudo na mesma linha
                                      Row(
                                          children: [
                                            // Campo de pesquisa
                                            Expanded(
                                              flex: 2,
                                              child: TextField(
                                                controller: _searchController,
                                                decoration: InputDecoration(
                                                  hintText: 'Pesquisar mensagens...',
                                                  prefixIcon: const Icon(Icons.search, size: 20),
                                                  suffixIcon: _searchController.text.isNotEmpty
                                                      ? IconButton(
                                                          icon: const Icon(Icons.clear, size: 20),
                                                          onPressed: () => _searchController.clear(),
                                                        )
                                                      : null,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  isDense: true,
                                                ),
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Ordenar por
                                            Expanded(
                                              flex: 1,
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.sort, size: 18, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: DropdownButton<SortOption>(
                                                      value: _sortOption,
                                                      isExpanded: true,
                                                      underline: Container(),
                                                      isDense: true,
                                                      items: const [
                                                        DropdownMenuItem(value: SortOption.name, child: Text('Nome', style: TextStyle(fontSize: 12))),
                                                        DropdownMenuItem(value: SortOption.shortcut, child: Text('Atalho', style: TextStyle(fontSize: 12))),
                                                        DropdownMenuItem(value: SortOption.message, child: Text('Mensagem', style: TextStyle(fontSize: 12))),
                                                        DropdownMenuItem(value: SortOption.mostUsed, child: Text('Mais usadas', style: TextStyle(fontSize: 12))),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          setState(() {
                                                            _sortOption = value;
                                                            _filterMessages();
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Botões de layout
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.view_compact,
                                                    size: 20,
                                                    color: _isCompactLayout ? Colors.blue[700] : Colors.grey[400],
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isCompactLayout = true;
                                                    });
                                                    _saveLayoutPreference(true);
                                                  },
                                                  tooltip: 'Layout compacto',
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.view_agenda,
                                                    size: 20,
                                                    color: !_isCompactLayout ? Colors.blue[700] : Colors.grey[400],
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isCompactLayout = false;
                                                    });
                                                    _saveLayoutPreference(false);
                                                  },
                                                  tooltip: 'Layout completo',
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                    : // ✅ Layout vertical: em coluna
                                      Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: _searchController,
                                              decoration: InputDecoration(
                                                hintText: 'Pesquisar mensagens...',
                                                prefixIcon: const Icon(Icons.search),
                                                suffixIcon: _searchController.text.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(Icons.clear),
                                                        onPressed: () => _searchController.clear(),
                                                      )
                                                    : null,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (widget.width >= 250)
                                                  const Icon(Icons.sort, size: 18, color: Colors.grey),
                                                if (widget.width >= 250)
                                                  const SizedBox(width: 8),
                                                if (widget.width >= 250)
                                                  const Text('Ordenar por:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                if (widget.width >= 250)
                                                  const SizedBox(width: 8),
                                                Expanded(
                                                  child: DropdownButton<SortOption>(
                                                    value: _sortOption,
                                                    isExpanded: true,
                                                    underline: Container(),
                                                    items: const [
                                                      DropdownMenuItem(value: SortOption.name, child: Text('Nome')),
                                                      DropdownMenuItem(value: SortOption.shortcut, child: Text('Atalho')),
                                                      DropdownMenuItem(value: SortOption.message, child: Text('Mensagem')),
                                                      DropdownMenuItem(value: SortOption.mostUsed, child: Text('Mais usadas')),
                                                    ],
                                                    onChanged: (value) {
                                                      if (value != null) {
                                                        setState(() {
                                                          _sortOption = value;
                                                          _filterMessages();
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.view_compact,
                                                    color: _isCompactLayout ? Colors.blue[700] : Colors.grey[400],
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isCompactLayout = true;
                                                    });
                                                    _saveLayoutPreference(true);
                                                  },
                                                  tooltip: 'Layout compacto',
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.view_agenda,
                                                    color: !_isCompactLayout ? Colors.blue[700] : Colors.grey[400],
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isCompactLayout = false;
                                                    });
                                                    _saveLayoutPreference(false);
                                                  },
                                                  tooltip: 'Layout completo',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                            // Informação sobre como usar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // ✅ Padding vertical reduzido
                              color: Colors.blue[50],
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Digite "$_activationKey" + atalho em qualquer campo de texto',
                                      style: TextStyle(color: Colors.blue[900], fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Lista de mensagens
                            Expanded(
                              child: _filteredMessages.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _messages.isEmpty ? Icons.message_outlined : Icons.search_off,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _messages.isEmpty
                                                ? 'Nenhuma mensagem rápida cadastrada'
                                                : 'Nenhuma mensagem encontrada',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    )
                                  : widget.isHorizontalLayout
                                      ? ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), // ✅ Sem padding vertical
                                          itemCount: _filteredMessages.length,
                                          itemBuilder: (context, index) {
                                            final message = _filteredMessages[index];
                                            final separator = '|||MULTI_TEXT_SEPARATOR|||';
                                            final hasMultipleTexts = message.message.contains(separator);
                                            final tooltipText = hasMultipleTexts
                                                ? message.message.split(separator).asMap().entries.map((entry) {
                                                    return '${entry.key + 1}. ${entry.value}';
                                                  }).join('\n\n')
                                                : message.message;
                                            
                                            return Tooltip(
                                              message: tooltipText,
                                              waitDuration: const Duration(milliseconds: 500),
                                              preferBelow: false,
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // ✅ Sem margem vertical
                                                child: Material(
                                                  elevation: 1,
                                                  borderRadius: BorderRadius.circular(4),
                                                  color: Colors.white,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(4),
                                                    onTap: () => _copyMessage(message),
                                                    onSecondaryTapDown: (details) {
                                                      showContextMenu(
                                                        context,
                                                        details.globalPosition,
                                                        message,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: EdgeInsets.only(
                                                        left: _isCompactLayout ? 10 : 12,
                                                        right: _isCompactLayout ? 10 : 12,
                                                        top: _isCompactLayout ? 6 : 8,
                                                        bottom: _isCompactLayout ? 0 : 2, // ✅ Padding bottom mínimo ou zero
                                                      ),
                                                      child: DefaultTextStyle(
                                                        style: const TextStyle(height: 1.0),
                                                        child: _isCompactLayout
                                                            ? // ✅ Layout compacto: apenas título e atalho
                                                              Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      message.title,
                                                                      style: const TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.w600,
                                                                        height: 1.0,
                                                                        color: Colors.black87, // ✅ Cor do título para ficar visível
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                    const SizedBox(height: 2),
                                                                    Text(
                                                                      '$_activationKey${message.shortcut}',
                                                                      style: TextStyle(
                                                                        color: Colors.blue[700],
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.w500,
                                                                        height: 1.0,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )
                                                            : // ✅ Layout completo: título, atalho e mensagem (sempre mostra nome)
                                                              Builder(
                                                                builder: (context) {
                                                                  final separator = '|||MULTI_TEXT_SEPARATOR|||';
                                                                  final hasMultipleTexts = message.message.contains(separator);
                                                                  
                                                                  return Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                                    children: [
                                                                    Text(
                                                                      message.title,
                                                                      style: const TextStyle(
                                                                        fontSize: 13,
                                                                        fontWeight: FontWeight.w500,
                                                                        height: 1.0,
                                                                        color: Colors.black87, // ✅ Cor do título para ficar visível
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                      const SizedBox(height: 3),
                                                                      Text(
                                                                        '$_activationKey${message.shortcut}',
                                                                        style: TextStyle(
                                                                          color: Colors.blue[700],
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.w500,
                                                                          height: 1.0,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 3),
                                                                      ConstrainedBox(
                                                                        constraints: const BoxConstraints(maxWidth: 200),
                                                                        child: hasMultipleTexts
                                                                            ? Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: message.message.split(separator).asMap().entries.map((entry) {
                                                                                  final index = entry.key;
                                                                                  final text = entry.value;
                                                                                  return Padding(
                                                                                    padding: EdgeInsets.only(bottom: index < message.message.split(separator).length - 1 ? 2 : 0),
                                                                                    child: Row(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        Container(
                                                                                          width: 14,
                                                                                          height: 14,
                                                                                          margin: const EdgeInsets.only(right: 4, top: 1),
                                                                                          decoration: BoxDecoration(
                                                                                            color: Colors.blue[100],
                                                                                            borderRadius: BorderRadius.circular(2),
                                                                                          ),
                                                                                          child: Center(
                                                                                            child: Text(
                                                                                              '${index + 1}',
                                                                                              style: TextStyle(
                                                                                                fontSize: 9,
                                                                                                fontWeight: FontWeight.bold,
                                                                                                color: Colors.blue[700],
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        Expanded(
                                                                                          child: Text(
                                                                                            text,
                                                                                            style: const TextStyle(
                                                                                              fontSize: 10,
                                                                                              height: 1.0,
                                                                                              color: Colors.black87,
                                                                                            ),
                                                                                            maxLines: 2,
                                                                                            overflow: TextOverflow.ellipsis,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  );
                                                                                }).toList(),
                                                                              )
                                                                            : Text(
                                                                                message.message,
                                                                                style: const TextStyle(
                                                                                  fontSize: 10,
                                                                                  height: 1.0,
                                                                                  color: Colors.black87,
                                                                                ),
                                                                                maxLines: 3,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          itemCount: _filteredMessages.length,
                                          itemBuilder: (context, index) {
                                        final message = _filteredMessages[index];
                                        final isSmallWidth = widget.width < 350;
                                        // ✅ Prepara o texto completo para o tooltip
                                        final separator = '|||MULTI_TEXT_SEPARATOR|||';
                                        final hasMultipleTexts = message.message.contains(separator);
                                        final tooltipText = hasMultipleTexts
                                            ? message.message.split(separator).asMap().entries.map((entry) {
                                                return '${entry.key + 1}. ${entry.value}';
                                              }).join('\n\n')
                                            : message.message;
                                        
                                        return Tooltip(
                                          message: tooltipText,
                                          waitDuration: const Duration(milliseconds: 500),
                                          preferBelow: false,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Card(
                                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                              elevation: 1,
                                              child: GestureDetector(
                                              onTap: () {
                                                // ✅ Ao clicar, copia a mensagem
                                                _copyMessage(message);
                                              },
                                              onSecondaryTapDown: (details) {
                                                // ✅ Menu de contexto com botão direito
                                                showContextMenu(
                                                  context,
                                                  details.globalPosition,
                                                  message,
                                                );
                                              },
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: ListTile(
                                                  dense: true,
                                                  mouseCursor: SystemMouseCursors.click,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  leading: null, // ✅ Removido ícone do modo completo
                                                  title: Text(
                                                    message.title,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  subtitle: _isCompactLayout
                                                      ? // ✅ Modo compacto: apenas atalho
                                                        Text(
                                                          '$_activationKey${message.shortcut}',
                                                          style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500),
                                                        )
                                                      : // ✅ Modo completo: atalho e mensagem
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                '$_activationKey${message.shortcut}',
                                                                style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              // ✅ Verifica se há múltiplos textos e exibe de forma amigável
                                                              Builder(
                                                                builder: (context) {
                                                                  final separator = '|||MULTI_TEXT_SEPARATOR|||';
                                                                  final hasMultipleTexts = message.message.contains(separator);
                                                                  
                                                                  if (hasMultipleTexts) {
                                                                    final texts = message.message.split(separator);
                                                                    return Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: texts.asMap().entries.map((entry) {
                                                                        final index = entry.key;
                                                                        final text = entry.value;
                                                                        return Padding(
                                                                          padding: EdgeInsets.only(bottom: index < texts.length - 1 ? 4 : 0),
                                                                          child: Row(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                              Container(
                                                                                width: 16,
                                                                                height: 16,
                                                                                margin: const EdgeInsets.only(right: 6, top: 2),
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.blue[100],
                                                                                  borderRadius: BorderRadius.circular(3),
                                                                                ),
                                                                                child: Center(
                                                                                  child: Text(
                                                                                    '${index + 1}',
                                                                                    style: TextStyle(
                                                                                      fontSize: 10,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      color: Colors.blue[700],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  text,
                                                                                  style: const TextStyle(fontSize: 12),
                                                                                  maxLines: 2,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                    );
                                                                  } else {
                                                                    return Text(
                                                                      message.message,
                                                                      style: const TextStyle(fontSize: 12),
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            FutureBuilder<int>(
                                                              future: _usageService.getTotalUsageCount(message),
                                                              builder: (context, snapshot) {
                                                                final totalUsage = snapshot.data ?? message.usageCount;
                                                                if (totalUsage > 0) {
                                                                  return Padding(
                                                                    padding: const EdgeInsets.only(top: 4),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.trending_up, size: 14, color: Colors.grey[600]),
                                                                        const SizedBox(width: 4),
                                                                        Text(
                                                                          'Usada $totalUsage vez${totalUsage != 1 ? 'es' : ''}',
                                                                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                }
                                                                return const SizedBox.shrink();
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
            // ✅ Botão flutuante para adicionar nova mensagem
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddEditDialog(),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Exporta SortOption para uso no painel
enum SortOption {
  name,
  shortcut,
  message,
  mostUsed,
}

