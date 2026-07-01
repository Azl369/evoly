import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';

class DocumentMapper {
  static EvolyDocument fromMap(Map<String, Object?> map) {
    return EvolyDocument(
      id: map['id']! as String,
      title: map['title']! as String,
      contentMarkdown: map['content_markdown']! as String,
      type: DocumentType.values.byName(map['type']! as String),
      createdAt: AppDatabaseDateCodec.decodeDate(map['created_at']!),
      updatedAt: AppDatabaseDateCodec.decodeDate(map['updated_at']!),
      deletedAt: AppDatabaseDateCodec.decodeNullableDate(map['deleted_at']),
    );
  }

  static Map<String, Object?> toMap(EvolyDocument document) {
    return {
      'id': document.id,
      'title': document.title,
      'content_markdown': document.contentMarkdown,
      'type': document.type.name,
      'created_at': AppDatabaseDateCodec.encodeDate(document.createdAt),
      'updated_at': AppDatabaseDateCodec.encodeDate(document.updatedAt),
      'deleted_at': document.deletedAt == null
          ? null
          : AppDatabaseDateCodec.encodeDate(document.deletedAt!),
    };
  }
}
