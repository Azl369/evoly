enum Priority {
  low,
  medium,
  high,
}

extension PriorityLabel on Priority {
  String get label {
    return switch (this) {
      Priority.low => '低',
      Priority.medium => '中',
      Priority.high => '高',
    };
  }

  int get weight {
    return switch (this) {
      Priority.low => 1,
      Priority.medium => 2,
      Priority.high => 3,
    };
  }
}
