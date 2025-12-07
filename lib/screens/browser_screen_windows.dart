import 'package:flutter/material.dart';
import '../services/tab_manager_windows.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/save_tab_dialog.dart';
import '../services/auth_service.dart';
import '../models/saved_tab.dart';

/// Tela principal do navegador para Windows
class BrowserScreenWindows extends StatefulWidget {
  const BrowserScreenWindows({super.key});

  @override
  State<BrowserScreenWindows> createState() => _BrowserScreenWindowsState();
}

class _BrowserScreenWindowsState extends State<BrowserScreenWindows> {
  late TabManagerWindows _tabManager;

  @override
  void initState() {
    super.initState();
    _tabManager = TabManagerWindows();
    _tabManager.addListener(_onTabManagerChanged);
    
    // Carrega página inicial na primeira aba
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialPage();
    });
  }

  void _loadInitialPage() async {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      // Carrega página inicial e atualiza a URL
      await currentTab.loadUrl('https://www.google.com');
      currentTab.updateUrl('https://www.google.com');
      setState(() {});
    }
  }

  void _onTabManagerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabManager.removeListener(_onTabManagerChanged);
    _tabManager.dispose();
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
    // Só atualiza se realmente mudou de aba
    if (index != _tabManager.currentTabIndex) {
      final tab = _tabManager.tabs[index];
      
      // Se a aba não foi carregada ainda (lazy loading), carrega agora
      if (tab.url == 'about:blank' || tab.url.isEmpty) {
        final savedTab = _tabManager.getSavedTab(tab.id);
        if (savedTab != null) {
          await tab.loadUrl(savedTab.url);
          tab.updateTitle(savedTab.name);
          tab.updateUrl(savedTab.url);
        }
      }
      
      _tabManager.selectTab(index);
      // Atualiza apenas a UI, sem forçar reconstrução do WebView
      setState(() {});
    }
  }

  void _onTabClosed(int index) {
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
    // Encontra a aba específica pelo ID e atualiza apenas ela
    try {
      final tab = _tabManager.tabs.firstWhere((t) => t.id == tabId);
      setState(() {
        // Atualiza o título e detecta notificações para a aba específica
        tab.updateTitle(title);
      });
    } catch (e) {
      // Aba não encontrada, ignora
    }
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
    final currentTab = _tabManager.currentTab;
    
    if (currentTab == null || _tabManager.isLoadingSavedTabs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerencia Zap'),
        actions: [
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
          // Isso evita recarregar quando troca de aba
          Expanded(
            child: IndexedStack(
              index: _tabManager.currentTabIndex,
                children: _tabManager.tabs.map((tab) {
                return BrowserWebViewWindows(
                  key: ValueKey('webview_${tab.id}'),
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
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
        ),
      ),
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onReorder: (oldIndex, newIndex) {
          _tabManager.reorderTabs(oldIndex, newIndex);
        },
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        children: List.generate(_tabManager.tabs.length, (index) {
          final tab = _tabManager.tabs[index];
          final isSelected = index == _tabManager.currentTabIndex;
          final isSaved = _tabManager.isTabSaved(tab.id);
          final savedTab = _tabManager.getSavedTab(tab.id);
          
          // Usa o nome salvo se existir, senão usa o título da página ou URL
          final displayName = savedTab?.name ?? 
              ((tab.title.isNotEmpty && tab.title != 'Nova Aba' && !tab.title.startsWith('http'))
                  ? tab.title 
                  : _getShortUrl(tab.url));
          
          return ReorderableDragStartListener(
            index: index,
            key: ValueKey('tab_${tab.id}'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
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
              child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Área principal arrastável (ícone + nome)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onTabSelected(index),
                      // Permite arrastar de qualquer lugar desta área
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ícone da aba (se salva) ou ícone padrão
                            savedTab?.iconUrl != null
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
                                  ),
                            const SizedBox(width: 8),
                            // Nome da aba
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
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
                                  // Badge de notificações
                                  if (tab.notificationCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        tab.notificationCount > 99 ? '99+' : '${tab.notificationCount}',
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
                  ),
                  // Botões não arrastáveis (usam GestureDetector para bloquear arrastar)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão para salvar/editar aba
                      GestureDetector(
                        onTap: () => _onSaveTab(index),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _onSaveTab(index),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                isSaved ? Icons.bookmark : Icons.bookmark_border,
                                size: 16,
                                color: isSaved ? Colors.blue[700] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Botão de fechar
                      GestureDetector(
                        onTap: () => _onTabClosed(index),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _onTabClosed(index),
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
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        }),
      ),
    );
  }

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
    final tab = _tabManager.tabs[index];
    final savedTab = _tabManager.getSavedTab(tab.id);
    
    final result = await showDialog<SavedTab?>(
      context: context,
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
      setState(() {});
    }
  }

}

