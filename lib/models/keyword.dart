/// Modelo para palavras-chave customizáveis
class Keyword {
  final String id;
  final String key; // Ex: "PIX" (sem os < >)
  final String value; // Valor que será substituído
  final DateTime createdAt;
  final DateTime? updatedAt;

  Keyword({
    required this.id,
    required this.key,
    required this.value,
    required this.createdAt,
    this.updatedAt,
  });

  /// Cria um Keyword a partir de um Map (do Supabase)
  factory Keyword.fromMap(Map<String, dynamic> map) {
    return Keyword(
      id: map['id'] as String,
      key: map['key'] as String,
      value: map['value'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Converte Keyword para Map (para salvar no Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Cria uma cópia do Keyword com campos atualizados
  Keyword copyWith({
    String? id,
    String? key,
    String? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Keyword(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

