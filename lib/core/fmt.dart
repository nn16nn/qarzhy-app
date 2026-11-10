import 'dart:math' as math;
import 'i18n.dart';

/// JSON мәнін санға айналдыру
double n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final x = double.tryParse(v.toString().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
  return (x == null || x.isNaN || x.isInfinite) ? 0 : x;
}

/// Мәтіннен сан (енгізу өрістері үшін)
double parseNum(String? v) => n(v ?? '');

String s(dynamic v) => v == null ? '' : v.toString();

String newId() => '${DateTime.now().millisecondsSinceEpoch}${math.Random().nextInt(900) + 100}';

String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String todayISO() => iso(DateTime.now());
DateTime parseISO(String s) {
  final p = s.split('-');
  int g(int i, int def) => i < p.length ? (int.tryParse(p[i]) ?? def) : def;
  return DateTime(g(0, 2000), g(1, 1), g(2, 1));
}
String ym(DateTime d) => iso(d).substring(0, 7);
int jsDay(DateTime d) => d.weekday % 7; // 0 = жексенбі

String fullDate(String? s) {
  if (s == null || s.isEmpty) return '—';
  final d = parseISO(s);
  return '${d.day} ${monName(d.month - 1).toLowerCase()} ${d.year}';
}

String dayTitle(String s) {
  final d = parseISO(s);
  final y = DateTime.now().subtract(const Duration(days: 1));
  if (s == todayISO()) return t('Бүгін');
  if (s == iso(y)) return t('Кеше');
  return '${d.day} ${monName(d.month - 1).toLowerCase()}, ${t(kWdays[jsDay(d)]).toLowerCase()}';
}

const thin = ' ';
const nbsp = ' ';

String nf(double v, [bool dec = false]) {
  final a = v.abs();
  String str;
  if (dec && a.roundToDouble() != a) {
    str = a.toStringAsFixed(2);
  } else {
    str = a.round().toString();
  }
  final p = str.split('.');
  final ip = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => thin);
  return ip + (p.length > 1 ? ',${p[1]}' : '');
}
