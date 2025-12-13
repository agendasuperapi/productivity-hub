import 'package:flutter/material.dart';
import 'browser_webview_windows.dart';
import '../models/browser_tab_windows.dart';
import '../models/quick_message.dart';
import 'page_navigation_bar.dart';
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
  final bool enableQuickMessages; // ✅ Se true, permite usar atalhos rápidos nesta aba
  final Function(String, String?)? onQuickMessageHint; // ✅ Callback para notificações de hint
  final String? iconUrl; // ✅ URL do ícone da aba (compartilhado entre todas as páginas)
  final String? pageName; // ✅ Nome da aba (compartilhado entre todas as páginas)
  final Function(String)? onNewTabRequested; // ✅ Callback para criar nova aba com URL
  final bool isPdfWindow; // ✅ Indica se esta é uma janela de PDF (não deve interceptar PDFs)
  final bool isAlwaysOnTop; // ✅ Indica se a janela está fixada (alwaysOnTop)

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
    this.iconUrl, // ✅ Ícone opcional
    this.pageName, // ✅ Nome opcional
    this.onNewTabRequested, // ✅ Callback opcional para criar nova aba
    this.isPdfWindow = false, // ✅ Por padrão, não é uma janela de PDF
    this.isAlwaysOnTop = false, // ✅ Por padrão, não está fixada
  });

  @override
  State<MultiPageWebView> createState() => _MultiPageWebViewState();
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
  bool _showControlsBar = false; // ✅ Flag para controlar visibilidade da barra de controles (inicia oculta)

  @override
  void initState() {
    super.initState();
    _loadProportions();
    _initializeTabs();
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

  /// ✅ Salva as proporções atuais
  Future<void> _saveProportions() async {
    try {
      await _localSettings.savePageProportions(
        widget.tabId,
        {
          'columns': List<double>.from(_columnProportions),
          'rows': List<double>.from(_rowProportions),
        },
      );
      setState(() {
        _hasUnsavedChanges = false;
        _showControlsBar = false; // Oculta a barra após salvar
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamanhos das páginas salvos com sucesso'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar tamanhos: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
        _showControlsBar = false; // Oculta a barra após restaurar
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamanhos restaurados para padrão'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Se houver erro ao remover, ainda restaura visualmente
      setState(() {
        _initializeProportions();
        _hasUnsavedChanges = false;
        _showControlsBar = false; // Oculta a barra após restaurar
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamanhos restaurados para padrão'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
        // ✅ Barra de controles com botão de salvar e restaurar
        if (_showControlsBar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ✅ Botão de restaurar (sempre visível)
                IconButton(
                  icon: const Icon(Icons.restore, size: 18),
                  onPressed: _restoreDefaultProportions,
                  tooltip: 'Restaurar tamanhos padrões',
                  color: Colors.grey[700],
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // ✅ Botão de salvar (só aparece se houver mudanças não salvas)
                if (_hasUnsavedChanges)
                  IconButton(
                    icon: const Icon(Icons.save, size: 18),
                    onPressed: _saveProportions,
                    tooltip: 'Salvar tamanhos das páginas',
                    color: Colors.blue,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                // ✅ Botão de fechar/ocultar barra (agora à direita do botão de salvar)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _showControlsBar = false;
                    });
                  },
                  tooltip: 'Ocultar controles',
                  color: Colors.grey[600],
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
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
              return Stack(
                children: [
                  // ✅ Páginas
                  ..._buildPages(columnWidths, rowHeights, dividerWidth),
                  // ✅ Divisores verticais (entre colunas)
                  ..._buildVerticalDividers(columnWidths, rowHeights, dividerWidth, availableHeight),
                  // ✅ Divisores horizontais (entre linhas)
                  ..._buildHorizontalDividers(columnWidths, rowHeights, dividerWidth, availableWidth),
                  // ✅ Botão flutuante para mostrar controles
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _showControlsBar = !_showControlsBar;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Icon(
                            _showControlsBar ? Icons.settings : Icons.settings_outlined,
                            size: 18,
                            color: _showControlsBar ? Colors.blue : Colors.grey[600],
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
                    enableQuickMessages: widget.enableQuickMessages,
                    onQuickMessageHint: widget.onQuickMessageHint,
                    iconUrl: widget.iconUrl, // ✅ Passa ícone compartilhado
                    pageName: widget.pageName, // ✅ Passa nome compartilhado
                    isAlwaysOnTop: widget.isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                    onNewTabRequested: widget.onNewTabRequested, // ✅ Callback para criar nova aba (PDFs)
                    isPdfWindow: widget.isPdfWindow, // ✅ Indica se é uma janela de PDF
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
                  _showControlsBar = true; // ✅ Mostra a barra quando redimensiona
                });
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
                  _showControlsBar = true; // ✅ Mostra a barra quando redimensiona
                });
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
