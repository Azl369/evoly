class AppClock {
  const AppClock();

  DateTime now() => DateTime.now();

  DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }
}
