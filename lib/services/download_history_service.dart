import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

/// Serviço para gerenciar histórico de downloads
class DownloadHistoryService {
  static const String _key = 'download_history';
  static const int _maxDownloads = 100; // Limite máximo de downloads salvos

  /// Salva um novo download no histórico
  Future<void> saveDownload(DownloadItem download) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = await getDownloads();
      
      // Adiciona o novo download no início da lista
      downloads.insert(0, download);
      
      // Remove downloads antigos se exceder o limite
      if (downloads.length > _maxDownloads) {
        downloads.removeRange(_maxDownloads, downloads.length);
      }
      
      // Salva a lista atualizada
      final jsonList = downloads.map((d) => d.toMap()).toList();
      await prefs.setString(_key, jsonEncode(jsonList));
      debugPrint('✅ Download salvo: ${download.fileName}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar download: $e');
    }
  }

  /// Obtém todos os downloads salvos
  Future<List<DownloadItem>> getDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('📥 Histórico: Nenhum dado salvo');
        return [];
      }
      
      debugPrint('📥 Histórico: Dados encontrados (${jsonString.length} chars)');
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final downloads = jsonList.map((item) => DownloadItem.fromMap(item as Map<String, dynamic>)).toList();
      debugPrint('📥 Histórico: ${downloads.length} downloads carregados');
      return downloads;
    } catch (e) {
      debugPrint('❌ Erro ao carregar downloads: $e');
      return [];
    }
  }

  /// Remove um download do histórico
  Future<void> removeDownload(String downloadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = await getDownloads();
      downloads.removeWhere((d) => d.id == downloadId);
      
      final jsonList = downloads.map((d) => d.toMap()).toList();
      await prefs.setString(_key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Erro ao remover download: $e');
    }
  }

  /// Limpa todo o histórico de downloads
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Erro ao limpar histórico: $e');
    }
  }
}

