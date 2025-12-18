import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/unified_icons_api_service.dart';
import '../services/icons_api_service.dart';

/// Dialog para selecionar ícones de múltiplas APIs
class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({super.key});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final _unifiedIconsApiService = UnifiedIconsApiService();
  final _searchController = TextEditingController();
  List<IconResult> _icons = [];
  List<IconResult> _filteredIcons = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadPopularIcons();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  /// ✅ Detecta se é SVG ou PNG e renderiza adequadamente
  Widget _buildIconWidget(String url) {
    final isSvg = url.toLowerCase().endsWith('.svg') || url.contains('.svg?');
    
    if (isSvg) {
      // ✅ Para SVG, usa SvgPicture
      try {
        return SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (context) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        );
      } catch (e) {
        return Icon(
          Icons.broken_image,
          size: 32,
          color: Colors.grey[400],
        );
      }
    } else {
      // ✅ Para PNG/JPG, usa Image.network
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.broken_image,
            size: 32,
            color: Colors.grey[400],
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      );
    }
  }

  void _onSearchChanged() {
    // ✅ Debounce: aguarda 500ms após o usuário parar de digitar
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchIcons(_searchController.text);
    });
  }

  Future<void> _loadPopularIcons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Busca em todas as APIs simultaneamente
      final icons = await _unifiedIconsApiService.getPopularIcons(limit: 100);
      if (mounted) {
        setState(() {
          _icons = icons;
          _filteredIcons = icons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar ícones: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchIcons(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredIcons = _icons;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Busca em todas as APIs simultaneamente
      final icons = await _unifiedIconsApiService.searchIcons(query, limit: 150);
      if (mounted) {
        setState(() {
          _filteredIcons = icons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao buscar ícones: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      child: Container(
        width: isSmallScreen ? screenSize.width * 0.9 : 700,
        height: isSmallScreen ? screenSize.height * 0.8 : 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título e campo de busca
            Row(
              children: [
                const Icon(Icons.palette, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Selecionar Ícone',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredIcons.length} ícones',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar ícones (ex: home, user, settings)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filteredIcons = _icons;
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            // Lista de ícones
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPopularIcons,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _filteredIcons.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum ícone encontrado',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tente buscar por outro termo',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen ? 4 : 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _filteredIcons.length,
                              itemBuilder: (context, index) {
                                final icon = _filteredIcons[index];
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop(icon);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // ✅ Exibe o ícone (detecta automaticamente SVG ou PNG)
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: _buildIconWidget(icon.url),
                                          ),
                                        ),
                                        // Nome do ícone
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            icon.name.length > 12
                                                ? '${icon.name.substring(0, 12)}...'
                                                : icon.name,
                                            style: const TextStyle(fontSize: 10),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

