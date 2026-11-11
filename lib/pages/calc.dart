import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/pro.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'paywall.dart';
import 'shell.dart';

const kCalcs = [
  ['loan', 'card', 'Несие', 'Ай төлем · артық төлем · кесте'],
  ['dep', 'bank', 'Депозит', 'Капитализация · толықтыру'],
  ['inv', 'invest', 'Инвестиция', 'Күрделі пайыз · мақсатқа жету'],
  ['split', 'split', 'Жалақы бөлу', 'Айлықты пайызбен бөлу'],
  ['payoff', 'card', 'Несиелерді жабу', 'Қайсысын бірінші жабу тиімді'],
  ['tax', 'percent', 'ЖК салығы', 'Оңайлатылған декларация · 910'],
];

/// Есептегіш мәндері (сессия ішінде сақталады)
final Map<String, Map<String, dynamic>> calcIn = {
  'loan': {'amt': 2000000.0, 'rate': 24.0, 'months': 24.0, 'type': 'ann', 'extra': 0.0},
  'dep': {'amt': 1000000.0, 'rate': 14.0, 'months': 12.0, 'top': 0.0, 'cap': true},
  'inv': {'amt': 500000.0, 'month': 50000.0, 'rate': 12.0, 'years': 10.0, 're': true, 'usd': false, 'goal': 0.0},
  'tax': {'income': 3000000.0, 'rate': 4.0, 'months': 6.0, 'mzp': 85000.0, 'declared': 85000.0},
  'payoff': {'extra': 20000.0},
};

class CalcListPage extends StatelessWidget {
  const CalcListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = Store.i;
    return SubPage([
      TopBar(t('Есептегіш'), sub: t('Қаржылық есептеулер')),
      QList([
        for (final c in kCalcs)
          if (c[0] != 'tax' || st.base == 'KZT')
            QRow(
              lead: IconBox(c[1]),
              title: t(c[2]),
              titleTrail: kProCalcs.contains(c[0]) && !Pro.i.isPro ? const ProTag() : null,
              sub: t(c[3]),
              trail: QIcon('right', color: p.mute),
              onTap: () => pushPage(context, (_) => CalcPage(c[0])),
            ),
      ]),
    ]);
  }
}

class CalcPage extends StatefulWidget {
  final String k;
  const CalcPage(this.k, {super.key});
  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  Map<String, dynamic> get c => calcIn[widget.k] ?? {};

  Widget numIn(String f, String label, [String? suffix]) => Field(
        '${t(label)}${suffix != null && suffix.isNotEmpty ? ', $suffix' : ''}',
        QInput(
          initial: n(c[f]) == 0 ? '' : nf(n(c[f]), true).replaceAll(thin, ''),
          hint: '0',
          number: true,
          onChanged: (v) => setState(() => c[f] = parseNum(v)),
        ),
      );

  Widget seg(String f, List<List<dynamic>> opts) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: QSeg(
          items: [for (final o in opts) ['${o[0]}', t('${o[1]}')]],
          value: '${c[f]}',
          onChanged: (v) => setState(() {
            final o = opts.firstWhere((x) => '${x[0]}' == v);
            c[f] = o[0];
          }),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final meta = kCalcs.firstWhere((x) => x[0] == widget.k);
    if (kProCalcs.contains(widget.k) && !Pro.i.isPro) {
      return SubPage([TopBar(t(meta[2]), sub: t(meta[3])), LockedCard(meta[2])]);
    }
    final st = Store.i;
    final sym = st.sym;
    List<Widget> form;
    List<Widget> out;
    switch (widget.k) {
      case 'loan':
        form = [
          seg('type', [['ann', 'Аннуитет'], ['diff', 'Дифференциал']]),
          numIn('amt', 'Несие сомасы', sym),
          Row(children: [Expanded(child: numIn('rate', 'Жылдық мөлшерлеме', '%')), const SizedBox(width: 10), Expanded(child: numIn('months', 'Мерзімі', t('ай')))]),
          numIn('extra', 'Айына қосымша төлем (ерте өтеу)', sym),
        ];
        out = _loan();
      case 'dep':
        form = [
          numIn('amt', 'Салым сомасы', sym),
          Row(children: [Expanded(child: numIn('rate', 'Жылдық мөлшерлеме', '%')), const SizedBox(width: 10), Expanded(child: numIn('months', 'Мерзімі', t('ай')))]),
          numIn('top', 'Ай сайын толықтыру', sym),
          seg('cap', [[true, 'Капитализациямен'], [false, 'Капитализациясыз']]),
        ];
        out = _dep();
      case 'inv':
        form = [
          if (st.base != 'USD') seg('usd', [[false, '$sym ${st.base}'], [true, '\$ USD']]),
          Row(children: [Expanded(child: numIn('amt', 'Бастапқы сома')), const SizedBox(width: 10), Expanded(child: numIn('month', 'Ай сайын салу'))]),
          Row(children: [Expanded(child: numIn('rate', 'Жылдық табыс', '%')), const SizedBox(width: 10), Expanded(child: numIn('years', 'Мерзімі', t('жыл')))]),
          numIn('goal', 'Мақсатты сома (міндетті емес)'),
          seg('re', [[true, 'Реинвестиция'], [false, 'Табысты алу']]),
        ];
        out = _inv();
      case 'tax':
        form = [
          numIn('income', 'Кезеңдегі табыс', '₸'),
          Row(children: [Expanded(child: numIn('rate', 'Салық мөлшерлемесі', '%')), const SizedBox(width: 10), Expanded(child: numIn('months', 'Ай саны'))]),
          Row(children: [Expanded(child: numIn('declared', 'Өзіңізге айлық табыс', '₸')), const SizedBox(width: 10), Expanded(child: numIn('mzp', 'ЕТЖ (МЗП)', '₸'))]),
          _note(t('2026 ж. базалық мөлшерлеме — 4%, маслихат оны өзгерте алады. Өз өңіріңіздің мөлшерлемесін тексеріңіз.')),
        ];
        out = _tax();
      case 'payoff':
        final ls = st.accsOf('debt').where((a) => n(a['bal']) > 0).toList();
        final miss = ls.where((a) => !(n(a['pay']) > 0)).toList();
        form = ls.isEmpty
            ? [_note(t('Несие жоқ — тамаша.'))]
            : [
                numIn('extra', 'Айына қосымша сала аласыз', sym),
                if (miss.isNotEmpty) _note('${t('Айлық төлемі жазылмаған несиелер есепке кірмейді')}: ${miss.map((a) => s(a['name'])).join(', ')}'),
              ];
        out = ls.isEmpty ? [] : _payoff();
      case 'split':
        return SplitPage(meta: meta);
      default:
        form = [];
        out = [];
    }
    return SubPage([
      TopBar(t(meta[2]), sub: t(meta[3])),
      QCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: form)),
      ...out,
    ]);
  }

  Widget _note(String txt) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
        child: Text(txt, style: TextStyle(color: context.pal.mute, fontSize: 12.5)),
      );

  Widget _result(String label, String big, List<List<String>> cells, {List<Color?>? colors}) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t(label), style: TextStyle(color: p.heroMute, fontSize: 13.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(big, style: TextStyle(color: p.heroInk, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: kNum)),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t(cells[i][0]), style: TextStyle(color: p.heroMute, fontSize: 12)),
                const SizedBox(height: 2),
                Text(cells[i][1],
                    maxLines: 2,
                    style: TextStyle(color: (colors != null && colors[i] != null) ? colors[i] : p.heroInk, fontWeight: FontWeight.w700, fontSize: 14, fontFeatures: kNum)),
              ]),
            ),
        ]),
      ]),
    );
  }

  Widget _table(String title, List<String> head, List<List<String>> rows) {
    final p = context.pal;
    TextStyle hs = TextStyle(color: p.mute, fontSize: 12.5, fontWeight: FontWeight.w600);
    const cs = TextStyle(fontSize: 13, fontFeatures: kNum);
    return QCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [for (final h in head) Expanded(child: Text(t(h), style: hs, textAlign: TextAlign.right))]),
        const SizedBox(height: 4),
        SizedBox(
          height: math.min(360, rows.length * 30.0 + 4),
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) => Container(
              height: 30,
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line.withValues(alpha: .6)))),
              child: Row(children: [for (final c in rows[i]) Expanded(child: Text(c, style: cs, textAlign: TextAlign.right))]),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------- несие ----------
  List<List<double>> _sched(double amt, double rate, double months, String type, double extra) {
    final P = amt, i = rate / 1200;
    final k = math.max(1, months.round());
    final ann = i > 0 ? P * i / (1 - math.pow(1 + i, -k)) : P / k;
    final rows = <List<double>>[];
    var bal = P;
    for (var m = 1; m <= 600 && bal > .5; m++) {
      final it = bal * i;
      double princ, pay;
      if (type == 'ann') {
        pay = ann + extra;
        princ = pay - it;
      } else {
        princ = P / k + extra;
        pay = princ + it;
      }
      if (princ > bal) {
        princ = bal;
        pay = princ + it;
      }
      bal -= princ;
      rows.add([m.toDouble(), pay, it, princ, math.max(0, bal)]);
      if (type == 'ann' && pay <= it) break;
    }
    return rows;
  }

  List<Widget> _loan() {
    final st = Store.i;
    final amt = n(c['amt']), months = n(c['months']), extra = n(c['extra']);
    if (amt <= 0 || months <= 0) return [];
    final rows = _sched(amt, n(c['rate']), months, s(c['type']), extra);
    final base = _sched(amt, n(c['rate']), months, s(c['type']), 0);
    double tot = 0, ints = 0, bInt = 0;
    for (final r in rows) {
      tot += r[1];
      ints += r[2];
    }
    for (final r in base) {
      bInt += r[2];
    }
    final first = rows.isNotEmpty ? rows.first[1] : 0.0, last = rows.isNotEmpty ? rows.last[1] : 0.0;
    return [
      _result('Ай сайынғы төлем', c['type'] == 'ann' ? st.money(first) : '${st.money(first)} → ${st.moneyShort(last)}',
          [['Артық төлем', st.moneyShort(ints)], ['Барлығы', st.moneyShort(tot)], ['Мерзім', '${rows.length} ${t('ай')}']]),
      if (extra > 0)
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Ерте өтеу әсері'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${base.length - rows.length} ${t('ай ерте жабылады')} · ${t('пайыз үнемі')} ${st.money(bInt - ints)}', style: TextStyle(color: context.pal.mute)),
          ]),
        ),
      _table('Төлем кестесі', ['Ай', 'Төлем', 'Пайыз', 'Қалдық'], [for (final r in rows) ['${r[0].round()}', nf(r[1]), nf(r[2]), nf(r[4])]]),
    ];
  }

  // ---------- депозит ----------
  List<Widget> _dep() {
    final st = Store.i;
    final amt = n(c['amt']), top = n(c['top']);
    if (amt <= 0 && top <= 0) return [];
    final i = n(c['rate']) / 1200;
    final k = n(c['months']).round();
    var bal = amt, paidOut = 0.0, put = amt;
    for (var m = 1; m <= k; m++) {
      final it = bal * i;
      if (c['cap'] == true) {
        bal += it;
      } else {
        paidOut += it;
      }
      if (m < k && top > 0) {
        bal += top;
        put += top;
      }
    }
    final fin = bal + paidOut, inc = fin - put;
    return [
      _result('Мерзім соңында', st.money(fin), [['Салғаныңыз', st.moneyShort(put)], ['Табыс', '+${st.moneyShort(inc)}'], ['Айына орташа', st.moneyShort(inc / math.max(1, k))]],
          colors: [null, Pal.light.lime, null]),
      _note(t('Есеп шамамен: салық пен банк шарттары ескерілмеген.')),
    ];
  }

  // ---------- инвестиция ----------
  List<Widget> _inv() {
    final st = Store.i;
    final sy = c['usd'] == true ? '\$' : st.sym;
    final i = n(c['rate']) / 1200;
    final goal = n(c['goal']), month = n(c['month']);
    var bal = n(c['amt']), put = n(c['amt']), taken = 0.0;
    var goalM = 0;
    final years = <List<double>>[];
    final total = (n(c['years']) * 12).round();
    for (var m = 1; m <= total; m++) {
      final it = bal * i;
      if (c['re'] == true) {
        bal += it;
      } else {
        taken += it;
      }
      bal += month;
      put += month;
      if (goal > 0 && goalM == 0 && bal + taken >= goal) goalM = m;
      if (m % 12 == 0) years.add([m / 12, put, bal + taken]);
    }
    if (goal > 0 && goalM == 0) {
      var b2 = bal;
      var m2 = total;
      while (b2 < goal && m2 < 1200) {
        b2 = b2 * (1 + i) + month;
        m2++;
      }
      if (b2 >= goal) goalM = m2;
    }
    final fin = bal + taken, prof = fin - put;
    return [
      _result('Мерзім соңында', st.money(fin, sy),
          [['Салғаныңыз', st.moneyShort(put, sy)], ['Табыс', '+${st.moneyShort(prof, sy)}'], ['Өсім', put > 0 ? '×${(fin / put).toStringAsFixed(2).replaceAll('.', ',')}' : '—']],
          colors: [null, Pal.light.lime, null]),
      if (goal > 0)
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Мақсатқа жету'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(goalM > 0 ? '${goalM ~/ 12} ${t('жыл')} ${goalM % 12} ${t('ай')}' : t('100 жылда да жетпейді'), style: TextStyle(color: context.pal.mute)),
          ]),
        ),
      if (years.isNotEmpty) _table('Жыл сайын', ['Жыл', 'Салынды', 'Барлығы'], [for (final y in years) ['${y[0].round()}', nf(y[1]), nf(y[2])]]),
    ];
  }

  // ---------- ЖК салығы ----------
  List<Widget> _tax() {
    final st = Store.i;
    final income = n(c['income']);
    if (income <= 0) return [];
    final mzp = n(c['mzp']) > 0 ? n(c['mzp']) : 85000.0;
    final dec = math.max(n(c['declared']) > 0 ? n(c['declared']) : mzp, mzp);
    final m = n(c['months']).round() > 0 ? n(c['months']).round() : 6;
    final ipn = income * n(c['rate']) / 100, opv = dec * .10 * m, so = dec * .05 * m, vosms = 1.4 * mzp * .05 * m;
    final sum = ipn + opv + so + vosms;
    return [
      _result('Барлығы төлеу керек', st.money(sum), [['Табыс салығы', st.moneyShort(ipn)], ['Әлеуметтік', st.moneyShort(opv + so + vosms)], ['Қолда қалады', st.moneyShort(income - sum)]]),
      QCard(
        child: Column(children: [
          Kv('${t('Табыс салығы')} (${nf(n(c['rate']), true)}%)', st.money(ipn)),
          Kv(t('ОПВ · 10%'), st.money(opv)),
          Kv(t('СО · 5%'), st.money(so)),
          Kv(t('ВОСМС · 5% × 1,4 ЕТЖ'), st.money(vosms)),
        ]),
      ),
      _note(t('Есеп шамамен. Нақты сомасын КГД немесе бухгалтермен тексеріңіз.')),
    ];
  }

  // ---------- несиелерді жабу ----------
  _Sim? _sim(String order, double extra) {
    final L = Store.i
        .accsOf('debt')
        .where((a) => n(a['bal']) > 0 && n(a['pay']) > 0)
        .map((a) => _Loan(s(a['name']), n(a['bal']), n(a['rate']) / 1200, n(a['pay'])))
        .toList();
    if (L.isEmpty) return null;
    if (order == 'aval') {
      L.sort((a, b) => b.r != a.r ? b.r.compareTo(a.r) : a.bal.compareTo(b.bal));
    } else if (order == 'snow') {
      L.sort((a, b) => a.bal != b.bal ? a.bal.compareTo(b.bal) : b.r.compareTo(a.r));
    }
    if (order == 'none' && L.any((l) => l.pay <= l.bal * l.r)) return _Sim(-1, 0, L);
    var m = 0;
    var interest = 0.0;
    final roll = order != 'none';
    while (L.any((l) => l.bal > .5) && m < 600) {
      m++;
      var pool = roll ? extra : 0.0;
      for (final l in L) {
        if (l.bal <= .5) {
          if (roll) pool += l.pay;
          continue;
        }
        final it = l.bal * l.r;
        interest += it;
        l.bal += it;
        final pp = math.min(l.pay, l.bal);
        l.bal -= pp;
        if (roll) pool += l.pay - pp;
        if (l.bal <= .5) {
          l.bal = 0;
          if (l.done == 0) l.done = m;
        }
      }
      if (roll) {
        for (final l in L) {
          if (l.bal <= .5 || pool <= 0) continue;
          final pp = math.min(pool, l.bal);
          l.bal -= pp;
          pool -= pp;
          if (l.bal <= .5) {
            l.bal = 0;
            if (l.done == 0) l.done = m;
          }
        }
      }
    }
    return _Sim(m, interest, L);
  }

  List<Widget> _payoff() {
    final st = Store.i;
    final extra = n(c['extra']);
    final base = _sim('none', 0), av = _sim('aval', extra), sn = _sim('snow', extra);
    if (base == null || av == null || sn == null) return [];
    final best = av.interest <= sn.interest ? av : sn;
    final order = List<_Loan>.from(best.L)..sort((a, b) => a.done.compareTo(b.done));
    return [
      _result('Барлық несие жабылады', best.m > 0 ? '${best.m} ${t('айда')}' : '—', [
        ['Үнемделетін пайыз', base.m > 0 ? st.moneyShort(math.max(0, base.interest - best.interest)) : '—'],
        ['Ерте жабылады', base.m > 0 ? '${base.m - best.m} ${t('ай')}' : '—'],
        ['Бірінші жабыңыз', order.first.name],
      ]),
      if ((av.interest - sn.interest).abs() < 1) _note(t('Сіздің несиелеріңізде екі тәсіл бірдей нәтиже береді.')),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Екі тәсілді салыстыру'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Kv('${t('Қымбатынан бастау')} · ${t('пайызы жоғары')}', '${av.m} ${t('ай')} · ${st.moneyShort(av.interest)}'),
          Kv('${t('Кішісінен бастау')} · ${t('қалдығы аз')}', '${sn.m} ${t('ай')} · ${st.moneyShort(sn.interest)}'),
          Kv(t('Қосымшасыз'), base.m > 0 ? '${base.m} ${t('ай')} · ${st.moneyShort(base.interest)}' : t('айлық төлем пайызды жаппайды')),
        ]),
      ),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Жабу реті'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          for (var i = 0; i < order.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${(order[i].r * 1200).toStringAsFixed(1).replaceAll('.', ',')}% · ${t('айына')} ${st.moneyShort(order[i].pay)}',
                        style: TextStyle(color: context.pal.mute, fontSize: 13)),
                  ]),
                ),
                Text('${order[i].done} ${t('айда')}', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kNum)),
              ]),
            ),
          _note(t('Бір несие жабылғанда, оның айлық төлемі келесісіне қосылады.')),
        ]),
      ),
    ];
  }
}

class _Loan {
  final String name;
  double bal;
  final double r, pay;
  int done = 0;
  _Loan(this.name, this.bal, this.r, this.pay);
}

class _Sim {
  final int m;
  final double interest;
  final List<_Loan> L;
  _Sim(this.m, this.interest, this.L);
}

// ======================= ЖАЛАҚЫ БӨЛУ =======================

const _splitDef = [['Қажеттілік', 50], ['Инвестиция', 20], ['Жинақ', 20], ['Өзіме', 10]];
const _splitCol = [Color(0xFF141412), Color(0xFF169A55), Color(0xFFC08A06), Color(0xFF8B5CF6), Color(0xFFE2474C), Color(0xFF0A8FB0), Color(0xFFE07A2F), Color(0xFF7C776E)];

class SplitPage extends StatefulWidget {
  final List<String> meta;
  const SplitPage({super.key, required this.meta});
  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  double sum = 0;
  late List<Map<String, dynamic>> items;
  Timer? _tm;

  @override
  void initState() {
    super.initState();
    final sp = Store.i.db['split'];
    final m = sp is Map ? sp : const {};
    sum = n(m['sum']);
    final its = m['items'] is List && (m['items'] as List).isNotEmpty ? (m['items'] as List).whereType<Map>().toList() : null;
    items = its != null
        ? [for (final x in its) {'name': t(s(x['name'])), 'pct': n(x['pct']), 'to': s(x['to'])}]
        : [for (final x in _splitDef) {'name': t('${x[0]}'), 'pct': (x[1] as int).toDouble(), 'to': ''}];
  }

  void _save() {
    _tm?.cancel();
    _tm = Timer(const Duration(milliseconds: 400), () {
      final st = Store.i;
      final old = st.db['split'];
      st.db['split'] = {
        'sum': sum,
        'src': old is Map ? old['src'] : null,
        'applied': old is Map ? old['applied'] : null,
        'items': [for (final x in items) {'name': x['name'], 'pct': x['pct'], 'to': x['to']}],
      };
      st.save();
    });
  }

  @override
  void dispose() {
    _tm?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final tot = items.fold<double>(0, (a, b) => a + n(b['pct']));
    final ok = tot.round() == 100;
    return SubPage([
      TopBar(t(widget.meta[2]), sub: t(widget.meta[3])),
      QCard(
        child: Field(
          '${t('Айлық сомасы')}, ${st.sym}',
          QInput(
            initial: sum > 0 ? '${sum.round()}' : '',
            hint: '0',
            number: true,
            onChanged: (v) => setState(() {
              sum = parseNum(v);
              _save();
            }),
          ),
        ),
      ),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(t('Бөлімдер'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text('${tot.round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: ok ? p.pos : p.neg)),
          ]),
          for (var i = 0; i < items.length; i++)
            Padding(
              key: ObjectKey(items[i]),
              padding: const EdgeInsets.only(top: 12),
              child: Column(children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _splitCol[i % _splitCol.length], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: s(items[i]['name']),
                      decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      onChanged: (v) {
                        items[i]['name'] = v;
                        _save();
                      },
                    ),
                  ),
                  Text(st.money(sum * n(items[i]['pct']) / 100), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kNum)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: QIcon('x', size: 16, color: p.mute),
                    onPressed: () => setState(() {
                      items.removeAt(i);
                      _save();
                    }),
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: Slider(
                      value: n(items[i]['pct']).clamp(0, 100).toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      activeColor: _splitCol[i % _splitCol.length],
                      onChanged: (v) => setState(() {
                        items[i]['pct'] = v.roundToDouble();
                        _save();
                      }),
                    ),
                  ),
                  SizedBox(width: 48, child: Text('${n(items[i]['pct']).round()}%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: QBtn(t('Бөлім қосу'), icon: 'plus', kind: BtnKind.line, small: true, onTap: () => setState(() {
                    items.add({'name': t('Жаңа бөлім'), 'pct': 0.0, 'to': ''});
                    _save();
                  })),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QBtn(t('Әдепкі 50/20/20/10'), kind: BtnKind.line, small: true, onTap: () => setState(() {
                    items = [for (final x in _splitDef) {'name': t('${x[0]}'), 'pct': (x[1] as int).toDouble(), 'to': ''}];
                    _save();
                  })),
            ),
          ]),
        ]),
      ),
      if (sum > 0)
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  for (var i = 0; i < items.length; i++)
                    if (n(items[i]['pct']) > 0) Expanded(flex: (n(items[i]['pct']) * 10).round(), child: Container(color: _splitCol[i % _splitCol.length])),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Text(ok ? t('Барлығы 100% — жоспар дайын.') : t('Пайыздардың жиыны 100% болуы керек.'), style: TextStyle(color: p.mute, fontSize: 13)),
          ]),
        ),
    ]);
  }
}
