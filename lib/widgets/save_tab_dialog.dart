import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/saved_tab.dart';
import '../services/saved_tabs_service.dart';
import '../services/local_tab_settings_service.dart';
import '../services/tab_groups_service.dart';
import '../models/tab_group.dart';

/// Dialog para salvar uma aba como favorito
class SaveTabDialog extends StatefulWidget {
  final String currentUrl;
  final String currentTitle;
  final SavedTab? existingTab; // Se fornecido, está editando uma aba existente
  final String? selectedGroupId; // ID do grupo selecionado (padrão)

  const SaveTabDialog({
    super.key,
    required this.currentUrl,
    required this.currentTitle,
    this.existingTab,
    this.selectedGroupId,
  });

  @override
  State<SaveTabDialog> createState() => _SaveTabDialogState();
}

class _SaveTabDialogState extends State<SaveTabDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<TextEditingController> _urlControllers = [];
  final _savedTabsService = SavedTabsService();
  final _localTabSettingsService = LocalTabSettingsService();
  final _tabGroupsService = TabGroupsService();
  File? _iconFile;
  String? _currentIconUrl; // URL do ícone já salvo
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedColumns;
  int? _selectedRows;
  bool _openAsWindow = false;
  bool _alwaysOnTop = false; // Por padrão, não fica sempre no topo
  Map<String, bool> _enableQuickMessagesByUrl = {}; // ✅ Map de URL -> bool para atalhos rápidos por página
  String? _selectedGroupId; // ID do grupo selecionado
  List<TabGroup> _groups = []; // Lista de grupos disponíveis

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existingTab?.name ?? widget.currentTitle;
    _selectedGroupId = widget.existingTab?.groupId ?? widget.selectedGroupId;
    _loadGroups();
    
    // Inicializa URLs
    if (widget.existingTab != null && widget.existingTab!.hasMultiplePages) {
      final urls = widget.existingTab!.urlList;
      for (var url in urls) {
        final controller = TextEditingController(text: url);
        _addUrlControllerListener(controller, _urlControllers.length);
        _urlControllers.add(controller);
      }
      _selectedColumns = widget.existingTab!.columns;
      _selectedRows = widget.existingTab!.rows;
    } else {
      // ✅ Se currentUrl for 'about:blank' ou vazio, deixa o campo em branco
      final url = widget.existingTab?.url ?? widget.currentUrl;
      final controller = TextEditingController(text: (url == 'about:blank' || url.isEmpty) ? '' : url);
      _addUrlControllerListener(controller, 0);
      _urlControllers.add(controller);
    }
    
    _currentIconUrl = widget.existingTab?.iconUrl;
    
    // ✅ Carrega configuração de atalhos rápidos por URL do armazenamento local
    _loadQuickMessagesByUrl();
    
    // ✅ Carrega openAsWindow do armazenamento local
    _loadOpenAsWindow();
    
    // Calcula layout padrão se não especificado
    if (_selectedColumns == null && _selectedRows == null) {
      _calculateDefaultLayout();
    }
  }

  /// Carrega os grupos disponíveis
  Future<void> _loadGroups() async {
    try {
      final groups = await _tabGroupsService.getTabGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          // Se não tem grupo selecionado e tem grupos, seleciona o primeiro
          if (_selectedGroupId == null && groups.isNotEmpty) {
            _selectedGroupId = groups.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar grupos: $e');
    }
  }

  /// ✅ Carrega a configuração openAsWindow do armazenamento local
  Future<void> _loadOpenAsWindow() async {
    if (widget.existingTab?.id != null) {
      final value = await _localTabSettingsService.getOpenAsWindow(widget.existingTab!.id!);
      if (mounted) {
        setState(() {
          _openAsWindow = value;
        });
      }
    }
  }

  /// ✅ Carrega a configuração de atalhos rápidos por URL do armazenamento local
  /// ✅ Converte configuração salva (por URL) para configuração por índice
  Future<void> _loadQuickMessagesByUrl() async {
    if (widget.existingTab?.id != null) {
      final config = await _localTabSettingsService.getQuickMessagesByUrl(widget.existingTab!.id!);
      if (mounted) {
        setState(() {
          if (config != null) {
            // ✅ Configuração já vem como Map com índices (_index_X) -> bool
            // Isso permite que URLs duplicadas tenham configurações diferentes
            _enableQuickMessagesByUrl = Map<String, bool>.from(config);
            
            // ✅ Garante que todos os controllers tenham configuração
            for (int i = 0; i < _urlControllers.length; i++) {
              final indexKey = '_index_$i';
              if (!_enableQuickMessagesByUrl.containsKey(indexKey)) {
                _enableQuickMessagesByUrl[indexKey] = true;
              }
            }
          } else {
            // ✅ Se não há configuração salva, inicializa todos os índices como true
            _enableQuickMessagesByUrl = {};
            for (int i = 0; i < _urlControllers.length; i++) {
              _enableQuickMessagesByUrl['_index_$i'] = true;
            }
          }
        });
      }
    } else {
      // ✅ Para nova aba, inicializa com índice 0 como true
      _enableQuickMessagesByUrl = {'_index_0': true};
    }
  }

  void _calculateDefaultLayout() {
    try {
      final urlCount = _urlControllers.length;
      if (urlCount <= 1) {
        _selectedColumns = null;
        _selectedRows = null;
      } else if (urlCount == 2) {
        _selectedColumns = 2;
        _selectedRows = 1;
      } else if (urlCount <= 4) {
        _selectedColumns = 2;
        _selectedRows = 2;
      } else if (urlCount <= 6) {
        _selectedColumns = 3;
        _selectedRows = 2;
      } else {
        // Para mais de 6, calcula automaticamente
        _selectedColumns = 3;
        _selectedRows = (urlCount / 3).ceil();
      }
    } catch (e) {
      debugPrint('Erro ao calcular layout padrão: $e');
      // Define valores padrão seguros
      _selectedColumns = 2;
      _selectedRows = 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var controller in _urlControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ✅ Adiciona listener a um controller de URL para atualizar configuração quando URL mudar
  /// ✅ Usa índice como chave, não a URL, para permitir URLs duplicadas
  void _addUrlControllerListener(TextEditingController controller, int index) {
    controller.addListener(() {
      // ✅ Não precisa fazer nada aqui, pois usamos índice como chave
      // A configuração é sempre baseada no índice, não na URL
    });
  }

  void _addUrl() {
    try {
      setState(() {
        final newController = TextEditingController();
        final index = _urlControllers.length;
        _addUrlControllerListener(newController, index);
        _urlControllers.add(newController);
        _calculateDefaultLayout();
        // ✅ Atualiza configuração de atalhos rápidos para incluir nova URL
        _updateQuickMessagesConfig();
      });
    } catch (e) {
      debugPrint('Erro ao adicionar URL: $e');
      // Tenta adicionar mesmo assim, sem calcular layout
      if (mounted) {
        setState(() {
          if (_urlControllers.length == 1) {
            _selectedColumns = 2;
            _selectedRows = 1;
          }
          final newController = TextEditingController();
          final index = _urlControllers.length;
          _addUrlControllerListener(newController, index);
          _urlControllers.add(newController);
          _updateQuickMessagesConfig();
        });
      }
    }
  }

  /// ✅ Atualiza a configuração de atalhos rápidos quando uma URL é adicionada ou removida
  /// ✅ IMPORTANTE: Usa índice como chave principal para permitir URLs duplicadas
  void _updateQuickMessagesConfig() {
    // ✅ Usa todos os controllers, sempre usando índice como chave principal
    for (int i = 0; i < _urlControllers.length; i++) {
      final indexKey = '_index_$i'; // ✅ Chave baseada no índice (permite URLs duplicadas)
      
      // ✅ Inicializa como true se não existir
      if (!_enableQuickMessagesByUrl.containsKey(indexKey)) {
        _enableQuickMessagesByUrl[indexKey] = true;
      }
    }
    
    // ✅ Remove configurações de índices que não existem mais
    _enableQuickMessagesByUrl.removeWhere((key, _) => 
      key.startsWith('_index_') && 
      int.tryParse(key.substring(7)) != null &&
      int.parse(key.substring(7)) >= _urlControllers.length);
  }

  void _removeUrl(int index) {
    if (_urlControllers.length > 1) {
      setState(() {
        final controller = _urlControllers[index];
        final indexKey = '_index_$index';
        
        // ✅ Remove configuração do índice removido
        _enableQuickMessagesByUrl.remove(indexKey);
        
        controller.dispose();
        _urlControllers.removeAt(index);
        
        // ✅ Reindexa configurações restantes (move índices para baixo)
        final reindexedConfig = <String, bool>{};
        for (int i = 0; i < _urlControllers.length; i++) {
          final oldIndexKey = i >= index ? '_index_${i + 1}' : '_index_$i';
          final newIndexKey = '_index_$i';
          
          // ✅ Busca valor pelo índice antigo ou usa true como padrão
          final value = _enableQuickMessagesByUrl[oldIndexKey] ?? 
                       _enableQuickMessagesByUrl[newIndexKey] ?? 
                       true;
          reindexedConfig[newIndexKey] = value;
        }
        _enableQuickMessagesByUrl = reindexedConfig;
        
        _calculateDefaultLayout();
      });
    }
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _iconFile = File(result.files.single.path!);
        _currentIconUrl = null; // Remove o ícone antigo quando seleciona um novo
      });
    }
  }

  List<String> _getUrls() {
    return _urlControllers.map((c) => c.text.trim()).where((url) => url.isNotEmpty).toList();
  }

  Future<void> _saveTab() async {
    if (!_formKey.currentState!.validate()) return;

    final urls = _getUrls();
    if (urls.isEmpty) {
      setState(() {
        _errorMessage = 'Adicione pelo menos uma URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SavedTab savedTab;
      if (widget.existingTab != null) {
        // Atualiza aba existente
        savedTab = await _savedTabsService.updateTab(
          id: widget.existingTab!.id!,
          name: _nameController.text.trim(),
          urls: urls.length > 1 ? urls : null,
          url: urls.length == 1 ? urls.first : null,
          columns: _selectedColumns,
          rows: _selectedRows,
          enableQuickMessages: true, // ✅ Mantém compatibilidade, mas não é mais usado (usa configuração por URL)
          // ✅ openAsWindow removido - agora é gerenciado localmente
          iconFile: _iconFile,
          groupId: _selectedGroupId,
        );
      } else {
        // Cria nova aba salva
        savedTab = await _savedTabsService.saveTab(
          name: _nameController.text.trim(),
          urls: urls.length > 1 ? urls : null,
          url: urls.length == 1 ? urls.first : null,
          columns: _selectedColumns,
          rows: _selectedRows,
          enableQuickMessages: true, // ✅ Mantém compatibilidade, mas não é mais usado (usa configuração por URL)
          // ✅ openAsWindow removido - agora é gerenciado localmente
          iconFile: _iconFile,
          groupId: _selectedGroupId,
        );
      }

      // ✅ Salva openAsWindow, alwaysOnTop e quickMessagesByUrl no armazenamento local após salvar/atualizar a aba
      if (savedTab.id != null) {
        await _localTabSettingsService.setOpenAsWindow(savedTab.id!, _openAsWindow);
        await _localTabSettingsService.setAlwaysOnTop(savedTab.id!, _alwaysOnTop);
        // ✅ Salva configuração por índice para permitir URLs duplicadas com configurações individuais
        await _localTabSettingsService.saveQuickMessagesByIndex(savedTab.id!, urls, _enableQuickMessagesByUrl);
      }

      if (!mounted) return;
      
      // Reseta o estado de loading antes de fechar o dialog
      setState(() {
        _isLoading = false;
      });
      
      // Usa addPostFrameCallback para garantir que o Navigator não está bloqueado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(savedTab);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLayoutSelector() {
    final urlCount = _urlControllers.length;
    if (urlCount <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Layout de Exibição',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$urlCount página${urlCount > 1 ? 's' : ''}',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        const SizedBox(height: 8),
        // Opções de layout baseadas no número de URLs
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _buildLayoutOptions(urlCount),
        ),
        const SizedBox(height: 8),
        // Preview visual do layout
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey[50],
          ),
          child: _buildLayoutPreview(),
        ),
      ],
    );
  }

  List<Widget> _buildLayoutOptions(int urlCount) {
    final options = <Map<String, int>>[];

    if (urlCount == 2) {
      options.addAll([
        {'cols': 2, 'rows': 1, 'label': 2}, // 2 colunas
        {'cols': 1, 'rows': 2, 'label': 2}, // 2 linhas
      ]);
    } else if (urlCount == 3) {
      options.addAll([
        {'cols': 3, 'rows': 1, 'label': 3}, // 3 colunas
        {'cols': 1, 'rows': 3, 'label': 3}, // 3 linhas
      ]);
    } else if (urlCount == 4) {
      options.addAll([
        {'cols': 4, 'rows': 1, 'label': 4}, // 4 colunas
        {'cols': 2, 'rows': 2, 'label': 4}, // 2x2
        {'cols': 1, 'rows': 4, 'label': 4}, // 4 linhas
      ]);
    } else if (urlCount == 5) {
      options.addAll([
        {'cols': 5, 'rows': 1, 'label': 5}, // 5 colunas
        {'cols': 3, 'rows': 2, 'label': 6}, // 3x2 (mostra 5)
        {'cols': 2, 'rows': 3, 'label': 6}, // 2x3 (mostra 5)
      ]);
    } else if (urlCount == 6) {
      options.addAll([
        {'cols': 6, 'rows': 1, 'label': 6}, // 6 colunas
        {'cols': 3, 'rows': 2, 'label': 6}, // 3x2
        {'cols': 2, 'rows': 3, 'label': 6}, // 2x3
      ]);
    } else {
      // Para mais de 6, oferece opções padrão
      final cols = (urlCount / 2).ceil();
      final rows = 2;
      options.addAll([
        {'cols': urlCount, 'rows': 1, 'label': urlCount}, // Todas em linha
        {'cols': cols, 'rows': rows, 'label': urlCount}, // Grid calculado
        {'cols': 1, 'rows': urlCount, 'label': urlCount}, // Todas em coluna
      ]);
    }

    return options.map((option) {
      final cols = option['cols']!;
      final rows = option['rows']!;
      final isSelected = _selectedColumns == cols && _selectedRows == rows;

      return InkWell(
        onTap: () {
          setState(() {
            _selectedColumns = cols;
            _selectedRows = rows;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$cols × $rows',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.black,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              _buildMiniPreview(cols, rows, urlCount),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Lista de cores para os blocos do preview
  static const List<Color> _previewColors = [
    Color(0xFFE3F2FD), // Azul claro
    Color(0xFFF3E5F5), // Roxo claro
    Color(0xFFE8F5E9), // Verde claro
    Color(0xFFFFF3E0), // Laranja claro
    Color(0xFFFCE4EC), // Rosa claro
    Color(0xFFE0F2F1), // Ciano claro
    Color(0xFFFFF9C4), // Amarelo claro
    Color(0xFFEFEBE9), // Marrom claro
    Color(0xFFE1F5FE), // Azul celeste
    Color(0xFFF1F8E9), // Verde limão
  ];

  Widget _buildMiniPreview(int cols, int rows, int total) {
    // Calcula quantos itens mostrar (máximo cols * rows, mas não mais que total)
    final displayCount = (cols * rows) > total ? total : (cols * rows);
    
    // Calcula dimensões do preview
    final previewWidth = 60.0;
    final previewHeight = 40.0;
    final spacing = 1.0;
    
    // Calcula tamanho das células
    final totalSpacingWidth = (cols - 1) * spacing;
    final totalSpacingHeight = (rows - 1) * spacing;
    final cellWidth = (previewWidth - totalSpacingWidth) / cols;
    final cellHeight = (previewHeight - totalSpacingHeight) / rows;
    final aspectRatio = cellWidth / cellHeight;
    
    return SizedBox(
      width: previewWidth,
      height: previewHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final colorIndex = index % _previewColors.length;
          return Container(
            decoration: BoxDecoration(
              color: _previewColors[colorIndex],
              border: Border.all(color: Colors.grey[400]!, width: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }

  /// ✅ Constrói a seção de configuração de atalhos rápidos por URL
  Widget _buildQuickMessagesByUrlSection() {
    // ✅ Atualiza configuração quando URLs mudam
    _updateQuickMessagesConfig();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Atalhos rápidos por página',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Configure se cada página/URL deve aceitar atalhos rápidos (ex: /x32)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          // ✅ Lista de checkboxes, um para cada controller (mesmo se URL estiver vazia)
          // ✅ IMPORTANTE: Usa índice como chave para permitir URLs duplicadas
          ..._urlControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            final url = controller.text.trim();
            // ✅ Sempre usa índice como chave (permite URLs duplicadas)
            final indexKey = '_index_$index';
            final isEnabled = _enableQuickMessagesByUrl[indexKey] ?? true;
            
            return Padding(
              padding: EdgeInsets.only(bottom: index < _urlControllers.length - 1 ? 8 : 0),
              child: Row(
                children: [
                  Checkbox(
                    key: ValueKey('quick_msg_checkbox_$index'), // ✅ Key única por índice
                    value: isEnabled,
                    onChanged: (value) {
                      setState(() {
                        // ✅ Atualiza apenas a configuração deste índice específico (permite URLs duplicadas)
                        _enableQuickMessagesByUrl[indexKey] = value ?? true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'URL ${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          url.isEmpty 
                              ? '(URL não informada)' 
                              : (url.length > 60 ? '${url.substring(0, 60)}...' : url),
                          style: TextStyle(
                            fontSize: 10,
                            color: url.isEmpty ? Colors.grey[500] : Colors.grey[700],
                            fontStyle: url.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLayoutPreview() {
    if (_selectedColumns == null || _selectedRows == null) {
      return const Text('Selecione um layout', style: TextStyle(fontSize: 11));
    }

    try {
      final urlCount = _urlControllers.length;
      final totalCells = _selectedColumns! * _selectedRows!;
      final displayCount = urlCount > totalCells ? totalCells : urlCount;

      // Calcula altura do preview baseada no número de linhas
      // Cada linha tem aproximadamente 50px de altura
      // Para garantir que todas as linhas sejam visíveis, calcula baseado no número de linhas
      final baseHeightPerRow = 50.0;
      final previewHeight = (_selectedRows! * baseHeightPerRow).clamp(baseHeightPerRow, 200.0);
      
      // Calcula aspect ratio para que cada célula ocupe espaço proporcional
      // Usa largura de 300px para o preview
      final previewWidth = 300.0;
      final totalSpacingWidth = (_selectedColumns! - 1) * 3.0;
      final totalSpacingHeight = (_selectedRows! - 1) * 3.0;
      final cellWidth = (previewWidth - totalSpacingWidth) / _selectedColumns!;
      final cellHeight = (previewHeight - totalSpacingHeight) / _selectedRows!;
      final aspectRatio = cellWidth / cellHeight;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Preview: $_selectedColumns colunas × $_selectedRows linhas',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _selectedColumns!,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: aspectRatio,
              ),
              itemCount: displayCount,
              itemBuilder: (context, index) {
                final colorIndex = index % _previewColors.length;
                return Container(
                  decoration: BoxDecoration(
                    color: _previewColors[colorIndex],
                    border: Border.all(color: Colors.grey[600]!, width: 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.web,
                          size: 14,
                          color: Colors.grey[800],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (urlCount > totalCells)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${urlCount - totalCells} página(s) adicional(is)',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
        ],
      );
    } catch (e) {
      return Text('Erro ao gerar preview: $e', style: const TextStyle(color: Colors.red, fontSize: 12));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingTab != null ? 'Editar Aba' : 'Salvar Aba',
        style: const TextStyle(fontSize: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Nome e Ícone na mesma linha
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        labelStyle: TextStyle(fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title, size: 20),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira um nome';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Card com Ícone e botões - mesma altura do campo
                  Container(
                    height: 56, // Altura aproximada do TextFormField com label
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ícone
                        if (_iconFile != null || _currentIconUrl != null)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _iconFile != null
                                  ? Image.file(
                                      _iconFile!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 32,
                                          height: 32,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image, size: 16),
                                        );
                                      },
                                    )
                                  : _currentIconUrl != null
                                      ? Image.network(
                                          _currentIconUrl!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 32,
                                              height: 32,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image, size: 16),
                                            );
                                          },
                                        )
                                      : const SizedBox.shrink(),
                            ),
                          ),
                        // Botão Editar
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            icon: Icon(
                              _iconFile != null || _currentIconUrl != null ? Icons.edit : Icons.add_photo_alternate,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                            onPressed: _pickIcon,
                            tooltip: _iconFile != null || _currentIconUrl != null ? 'Trocar ícone' : 'Adicionar ícone',
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        // Botão Excluir (só aparece se tem ícone)
                        if (_iconFile != null || _currentIconUrl != null)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _iconFile = null;
                                  _currentIconUrl = null;
                                });
                              },
                              tooltip: 'Remover ícone',
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Seleção de Grupo
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Grupo',
                  labelStyle: TextStyle(fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder, size: 20),
                  isDense: true,
                ),
                items: _groups.map((group) {
                  return DropdownMenuItem<String>(
                    value: group.id,
                    child: Text(group.name, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGroupId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Lista de URLs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'URLs',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addUrl,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_urlControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _urlControllers[index],
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'URL ${index + 1}',
                            labelStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.link, size: 18),
                            isDense: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'URL não pode estar vazia';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_urlControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removeUrl(index),
                          tooltip: 'Remover URL',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Opção de abrir como janela
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _openAsWindow,
                          onChanged: (value) {
                            setState(() {
                              _openAsWindow = value ?? false;
                              // Se desmarcar "abrir como janela", desmarca "sempre no topo" também
                              if (!_openAsWindow) {
                                _alwaysOnTop = false;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Abrir como janela',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Se marcado, esta aba será aberta em uma nova janela do navegador ao invés de carregar nas abas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ✅ Opção de sempre no topo (só aparece se abrir como janela estiver marcado)
                    if (_openAsWindow) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _alwaysOnTop,
                              onChanged: (value) {
                                setState(() {
                                  _alwaysOnTop = value ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sempre no topo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Se marcado, esta janela ficará sempre visível acima de outras janelas e será ativada ao clicar na tela principal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ✅ Opção de habilitar atalhos rápidos por URL/página
              _buildQuickMessagesByUrlSection(),
              // Layout selector
              _buildLayoutSelector(),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            // Usa addPostFrameCallback para garantir que o Navigator não está bloqueado
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop(null);
              }
            });
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTab,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingTab != null ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
