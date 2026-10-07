import 'package:intl/intl.dart';

final _dayFormat = DateFormat('dd/MM/yyyy');
final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

String formatDate(DateTime value) => _dayFormat.format(value.toLocal());

String formatDateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());

Map<String, String> periodQuery(String period) {
  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day);
  var from = startToday;
  if (period == '7d') {
    from = startToday.subtract(const Duration(days: 6));
  } else if (period == '30d') {
    from = startToday.subtract(const Duration(days: 29));
  }
  final to = startToday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  return {
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
  };
}
