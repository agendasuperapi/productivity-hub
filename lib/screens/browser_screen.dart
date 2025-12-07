import 'package:flutter/material.dart';
import '../services/tab_manager.dart';
import '../widgets/browser_tab_bar.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview.dart';

/// Tela principal do navegador
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late TabManager _tabManager;

  @override
  void initState() {
    super.initState();
    _tabManager = TabManager();
    _tabManager.addListener(_onTabManagerChanged);
    
    // Carrega página inicial na primeira aba
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialPage();
    });
  }

  void _loadInitialPage() {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      currentTab.loadUrl('https://www.google.com');
    }
  }

  void _onTabManagerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabManager.removeListener(_onTabManagerChanged);
    super.dispose();
  }

  void _onUrlSubmitted(String url) {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      currentTab.loadUrl(url);
    }
  }

  void _onBackPressed() {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.canGoBack) {
      currentTab.controller.goBack();
    }
  }

  void _onForwardPressed() {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.canGoForward) {
      currentTab.controller.goForward();
    }
  }

  void _onRefreshPressed() {
    final currentTab = _tabManager.currentTab;
    if (currentTab != null) {
      currentTab.controller.reload();
    }
  }

  void _onNewTabPressed() {
    final newTab = _tabManager.createNewTab();
    newTab.loadUrl('https://www.google.com');
  }

  void _onTabSelected(int index) {
    _tabManager.selectTab(index);
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
      // Notifica mudanças para atualizar a UI das abas
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
          
          // Barra de abas
          BrowserTabBar(
            tabs: _tabManager.tabs,
            currentIndex: _tabManager.currentTabIndex,
            onTabSelected: _onTabSelected,
            onTabClosed: _onTabClosed,
          ),
          
          // WebView
          Expanded(
            child: BrowserWebView(
              tab: currentTab,
              onUrlChanged: _onUrlChanged,
              onTitleChanged: _onTitleChanged,
              onNavigationStateChanged: _onNavigationStateChanged,
            ),
          ),
        ],
      ),
    );
  }
}

