import 'package:flutter/material.dart';
import '../services/tab_manager_windows.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';

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

  void _onTabSelected(int index) {
    // Só atualiza se realmente mudou de aba
    if (index != _tabManager.currentTabIndex) {
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

  void _onTitleChanged(String title) {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      setState(() {
        currentTab.updateTitle(title);
      });
      _tabManager.selectTab(_tabManager.currentTabIndex);
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
    
    if (currentTab == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
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
                  onUrlChanged: _onUrlChanged,
                  onTitleChanged: _onTitleChanged,
                  onNavigationStateChanged: _onNavigationStateChanged,
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
      height: 40,
      color: Colors.grey[200],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabManager.tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabManager.tabs[index];
          final isSelected = index == _tabManager.currentTabIndex;
          
          return GestureDetector(
            onTap: () => _onTabSelected(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.language,
                    size: 16,
                    color: isSelected ? Colors.blue : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 100,
                    child: Text(
                      tab.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _onTabClosed(index),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

