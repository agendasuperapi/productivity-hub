import 'package:flutter/foundation.dart';

/// Utilitário para logs compactos
class CompactLogger {
  /// Encurta uma URL para exibição
  static String shortenUrl(String url, {int maxLength = 50}) {
    // ✅ Detecta data URLs (base64) e mostra apenas o tipo
    if (url.startsWith('data:')) {
      try {
        final parts = url.split(';');
        if (parts.isNotEmpty) {
          final mimeType = parts[0].replaceFirst('data:', '');
          // Tenta extrair nome do arquivo se houver
          if (mimeType.contains('pdf')) {
            return 'data:application/pdf (base64)';
          } else if (mimeType.contains('image')) {
            return 'data:$mimeType (base64)';
          } else {
            return 'data:$mimeType (base64)';
          }
        }
        return 'data: (base64)';
      } catch (e) {
        return 'data: (base64)';
      }
    }
    
    if (url.length <= maxLength) return url;
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final path = uri.path;
      
      if (host.isEmpty) {
        return url.length > maxLength ? '${url.substring(0, maxLength - 3)}...' : url;
      }
      
      // Se tem path, mostra host + parte do path
      if (path.isNotEmpty && path != '/') {
        final shortPath = path.length > 20 ? '${path.substring(0, 17)}...' : path;
        final result = '$host$shortPath';
        return result.length > maxLength ? '${result.substring(0, maxLength - 3)}...' : result;
      }
      
      return host;
    } catch (e) {
      return url.length > maxLength ? '${url.substring(0, maxLength - 3)}...' : url;
    }
  }

  /// Extrai apenas o nome do arquivo de uma URL ou caminho
  static String getFileName(String path) {
    // ✅ Para data URLs, retorna apenas o tipo
    if (path.startsWith('data:')) {
      try {
        final parts = path.split(';');
        if (parts.isNotEmpty) {
          final mimeType = parts[0].replaceFirst('data:', '');
          if (mimeType.contains('pdf')) {
            return 'arquivo.pdf';
          } else if (mimeType.contains('image')) {
            final ext = mimeType.split('/').last;
            return 'imagem.$ext';
          }
          return 'arquivo';
        }
        return 'arquivo';
      } catch (e) {
        return 'arquivo';
      }
    }
    
    try {
      final uri = Uri.parse(path);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final fileName = segments.last;
        if (fileName.isNotEmpty) return fileName;
      }
      
      // Se não tem segmentos, tenta pegar da query string
      if (uri.hasQuery && uri.queryParameters.containsKey('filename')) {
        return uri.queryParameters['filename']!;
      }
      
      // Se ainda não encontrou, retorna o último caractere após /
      final lastSlash = path.lastIndexOf('/');
      if (lastSlash != -1 && lastSlash < path.length - 1) {
        return path.substring(lastSlash + 1);
      }
      
      return path;
    } catch (e) {
      final lastSlash = path.lastIndexOf('/');
      if (lastSlash != -1 && lastSlash < path.length - 1) {
        return path.substring(lastSlash + 1);
      }
      return path;
    }
  }

  /// Encurta um texto longo
  static String shortenText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Log compacto com URL encurtada
  static void logUrl(String message, String url) {
    debugPrint('$message: ${shortenUrl(url)}');
  }

  /// Log compacto com nome de arquivo
  static void logFile(String message, String filePath) {
    debugPrint('$message: ${getFileName(filePath)}');
  }

  /// Log compacto genérico
  static void log(String message, [String? detail]) {
    if (detail != null) {
      debugPrint('$message: ${shortenText(detail)}');
    } else {
      debugPrint(message);
    }
  }

  /// Log de aviso
  static void logWarning(String message) {
    debugPrint('⚠️ AVISO: $message');
  }

  /// Log de erro
  static void logError(String message, dynamic error, StackTrace? stackTrace) {
    debugPrint('❌ ERRO: $message');
    if (error != null) {
      debugPrint('   Detalhes: $error');
    }
    if (stackTrace != null) {
      final stackLines = stackTrace.toString().split('\n');
      final shortStack = stackLines.take(5).join('\n');
      debugPrint('   Stack: $shortStack');
    }
  }
}

