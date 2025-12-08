import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        // Abas marcadas como janela aparecem na barra mas não carregam conteúdo
        int firstTabIndex = -1;
        for (int i = 0; i < savedTabs.length; i++) {
          final savedTab = savedTabs[i];
          
          // Encontra o índice da primeira aba válida (não marcada como janela)
          if (!savedTab.openAsWindow && firstTabIndex == -1) {
            firstTabIndex = _tabs.length;
          }
          
          final tab = await BrowserTabWindows.createAsync(
            id: savedTab.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            // Só carrega a primeira aba que não é janela
            initialUrl: (!savedTab.openAsWindow && firstTabIndex == _tabs.length) ? savedTab.url : null,
          );
          
          // Atualiza título e URL da aba
          tab.updateTitle(savedTab.name);
          tab.updateUrl(savedTab.url);
          
          // Marca a primeira aba válida como carregada
          if (!savedTab.openAsWindow && firstTabIndex == _tabs.length) {
            tab.isLoaded = true;
          }
          
          _tabs.add(tab);
          _savedTabsMap[tab.id] = savedTab;
        }
        
        // Se não há abas válidas, cria uma padrão
        if (_tabs.isEmpty) {
          _createNewTab();
        } else {
          _currentTabIndex = 0;
        }
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
    
    // Se tem URL inicial, marca como carregada
    if (initialUrl != null && initialUrl.isNotEmpty && initialUrl != 'about:blank') {
      tab.isLoaded = true;
    }
    
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

  /// Remove a associação de uma aba salva
  void removeSavedTabAssociation(String tabId) {
    _savedTabsMap.remove(tabId);
    notifyListeners();
  }

  /// Reordena as abas
  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    // Valida os índices
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length) return;
    if (oldIndex == newIndex) return;
    
    // Ajusta o newIndex conforme necessário
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex = newIndex - 1;
    }
    
    // Garante que o índice ajustado é válido
    if (adjustedNewIndex < 0 || adjustedNewIndex >= _tabs.length) {
      adjustedNewIndex = newIndex;
    }
    
    // Remove e insere a aba na nova posição
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(adjustedNewIndex, tab);
    
    // Atualiza o índice atual se necessário
    if (_currentTabIndex == oldIndex) {
      _currentTabIndex = adjustedNewIndex;
    } else if (_currentTabIndex > oldIndex && _currentTabIndex <= adjustedNewIndex) {
      _currentTabIndex--;
    } else if (_currentTabIndex < oldIndex && _currentTabIndex >= adjustedNewIndex) {
      _currentTabIndex++;
    }
    
    // Salva a nova ordem no Supabase (de forma assíncrona para não bloquear)
    final savedTabIds = _tabs
        .where((tab) => _savedTabsMap.containsKey(tab.id))
        .map((tab) => _savedTabsMap[tab.id]!.id!)
        .toList();
    
    if (savedTabIds.isNotEmpty) {
      // Não aguarda para não bloquear a UI
      _savedTabsService.updateTabsOrder(savedTabIds).catchError((e) {
        debugPrint('Erro ao salvar ordem das abas: $e');
      });
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

  /// Abre uma aba salva em uma janela externa do navegador
  Future<void> _openInExternalWindow(SavedTab savedTab) async {
    try {
      final urls = savedTab.urlList;
      if (urls.isEmpty) return;
      
      // Abre cada URL em uma nova janela do navegador padrão
      for (final url in urls) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Abre em aplicativo externo (navegador)
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao abrir janela externa: $e');
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
