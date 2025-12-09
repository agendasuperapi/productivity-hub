/// Modelo para mensagens rápidas
class QuickMessage {
  final String id;
  final String title;
  final String message;
  final String shortcut; // Atalho (ex: "obr")
  final DateTime createdAt;
  final DateTime? updatedAt;

  QuickMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.shortcut,
    required this.createdAt,
    this.updatedAt,
  });

  /// Converte para Map (para salvar no Supabase ou local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'shortcut': shortcut.toLowerCase(), // Sempre em minúsculas
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Cria a partir de um Map
  factory QuickMessage.fromMap(Map<String, dynamic> map) {
    return QuickMessage(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      shortcut: (map['shortcut'] as String).toLowerCase(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Cria uma cópia com campos atualizados
  QuickMessage copyWith({
    String? id,
    String? title,
    String? message,
    String? shortcut,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      shortcut: shortcut ?? this.shortcut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

