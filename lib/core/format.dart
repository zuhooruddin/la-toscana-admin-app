import 'package:intl/intl.dart';

String eur(int cents, [String lang = 'es']) => NumberFormat.currency(locale: lang == 'en' ? 'en_IE' : 'es_ES', symbol: '€').format(cents / 100);

/// Option price delta, e.g. "+1,50 €" (empty when free).
String delta(int cents, [String lang = 'es']) => cents == 0 ? '' : '${cents > 0 ? '+' : '−'}${eur(cents.abs(), lang)}';

/// Times are shown in the device's local time; customers order from Spain (Europe/Madrid).
String hhmm(DateTime t) => DateFormat.Hm().format(t.toLocal());

String dayLabel(DateTime d, String lang) {
  final local = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return lang == 'en' ? 'Today' : 'Hoy';
  if (diff == 1) return lang == 'en' ? 'Tomorrow' : 'Mañana';
  return DateFormat.MMMEd(lang == 'en' ? 'en' : 'es').format(local);
}

String dateTime(DateTime d, String lang) => DateFormat.yMMMd(lang == 'en' ? 'en' : 'es').add_Hm().format(d.toLocal());
