import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'icons_api_service.dart';

/// Serviço para buscar ícones COLORIDOS da API Icons8
/// Esta API oferece ícones coloridos em PNG
class ColoredIconsApiService {
  // ✅ API Icons8 - oferece ícones coloridos gratuitos via CDN
  static const String _baseUrl = 'https://img.icons8.com';
  
  /// Busca ícones coloridos por termo de pesquisa
  /// Retorna lista de ícones coloridos que correspondem ao termo
  Future<List<IconResult>> searchIcons(String query, {int limit = 50}) async {
    try {
      if (query.trim().isEmpty) {
        // ✅ Se não há termo de busca, retorna ícones populares coloridos
        return await _getPopularColoredIcons(limit: limit);
      }

      // ✅ Busca ícones coloridos baseado no termo
      return await _searchColoredIconsFromIcons8(query, limit: limit);
    } catch (e) {
      debugPrint('[ColoredIconsApiService] ❌ Erro ao buscar ícones: $e');
      return [];
    }
  }

  /// Busca ícones coloridos usando Icons8 (CDN público)
  Future<List<IconResult>> _searchColoredIconsFromIcons8(String query, {int limit = 50}) async {
    try {
      final results = <IconResult>[];
      final queryLower = query.toLowerCase().trim();
      
      // ✅ Mapeamento de termos comuns para ícones do Icons8
      final iconMappings = _getIconMappings(queryLower);
      
      for (var mapping in iconMappings) {
        if (results.length >= limit) break;
        
        // ✅ Gera URL do ícone colorido (PNG 512x512)
        final iconUrl = '$_baseUrl/color/512/${mapping['icon']}.png';
        
        results.add(IconResult(
          name: mapping['name'] ?? mapping['icon'] ?? '',
          prefix: 'icons8',
          url: iconUrl,
        ));
      }
      
      debugPrint('[ColoredIconsApiService] ✅ ${results.length} ícones coloridos encontrados para "$query"');
      return results;
    } catch (e) {
      debugPrint('[ColoredIconsApiService] ❌ Erro ao buscar ícones coloridos: $e');
      return [];
    }
  }

  /// Mapeia termos de busca para ícones do Icons8
  List<Map<String, String>> _getIconMappings(String query) {
    final mappings = <Map<String, String>>[];
    
    // ✅ Mapeamento de termos comuns para ícones do Icons8
    final allMappings = {
      'home': ['home', 'house', 'casa', 'início'],
      'settings': ['settings', 'configurações', 'config', 'configuração'],
      'user': ['user', 'usuário', 'person', 'pessoa', 'perfil'],
      'folder': ['folder', 'pasta', 'directory', 'diretório'],
      'file': ['file', 'arquivo', 'document', 'documento'],
      'link': ['link', 'url', 'chain', 'cadeia'],
      'search': ['search', 'buscar', 'lupa', 'pesquisa'],
      'star': ['star', 'estrela', 'favorite', 'favorito'],
      'heart': ['heart', 'coração', 'like', 'curtir'],
      'bell': ['bell', 'sino', 'notification', 'notificação'],
      'email': ['email', 'mail', 'correio', 'e-mail'],
      'phone': ['phone', 'telefone', 'call', 'chamada'],
      'message': ['message', 'mensagem', 'chat', 'conversa'],
      'calendar': ['calendar', 'calendário'],
      'clock': ['clock', 'relógio', 'time', 'tempo'],
      'camera': ['camera', 'câmera', 'foto'],
      'image': ['image', 'imagem', 'photo', 'fotografia'],
      'video': ['video', 'vídeo'],
      'music': ['music', 'música'],
      'download': ['download', 'baixar', 'descarregar'],
      'upload': ['upload', 'enviar', 'carregar'],
      'share': ['share', 'compartilhar'],
      'edit': ['edit', 'editar', 'pencil', 'lápis'],
      'delete': ['delete', 'deletar', 'trash', 'lixeira'],
      'save': ['save', 'salvar', 'disk', 'disco'],
      'print': ['print', 'imprimir'],
      'lock': ['lock', 'bloquear', 'segurança'],
      'unlock': ['unlock', 'desbloquear'],
      'eye': ['eye', 'olho', 'visualizar', 'ver'],
      'key': ['key', 'chave'],
      'shield': ['shield', 'escudo', 'proteção'],
      'fire': ['fire', 'fogo', 'hot', 'quente'],
      'cloud': ['cloud', 'nuvem'],
      'sun': ['sun', 'sol'],
      'moon': ['moon', 'lua'],
      'wifi': ['wifi', 'wireless', 'sem-fio'],
      'battery': ['battery', 'bateria'],
      'location': ['location', 'localização', 'map', 'mapa'],
      'shopping': ['shopping', 'compras', 'cart', 'carrinho'],
      'money': ['money', 'dinheiro', 'dollar', 'dólar'],
      'credit-card': ['credit-card', 'cartão', 'card'],
      'gift': ['gift', 'presente'],
      'trophy': ['trophy', 'troféu'],
      'medal': ['medal', 'medalha'],
      'flag': ['flag', 'bandeira'],
      'book': ['book', 'livro'],
      'school': ['school', 'escola'],
      'hospital': ['hospital', 'hospital'],
      'car': ['car', 'carro', 'automobile', 'automóvel'],
      'plane': ['plane', 'avião'],
      'train': ['train', 'trem'],
      'bus': ['bus', 'ônibus'],
      'bike': ['bike', 'bicicleta'],
      'game': ['game', 'jogo', 'gaming'],
      'play': ['play', 'reproduzir'],
      'pause': ['pause', 'pausar'],
      'stop': ['stop', 'parar'],
      'refresh': ['refresh', 'atualizar', 'reload', 'recarregar'],
      'menu': ['menu', 'hamburger', 'hambúrguer'],
      'filter': ['filter', 'filtro'],
      'grid': ['grid', 'grade'],
      'list': ['list', 'lista'],
    };
    
    // ✅ Busca mapeamentos que correspondem ao termo
    for (var entry in allMappings.entries) {
      if (entry.value.any((term) => term.contains(query) || query.contains(term))) {
        mappings.add({
          'name': entry.key,
          'icon': entry.key,
        });
        if (mappings.length >= 50) break;
      }
    }
    
    // ✅ Se não encontrou nada, tenta usar o termo diretamente
    if (mappings.isEmpty) {
      final cleanQuery = query.replaceAll(RegExp(r'[^a-z0-9]'), '-');
      mappings.add({
        'name': query,
        'icon': cleanQuery,
      });
    }
    
    return mappings;
  }

  /// Retorna ícones populares coloridos
  Future<List<IconResult>> _getPopularColoredIcons({int limit = 50}) async {
    final popularIcons = [
      'home', 'settings', 'user', 'folder', 'file', 'link', 'search', 
      'star', 'heart', 'bell', 'email', 'phone', 'message', 'calendar',
      'clock', 'camera', 'image', 'video', 'music', 'download', 'upload',
      'share', 'edit', 'delete', 'save', 'print', 'lock', 'unlock',
      'eye', 'key', 'shield', 'fire', 'cloud', 'sun', 'moon', 'wifi',
      'battery', 'location', 'shopping', 'money', 'credit-card', 'gift',
      'trophy', 'medal', 'flag', 'book', 'school', 'hospital', 'car',
      'plane', 'train', 'bus', 'bike', 'game', 'play', 'pause', 'stop'
    ];
    
    final results = <IconResult>[];
    for (var iconName in popularIcons.take(limit)) {
      results.add(IconResult(
        name: iconName,
        prefix: 'icons8',
        url: '$_baseUrl/color/512/$iconName.png',
      ));
    }
    
    return results;
  }
}
