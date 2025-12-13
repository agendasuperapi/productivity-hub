import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/page_download_history_service.dart';

/// Diálogo para exibir o histórico de downloads de uma página específica
class DownloadHistoryDialog extends StatefulWidget {
  final String pageId; // ✅ ID da página para histórico individual
  final Function(String)? onFileSelected; // Callback quando um arquivo é selecionado

  const DownloadHistoryDialog({
    super.key,
    required this.pageId,
    this.onFileSelected,
  });

  @override
  State<DownloadHistoryDialog> createState() => _DownloadHistoryDialogState();
}

class _DownloadHistoryDialogState extends State<DownloadHistoryDialog> {
  List<DownloadItem> _downloads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  void _loadDownloads() {
    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Carrega downloads da página específica (armazenado em memória)
      final downloads = PageDownloadHistoryService.getDownloads(widget.pageId);
      debugPrint('📥 Histórico da página ${widget.pageId}: ${downloads.length} downloads encontrados');
      
      setState(() {
        _downloads = downloads;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar histórico: $e');
      setState(() {
        _downloads = [];
        _isLoading = false;
      });
    }
  }

  void _deleteDownload(DownloadItem download) {
    PageDownloadHistoryService.removeDownload(widget.pageId, download.id);
    _loadDownloads();
  }

  void _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico'),
        content: const Text('Deseja realmente limpar todo o histórico de downloads desta página?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      PageDownloadHistoryService.clearHistory(widget.pageId);
      _loadDownloads();
    }
  }

  void _openFile(DownloadItem download) {
    if (widget.onFileSelected != null) {
      widget.onFileSelected!(download.filePath);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
            child: SizedBox(
              width: 600,
              height: 500,
              child: Column(
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Histórico de Downloads',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_downloads.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Limpar tudo'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            // Lista de downloads
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _downloads.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.download_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum download encontrado',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _downloads.length,
                          itemBuilder: (context, index) {
                            final download = _downloads[index];
                            return ListTile(
                              leading: const Icon(Icons.insert_drive_file, size: 32),
                              title: Text(
                                download.fileName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(download.formattedDate),
                                  if (download.formattedSize.isNotEmpty)
                                    Text(
                                      download.formattedSize,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, size: 20),
                                    onPressed: () => _openFile(download),
                                    tooltip: 'Abrir arquivo',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => _deleteDownload(download),
                                    tooltip: 'Remover',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              onTap: () => _openFile(download),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

