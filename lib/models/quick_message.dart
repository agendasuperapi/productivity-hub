/// Modelo para mensagens rápidas
class QuickMessage {
  final String id;
  final String title;
  final String message;
  final String shortcut; // Atalho (ex: "obr")
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int usageCount; // ✅ Contador de uso da mensagem
  final String? imagePath; // ✅ Caminho da imagem anexada (opcional)

  QuickMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.shortcut,
    required this.createdAt,
    this.updatedAt,
    this.usageCount = 0, // ✅ Default 0
    this.imagePath, // ✅ Caminho da imagem (opcional)
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
      'usage_count': usageCount, // ✅ Inclui contador de uso
      'image_path': imagePath, // ✅ Caminho da imagem
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
      usageCount: (map['usage_count'] as int?) ?? 0, // ✅ Lê contador de uso (default 0)
      imagePath: map['image_path'] as String?, // ✅ Lê caminho da imagem (opcional)
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
    int? usageCount,
    String? imagePath,
  }) {
    return QuickMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      shortcut: shortcut ?? this.shortcut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount, // ✅ Inclui contador de uso
      imagePath: imagePath ?? this.imagePath, // ✅ Inclui caminho da imagem
    );
  }
}






