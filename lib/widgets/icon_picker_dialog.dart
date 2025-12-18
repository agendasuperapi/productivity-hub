import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/icons_api_service.dart';

/// Dialog para selecionar ícones da API
class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({super.key});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final _iconsApiService = IconsApiService();
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
      final icons = await _iconsApiService.searchIcons('', limit: 50);
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
      final icons = await _iconsApiService.searchIcons(query, limit: 100);
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
                const Icon(Icons.image_search, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Selecionar Ícone',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
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
                                        // ✅ Exibe o ícone como imagem SVG
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Builder(
                                              builder: (context) {
                                                try {
                                                  return SvgPicture.network(
                                                    icon.url,
                                                    fit: BoxFit.contain,
                                                    placeholderBuilder: (context) {
                                                      return const Center(
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      );
                                                    },
                                                  );
                                                } catch (e) {
                                                  // ✅ Fallback para ícone quebrado se SVG falhar
                                                  return Icon(
                                                    Icons.broken_image,
                                                    size: 32,
                                                    color: Colors.grey[400],
                                                  );
                                                }
                                              },
                                            ),
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

