/// Modelo de dados para grupos de abas no Supabase
class TabGroup {
  final String? id;
  final String userId;
  final String name;
  final int groupOrder; // Ordem do grupo
  final DateTime createdAt;
  final DateTime updatedAt;

  TabGroup({
    this.id,
    required this.userId,
    required this.name,
    required this.groupOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Cria um TabGroup a partir de um Map (do Supabase)
  factory TabGroup.fromMap(Map<String, dynamic> map) {
    return TabGroup(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      groupOrder: map['group_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Converte TabGroup para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'group_order': groupOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converte TabGroup para JSON (para passar como parâmetro)
  Map<String, dynamic> toJson() => toMap();

  /// Cria uma cópia com campos atualizados
  TabGroup copyWith({
    String? id,
    String? userId,
    String? name,
    int? groupOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TabGroup(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      groupOrder: groupOrder ?? this.groupOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

