import 'package:flutter/foundation.dart';
import 'icons_api_service.dart';
import 'colored_icons_api_service.dart';

/// Serviço unificado que busca ícones em múltiplas APIs simultaneamente
class UnifiedIconsApiService {
  final _iconifyService = IconsApiService();
  final _coloredIconsService = ColoredIconsApiService();

  /// Busca ícones em todas as APIs disponíveis e combina os resultados
  Future<List<IconResult>> searchIcons(String query, {int limit = 100}) async {
    try {
      // ✅ Busca em todas as APIs simultaneamente
      final futures = <Future<List<IconResult>>>[
        _iconifyService.searchIcons(query, limit: limit ~/ 2),
        _coloredIconsService.searchIcons(query, limit: limit ~/ 2),
        _searchFlaticon(query, limit: limit ~/ 3),
        _searchFontAwesome(query, limit: limit ~/ 3),
      ];

      final results = await Future.wait(futures);
      
      // ✅ Combina todos os resultados
      final allIcons = <IconResult>[];
      final seenUrls = <String>{};
      
      for (var iconList in results) {
        for (var icon in iconList) {
          // ✅ Remove duplicatas baseado na URL
          if (!seenUrls.contains(icon.url)) {
            seenUrls.add(icon.url);
            allIcons.add(icon);
            if (allIcons.length >= limit) break;
          }
        }
        if (allIcons.length >= limit) break;
      }
      
      debugPrint('[UnifiedIconsApiService] ✅ ${allIcons.length} ícones encontrados em múltiplas APIs para "$query"');
      return allIcons;
    } catch (e) {
      debugPrint('[UnifiedIconsApiService] ❌ Erro ao buscar ícones: $e');
      return [];
    }
  }

  /// Busca ícones populares em todas as APIs
  Future<List<IconResult>> getPopularIcons({int limit = 100}) async {
    return await searchIcons('', limit: limit);
  }

  /// Busca ícones no Flaticon (API alternativa)
  Future<List<IconResult>> _searchFlaticon(String query, {int limit = 30}) async {
    try {
      // ✅ Flaticon não tem API pública gratuita, então vamos usar uma busca alternativa
      // Vou usar uma lista de ícones populares do Flaticon via CDN
      final results = <IconResult>[];
      
      if (query.trim().isEmpty) {
        final popularIcons = _getFlaticonPopularIcons(limit: limit);
        for (var iconData in popularIcons) {
          results.add(IconResult(
            name: iconData['name'] ?? '',
            prefix: 'flaticon',
            url: iconData['url'] ?? '',
          ));
        }
        return results;
      }
      
      // ✅ Para busca, filtra ícones populares que correspondem ao termo
      final queryLower = query.toLowerCase();
      final popularIcons = _getFlaticonPopularIcons(limit: 100);
      
      for (var iconData in popularIcons) {
        final name = iconData['name'] ?? '';
        if (name.contains(queryLower) || queryLower.contains(name)) {
          results.add(IconResult(
            name: name,
            prefix: 'flaticon',
            url: iconData['url'] ?? '',
          ));
          if (results.length >= limit) break;
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('[UnifiedIconsApiService] Erro ao buscar Flaticon: $e');
      return [];
    }
  }

  /// Busca ícones no Font Awesome (via CDN)
  Future<List<IconResult>> _searchFontAwesome(String query, {int limit = 30}) async {
    try {
      // ✅ Font Awesome tem ícones via CDN
      // Formato: https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/icon-name.svg
      final results = <IconResult>[];
      final queryLower = query.toLowerCase();
      
      // ✅ Lista de ícones Font Awesome populares
      final faIcons = _getFontAwesomeMappings(queryLower);
      
      for (var iconName in faIcons.take(limit)) {
        results.add(IconResult(
          name: iconName,
          prefix: 'fontawesome',
          url: 'https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/$iconName.svg',
        ));
      }
      
      return results;
    } catch (e) {
      debugPrint('[UnifiedIconsApiService] Erro ao buscar Font Awesome: $e');
      return [];
    }
  }

  /// Retorna ícones populares do Flaticon
  List<Map<String, String>> _getFlaticonPopularIcons({int limit = 30}) {
    final popular = [
      {'name': 'home', 'url': 'https://cdn-icons-png.flaticon.com/512/25/25694.png'},
      {'name': 'settings', 'url': 'https://cdn-icons-png.flaticon.com/512/3524/3524659.png'},
      {'name': 'user', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png'},
      {'name': 'folder', 'url': 'https://cdn-icons-png.flaticon.com/512/3767/3767084.png'},
      {'name': 'file', 'url': 'https://cdn-icons-png.flaticon.com/512/136/136528.png'},
      {'name': 'search', 'url': 'https://cdn-icons-png.flaticon.com/512/54/54481.png'},
      {'name': 'star', 'url': 'https://cdn-icons-png.flaticon.com/512/1828/1828884.png'},
      {'name': 'heart', 'url': 'https://cdn-icons-png.flaticon.com/512/1077/1077035.png'},
      {'name': 'bell', 'url': 'https://cdn-icons-png.flaticon.com/512/1077/1077114.png'},
      {'name': 'email', 'url': 'https://cdn-icons-png.flaticon.com/512/732/732200.png'},
      {'name': 'phone', 'url': 'https://cdn-icons-png.flaticon.com/512/724/724664.png'},
      {'name': 'calendar', 'url': 'https://cdn-icons-png.flaticon.com/512/833/833593.png'},
      {'name': 'clock', 'url': 'https://cdn-icons-png.flaticon.com/512/2088/2088617.png'},
      {'name': 'camera', 'url': 'https://cdn-icons-png.flaticon.com/512/1042/1042339.png'},
      {'name': 'download', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135713.png'},
      {'name': 'upload', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135716.png'},
      {'name': 'share', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135717.png'},
      {'name': 'edit', 'url': 'https://cdn-icons-png.flaticon.com/512/2921/2921222.png'},
      {'name': 'delete', 'url': 'https://cdn-icons-png.flaticon.com/512/1214/1214428.png'},
      {'name': 'save', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135719.png'},
      {'name': 'lock', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135718.png'},
      {'name': 'wifi', 'url': 'https://cdn-icons-png.flaticon.com/512/2111/2111648.png'},
      {'name': 'location', 'url': 'https://cdn-icons-png.flaticon.com/512/684/684908.png'},
      {'name': 'shopping', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135710.png'},
      {'name': 'money', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135711.png'},
      {'name': 'gift', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135712.png'},
      {'name': 'trophy', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135720.png'},
      {'name': 'book', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135721.png'},
      {'name': 'car', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135722.png'},
      {'name': 'plane', 'url': 'https://cdn-icons-png.flaticon.com/512/3135/3135723.png'},
    ];
    
    return popular.take(limit).toList();
  }


  /// Mapeia termos para ícones Font Awesome
  List<String> _getFontAwesomeMappings(String query) {
    final allIcons = [
      'house', 'gear', 'user', 'folder', 'file', 'link', 'magnifying-glass',
      'star', 'heart', 'bell', 'envelope', 'phone', 'message', 'calendar',
      'clock', 'camera', 'image', 'video', 'music', 'download', 'upload',
      'share', 'pencil', 'trash', 'floppy-disk', 'print', 'lock', 'unlock',
      'eye', 'key', 'shield', 'fire', 'cloud', 'sun', 'moon', 'wifi',
      'battery-full', 'location-dot', 'cart-shopping', 'dollar-sign', 'credit-card',
      'gift', 'trophy', 'medal', 'flag', 'book', 'school', 'hospital', 'car',
      'plane', 'train', 'bus', 'bicycle', 'gamepad', 'play', 'pause', 'stop',
      'refresh', 'bars', 'filter', 'table-cells', 'list', 'grid-3', 'th-large',
    ];
    
    // ✅ Filtra ícones que correspondem à query
    if (query.isEmpty) return allIcons;
    
    return allIcons.where((icon) => 
      icon.contains(query) || query.contains(icon)
    ).toList();
  }
}

