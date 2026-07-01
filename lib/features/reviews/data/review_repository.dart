import 'package:evoly/features/reviews/domain/review.dart';

abstract class ReviewRepository {
  Future<List<Review>> findByGoalId(String goalId);

  Future<void> save(Review review);
}
