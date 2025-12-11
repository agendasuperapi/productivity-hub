import 'package:flutter/material.dart';
import 'browser_webview_windows.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import 'page_navigation_bar.dart';

/// Widget que exibe múltiplas páginas em um grid
class MultiPageWebView extends StatefulWidget {
  final List<String> urls;
  final int columns;
  final int rows;
  final String tabId;
  final Function(String) onUrlChanged;
  final Function(String, String) onTitleChanged;
  final Function(bool, bool, bool) onNavigationStateChanged;
  final List<QuickMessage> quickMessages; // ✅ Mensagens rápidas
  final bool enableQuickMessages; // ✅ Se true, permite usar atalhos rápidos nesta aba
  final Function(String, String?)? onQuickMessageHint; // ✅ Callback para notificações de hint

  const MultiPageWebView({
    super.key,
    required this.urls,
    required this.columns,
    required this.rows,
    required this.tabId,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
    this.quickMessages = const [], // ✅ Default vazio
    this.enableQuickMessages = true, // ✅ Por padrão, atalhos rápidos estão habilitados
    this.onQuickMessageHint, // ✅ Callback opcional para hints
  });

  @override
  State<MultiPageWebView> createState() => _MultiPageWebViewState();
}

class _MultiPageWebViewState extends State<MultiPageWebView> {
  final Map<int, BrowserTabWindows> _tabs = {};

  @override
  void initState() {
    super.initState();
    _initializeTabs();
  }

  Future<void> _initializeTabs() async {
    for (int i = 0; i < widget.urls.length; i++) {
      final url = widget.urls[i];
      if (url.isEmpty || url == 'about:blank') continue;
      
      final tab = await BrowserTabWindows.createAsync(
        id: '${widget.tabId}_page_$i',
        initialUrl: url, // Carrega a URL na criação
      );
      tab.isLoaded = true;
      tab.updateUrl(url);
      _tabs[i] = tab;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (var tab in _tabs.values) {
      tab.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula a altura disponível dividida pelo número de linhas
        final availableHeight = constraints.maxHeight;
        final cellHeight = (availableHeight - (widget.rows - 1) * 4) / widget.rows; // 4 é o mainAxisSpacing
        final cellWidth = (constraints.maxWidth - (widget.columns - 1) * 4) / widget.columns; // 4 é o crossAxisSpacing
        final calculatedAspectRatio = cellWidth / cellHeight;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: calculatedAspectRatio,
          ),
          itemCount: widget.urls.length,
          itemBuilder: (context, index) {
            final tab = _tabs[index];
            if (tab == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                // ✅ BrowserWebViewWindows já inclui a barra de navegação individual
                child: BrowserWebViewWindows(
                  tab: tab,
                  onUrlChanged: (url) {
                    widget.onUrlChanged(url);
                  },
                  onTitleChanged: (title, tabId) {
                    widget.onTitleChanged(title, tabId);
                  },
                  onNavigationStateChanged: (isLoading, canGoBack, canGoForward) {
                    widget.onNavigationStateChanged(isLoading, canGoBack, canGoForward);
                  },
                  quickMessages: widget.quickMessages, // ✅ Passa mensagens rápidas
                  enableQuickMessages: widget.enableQuickMessages, // ✅ Passa configuração de atalhos rápidos
                  onQuickMessageHint: widget.onQuickMessageHint, // ✅ Passa callback de hints
                ),
              ),
            );
          },
        );
      },
    );
  }
}

