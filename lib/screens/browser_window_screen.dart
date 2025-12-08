import 'package:flutter/material.dart';
import 'dart:io';
import '../models/saved_tab.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../models/browser_tab_windows.dart';
import '../utils/window_manager_helper.dart';
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
  late TextEditingController _urlController;
  final FocusNode _urlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _currentUrl);
    // ✅ Configura título da janela
    _updateWindowTitle();
    // ✅ OTIMIZAÇÃO 4: Carregar WebView apenas quando necessário (lazy loading)
    Future.microtask(() {
      _initializeTab();
    });
  }

  Future<void> _updateWindowTitle() async {
    if (Platform.isWindows) {
      try {
        // O título é definido no MaterialApp, mas vamos garantir que está atualizado
        // O MaterialApp title já está configurado com widget.savedTab.name
        debugPrint('Título da janela: ${widget.savedTab.name}');
      } catch (e) {
        debugPrint('Erro ao atualizar título: $e');
      }
    }
  }

  @override
  void didUpdateWidget(BrowserWindowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedTab.id != oldWidget.savedTab.id) {
      _urlController.text = _currentUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _tab?.dispose();
    // Remove a janela do registro quando ela for fechada
    if (widget.savedTab.id != null) {
      WindowManagerHelper().unregisterWindow(widget.savedTab.id!);
    }
    super.dispose();
  }

  Future<void> _initializeTab() async {
    try {
      final urls = widget.savedTab.urlList;
      
      if (urls.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ OTIMIZAÇÃO 4: Cria WebView de forma assíncrona e não bloqueante
      final tab = await BrowserTabWindows.createAsync(
        id: 'window_${widget.savedTab.id}_${DateTime.now().millisecondsSinceEpoch}',
        initialUrl: urls.first,
      );

      tab.updateTitle(widget.savedTab.name);
      tab.updateUrl(urls.first);
      tab.isLoaded = true;

      if (mounted) {
        setState(() {
          _tab = tab;
          _currentUrl = urls.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ✅ OTIMIZAÇÃO 4: Apenas logar erros críticos
      debugPrint('Erro ao inicializar aba na janela: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      _urlController.text = url;
    });
  }

  void _handleUrlSubmitted(String value) {
    String url = value.trim();
    
    // Adiciona https:// se não tiver protocolo
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Verifica se parece ser um domínio ou IP
      if (url.contains('.') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(url)) {
        url = 'https://$url';
      } else {
        // Se não parecer URL, faz busca no Google
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    
    _onUrlSubmitted(url);
    _urlFocusNode.unfocus();
  }

  void _onTitleChanged(String title, String tabId) async {
    // ✅ O título da janela é definido no MaterialApp (main.dart)
    // Não é possível atualizar dinamicamente em janelas secundárias do desktop_multi_window
  }

  void _onNavigationStateChanged(bool isLoading, bool canGoBack, bool canGoForward) {
    setState(() {
      _isPageLoading = isLoading;
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Se ainda está carregando, mostra indicador
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Carregando: ${widget.savedTab.name}'),
            ],
          ),
        ),
      );
    }
    
    // Se não tem tab, mostra erro
    if (_tab == null) {
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
            ],
          ),
        ),
      );
    }
    
    // ✅ OTIMIZAÇÃO 4: Renderiza WebView apenas quando visível
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Barra de navegação customizada para janelas secundárias
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[100],
            child: Row(
              children: [
                // Ícone e nome da aba
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone da aba
                      if (widget.savedTab.iconUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            widget.savedTab.iconUrl!,
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.language,
                                size: 20,
                                color: Colors.blue,
                              );
                            },
                          ),
                        )
                      else
                        const Icon(
                          Icons.language,
                          size: 20,
                          color: Colors.blue,
                        ),
                      const SizedBox(width: 6),
                      // Nome da aba
                      Text(
                        widget.savedTab.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botões de navegação
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: _canGoBack ? _onBackPressed : null,
                  tooltip: 'Voltar',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  onPressed: _canGoForward ? _onForwardPressed : null,
                  tooltip: 'Avançar',
                ),
                IconButton(
                  icon: _isPageLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: _onRefreshPressed,
                  tooltip: 'Atualizar',
                ),
                const SizedBox(width: 8),
                // Campo de URL
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Digite uma URL ou pesquise',
                        hintStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _handleUrlSubmitted,
                      onTap: () {
                        _urlController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _urlController.text.length,
                        );
                      },
                    ),
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

