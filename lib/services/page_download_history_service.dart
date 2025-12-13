import 'package:flutter/foundation.dart';
import '../models/download_item.dart';

/// Serviço para gerenciar histórico de downloads por página (armazenado em memória)
class PageDownloadHistoryService {
  // ✅ Map que armazena histórico por tabId/página
  // Chave: tabId (ex: "tab123" ou "tab123_page_0"), Valor: lista de downloads
  static final Map<String, List<DownloadItem>> _downloadsByPage = {};
  static const int _maxDownloadsPerPage = 100; // Limite máximo de downloads por página

  /// Salva um novo download no histórico da página
  static void saveDownload(String pageId, DownloadItem download) {
    try {
      // ✅ Inicializa a lista se não existir
      if (!_downloadsByPage.containsKey(pageId)) {
        _downloadsByPage[pageId] = [];
      }
      
      final downloads = _downloadsByPage[pageId]!;
      
      // ✅ Adiciona o novo download no início da lista
      downloads.insert(0, download);
      
      // ✅ Remove downloads antigos se exceder o limite
      if (downloads.length > _maxDownloadsPerPage) {
        downloads.removeRange(_maxDownloadsPerPage, downloads.length);
      }
      
      debugPrint('📥 Download salvo na página $pageId: ${download.fileName}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar download na página $pageId: $e');
    }
  }

  /// Obtém todos os downloads salvos de uma página específica
  static List<DownloadItem> getDownloads(String pageId) {
    try {
      final downloads = _downloadsByPage[pageId] ?? [];
      debugPrint('📥 Histórico da página $pageId: ${downloads.length} downloads');
      return downloads;
    } catch (e) {
      debugPrint('❌ Erro ao carregar downloads da página $pageId: $e');
      return [];
    }
  }

  /// Atualiza o filePath de um download existente (útil para atualizar blob URLs para data URLs)
  static void updateDownloadPath(String pageId, String downloadId, String newFilePath) {
    try {
      final downloads = _downloadsByPage[pageId];
      if (downloads != null) {
        final index = downloads.indexWhere((d) => d.id == downloadId);
        if (index != -1) {
          final oldDownload = downloads[index];
          downloads[index] = DownloadItem(
            id: oldDownload.id,
            fileName: oldDownload.fileName,
            filePath: newFilePath, // ✅ Atualiza o caminho
            downloadDate: oldDownload.downloadDate,
            fileSize: oldDownload.fileSize,
          );
          debugPrint('📥 Download atualizado na página $pageId: ${oldDownload.fileName}');
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar download da página $pageId: $e');
    }
  }

  /// Remove um download do histórico da página
  static void removeDownload(String pageId, String downloadId) {
    try {
      final downloads = _downloadsByPage[pageId];
      if (downloads != null) {
        downloads.removeWhere((d) => d.id == downloadId);
      }
    } catch (e) {
      debugPrint('❌ Erro ao remover download da página $pageId: $e');
    }
  }

  /// Limpa todo o histórico de downloads de uma página
  static void clearHistory(String pageId) {
    try {
      _downloadsByPage[pageId]?.clear();
    } catch (e) {
      debugPrint('❌ Erro ao limpar histórico da página $pageId: $e');
    }
  }

  /// Limpa todo o histórico de todas as páginas (útil para limpeza geral)
  static void clearAllHistory() {
    _downloadsByPage.clear();
  }
}

