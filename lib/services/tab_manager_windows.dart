import 'package:flutter/material.dart';
import '../models/browser_tab_windows.dart';

/// Gerenciador de abas do navegador para Windows
class TabManagerWindows extends ChangeNotifier {
  final List<BrowserTabWindows> _tabs = [];
  int _currentTabIndex = 0;

  List<BrowserTabWindows> get tabs => _tabs;
  BrowserTabWindows? get currentTab => _tabs.isEmpty ? null : _tabs[_currentTabIndex];
  int get currentTabIndex => _currentTabIndex;
  int get tabCount => _tabs.length;

  TabManagerWindows() {
    // Cria a primeira aba ao inicializar
    _createNewTab();
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
