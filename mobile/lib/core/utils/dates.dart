import 'package:intl/intl.dart';

final _dayFormat = DateFormat('dd/MM/yyyy');
final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

String formatDate(DateTime value) => _dayFormat.format(value.toLocal());

String formatDateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());
