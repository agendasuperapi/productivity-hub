import 'package:flutter/material.dart';
import 'dart:io';
import '../services/tab_manager_windows.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../widgets/save_tab_dialog.dart';
import '../services/auth_service.dart';
import '../services/saved_tabs_service.dart';
import '../services/quick_messages_service.dart';
import '../models/saved_tab.dart';
import '../models/browser_tab_windows.dart';
import 'browser_window_screen.dart';
import 'quick_messages_screen.dart';
import 'welcome_screen.dart';
import '../utils/window_manager_helper.dart';

/// Tela principal do navegador para Windows
class BrowserScreenWindows extends StatefulWidget {
  const BrowserScreenWindows({super.key});

  @override
  State<BrowserScreenWindows> createState() => _BrowserScreenWindowsState();
}

class _BrowserScreenWindowsState extends State<BrowserScreenWindows> {
  late TabManagerWindows _tabManager;
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

  @override
  void initState() {
    super.initState();
    _initializeTabManager();
  }

  Future<void> _initializeTabManager() async {
    _tabManager = TabManagerWindows();
    _tabManager.addListener(_onTabManagerChanged);
    
    // ✅ Aguarda a criação da aba Home antes de permitir o build
    // Isso garante que currentTab não seja null na primeira renderização
    await _tabManager.waitForHomeTab();
    
    // ✅ Aguarda o carregamento das abas salvas também
    // Isso garante que todas as abas estejam disponíveis quando a UI for renderizada
    while (_tabManager.isLoadingSavedTabs) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // ✅ Inicializa cache de notificações
    _updateNotificationCache();
    _lastTabCount = _tabManager.tabs.length;
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
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
    
    if (mounted) {
      setState(() {});
    }
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

  @override
  void dispose() {
    _tabManager.removeListener(_onTabManagerChanged);
    // ✅ IMPORTANTE: dispose() do TabManager NÃO limpa cache ou dados persistentes
    // Os WebViewEnvironments e userDataFolders são preservados para carregamento rápido
    _tabManager.dispose();
    // ✅ _widgetCache não precisa ser limpo aqui - é apenas cache em memória
    // Os dados importantes (cache do WebView, cookies) estão no userDataFolder e são preservados
    super.dispose();
  }

  void _onUrlSubmitted(String url) async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      // Atualiza a URL da aba antes de carregar
      currentTab.updateUrl(url);
      await currentTab.loadUrl(url);
      // Força atualização da UI
      setState(() {});
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
    // Cria nova aba sem URL inicial - cada aba começa vazia
    await _tabManager.createNewTab(initialUrl: 'about:blank');
    // Força atualização da UI para mostrar a nova aba com barra de endereço vazia
    setState(() {});
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
      final savedTab = _tabManager.getSavedTab(tab.id);
      if (savedTab != null && savedTab.openAsWindow) {
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
      
      // ✅ Agora sim, seleciona a aba para abas normais (não Home, não janela)
      _tabManager.selectTab(index);
      if (mounted) {
        setState(() {});
      }
      
      // ✅ Se a aba não foi carregada ainda (lazy loading), carrega APENAS quando clicada
      if (!tab.isLoaded) {
        if (savedTab != null && savedTab.url.isNotEmpty) {
          // ✅ Aguarda o WebView ser criado antes de tentar carregar
          await Future.delayed(const Duration(milliseconds: 200));
          
          // ✅ Tenta carregar a URL - se o controller ainda não estiver pronto, tenta novamente
          int attempts = 0;
          while (attempts < 2 && tab.controller == null) {
            await Future.delayed(const Duration(milliseconds: 150));
            attempts++;
          }
          
          if (tab.controller != null) {
            await tab.loadUrl(savedTab.url);
            tab.updateTitle(savedTab.name);
            tab.updateUrl(savedTab.url);
            tab.isLoaded = true; // ✅ Marca como carregada após sucesso
            // ✅ Atualiza cache de notificações após carregar
            _updateNotificationCache();
          } else {
            // Se o controller ainda não está pronto, marca como carregada para tentar depois
            tab.isLoaded = true;
            debugPrint('⚠️ WebView controller não está pronto para aba ${tab.id}');
          }
        } else if (tab.url.isEmpty || tab.url == 'about:blank') {
          // Se não há URL salva, marca como carregada para evitar tentativas repetidas
          tab.isLoaded = true;
        }
        
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
                child: BrowserWindowScreen(savedTab: savedTab),
              ),
            ),
          );
        }
        return;
      }

      // ✅ Carrega mensagens rápidas antes de criar a janela
      final quickMessagesService = QuickMessagesService();
      final quickMessages = await quickMessagesService.getAllMessages();
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
    } catch (e) {
      // ✅ Apenas loga erros críticos
      debugPrint('Erro ao criar nova janela: $e');
    }
  }

  void _onTabClosed(int index) {
    final tab = _tabManager.tabs[index];
    // ✅ Remove do cache quando a aba é fechada
    _widgetCache.remove('webview_${tab.id}');
    _widgetCache.remove('multipage_${tab.id}');
    _widgetCache.remove('home_${tab.id}');
    
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
      final oldNotificationCount = tab.notificationCount;
      
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
        appBar: AppBar(
          title: const Text('Gerencia Zap'),
          actions: [
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
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final authService = AuthService();
                await authService.signOut();
              },
              tooltip: 'Sair',
            ),
          ],
        ),
        body: Column(
          children: [
            // Barra de abas
            _buildTabBar(),
            // Tela de boas-vindas
            Expanded(
              child: WelcomeScreen(
                onGetStarted: () {
                  // Quando clicar em "Começar", não faz nada (já está na Home)
                  // O usuário pode clicar em outras abas para navegar
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerencia Zap'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = AuthService();
              await authService.signOut();
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de endereço
          BrowserAddressBar(
            currentUrl: currentTab.url,
            isLoading: currentTab.isLoading,
            canGoBack: currentTab.canGoBack,
            canGoForward: currentTab.canGoForward,
            onUrlSubmitted: _onUrlSubmitted,
            onBackPressed: _onBackPressed,
            onForwardPressed: _onForwardPressed,
            onRefreshPressed: _onRefreshPressed,
            onNewTabPressed: _onNewTabPressed,
          ),
          
          // Barra de abas (precisa adaptar para usar BrowserTabWindows)
          _buildTabBar(),
          
          // WebView - Usa IndexedStack para manter todos os WebViews vivos
          // ✅ Usa cache de widgets para evitar recriação e descarte dos WebViews
          Expanded(
            child: IndexedStack(
              index: _tabManager.currentTabIndex,
              // ✅ Usa cache para garantir que os widgets não sejam recriados
              children: _tabManager.tabs.map((tab) {
                // ✅ Se for a aba Home, mostra tela de boas-vindas
                if (_tabManager.isHomeTab(tab.id)) {
                  if (!_widgetCache.containsKey('home_${tab.id}')) {
                    _widgetCache['home_${tab.id}'] = WelcomeScreen(
                      key: ValueKey('home_${tab.id}'), // ✅ Key estável para evitar recriação
                      onGetStarted: () {
                        // Quando clicar em "Começar", não faz nada
                      },
                    );
                  }
                  return _widgetCache['home_${tab.id}']!;
                }
                
                // Verifica se a aba tem múltiplas páginas
                final savedTab = _tabManager.getSavedTab(tab.id);
                if (savedTab != null && savedTab.hasMultiplePages) {
                  final urls = savedTab.urlList;
                  final columns = savedTab.columns ?? 2;
                  final rows = savedTab.rows ?? 2;
                  
                  // ✅ Usa cache para evitar recriação do widget
                  if (!_widgetCache.containsKey('multipage_${tab.id}')) {
                    _widgetCache['multipage_${tab.id}'] = _KeepAliveWebView(
                      key: ValueKey('keepalive_multipage_${tab.id}'),
                      child: MultiPageWebView(
                        key: ValueKey('multipage_${tab.id}'),
                        urls: urls,
                        columns: columns,
                        rows: rows,
                        tabId: tab.id,
                        onUrlChanged: (url) {
                          // Atualiza apenas se for a aba atual
                          if (tab.id == _tabManager.currentTab?.id) {
                            _onUrlChanged(url);
                          }
                        },
                        onTitleChanged: (title, tabId) {
                          // Atualiza o título da aba específica usando o tabId passado
                          _onTitleChanged(title, tabId);
                        },
                        onNavigationStateChanged: (isLoading, canGoBack, canGoForward) {
                          // Atualiza apenas se for a aba atual
                          if (tab.id == _tabManager.currentTab?.id) {
                            _onNavigationStateChanged(isLoading, canGoBack, canGoForward);
                          }
                        },
                      ),
                    );
                  }
                  return _widgetCache['multipage_${tab.id}']!;
                } else {
                  // Aba normal com uma única página
                  // ✅ Log quando aba é criada/renderizada pela primeira vez
                  final isCurrentTab = tab.id == _tabManager.currentTab?.id;
                  if (isCurrentTab && !_widgetCache.containsKey('webview_${tab.id}')) {
                    debugPrint('═══════════════════════════════════════════════════════════');
                    debugPrint('🆕 NOVA ABA CRIADA/RENDERIZADA');
                    debugPrint('   └─ Nome: ${tab.title}');
                    debugPrint('   └─ ID: ${tab.id}');
                    debugPrint('   └─ URL: ${tab.url}');
                    debugPrint('═══════════════════════════════════════════════════════════');
                  }
                  
                  // ✅ Usa cache para evitar recriação do widget
                  if (!_widgetCache.containsKey('webview_${tab.id}')) {
                    _widgetCache['webview_${tab.id}'] = _KeepAliveWebView(
                      key: ValueKey('keepalive_webview_${tab.id}'),
                      child: BrowserWebViewWindows(
                        key: ValueKey('webview_${tab.id}'), // ✅ Key estável baseada no ID da aba
                        tab: tab,
                        onUrlChanged: (url) {
                          // Atualiza apenas se for a aba atual
                          if (tab.id == _tabManager.currentTab?.id) {
                            _onUrlChanged(url);
                          }
                        },
                        onTitleChanged: (title, tabId) {
                          // Atualiza o título da aba específica usando o tabId passado
                          _onTitleChanged(title, tabId);
                        },
                        onNavigationStateChanged: (isLoading, canGoBack, canGoForward) {
                          // Atualiza apenas se for a aba atual
                          if (tab.id == _tabManager.currentTab?.id) {
                            _onNavigationStateChanged(isLoading, canGoBack, canGoForward);
                          }
                        },
                        quickMessages: const [], // ✅ NÃO passa mensagens - só injeta quando usuário abrir aba/janela
                      ),
                    );
                  }
                  return _widgetCache['webview_${tab.id}']!;
                }
              }).toList(), // ✅ Converte para lista para garantir estabilidade
            ),
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
    
    final totalNotifications = _cachedTotalNotifications;
    final hasMultiplePages = _cachedHasMultiplePages;
    
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
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Criar Nova Aba'),
            onPressed: _onNewTabPressed,
          ),
        ),
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
      child: Align(
        alignment: Alignment.centerLeft, // ✅ Força alinhamento à esquerda
        child: ReorderableListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4), // ✅ Alinha à esquerda
          shrinkWrap: true,
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
          // ✅ Garante que os cliques sejam processados mesmo durante arrasto
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
            // Cada aba mostra apenas suas próprias notificações
            // Se a aba tem múltiplas páginas, soma as notificações de todas as páginas dessa aba
            int notificationCountToShow = 0;
            if (!isHome) {
              // ✅ Usa a função que calcula notificações da aba específica
              notificationCountToShow = _getTabNotificationCount(tab);
              
              // ✅ Log para debug
              if (notificationCountToShow > 0) {
                final savedTab = _tabManager.getSavedTab(tab.id);
                final hasMultiplePagesInTab = savedTab?.hasMultiplePages ?? false;
                debugPrint('📊 Badge calculado para aba "${displayName}": $notificationCountToShow (individual: ${tab.notificationCount}, múltiplas páginas na aba: $hasMultiplePagesInTab)');
              }
            }
            
            const minTabWidth = 120.0; // ✅ Largura mínima fixa para permitir scroll
            
            return ReorderableDragStartListener(
              index: visibleIndex,
              key: ValueKey('tab_${tab.id}_$originalIndex'),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: minTabWidth,
                  constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
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
                      // ✅ Garante que o clique seja processado mesmo com conflitos de gesto
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
                        // Área principal clicável (ícone + nome)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✅ Ícone da aba Home ou ícone padrão
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
                                // Nome da aba
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
                                      // ✅ Badge de notificação (mostra apenas as notificações dessa aba específica)
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
                        // Botões de ação (não arrastáveis)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ✅ Botão para salvar (apenas se não estiver salva E não for Home)
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
                            // ✅ Botão de fechar (apenas para abas não salvas E não for Home)
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
            ),
          );
          }),
        ),
      ),
    );
  }

  /// Widget wrapper que mantém o WebView vivo mesmo quando não está visível
  /// Evita que os WebViews sejam descartados quando muda para a aba Home
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
        
        // Remove a associação da aba salva
        _tabManager.removeSavedTabAssociation(tab.id);
        
        setState(() {});
        
        if (mounted) {
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

