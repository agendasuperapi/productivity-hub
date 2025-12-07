import 'package:flutter/material.dart';
import '../models/browser_tab.dart';

/// Gerenciador de abas do navegador
class TabManager extends ChangeNotifier {
  final List<BrowserTab> _tabs = [];
  int _currentTabIndex = 0;

  List<BrowserTab> get tabs => _tabs;
  BrowserTab? get currentTab => _tabs.isEmpty ? null : _tabs[_currentTabIndex];
  int get currentTabIndex => _currentTabIndex;
  int get tabCount => _tabs.length;

  TabManager() {
    // Cria a primeira aba ao inicializar
    _createNewTab();
  }

  /// Cria uma nova aba
  BrowserTab createNewTab({String? initialUrl}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final tab = BrowserTab.create(
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
    createNewTab();
  }

  /// Fecha a aba atual
  void closeCurrentTab() {
    removeTab(_currentTabIndex);
  }

  /// Fecha todas as abas exceto a atual
  void closeOtherTabs() {
    final currentTab = _tabs[_currentTabIndex];
    _tabs.clear();
    _tabs.add(currentTab);
    _currentTabIndex = 0;
    notifyListeners();
  }
}

