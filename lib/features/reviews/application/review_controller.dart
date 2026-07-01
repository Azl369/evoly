import 'package:flutter/foundation.dart';
import 'package:evoly/features/reviews/data/review_repository.dart';
import 'package:evoly/features/reviews/domain/review.dart';

class ReviewController extends ChangeNotifier {
  ReviewController(this.repository);

  final ReviewRepository repository;

  Future<void> save(Review review) async {
    await repository.save(review);
    notifyListeners();
  }
}
