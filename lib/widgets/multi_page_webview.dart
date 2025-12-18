import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'browser_webview_windows.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import '../services/local_tab_settings_service.dart';

/// Widget que exibe múltiplas páginas em um grid com divisores redimensionáveis
class MultiPageWebView extends StatefulWidget {
  final List<String> urls;
  final int columns;
  final int rows;
  final String tabId;
  final Function(String) onUrlChanged;
  final Function(String, String) onTitleChanged;
  final Function(bool, bool, bool) onNavigationStateChanged;
  final List<QuickMessage> quickMessages; // ✅ Mensagens rápidas
  final Map<String, String> keywords; // ✅ Palavras-chave customizadas passadas como parâmetro
  final bool enableQuickMessages; // ✅ DEPRECATED: Mantido para compatibilidade, use enableQuickMessagesByUrl
  final Map<String, bool>? enableQuickMessagesByUrl; // ✅ Configuração de atalhos rápidos por URL (URL -> bool)
  final Function(String, String?)? onQuickMessageHint; // ✅ Callback para notificações de hint
  final String? iconUrl; // ✅ URL do ícone da aba (compartilhado entre todas as páginas)
  final String? pageName; // ✅ Nome da aba (compartilhado entre todas as páginas)
  final Function(String)? onNewTabRequested; // ✅ Callback para criar nova aba com URL
  final bool isPdfWindow; // ✅ Indica se esta é uma janela de PDF (não deve interceptar PDFs)
  final bool isAlwaysOnTop; // ✅ Indica se a janela está fixada (alwaysOnTop)
  final bool? externalNavBarVisibility; // ✅ Controle externo de visibilidade das barras de navegação
  final bool hideFloatingButton; // ✅ Se true, oculta o botão flutuante
  final Function(bool)? onUnsavedChangesChanged; // ✅ Callback para notificar mudanças não salvas
  final Function(bool)? onNavBarVisibilityChanged; // ✅ Callback quando a visibilidade da barra mudar
  final String openLinksMode; // ✅ 'same_page' = própria página, 'external_browser' = navegador externo, 'webview_window' = janela nativa do WebView2

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
    this.keywords = const {}, // ✅ Default vazio - palavras-chave passadas como parâmetro
    this.enableQuickMessages = true, // ✅ DEPRECATED: Mantido para compatibilidade
    this.enableQuickMessagesByUrl, // ✅ Configuração por URL (opcional)
    this.onQuickMessageHint, // ✅ Callback opcional para hints
    this.iconUrl, // ✅ Ícone opcional
    this.pageName, // ✅ Nome opcional
    this.onNewTabRequested, // ✅ Callback opcional para criar nova aba
    this.isPdfWindow = false, // ✅ Por padrão, não é uma janela de PDF
    this.isAlwaysOnTop = false, // ✅ Por padrão, não está fixada
    this.externalNavBarVisibility, // ✅ Controle externo opcional
    this.hideFloatingButton = false, // ✅ Por padrão, mostra o botão flutuante
    this.onUnsavedChangesChanged, // ✅ Callback opcional para mudanças não salvas
    this.onNavBarVisibilityChanged, // ✅ Callback opcional para mudanças de visibilidade
    this.openLinksMode = 'same_page', // ✅ Por padrão, abre na própria página
  });

  @override
  State<MultiPageWebView> createState() => _MultiPageWebViewState();
  
  /// ✅ Método estático para salvar proporções através de um GlobalKey
  static Future<void> saveProportionsFromKey(GlobalKey key) async {
    final state = key.currentState;
    if (state != null && state is _MultiPageWebViewState) {
      await state.saveProportions();
    }
  }
  
  /// ✅ Método estático para restaurar proporções através de um GlobalKey
  static Future<void> restoreProportionsFromKey(GlobalKey key) async {
    final state = key.currentState;
    if (state != null && state is _MultiPageWebViewState) {
      await state._restoreDefaultProportions();
    }
  }
  
}

class _MultiPageWebViewState extends State<MultiPageWebView> {
  final Map<int, BrowserTabWindows> _tabs = {};
  final LocalTabSettingsService _localSettings = LocalTabSettingsService();
  // ✅ Armazena as proporções de tamanho das páginas (0.0 a 1.0)
  // Para colunas: lista de proporções horizontais
  // Para linhas: lista de proporções verticais
  final List<double> _columnProportions = [];
  final List<double> _rowProportions = [];
  int? _draggingColumnDivider; // Índice do divisor sendo arrastado (entre colunas)
  int? _draggingRowDivider; // Índice do divisor sendo arrastado (entre linhas)
  double? _dragStartX; // Posição X inicial do arraste (para divisores verticais)
  double? _dragStartY; // Posição Y inicial do arraste (para divisores horizontais)
  double? _dragStartLeftWidth; // Largura inicial da coluna à esquerda
  double? _dragStartTopHeight; // Altura inicial da linha superior
  bool _hasUnsavedChanges = false; // ✅ Flag para indicar se há mudanças não salvas
  
  // ✅ Posição do ícone flutuante para múltiplas páginas
  Offset _floatingIconPosition = const Offset(1.0, 1.0); // Posição padrão: canto inferior direito
  bool _isDraggingIcon = false;
  bool _showNavigationBars = false; // ✅ Controla visibilidade das barras de navegação de todas as páginas
  
  static const String _prefsKeyMultiPageIconX = 'multi_page_nav_icon_position_x';
  static const String _prefsKeyMultiPageIconY = 'multi_page_nav_icon_position_y';

  @override
  void initState() {
    super.initState();
    _loadProportions();
    _initializeTabs();
    _loadFloatingIconPosition();
    // ✅ Se há controle externo, sincroniza estado inicial
    if (widget.externalNavBarVisibility != null) {
      _showNavigationBars = widget.externalNavBarVisibility!;
    }
  }
  
  @override
  void didUpdateWidget(MultiPageWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Sincroniza estado quando controle externo muda
    if (widget.externalNavBarVisibility != null && widget.externalNavBarVisibility != oldWidget.externalNavBarVisibility) {
      setState(() {
        _showNavigationBars = widget.externalNavBarVisibility!;
      });
    }
  }
  
  /// ✅ Carrega a posição salva do ícone flutuante
  Future<void> _loadFloatingIconPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_prefsKeyMultiPageIconX);
      final y = prefs.getDouble(_prefsKeyMultiPageIconY);
      if (x != null && y != null && mounted) {
        setState(() {
          _floatingIconPosition = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        });
      }
    } catch (e) {
      // Ignora erros silenciosamente
    }
  }

  /// ✅ Salva a posição do ícone flutuante
  Future<void> _saveFloatingIconPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyMultiPageIconX, _floatingIconPosition.dx);
      await prefs.setDouble(_prefsKeyMultiPageIconY, _floatingIconPosition.dy);
    } catch (e) {
      // Ignora erros silenciosamente
    }
  }
  
  void _onIconPanStart(DragStartDetails details) {
    setState(() {
      _isDraggingIcon = true;
    });
  }

  void _onIconPanUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      // ✅ Inverte delta.dy porque o eixo Y é invertido (0.0 = topo, 1.0 = base)
      double newX = _floatingIconPosition.dx + (details.delta.dx / screenSize.width);
      double newY = _floatingIconPosition.dy - (details.delta.dy / screenSize.height); // ✅ Invertido: menos delta.dy
      newX = newX.clamp(0.0, 1.0);
      newY = newY.clamp(0.0, 1.0);
      _floatingIconPosition = Offset(newX, newY);
    });
  }

  void _onIconPanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingIcon = false;
    });
    _saveFloatingIconPosition();
  }
  
  void _toggleNavigationBars() {
    setState(() {
      _showNavigationBars = !_showNavigationBars;
      // ✅ Notifica todas as páginas para mostrar/esconder barras
      // Isso será feito através de um callback ou estado compartilhado
    });
  }

  /// ✅ Carrega as proporções salvas ou inicializa com valores iguais
  Future<void> _loadProportions() async {
    try {
      final savedProportions = await _localSettings.getPageProportions(widget.tabId);
      
      if (savedProportions != null && 
          savedProportions['columns']?.length == widget.columns &&
          savedProportions['rows']?.length == widget.rows) {
        // ✅ Carrega proporções salvas
        _columnProportions.clear();
        _columnProportions.addAll(savedProportions['columns']!);
        _rowProportions.clear();
        _rowProportions.addAll(savedProportions['rows']!);
      } else {
        // ✅ Inicializa com valores iguais se não houver proporções salvas
        _initializeProportions();
      }
    } catch (e) {
      // Se houver erro, inicializa com valores padrão
      _initializeProportions();
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  /// ✅ Inicializa as proporções com valores iguais
  void _initializeProportions() {
    // Inicializa proporções das colunas (divide igualmente)
    _columnProportions.clear();
    for (int i = 0; i < widget.columns; i++) {
      _columnProportions.add(1.0 / widget.columns);
    }
    
    // Inicializa proporções das linhas (divide igualmente)
    _rowProportions.clear();
    for (int i = 0; i < widget.rows; i++) {
      _rowProportions.add(1.0 / widget.rows);
    }
  }

  /// ✅ Salva as proporções atuais (método público para ser chamado externamente)
  Future<void> saveProportions() async {
    try {
      await _localSettings.savePageProportions(
        widget.tabId,
        {
          'columns': List<double>.from(_columnProportions),
          'rows': List<double>.from(_rowProportions),
        },
      );
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
      // ✅ Notifica que não há mais mudanças não salvas
      widget.onUnsavedChangesChanged?.call(false);
      debugPrint('✅ Proporções salvas: columns=$_columnProportions, rows=$_rowProportions');
    } catch (e) {
      debugPrint('❌ Erro ao salvar proporções: $e');
      rethrow; // Re-lança o erro para que o chamador possa tratá-lo
    }
  }

  /// ✅ Restaura os tamanhos padrões (proporções iguais)
  Future<void> _restoreDefaultProportions() async {
    try {
      // Remove as proporções salvas do armazenamento local
      await _localSettings.removePageProportions(widget.tabId);
      
      setState(() {
        _initializeProportions();
        _hasUnsavedChanges = false; // Não há mudanças não salvas após restaurar
      });
      // ✅ Notifica que não há mais mudanças não salvas
      widget.onUnsavedChangesChanged?.call(false);
      
      // ✅ Não mostra SnackBar aqui, pois será mostrada na tela principal
    } catch (e) {
      // Se houver erro ao remover, ainda restaura visualmente
      setState(() {
        _initializeProportions();
        _hasUnsavedChanges = false;
      });
      // ✅ Notifica que não há mais mudanças não salvas
      widget.onUnsavedChangesChanged?.call(false);
      
      // ✅ Não mostra SnackBar aqui, pois será mostrada na tela principal
    }
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

    return Column(
      children: [
        // ✅ Grid de páginas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;
              const dividerWidth = 4.0;

              // ✅ Calcula larguras das colunas baseado nas proporções
              final columnWidths = _columnProportions.map((prop) => (availableWidth - (widget.columns - 1) * dividerWidth) * prop).toList();
              
              // ✅ Calcula alturas das linhas baseado nas proporções
              final rowHeights = _rowProportions.map((prop) => (availableHeight - (widget.rows - 1) * dividerWidth) * prop).toList();

              // ✅ Constrói o grid com divisores
              final screenSize = MediaQuery.of(context).size;
              const iconSize = 28.0;
              const padding = 12.0;
              
              // Calcula posição do ícone flutuante
              final absoluteX = screenSize.width * _floatingIconPosition.dx - iconSize - padding;
              final absoluteY = screenSize.height * (1.0 - _floatingIconPosition.dy) - iconSize - padding;
              
              return Stack(
                children: [
                  // ✅ Páginas
                  ..._buildPages(columnWidths, rowHeights, dividerWidth),
                  // ✅ Divisores verticais (entre colunas)
                  ..._buildVerticalDividers(columnWidths, rowHeights, dividerWidth, availableHeight),
                  // ✅ Divisores horizontais (entre linhas)
                  ..._buildHorizontalDividers(columnWidths, rowHeights, dividerWidth, availableWidth),
                  // ✅ Botão flutuante para mostrar/esconder barras de navegação (oculto se hideFloatingButton = true)
                  if (!widget.hideFloatingButton)
                    Positioned(
                      left: absoluteX.clamp(padding, screenSize.width - iconSize - padding),
                      top: absoluteY.clamp(padding, screenSize.height - iconSize - padding),
                      child: GestureDetector(
                        onPanStart: _onIconPanStart,
                        onPanUpdate: (details) => _onIconPanUpdate(details, screenSize),
                        onPanEnd: _onIconPanEnd,
                        onTap: _toggleNavigationBars,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isDraggingIcon 
                                ? Colors.black.withOpacity(0.05) 
                                : Colors.transparent,
                            boxShadow: _isDraggingIcon
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(iconSize / 2),
                              onTap: _toggleNavigationBars,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _showNavigationBars ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: const Color(0xFF00a4a4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// ✅ Constrói as páginas posicionadas
  List<Widget> _buildPages(List<double> columnWidths, List<double> rowHeights, double dividerWidth) {
    final pages = <Widget>[];
    int pageIndex = 0;

    for (int row = 0; row < widget.rows && pageIndex < widget.urls.length; row++) {
      double top = 0;
      for (int r = 0; r < row; r++) {
        top += rowHeights[r] + dividerWidth;
      }

      for (int col = 0; col < widget.columns && pageIndex < widget.urls.length; col++) {
        double left = 0;
        for (int c = 0; c < col; c++) {
          left += columnWidths[c] + dividerWidth;
        }

        final tab = _tabs[pageIndex];
        if (tab != null) {
          // ✅ Obtém configuração de atalhos rápidos para este índice específico (permite URLs duplicadas)
          final indexKey = '_index_$pageIndex';
          final enableQuickMessagesForUrl = widget.enableQuickMessagesByUrl?[indexKey] ?? widget.enableQuickMessages;
          
          pages.add(
            Positioned(
              left: left,
              top: top,
              width: columnWidths[col],
              height: rowHeights[row],
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
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
                      quickMessages: widget.quickMessages,
                      keywords: widget.keywords, // ✅ Passa palavras-chave como parâmetro
                      enableQuickMessages: enableQuickMessagesForUrl, // ✅ Usa configuração por URL
                      onQuickMessageHint: widget.onQuickMessageHint,
                      iconUrl: widget.iconUrl, // ✅ Passa ícone compartilhado
                      pageName: widget.pageName, // ✅ Passa nome compartilhado
                      isAlwaysOnTop: widget.isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                      onNewTabRequested: widget.onNewTabRequested, // ✅ Callback para criar nova aba (PDFs)
                      isPdfWindow: widget.isPdfWindow, // ✅ Indica se é uma janela de PDF
                      externalNavBarVisibility: widget.externalNavBarVisibility != null ? widget.externalNavBarVisibility : _showNavigationBars, // ✅ Usa controle externo se disponível, senão usa interno
                      openLinksMode: widget.openLinksMode, // ✅ Passa configuração de abrir links
                      onNavBarVisibilityChanged: widget.onNavBarVisibilityChanged, // ✅ Passa callback para mudanças de visibilidade
                    ),
                  ),
              ),
            ),
          );
        }
        pageIndex++;
      }
    }

    return pages;
  }

  /// ✅ Constrói os divisores verticais (entre colunas)
  List<Widget> _buildVerticalDividers(List<double> columnWidths, List<double> rowHeights, double dividerWidth, double totalHeight) {
    final dividers = <Widget>[];
    
    // Cria divisores entre colunas (não na última coluna)
    for (int col = 0; col < widget.columns - 1; col++) {
      double left = 0;
      for (int c = 0; c <= col; c++) {
        left += columnWidths[c];
        if (c < col) left += dividerWidth;
      }
      left += dividerWidth / 2 - dividerWidth;

      final isDragging = _draggingColumnDivider == col;
      
      dividers.add(
        Positioned(
          left: left,
          top: 0,
          width: dividerWidth,
          height: totalHeight,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _draggingColumnDivider = col;
                _dragStartX = details.globalPosition.dx;
                _dragStartLeftWidth = columnWidths[col];
              });
            },
            onPanUpdate: (details) {
              if (_draggingColumnDivider == col && _dragStartX != null && _dragStartLeftWidth != null) {
                // Usa coordenadas globais para cálculo preciso
                final deltaX = details.globalPosition.dx - _dragStartX!;
                final totalWidth = columnWidths[col] + columnWidths[col + 1] + dividerWidth;
                final newLeftWidth = (_dragStartLeftWidth! + deltaX).clamp(
                  totalWidth * 0.1, // Mínimo 10%
                  totalWidth * 0.9, // Máximo 90%
                );
                final newRightWidth = totalWidth - newLeftWidth - dividerWidth;
                
                // Calcula novas proporções mantendo a soma total
                final totalProportion = _columnProportions[col] + _columnProportions[col + 1];
                final newLeftProp = (newLeftWidth / (totalWidth - dividerWidth)) * totalProportion;
                final newRightProp = totalProportion - newLeftProp;
                
                setState(() {
                  _columnProportions[col] = newLeftProp;
                  _columnProportions[col + 1] = newRightProp;
                  _hasUnsavedChanges = true; // ✅ Marca que há mudanças não salvas
                });
                // ✅ Notifica mudança não salva
                widget.onUnsavedChangesChanged?.call(true);
              }
            },
            onPanEnd: (details) {
              setState(() {
                _draggingColumnDivider = null;
                _dragStartX = null;
                _dragStartLeftWidth = null;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                color: isDragging ? Colors.blue.withOpacity(0.5) : Colors.grey[300]!.withOpacity(0.3),
                child: Center(
                  child: Container(
                    width: 2,
                    color: isDragging ? Colors.blue : Colors.grey[400],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return dividers;
  }

  /// ✅ Constrói os divisores horizontais (entre linhas)
  List<Widget> _buildHorizontalDividers(List<double> columnWidths, List<double> rowHeights, double dividerWidth, double totalWidth) {
    final dividers = <Widget>[];
    
    // Cria divisores entre linhas (não na última linha)
    for (int row = 0; row < widget.rows - 1; row++) {
      double top = 0;
      for (int r = 0; r <= row; r++) {
        top += rowHeights[r];
        if (r < row) top += dividerWidth;
      }
      top += dividerWidth / 2 - dividerWidth;

      final isDragging = _draggingRowDivider == row;
      
      dividers.add(
        Positioned(
          left: 0,
          top: top,
          width: totalWidth,
          height: dividerWidth,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _draggingRowDivider = row;
                _dragStartY = details.globalPosition.dy;
                _dragStartTopHeight = rowHeights[row];
              });
            },
            onPanUpdate: (details) {
              if (_draggingRowDivider == row && _dragStartY != null && _dragStartTopHeight != null) {
                // Usa coordenadas globais para cálculo preciso
                final deltaY = details.globalPosition.dy - _dragStartY!;
                final totalHeight = rowHeights[row] + rowHeights[row + 1] + dividerWidth;
                final newTopHeight = (_dragStartTopHeight! + deltaY).clamp(
                  totalHeight * 0.1, // Mínimo 10%
                  totalHeight * 0.9, // Máximo 90%
                );
                final newBottomHeight = totalHeight - newTopHeight - dividerWidth;
                
                // Calcula novas proporções mantendo a soma total
                final totalProportion = _rowProportions[row] + _rowProportions[row + 1];
                final newTopProp = (newTopHeight / (totalHeight - dividerWidth)) * totalProportion;
                final newBottomProp = totalProportion - newTopProp;
                
                setState(() {
                  _rowProportions[row] = newTopProp;
                  _rowProportions[row + 1] = newBottomProp;
                  _hasUnsavedChanges = true; // ✅ Marca que há mudanças não salvas
                });
                // ✅ Notifica mudança não salva
                widget.onUnsavedChangesChanged?.call(true);
              }
            },
            onPanEnd: (details) {
              setState(() {
                _draggingRowDivider = null;
                _dragStartY = null;
                _dragStartTopHeight = null;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                color: isDragging ? Colors.blue.withOpacity(0.5) : Colors.grey[300]!.withOpacity(0.3),
                child: Center(
                  child: Container(
                    height: 2,
                    color: isDragging ? Colors.blue : Colors.grey[400],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return dividers;
  }
}
