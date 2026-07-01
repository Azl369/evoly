import 'package:evoly/features/goals/domain/goal.dart';

class DocumentFolderSummary {
  const DocumentFolderSummary({
    required this.goalId,
    required this.goalTitle,
    required this.goalStatus,
    required this.goalProgress,
    required this.documentCount,
    this.latestDocumentTitle,
    this.latestUpdatedAt,
  });

  final String goalId;
  final String goalTitle;
  final GoalStatus goalStatus;
  final double goalProgress;
  final int documentCount;
  final String? latestDocumentTitle;
  final DateTime? latestUpdatedAt;

  bool get hasDocuments => documentCount > 0;
}
