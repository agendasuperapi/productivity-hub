import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/browser_tab_windows.dart';
import '../models/saved_tab.dart';
import '../services/saved_tabs_service.dart';

/// Gerenciador de abas do navegador para Windows
class TabManagerWindows extends ChangeNotifier {
  final List<BrowserTabWindows> _tabs = [];
  final Map<String, SavedTab> _savedTabsMap = {}; // Mapeia tab.id -> SavedTab
  int _currentTabIndex = 0;
  final SavedTabsService _savedTabsService = SavedTabsService();
  bool _isLoadingSavedTabs = false;

  List<BrowserTabWindows> get tabs => _tabs;
  BrowserTabWindows? get currentTab => _tabs.isEmpty ? null : _tabs[_currentTabIndex];
  int get currentTabIndex => _currentTabIndex;
  int get tabCount => _tabs.length;
  bool get isLoadingSavedTabs => _isLoadingSavedTabs;

  TabManagerWindows() {
    // Carrega abas salvas ao inicializar
    loadSavedTabs();
  }

  /// Carrega abas salvas do Supabase
  Future<void> loadSavedTabs() async {
    _isLoadingSavedTabs = true;
    notifyListeners();

    try {
      final savedTabs = await _savedTabsService.getSavedTabs();
      
      if (savedTabs.isEmpty) {
        // Se não há abas salvas, cria uma aba padrão
        _createNewTab();
      } else {
        // Cria abas a partir das salvas, mas só carrega a primeira
        for (int i = 0; i < savedTabs.length; i++) {
          final savedTab = savedTabs[i];
          final tab = await BrowserTabWindows.createAsync(
            id: savedTab.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            initialUrl: i == 0 ? savedTab.url : null, // Só carrega a primeira
          );
          
          // Atualiza título e URL da aba
          tab.updateTitle(savedTab.name);
          tab.updateUrl(savedTab.url);
          
          _tabs.add(tab);
          _savedTabsMap[tab.id] = savedTab;
        }
        
        _currentTabIndex = 0;
      }
    } catch (e) {
      // Se houver erro, cria uma aba padrão
      _createNewTab();
    } finally {
      _isLoadingSavedTabs = false;
      notifyListeners();
    }
  }

  /// Cria uma nova aba
  Future<BrowserTabWindows> createNewTab({String? initialUrl}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final tab = await BrowserTabWindows.createAsync(
      id: id,
      initialUrl: initialUrl,
    );
    
    _tabs.add(tab);
    _currentTabIndex = _tabs.length - 1;
    
    notifyListeners();
    return tab;
  }

  /// Verifica se uma aba está salva
  bool isTabSaved(String tabId) {
    return _savedTabsMap.containsKey(tabId);
  }

  /// Obtém o SavedTab associado a uma aba
  SavedTab? getSavedTab(String tabId) {
    return _savedTabsMap[tabId];
  }

  /// Associa um SavedTab a uma aba existente
  void associateSavedTab(String tabId, SavedTab savedTab) {
    _savedTabsMap[tabId] = savedTab;
    notifyListeners();
  }

  /// Reordena as abas
  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    
    // Atualiza o índice atual se necessário
    if (_currentTabIndex == oldIndex) {
      _currentTabIndex = newIndex;
    } else if (_currentTabIndex > oldIndex && _currentTabIndex <= newIndex) {
      _currentTabIndex--;
    } else if (_currentTabIndex < oldIndex && _currentTabIndex >= newIndex) {
      _currentTabIndex++;
    }
    
    // Salva a nova ordem no Supabase
    final savedTabIds = _tabs
        .where((tab) => _savedTabsMap.containsKey(tab.id))
        .map((tab) => _savedTabsMap[tab.id]!.id!)
        .toList();
    
    if (savedTabIds.isNotEmpty) {
      try {
        await _savedTabsService.updateTabsOrder(savedTabIds);
      } catch (e) {
        debugPrint('Erro ao salvar ordem das abas: $e');
      }
    }
    
    notifyListeners();
  }

  /// Remove uma aba
  void removeTab(int index) {
    if (_tabs.length <= 1) {
      // Não permite fechar a última aba, cria uma nova
      _tabs.clear();
      _createNewTab();
      return;
    }

    // Dispose do ambiente e limpa recursos
    _tabs[index].dispose();
    _tabs.removeAt(index);
    
    if (_currentTabIndex >= _tabs.length) {
      _currentTabIndex = _tabs.length - 1;
    } else if (_currentTabIndex > index) {
      _currentTabIndex--;
    }
    
    notifyListeners();
  }

  /// Seleciona uma aba
  void selectTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  /// Cria uma nova aba vazia
  void _createNewTab() {
    createNewTab().then((_) {
      notifyListeners();
    });
  }

  /// Fecha a aba atual
  void closeCurrentTab() {
    removeTab(_currentTabIndex);
  }

  @override
  void dispose() {
    for (var tab in _tabs) {
      tab.dispose();
    }
    _tabs.clear();
    super.dispose();
  }
}
