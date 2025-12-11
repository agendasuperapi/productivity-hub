import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  static const String HOME_TAB_ID = '__home__'; // ✅ ID especial para aba Home fixa

  bool _homeTabCreated = false; // ✅ Flag para rastrear se a aba Home foi criada
  final Completer<void> _homeTabCompleter = Completer<void>(); // ✅ Completer para aguardar criação da Home

  TabManagerWindows() {
    // ✅ Cria aba Home fixa primeiro (assíncrono)
    _createHomeTab();
    // Carrega abas salvas ao inicializar (sem carregar automaticamente)
    loadSavedTabs();
  }

  /// ✅ Aguarda a criação da aba Home
  Future<void> waitForHomeTab() async {
    if (_homeTabCreated) {
      return; // Já foi criada
    }
    return _homeTabCompleter.future;
  }

  /// ✅ Cria a aba Home fixa
  Future<void> _createHomeTab() async {
    try {
      // Cria um ambiente mínimo para a aba Home (não precisa de WebView real)
      final appDataDir = await getApplicationSupportDirectory();
      final userDataFolder = path.join(
        appDataDir.path,
        'gerencia_zap',
        'home_tab',
      );
      
      // Cria um ambiente vazio (não será usado, mas é necessário para o construtor)
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: userDataFolder,
        ),
      );
      
      final homeTab = BrowserTabWindows(
        id: HOME_TAB_ID,
        title: 'Home',
        url: 'about:blank',
        environment: environment,
        userDataFolder: userDataFolder,
      );
      homeTab.isLoaded = true; // Marca como carregada (mostra tela de boas-vindas)
      _tabs.insert(0, homeTab); // Insere no início
      _currentTabIndex = 0; // Seleciona a aba Home
      _homeTabCreated = true; // ✅ Marca como criada
      
      if (!_homeTabCompleter.isCompleted) {
        _homeTabCompleter.complete(); // ✅ Completa o Future
      }
      
      notifyListeners(); // Notifica que a aba Home foi criada
    } catch (e) {
      debugPrint('Erro ao criar aba Home: $e');
      if (!_homeTabCompleter.isCompleted) {
        _homeTabCompleter.completeError(e); // ✅ Completa com erro
      }
    }
  }

  /// Verifica se uma aba é a aba Home fixa
  bool isHomeTab(String tabId) {
    return tabId == HOME_TAB_ID;
  }

  /// Verifica se a aba atual é a Home
  bool get isCurrentTabHome => currentTab?.id == HOME_TAB_ID;

  /// Carrega abas salvas do Supabase (sem carregar automaticamente)
  Future<void> loadSavedTabs() async {
    _isLoadingSavedTabs = true;
    notifyListeners();

    try {
      final savedTabs = await _savedTabsService.getSavedTabs();
      
      debugPrint('📋 Carregando ${savedTabs.length} abas salvas do Supabase');
      
      // ✅ Cria abas LEVES (sem WebViewEnvironment) - muito rápido!
      // Os ambientes serão criados apenas quando as abas forem clicadas
      for (final savedTab in savedTabs) {
        // ✅ Cria aba leve sem ambiente - instantâneo!
        final tab = BrowserTabWindows.createLightweight(
            id: savedTab.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          initialUrl: 'about:blank',
          );
          
        // Atualiza título e URL da aba (mas não carrega)
          tab.updateTitle(savedTab.name);
          tab.updateUrl(savedTab.url);
        tab.isLoaded = false; // ✅ NÃO marca como carregada - lazy loading
          
          _tabs.add(tab);
          _savedTabsMap[tab.id] = savedTab;
        
        debugPrint('   ✅ Aba criada: ${savedTab.name} (ID: ${tab.id})');
        }
        
      // ✅ Notifica listeners imediatamente - todas as abas aparecem de uma vez!
      notifyListeners();
      
      debugPrint('📋 Total de abas após carregamento: ${_tabs.length}');
    } catch (e) {
      debugPrint('❌ Erro ao carregar abas salvas: $e');
    } finally {
      _isLoadingSavedTabs = false;
      notifyListeners(); // ✅ Notifica final para garantir que todas as abas apareçam
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
  /// ✅ IMPORTANTE: Não causa recarregamento das páginas - apenas reordena a lista
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
    
    // ✅ Atualiza o índice atual silenciosamente (sem notificar listeners)
    // Isso evita recarregamento desnecessário durante o reorder
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
    
    // ✅ Notifica listeners apenas para atualizar a UI da barra de abas
    // O IndexedStack não será reconstruído porque os widgets têm keys estáveis baseadas no ID
    notifyListeners();
  }

  /// Remove uma aba
  void removeTab(int index) {
    // ✅ Não permite remover a aba Home fixa
    if (index < _tabs.length && isHomeTab(_tabs[index].id)) {
      return; // Não remove a aba Home
    }
    
    if (_tabs.length <= 1) {
      // Não permite fechar a última aba (Home), não faz nada
      return;
    }

    // Dispose do ambiente e limpa recursos
    _tabs[index].dispose();
    _savedTabsMap.remove(_tabs[index].id); // Remove associação se existir
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

  /// ✅ Seleciona uma aba SEM notificar listeners (para evitar rebuild quando é Home)
  void selectTabSilently(int index) {
    if (index >= 0 && index < _tabs.length) {
      _currentTabIndex = index;
      // ✅ NÃO chama notifyListeners() para evitar rebuild
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
    // ✅ Não faz dispose das abas para fechar mais rápido
    // Os recursos serão limpos automaticamente quando o aplicativo fechar
    // _tabs.clear(); // Não limpa para evitar operações bloqueantes
    super.dispose();
  }
}
