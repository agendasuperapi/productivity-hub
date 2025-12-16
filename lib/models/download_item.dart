/// Modelo para representar um item de download
class DownloadItem {
  final String id;
  final String fileName;
  final String filePath; // Caminho do arquivo baixado ou URL/data URL
  final DateTime downloadDate;
  final int fileSize; // Tamanho em bytes (opcional)

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.downloadDate,
    this.fileSize = 0,
  });

  /// Converte para Map para salvar no SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'downloadDate': downloadDate.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  /// Cria um DownloadItem a partir de um Map
  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      downloadDate: DateTime.parse(map['downloadDate'] as String),
      fileSize: map['fileSize'] as int? ?? 0,
    );
  }

  /// Formata a data e hora para exibição
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(downloadDate);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora';
        }
        return 'Há ${difference.inMinutes} min';
      }
      return 'Há ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return '${downloadDate.day}/${downloadDate.month}/${downloadDate.year}';
    }
  }

  /// Formata o tamanho do arquivo para exibição
  String get formattedSize {
    if (fileSize == 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}






