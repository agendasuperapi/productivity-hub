import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Modelo para representar um ícone da API
class IconResult {
  final String name;
  final String prefix;
  final String url; // URL da imagem PNG do ícone

  IconResult({
    required this.name,
    required this.prefix,
    required this.url,
  });

  factory IconResult.fromJson(Map<String, dynamic> json) {
    return IconResult(
      name: json['name'] ?? '',
      prefix: json['prefix'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// Serviço para buscar ícones da API Iconify
class IconsApiService {
  // ✅ API Iconify - gratuita e sem necessidade de autenticação
  static const String _baseUrl = 'https://api.iconify.design';
  
  /// Busca ícones por termo de pesquisa
  /// Retorna lista de ícones que correspondem ao termo
  Future<List<IconResult>> searchIcons(String query, {int limit = 50}) async {
    try {
      if (query.trim().isEmpty) {
        // ✅ Se não há termo de busca, retorna ícones populares
        return await _getPopularIcons(limit: limit);
      }

      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = '$_baseUrl/search?query=$encodedQuery&limit=$limit';
      
      debugPrint('[IconsApiService] 🔍 Buscando ícones: $query');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout ao buscar ícones');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final icons = data['icons'] as List<dynamic>? ?? [];
        
        final results = <IconResult>[];
        for (var icon in icons) {
          if (icon is String) {
            // ✅ Formato: "prefix:icon-name"
            final parts = icon.split(':');
            if (parts.length == 2) {
              final prefix = parts[0];
              final name = parts[1];
              // ✅ Gera URL da imagem SVG (usa API Iconify para renderizar)
              // Formato: https://api.iconify.design/prefix/name.svg?color=%23000000&width=128&height=128
              final imageUrl = '$_baseUrl/$prefix/$name.svg?color=%23000000&width=128&height=128';
              
              results.add(IconResult(
                name: name,
                prefix: prefix,
                url: imageUrl,
              ));
            }
          }
        }
        
        debugPrint('[IconsApiService] ✅ ${results.length} ícones encontrados para "$query"');
        return results;
      } else {
        debugPrint('[IconsApiService] ❌ Erro ao buscar ícones: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[IconsApiService] ❌ Erro ao buscar ícones: $e');
      return [];
    }
  }

  /// Retorna ícones populares (mais usados)
  Future<List<IconResult>> _getPopularIcons({int limit = 50}) async {
    try {
      // ✅ Busca ícones populares usando termos comuns
      final popularTerms = ['home', 'settings', 'user', 'folder', 'file', 'link', 'search', 'star', 'heart', 'bell'];
      final allResults = <IconResult>[];
      
      for (var term in popularTerms) {
        // ✅ Busca diretamente na API para evitar recursão
        final encodedQuery = Uri.encodeComponent(term);
        final url = '$_baseUrl/search?query=$encodedQuery&limit=10';
        
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final icons = data['icons'] as List<dynamic>? ?? [];
            
            for (var icon in icons) {
              if (icon is String) {
                final parts = icon.split(':');
                if (parts.length == 2) {
                  final prefix = parts[0];
                  final name = parts[1];
                  final imageUrl = '$_baseUrl/$prefix/$name.svg?color=%23000000&width=128&height=128';
                  
                  allResults.add(IconResult(
                    name: name,
                    prefix: prefix,
                    url: imageUrl,
                  ));
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[IconsApiService] Erro ao buscar termo "$term": $e');
        }
        
        if (allResults.length >= limit) break;
      }
      
      // ✅ Remove duplicatas
      final uniqueResults = <String, IconResult>{};
      for (var result in allResults) {
        final key = '${result.prefix}:${result.name}';
        if (!uniqueResults.containsKey(key)) {
          uniqueResults[key] = result;
        }
      }
      
      return uniqueResults.values.take(limit).toList();
    } catch (e) {
      debugPrint('[IconsApiService] ❌ Erro ao buscar ícones populares: $e');
      return [];
    }
  }

  /// Obtém URL da imagem do ícone em tamanho específico
  String getIconImageUrl(String prefix, String name, {int size = 128}) {
    return '$_baseUrl/$prefix/$name.svg?color=%23000000&width=$size&height=$size';
  }
}

