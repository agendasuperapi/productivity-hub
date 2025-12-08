import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import '../models/saved_tab.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../models/browser_tab_windows.dart';
import 'dart:async';

/// Tela de navegador para uma janela separada (aberta a partir de uma aba salva)
class BrowserWindowScreen extends StatefulWidget {
  final SavedTab savedTab;

  const BrowserWindowScreen({
    super.key,
    required this.savedTab,
  });

  @override
  State<BrowserWindowScreen> createState() => _BrowserWindowScreenState();
}

class _BrowserWindowScreenState extends State<BrowserWindowScreen> {
  BrowserTabWindows? _tab;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isPageLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('BrowserWindowScreen: initState() chamado, savedTab: ${widget.savedTab.name}');
    _initializeWindow();
    _initializeTab();
  }

  Future<void> _initializeWindow() async {
    // Não usa window_manager em janelas secundárias (não funciona)
    // O título será definido via desktop_multi_window quando a janela for criada
    debugPrint('BrowserWindowScreen: _initializeWindow() - janela secundária não usa window_manager');
  }

  Future<void> _initializeTab() async {
    try {
      debugPrint('BrowserWindowScreen: Inicializando aba, savedTab: ${widget.savedTab.name}');
      final urls = widget.savedTab.urlList;
      debugPrint('BrowserWindowScreen: URLs encontradas: $urls');
      
      if (urls.isEmpty) {
        debugPrint('BrowserWindowScreen: Nenhuma URL encontrada');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint('BrowserWindowScreen: Criando BrowserTabWindows com URL: ${urls.first}');
      // Cria uma aba isolada para esta janela com cache independente
      // O WebViewEnvironment criado será único para esta janela
      final tab = await BrowserTabWindows.createAsync(
        id: 'window_${widget.savedTab.id}_${DateTime.now().millisecondsSinceEpoch}',
        initialUrl: urls.first,
      );

      debugPrint('BrowserWindowScreen: BrowserTabWindows criado com sucesso');
      tab.updateTitle(widget.savedTab.name);
      tab.updateUrl(urls.first);
      tab.isLoaded = true;

      setState(() {
        _tab = tab;
        _currentUrl = urls.first;
        _isLoading = false;
      });
      debugPrint('BrowserWindowScreen: Estado atualizado, _tab=${_tab?.id}, _isLoading=false');
    } catch (e, stackTrace) {
      debugPrint('BrowserWindowScreen: Erro ao inicializar aba na janela: $e');
      debugPrint('BrowserWindowScreen: Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onUrlSubmitted(String url) async {
    if (_tab != null) {
      _tab!.updateUrl(url);
      await _tab!.loadUrl(url);
      setState(() {
        _currentUrl = url;
      });
    }
  }

  void _onBackPressed() async {
    if (_tab != null && _tab!.canGoBack && _tab!.controller != null) {
      await _tab!.controller!.goBack();
    }
  }

  void _onForwardPressed() async {
    if (_tab != null && _tab!.canGoForward && _tab!.controller != null) {
      await _tab!.controller!.goForward();
    }
  }

  void _onRefreshPressed() async {
    if (_tab != null && _tab!.controller != null) {
      await _tab!.controller!.reload();
    }
  }

  void _onUrlChanged(String url) {
    setState(() {
      _currentUrl = url;
    });
  }

  void _onTitleChanged(String title, String tabId) async {
    // Não usa window_manager em janelas secundárias (não funciona)
    // O título da janela não pode ser atualizado dinamicamente em janelas secundárias
    debugPrint('BrowserWindowScreen: Título mudou para: $title (não atualizando janela secundária)');
  }

  void _onNavigationStateChanged(bool isLoading, bool canGoBack, bool canGoForward) {
    setState(() {
      _isPageLoading = isLoading;
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Não usa window_manager em janelas secundárias (não funciona)
    // O título já foi definido quando a janela foi criada via desktop_multi_window

    debugPrint('BrowserWindowScreen: build() chamado, _isLoading=$_isLoading, _tab=${_tab?.id}, savedTab.name=${widget.savedTab.name}, savedTab.urlList=${widget.savedTab.urlList}');
    
    // Se ainda está carregando, mostra indicador
    if (_isLoading) {
      debugPrint('BrowserWindowScreen: Mostrando tela de carregamento');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Carregando: ${widget.savedTab.name}'),
              const SizedBox(height: 8),
              Text('URLs: ${widget.savedTab.urlList.join(", ")}'),
            ],
          ),
        ),
      );
    }
    
    // Se não tem tab, mostra erro
    if (_tab == null) {
      debugPrint('BrowserWindowScreen: ❌ Tab é null, mostrando erro');
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao carregar aba'),
              Text('Aba: ${widget.savedTab.name}'),
              Text('URLs: ${widget.savedTab.urlList}'),
            ],
          ),
        ),
      );
    }
    
    // Renderiza o conteúdo
    debugPrint('BrowserWindowScreen: ✅ Renderizando conteúdo com tab ${_tab!.id}');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
                  children: [
                    // Barra de navegação (igual à tela principal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _canGoBack ? _onBackPressed : null,
                            tooltip: 'Voltar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _canGoForward ? _onForwardPressed : null,
                            tooltip: 'Avançar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _onRefreshPressed,
                            tooltip: 'Recarregar',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BrowserAddressBar(
                              currentUrl: _currentUrl,
                              isLoading: _isPageLoading,
                              canGoBack: _canGoBack,
                              canGoForward: _canGoForward,
                              onUrlSubmitted: _onUrlSubmitted,
                              onBackPressed: _onBackPressed,
                              onForwardPressed: _onForwardPressed,
                              onRefreshPressed: _onRefreshPressed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Barra de abas (mostra apenas esta aba)
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Ícone da aba (se salva)
                                if (widget.savedTab.iconUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      widget.savedTab.iconUrl!,
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.language,
                                          size: 18,
                                          color: Colors.blue,
                                        );
                                      },
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.language,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.savedTab.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Conteúdo WebView
                    Expanded(
                      child: widget.savedTab.hasMultiplePages && _tab != null
                          ? MultiPageWebView(
                              urls: widget.savedTab.urlList,
                              columns: widget.savedTab.columns ?? 2,
                              rows: widget.savedTab.rows ?? 2,
                              tabId: _tab!.id,
                              onUrlChanged: _onUrlChanged,
                              onTitleChanged: _onTitleChanged,
                              onNavigationStateChanged: _onNavigationStateChanged,
                            )
                          : _tab != null
                              ? BrowserWebViewWindows(
                                  tab: _tab!,
                                  onUrlChanged: _onUrlChanged,
                                  onTitleChanged: _onTitleChanged,
                                  onNavigationStateChanged: _onNavigationStateChanged,
                                )
                              : const Center(child: Text('Carregando...')),
                    ),
                  ],
                ),
    );
  }
}

