import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/utils/money.dart';

/// French display formats. Amounts keep the 3 decimals of the dinar
/// (millimes), quantities drop useless zeros.
final _amountFormat = NumberFormat('#,##0.000', 'fr_FR');
final _quantityFormat = NumberFormat('#,##0.###', 'fr_FR');
final _countFormat = NumberFormat('#,##0', 'fr_FR');
final _compactFormat = NumberFormat.compact(locale: 'fr_FR');
final _percentFormat = NumberFormat('#,##0', 'fr_FR');

const currencyLabel = 'DT';

/// `'1250'` -> `'1 250,000 DT'` (narrow no-break space as thousands separator).
String formatAmount(String? raw) => '${_amountFormat.format(parseMoney(raw).toDouble())} $currencyLabel';

/// `'11.000'` -> `'11'`, `'2.500'` -> `'2,5'`.
String formatQuantity(String? raw) => _quantityFormat.format(parseMoney(raw).toDouble());

/// Signed quantity for stock movements: `'+12'`, `'−3'`.
String formatSignedQuantity(String? raw) {
  final value = parseMoney(raw);
  final text = _quantityFormat.format(value.abs().toDouble());
  if (value > Decimal.zero) return '+$text';
  if (value < Decimal.zero) return '−$text';
  return text;
}

String formatCount(int value) => _countFormat.format(value);

/// Short amount for chart axes: `1250` -> `1,3 k`.
String formatCompactAmount(double value) => _compactFormat.format(value);

/// Plural helper for French labels: `pluralize(2, 'vente')` -> `'2 ventes'`.
String pluralize(int count, String singular, {String? plural}) {
  final word = count > 1 ? (plural ?? '${singular}s') : singular;
  return '${formatCount(count)} $word';
}

enum VariationDirection { up, down, flat }

/// Change of a period total compared with the previous period.
class Variation {
  const Variation._(this.direction, this.label, {this.isNew = false});

  final VariationDirection direction;
  final String label;

  /// Previous period was zero: no percentage can be computed.
  final bool isNew;

  /// Returns null when there is nothing to compare (both periods at zero).
  /// Never divides by zero: a previous total of 0 gives "Nouveau".
  static Variation? compute(String? current, String? previous) {
    final now = parseMoney(current);
    final before = parseMoney(previous);
    if (before == Decimal.zero) {
      if (now == Decimal.zero) return null;
      return const Variation._(VariationDirection.up, 'Nouveau', isNew: true);
    }
    final delta = (now - before).toDouble() / before.toDouble() * 100;
    final rounded = delta.round();
    if (rounded == 0) {
      return const Variation._(VariationDirection.flat, '0 %');
    }
    final sign = rounded > 0 ? '+' : '−';
    return Variation._(
      rounded > 0 ? VariationDirection.up : VariationDirection.down,
      '$sign${_percentFormat.format(rounded.abs())} %',
    );
  }
}

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// `'mardi 7 octobre'`.
String formatLongDate(DateTime date) {
  return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
}

/// `'7 oct.'` style short day label for chart axes: `'07/10'`.
String formatShortDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String formatHour(DateTime date) => '${date.hour.toString().padLeft(2, '0')}h';

/// Recent activity time: "À l’instant", "il y a 5 min", "14:32" today,
/// "06/10 14:32" otherwise.
String formatActivityTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final diff = current.difference(local);
  final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (!diff.isNegative && diff.inMinutes < 1) return 'À l’instant';
  if (!diff.isNegative && diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  final sameDay =
      local.year == current.year && local.month == current.month && local.day == current.day;
  if (sameDay) return time;
  return '${formatShortDay(local)} $time';
}
