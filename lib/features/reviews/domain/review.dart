class Review {
  const Review({
    required this.id,
    required this.goalId,
    required this.result,
    required this.problem,
    required this.improvement,
    required this.createdAt,
  });

  final String id;
  final String goalId;
  final String result;
  final String problem;
  final String improvement;
  final DateTime createdAt;
}
