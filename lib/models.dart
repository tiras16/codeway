enum ProcessingType { face, document }

class ProcessItem {
  ProcessItem({
    required this.id,
    required this.type,
    required this.originalPath,
    required this.resultImagePath,
    required this.createdAt,
    required this.fileSizeBytes,
    this.pdfPath,
    this.pageCount = 1,
  });

  final String id;
  final ProcessingType type;
  final String originalPath;
  final String resultImagePath;
  final String? pdfPath;
  final DateTime createdAt;
  final int fileSizeBytes;
  final int pageCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'originalPath': originalPath,
      'resultImagePath': resultImagePath,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'pageCount': pageCount,
    };
  }

  factory ProcessItem.fromMap(Map<dynamic, dynamic> map) {
    return ProcessItem(
      id: map['id'] as String,
      type: (map['type'] as String) == 'face'
          ? ProcessingType.face
          : ProcessingType.document,
      originalPath: map['originalPath'] as String,
      resultImagePath: map['resultImagePath'] as String,
      pdfPath: map['pdfPath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      fileSizeBytes: map['fileSizeBytes'] as int,
      pageCount: (map['pageCount'] as int?) ?? 1,
    );
  }
}

class ProcessResult {
  ProcessResult({
    required this.type,
    required this.originalPath,
    required this.resultImagePath,
    this.pdfPath,
    this.pageCount = 1,
  });

  final ProcessingType type;
  final String originalPath;
  final String resultImagePath;
  final String? pdfPath;
  final int pageCount;
}
