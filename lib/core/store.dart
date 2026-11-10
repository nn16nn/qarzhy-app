import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'fmt.dart';
import 'i18n.dart';

typedef J = Map<String, dynamic>;

/// Қосымшаның барлық деректері. Құрылымы веб-нұсқамен (qarzhy_v1) бірдей,
/// сондықтан «Деректі сақтау» файлы екі жаққа да ашылады.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  J db = {};
  bool ready = false;
  late Directory _dir;
  Timer? _saveTimer;

  // ---------- жүктеу / сақтау ----------
  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    J? data;
    final f = File('${_dir.path}/qarzhy_db.json');
    final bak = File('${_dir.path}/qarzhy_db.bak.json');
    for (final file in [f, bak]) {
      if (data != null) break;
      try {
        if (await file.exists()) data = jsonDecode(await file.readAsString()) as J;
      } catch (_) {}
    }
    db = normalize(data ?? {});
    gLang = s(db['lang']);
    ready = true;
    notifyListeners();
    unawaited(_autoSnap());
  }

  /// Өзгерістен кейін шақырылады: экранды жаңартады және 300 мс кейін файлға жазады.
  void save() {
    db['updated'] = DateTime.now().toUtc().toIso8601String();
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!ready) return;
    try {
      final f = File('${_dir.path}/qarzhy_db.json');
      final tmp = File('${_dir.path}/qarzhy_db.tmp');
      await tmp.writeAsString(jsonEncode(db), flush: true);
      if (await f.exists()) await f.copy('${_dir.path}/qarzhy_db.bak.json');
      await tmp.rename(f.path);
    } catch (_) {}
  }

  // ---------- автокөшірме: күніне бір рет, соңғы 7 күн ----------
  Directory get _snapDir => Directory('${_dir.path}/snaps');

  Future<void> _autoSnap() async {
    if (txs.isEmpty) return;
    try {
      await _snapDir.create(recursive: true);
      final day = todayISO();
      final f = File('${_snapDir.path}/$day.json');
      if (await f.exists()) return;
      await f.writeAsString(jsonEncode(db));
      final list = await snaps();
      while (list.length > 7) {
        final old = list.removeAt(list.length - 1);
        await File('${_snapDir.path}/${old.day}.json').delete();
      }
    } catch (_) {}
  }

  /// Жаңасы бірінші
  Future<List<Snap>> snaps() async {
    try {
      if (!await _snapDir.exists()) return [];
      final out = <Snap>[];
      await for (final e in _snapDir.list()) {
        final name = e.uri.pathSegments.last;
        if (!name.endsWith('.json')) continue;
        final day = name.replaceAll('.json', '');
        int count = 0;
        try {
          final d = jsonDecode(await File(e.path).readAsString()) as J;
          count = (d['tx'] as List?)?.length ?? 0;
        } catch (_) {}
        out.add(Snap(day, count));
      }
      out.sort((a, b) => b.day.compareTo(a.day));
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<bool> restoreSnap(String day) async {
    try {
      final d = jsonDecode(await File('${_snapDir.path}/$day.json').readAsString()) as J;
      replaceAll(d);
      return true;
    } catch (_) {
      return false;
    }
  }

  void replaceAll(J d, {String? keepLang}) {
    db = normalize(d);
    if (keepLang != null && d['lang'] == null) db['lang'] = keepLang;
    gLang = s(db['lang']);
    save();
  }

  // ---------- қалыпқа келтіру ----------
  static J normalize(J d) {
    for (final k in ['tx', 'goals', 'accounts', 'btx', 'debts', 'recur']) {
      if (d[k] is! List) d[k] = <dynamic>[];
      d[k] = (d[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (d['limits'] is! Map) d['limits'] = <String, dynamic>{};
    if (d['rules'] is! Map) d['rules'] = <String, dynamic>{};
    if (d['pref'] is! Map) d['pref'] = <String, dynamic>{};
    d['pref'] = Map<String, dynamic>.from(d['pref'] as Map);
    if (d['lang'] == null || !['kk', 'ru', 'en'].contains(d['lang'])) d['lang'] = detectLang();
    if (d['theme'] == null) d['theme'] = 'auto';
    final pref = d['pref'] as J;
    if (pref['base'] == null || !kCurs.containsKey(pref['base'])) {
      pref['base'] = ((d['tx'] as List).isNotEmpty || (d['accounts'] as List).isNotEmpty) ? 'KZT' : guessBase(s(d['lang']));
    }
    if ((d['accounts'] as List).isEmpty) {
      d['accounts'] = [
        {'id': 'a1', 'name': {'kk': 'Қолма-қол', 'ru': 'Наличные', 'en': 'Cash'}[d['lang']] ?? 'Қолма-қол', 'kind': 'asset', 'icon': 'wallet', 'bal': 0, 'cur': pref['base']}
      ];
    }
    return d;
  }

  static String detectLang() {
    final l = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (l == 'kk') return 'kk';
    if (['ru', 'be', 'uk', 'ky', 'uz', 'tg'].contains(l)) return 'ru';
    if (l == 'en') return 'en';
    return 'kk';
  }

  static String guessBase(String lang) {
    final reg = (PlatformDispatcher.instance.locale.countryCode ?? '').toUpperCase();
    const m = {
      'KZ': 'KZT', 'RU': 'RUB', 'KG': 'KGS', 'UZ': 'UZS', 'US': 'USD', 'GB': 'GBP', 'TR': 'TRY', 'UA': 'UAH', 'BY': 'BYN', 'AZ': 'AZN',
      'GE': 'GEL', 'IN': 'INR', 'AE': 'AED', 'CN': 'CNY', 'TJ': 'TJS', 'KR': 'KRW', 'JP': 'JPY', 'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR'
    };
    if (m[reg] != null) return m[reg]!;
    return lang == 'en' ? 'USD' : 'KZT';
  }

  // ---------- қол жеткізу ----------
  List<J> get txs => (db['tx'] as List).cast<J>();
  set txs(List<J> v) => db['tx'] = v;
  List<J> get accounts => (db['accounts'] as List).cast<J>();
  set accounts(List<J> v) => db['accounts'] = v;
  List<J> get goals => (db['goals'] as List).cast<J>();
  set goals(List<J> v) => db['goals'] = v;
  List<J> get debts => (db['debts'] as List).cast<J>();
  set debts(List<J> v) => db['debts'] = v;
  List<J> get recur => (db['recur'] as List).cast<J>();
  set recur(List<J> v) => db['recur'] = v;
  J get pref => db['pref'] as J;
  String get theme => s(db['theme']);

  J? acc(dynamic id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a['id'] == id) return a;
    }
    return null;
  }

  List<J> accsOf(String kind) => accounts.where((a) => a['kind'] == kind).toList();
  List<J> get assets => accsOf('asset');

  J? txOf(String id) {
    for (final x in txs) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  // ---------- валюта ----------
  String get base => kCurs.containsKey(pref['base']) ? s(pref['base']) : 'KZT';
  String get sym => symOf(base);

  double fxRate([String? code]) {
    final b = base;
    code ??= b;
    if (code == b) return 1;
    final fx = db['fx'];
    if (fx is Map && fx['base'] == b && fx['r'] is Map && n((fx['r'] as Map)[code]) > 0) return n((fx['r'] as Map)[code]);
    final rate = db['rate'];
    if (code == 'USD' && b == 'KZT' && rate is Map && n(rate['v']) > 0) return n(rate['v']);
    return 0;
  }

  String curOf(J? a) => (a != null && a['cur'] != null) ? s(a['cur']) : base;
  String curSym(J? a) => symOf(curOf(a));
  bool foreign(J? a) => a != null && a['cur'] != null && a['cur'] != base;
  double toAcc(J? a, double v) {
    final r = foreign(a) ? fxRate(s(a!['cur'])) : 1.0;
    return r > 0 ? v / r : v;
  }

  double toBase(J? a) {
    if (a == null) return 0;
    final r = foreign(a) ? fxRate(s(a['cur'])) : 1.0;
    return r > 0 ? n(a['bal']) * r : n(a['bal']);
  }

  String fxLine(String code) {
    final r = fxRate(code);
    return r > 0 ? '1 ${symOf(code)} = ${nf(r, r < 100)} $sym' : '—';
  }

  Future<bool> fetchRate({bool manual = false}) async {
    const urls = ['https://open.er-api.com/v6/latest/USD', 'https://api.exchangerate-api.com/v4/latest/USD'];
    for (final u in urls) {
      try {
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final req = await c.getUrl(Uri.parse(u));
        final res = await req.close().timeout(const Duration(seconds: 10));
        final body = await res.transform(utf8.decoder).join();
        c.close();
        final d = jsonDecode(body);
        final rs = d is Map ? d['rates'] : null;
        final b = base;
        if (rs is! Map || rs[b] == null) continue;
        final map = <String, dynamic>{};
        for (final code in kCurs.keys) {
          if (rs[code] != null) map[code] = n(rs[b]) / n(rs[code]);
        }
        final fx = db['fx'];
        final keepManual = (fx is Map && fx['src'] == 'manual' && fx['base'] == b) ? fx['r'] as Map : null;
        if (keepManual != null && !manual) keepManual.forEach((k, v) => map[k.toString()] = v);
        final at = DateTime.now().toUtc().toIso8601String();
        db['fx'] = {'base': b, 'at': at, 'src': keepManual != null && !manual ? 'manual' : 'auto', 'r': map};
        if (rs['KZT'] != null) db['rate'] = {'v': n(rs['KZT']), 'at': at, 'src': 'auto'};
        save();
        return true;
      } catch (_) {}
    }
    return false;
  }

  // ---------- ақша форматы ----------
  String money(double v, [String? symbol, bool dec = false]) => '${v < 0 ? '−' : ''}${nf(v, dec)}$nbsp${symbol ?? sym}';
  String moneyShort(double v, [String? symbol]) {
    final a = v.abs();
    final sg = v < 0 ? '−' : '';
    final sy = symbol ?? sym;
    String d(double x) {
      final r = x >= 100 ? x.roundToDouble() : x >= 10 ? (x * 10).round() / 10 : (x * 100).round() / 100;
      var str = r == r.roundToDouble() ? r.round().toString() : r.toString();
      return str.replaceAll('.', ',');
    }

    if (a >= 1e9) return '$sg${d(a / 1e9)}$nbsp${t('млрд')}$nbsp$sy';
    if (a >= 1e6) return '$sg${d(a / 1e6)}$nbsp${t('млн')}$nbsp$sy';
    return money(v, sy);
  }

  String signed(double v, String type) => '${type == 'in' ? '+' : type == 'out' ? '−' : ''}${nf(v)}$nbsp$sym';

  // ---------- есептеулер ----------
  double debtLeft(J d) => math.max(0, n(d['amt']) - n(d['paid']));

  DebtTotals debtTotals() {
    final r = DebtTotals();
    final td = todayISO();
    for (final d in debts) {
      final l = debtLeft(d);
      if (l <= 0) continue;
      if (d['dir'] == 'out') {
        r.lent += l;
      } else {
        r.owed += l;
      }
      final due = s(d['due']);
      if (due.isNotEmpty && due.compareTo(td) < 0) r.late++;
    }
    return r;
  }

  Totals totals() {
    double b = 0, d = 0, g = 0;
    for (final x in accounts) {
      if (x['kind'] == 'debt') {
        d += toBase(x);
      } else if (x['kind'] != 'broker') {
        b += toBase(x);
      }
    }
    for (final x in goals) {
      g += n(x['saved']);
    }
    final dt = debtTotals();
    return Totals(b, d, g, dt.lent, dt.owed, b + dt.lent - dt.owed);
  }

  MonthSum monthSum(String key) {
    final r = MonthSum();
    for (final x in txs) {
      final date = s(x['date']);
      if (date.length >= 7 && date.substring(0, 7) == key && x['type'] != 'tr') {
        if (x['type'] == 'in') {
          r.inc += n(x['amt']);
        } else {
          r.out += n(x['amt']);
        }
        r.count++;
      }
    }
    return r;
  }

  void applyTx(J x, int sign) {
    final a = acc(x['acc']);
    if (x['type'] == 'tr') {
      final to = acc(x['to']);
      if (a != null) a['bal'] = n(a['bal']) - sign * (n(x['amtFrom']) > 0 ? n(x['amtFrom']) : toAcc(a, n(x['amt'])));
      if (to != null) to['bal'] = n(to['bal']) + sign * (n(x['amt2']) > 0 ? n(x['amt2']) : toAcc(to, n(x['amt'])));
      return;
    }
    if (a != null) a['bal'] = n(a['bal']) + sign * toAcc(a, x['type'] == 'in' ? n(x['amt']) : -n(x['amt']));
    if (x['loan'] != null) {
      final l = acc(x['loan']);
      if (l != null) l['bal'] = n(l['bal']) - sign * n(x['amt']);
    }
  }

  static List<J> sortTx(List<J> list) {
    list.sort((a, b) {
      final da = s(a['date']), db2 = s(b['date']);
      if (da == db2) return s(b['id']).compareTo(s(a['id']));
      return db2.compareTo(da);
    });
    return list;
  }

  RecurState recurState() {
    final now = DateTime.now();
    final key = ym(now);
    final d = now.day;
    final r = RecurState();
    for (final x in recur) {
      final amt = n(x['amt']);
      r.total += amt;
      if (x['paid'] != key) {
        r.unpaid += amt;
        final day = n(x['day']).round();
        if (day - d <= 3 && day - d >= -31) r.due.add(x);
      }
    }
    return r;
  }

  static int monthsLeft(double bal, double rate, double pay) {
    final i = rate / 12 / 100;
    var b = bal;
    var k = 0;
    if (pay <= bal * i) return -1;
    while (b > 0 && k < 600) {
      b = b * (1 + i) - pay;
      k++;
    }
    return k;
  }

  int loanLeft(J a) {
    if (!(n(a['bal']) > 0)) return 0;
    final end = s(a['end']);
    if (end.isNotEmpty) {
      final p = end.split('-');
      final d = DateTime.now();
      return math.max(1, (int.parse(p[0]) - d.year) * 12 + (int.parse(p[1]) - 1 - (d.month - 1)) + 1);
    }
    return n(a['pay']) > 0 ? monthsLeft(n(a['bal']), n(a['rate']), n(a['pay'])) : -1;
  }

  String loanEnd(J a, int k) {
    final end = s(a['end']);
    if (end.isNotEmpty) {
      final p = end.split('-');
      return '${monName(int.parse(p[1]) - 1)} ${p[0]}';
    }
    final now = DateTime.now();
    final d = DateTime(now.year, now.month + k - 1, 1);
    return '${monName(d.month - 1)} ${d.year}';
  }

  bool get isFresh =>
      txs.isEmpty && goals.isEmpty && debts.isEmpty && accounts.length <= 1 && !(accounts.isNotEmpty && n(accounts[0]['bal']) != 0);
}

class Snap {
  final String day;
  final int count;
  Snap(this.day, this.count);
}

class DebtTotals {
  double lent = 0, owed = 0;
  int late = 0;
}

class Totals {
  final double banks, loans, goals, lent, owed, net;
  Totals(this.banks, this.loans, this.goals, this.lent, this.owed, this.net);
}

class MonthSum {
  double inc = 0, out = 0;
  int count = 0;
}

class RecurState {
  double total = 0, unpaid = 0;
  final List<J> due = [];
}

// ================= ВАЛЮТАЛАР =================
const Map<String, List<String>> kCurs = {
  'KZT': ['₸', 'Теңге'], 'RUB': ['₽', 'Рубль'], 'USD': ['\$', 'Доллар'], 'EUR': ['€', 'Евро'], 'KGS': ['сом', 'Сом'], 'UZS': ['сўм', 'Сўм'],
  'TRY': ['₺', 'Лира'], 'GBP': ['£', 'Фунт'], 'CNY': ['¥', 'Юань'], 'AED': ['AED', 'Дирхам'], 'INR': ['₹', 'Рупия'], 'UAH': ['₴', 'Гривна'],
  'GEL': ['₾', 'Лари'], 'AZN': ['₼', 'Манат'], 'BYN': ['Br', 'Бел. рубль'], 'TJS': ['SM', 'Сомони'], 'KRW': ['₩', 'Вона'], 'JPY': ['¥', 'Иена'],
};
String symOf(String code) => (kCurs[code] ?? [code])[0];

// ================= САНАТТАР =================
const Map<String, List<String>> kCats = {
  'out': ['Тамақ', 'Ойын-сауық', 'Байланыс', 'Әке-шешеме', 'Көлік', 'Киім', 'Тұрғын үй', 'Денсаулық', 'Білім', 'Сыйлық', 'Инвестиция', 'Несие төлемі', 'Аударымдар', 'Басқа'],
  'in': ['Жалақы', 'Бизнес', 'Фриланс', 'Инвестиция', 'Кэшбэк', 'Несие алу', 'Сыйлық', 'Басқа'],
};

class CatMeta {
  final String icon;
  final Color color;
  const CatMeta(this.icon, this.color);
}

const Map<String, CatMeta> kCatMeta = {
  'Тамақ': CatMeta('food', Color(0xFFE07A2F)), 'Ойын-сауық': CatMeta('fun', Color(0xFF8B5CF6)), 'Байланыс': CatMeta('phone', Color(0xFF2F7DE1)),
  'Әке-шешеме': CatMeta('family', Color(0xFFD9467A)), 'Көлік': CatMeta('car', Color(0xFF0E9F9C)), 'Киім': CatMeta('shirt', Color(0xFFC2562B)),
  'Тұрғын үй': CatMeta('building', Color(0xFF5B6B82)), 'Денсаулық': CatMeta('health', Color(0xFFE2474C)), 'Білім': CatMeta('book', Color(0xFF3E6FE0)),
  'Сыйлық': CatMeta('gift', Color(0xFFD23C8F)), 'Инвестиция': CatMeta('invest', Color(0xFF169A55)), 'Несие төлемі': CatMeta('card', Color(0xFFB9750F)),
  'Аударымдар': CatMeta('swap', Color(0xFF6E7380)), 'Аударым': CatMeta('swap', Color(0xFF6E7380)), 'Басқа': CatMeta('other', Color(0xFF7C776E)),
  'Жалақы': CatMeta('salary', Color(0xFF169A55)), 'Бизнес': CatMeta('biz', Color(0xFF0A8FB0)), 'Фриланс': CatMeta('laptop', Color(0xFF7B47E0)),
  'Кэшбэк': CatMeta('coin', Color(0xFFC08A06)), 'Несие алу': CatMeta('card', Color(0xFFB9750F)),
};
CatMeta catMeta(String? c) => kCatMeta[c] ?? const CatMeta('other', Color(0xFF7C776E));

// ================= БАНКТЕР =================
class Bank {
  final String name, short;
  final RegExp re;
  final Color bg, fg;
  final String? logo;
  const Bank(this.name, this.re, this.short, this.bg, this.fg, this.logo);
}

final List<Bank> kBanks = [
  Bank('Kaspi Bank', RegExp(r'kaspi|каспи|каспий', caseSensitive: false), 'K', const Color(0xFFF14635), const Color(0xFFFFFFFF), 'kaspi'),
  Bank('Halyk Bank', RegExp(r'halyk|халык|халық|народный', caseSensitive: false), 'H', const Color(0xFF00815F), const Color(0xFFF1A400), 'halyk'),
  Bank('Freedom SuperApp', RegExp(r'freedom|фридом|ffin', caseSensitive: false), 'F', const Color(0xFF02B140), const Color(0xFFFFFFFF), 'freedom'),
  Bank('Jusan Bank', RegExp(r'jusan|жусан', caseSensitive: false), 'J', const Color(0xFFFF5A00), const Color(0xFFFFFFFF), 'jusan'),
  Bank('ForteBank', RegExp(r'forte|форте', caseSensitive: false), 'Fo', const Color(0xFF00B4C5), const Color(0xFFFFFFFF), 'forte'),
  Bank('Bereke Bank', RegExp(r'bereke|береке', caseSensitive: false), 'B', const Color(0xFF023DFF), const Color(0xFFFFFFFF), 'bereke'),
  Bank('Bank CenterCredit', RegExp(r'centercredit|центркредит|\bbcc\b|бцк', caseSensitive: false), 'BCC', const Color(0xFF00AB75), const Color(0xFFFFFFFF), 'bcc'),
  Bank('Otbasy Bank', RegExp(r'otbasy|отбасы|жилстрой', caseSensitive: false), 'O', const Color(0xFF00A3A3), const Color(0xFFFFFFFF), 'otbasy'),
  Bank('Home Credit Bank', RegExp(r'home ?credit|хоум ?кредит', caseSensitive: false), 'HC', const Color(0xFFE31E3A), const Color(0xFFFFFFFF), 'homecredit'),
  Bank('Qazaq Bank', RegExp(r'qazaq|назарбанк', caseSensitive: false), 'Q', const Color(0xFF2F6FB8), const Color(0xFFFFFFFF), 'qazaq'),
  Bank('Қолма-қол', RegExp(r'^қолма-қол|^наличн|^cash', caseSensitive: false), '●', const Color(0xFF141412), const Color(0xFFD2F45C), null),
];

Bank? bankOf(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final b in kBanks) {
    if (b.re.hasMatch(name)) return b;
  }
  return null;
}
