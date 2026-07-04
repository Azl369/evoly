class EvolyDocument {
  const EvolyDocument({
    required this.id,
    required this.title,
    required this.contentMarkdown,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String contentMarkdown;
  final DocumentType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get displayTitle {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '未命名文档' : trimmed;
  }

  String get excerpt {
    final normalized = contentMarkdown
        .replaceAll(RegExp(r'[#>*_`\-\[\]\(\)]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return '暂无正文。';
    }
    if (normalized.length <= 80) {
      return normalized;
    }
    return '${normalized.substring(0, 80)}…';
  }

  EvolyDocument copyWith({
    String? id,
    String? title,
    String? contentMarkdown,
    DocumentType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return EvolyDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

enum DocumentType {
  projectNote,
  projectSummary,
  review,
  knowledge,
}

extension DocumentTypeLabel on DocumentType {
  String get label {
    return switch (this) {
      DocumentType.projectNote => '项目文档',
      DocumentType.projectSummary => '项目总结',
      DocumentType.review => '复盘记录',
      DocumentType.knowledge => '知识笔记',
    };
  }
}
