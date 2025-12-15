import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciar o zoom das páginas com persistência local
class ZoomService {
  static const String _prefixZoom = 'page_zoom_';
  static const double _defaultZoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.002; // ✅ Reduzido 10x para incrementos muito menores e mais suaves

  /// Obtém o zoom salvo para uma página específica
  Future<double> getZoom(String pageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixZoom$pageId';
      final zoom = prefs.getDouble(key);
      return zoom ?? _defaultZoom;
    } catch (e) {
      debugPrint('[ZoomService] ❌ Erro ao obter zoom para $pageId: $e');
      return _defaultZoom;
    }
  }

  /// Salva o zoom para uma página específica
  Future<void> saveZoom(String pageId, double zoom) async {
    try {
      // Limita o zoom entre min e max
      final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixZoom$pageId';
      await prefs.setDouble(key, clampedZoom);
      debugPrint('[ZoomService] ✅ Zoom salvo para $pageId: $clampedZoom');
    } catch (e) {
      debugPrint('[ZoomService] ❌ Erro ao salvar zoom para $pageId: $e');
    }
  }

  /// Obtém o zoom padrão
  double get defaultZoom => _defaultZoom;

  /// Obtém o zoom mínimo
  double get minZoom => _minZoom;

  /// Obtém o zoom máximo
  double get maxZoom => _maxZoom;

  /// Obtém o incremento de zoom
  double get zoomStep => _zoomStep;

  /// Calcula o próximo zoom ao aumentar
  double increaseZoom(double currentZoom) {
    final newZoom = currentZoom + _zoomStep;
    return newZoom.clamp(_minZoom, _maxZoom);
  }

  /// Calcula o próximo zoom ao diminuir
  double decreaseZoom(double currentZoom) {
    final newZoom = currentZoom - _zoomStep;
    return newZoom.clamp(_minZoom, _maxZoom);
  }
}


