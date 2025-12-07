/// Modelo de dados para abas salvas no Supabase
class SavedTab {
  final String? id;
  final String userId;
  final String name;
  final String url;
  final String? iconUrl; // URL do ícone no Supabase Storage
  final int tabOrder; // Ordem da aba
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedTab({
    this.id,
    required this.userId,
    required this.name,
    required this.url,
    this.iconUrl,
    required this.tabOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Cria um SavedTab a partir de um Map (do Supabase)
  factory SavedTab.fromMap(Map<String, dynamic> map) {
    return SavedTab(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      iconUrl: map['icon_url'] as String?,
      tabOrder: map['tab_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Converte SavedTab para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'url': url,
      if (iconUrl != null) 'icon_url': iconUrl,
      'tab_order': tabOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Cria uma cópia com campos atualizados
  SavedTab copyWith({
    String? id,
    String? userId,
    String? name,
    String? url,
    String? iconUrl,
    int? tabOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedTab(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      url: url ?? this.url,
      iconUrl: iconUrl ?? this.iconUrl,
      tabOrder: tabOrder ?? this.tabOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

