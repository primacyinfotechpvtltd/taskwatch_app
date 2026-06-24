String dateToSimpleString(DateTime dateTime) {
  return dateTime.toIso8601String().split('.').first.replaceAll('T', ' ');
}
