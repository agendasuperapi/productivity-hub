/// Modelo de dados para abas salvas no Supabase
class SavedTab {
  final String? id;
  final String userId;
  final String name;
  final String url; // URL única (mantida para compatibilidade)
  final List<String>? urls; // Lista de URLs para múltiplas páginas
  final int? columns; // Número de colunas no layout (null = layout padrão)
  final int? rows; // Número de linhas no layout (null = layout padrão)
  final String? iconUrl; // URL do ícone no Supabase Storage
  final bool openAsWindow; // Se true, abre em uma nova janela ao invés de aba
  final bool enableQuickMessages; // Se true, permite usar atalhos rápidos nesta aba
  final int tabOrder; // Ordem da aba
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedTab({
    this.id,
    required this.userId,
    required this.name,
    String? url,
    this.urls,
    this.columns,
    this.rows,
    this.iconUrl,
    this.openAsWindow = false,
    this.enableQuickMessages = true,
    required this.tabOrder,
    required this.createdAt,
    required this.updatedAt,
  }) : url = url ?? (urls != null && urls.isNotEmpty ? urls.first : '');

  /// Retorna a lista de URLs (usa urls se disponível, senão usa url)
  List<String> get urlList {
    if (urls != null && urls!.isNotEmpty) {
      return urls!;
    }
    return url.isNotEmpty ? [url] : [];
  }

  /// Verifica se tem múltiplas páginas
  bool get hasMultiplePages => (urls != null && urls!.length > 1) || (url.isEmpty && urls != null && urls!.isNotEmpty);

  /// Cria um SavedTab a partir de um Map (do Supabase)
  factory SavedTab.fromMap(Map<String, dynamic> map) {
    // Processa URLs (pode ser string única ou lista JSON)
    List<String>? urls;
    String? url;
    
    if (map['urls'] != null) {
      // Se tem campo urls, usa ele
      if (map['urls'] is List) {
        urls = (map['urls'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (map['urls'] is String) {
        // Tenta fazer parse de JSON string
        try {
          final decoded = (map['urls'] as String).trim();
          if (decoded.startsWith('[') && decoded.endsWith(']')) {
            // É uma lista JSON
            final cleaned = decoded.substring(1, decoded.length - 1);
            urls = cleaned
                .split(',')
                .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (e) {
          // Ignora erro de parse
        }
      }
    }
    
    // Se não tem urls, usa url como fallback
    if (urls == null || urls.isEmpty) {
      url = map['url'] as String? ?? '';
    } else {
      url = urls.first;
    }

    return SavedTab(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      url: url,
      urls: urls,
      columns: map['columns'] as int?,
      rows: map['rows'] as int?,
      iconUrl: map['icon_url'] as String?,
      // ✅ openAsWindow agora é gerenciado localmente, não vem do Supabase
      openAsWindow: false, // Sempre false ao carregar do Supabase
      enableQuickMessages: map['enable_quick_messages'] as bool? ?? true, // Por padrão true se não existir
      tabOrder: map['tab_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Converte SavedTab para Map (para Supabase)
  /// ✅ openAsWindow NÃO é incluído - agora é gerenciado localmente
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'url': url, // Mantém para compatibilidade
      if (urls != null && urls!.isNotEmpty) 'urls': urls,
      if (columns != null) 'columns': columns,
      if (rows != null) 'rows': rows,
      if (iconUrl != null) 'icon_url': iconUrl,
      // ✅ openAsWindow removido - agora é gerenciado localmente via LocalTabSettingsService
      'enable_quick_messages': enableQuickMessages,
      'tab_order': tabOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converte SavedTab para JSON (para passar como parâmetro)
  Map<String, dynamic> toJson() => toMap();

  /// Cria uma cópia com campos atualizados
  SavedTab copyWith({
    String? id,
    String? userId,
    String? name,
    String? url,
    List<String>? urls,
    int? columns,
    int? rows,
    String? iconUrl,
    bool? openAsWindow,
    bool? enableQuickMessages,
    int? tabOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedTab(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      url: url ?? this.url,
      urls: urls ?? this.urls,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      iconUrl: iconUrl ?? this.iconUrl,
      openAsWindow: openAsWindow ?? this.openAsWindow,
      enableQuickMessages: enableQuickMessages ?? this.enableQuickMessages,
      tabOrder: tabOrder ?? this.tabOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

