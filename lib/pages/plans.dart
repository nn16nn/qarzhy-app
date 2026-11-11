import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'shell.dart';

// ======================= МАҚСАТТАР =======================

class GoalPace {
  final double left, need;
  final int days;
  final bool late;
  GoalPace(this.left, this.need, this.days, this.late);
}

GoalPace goalPace(J g) {
  final left = math.max(0.0, n(g['target']) - n(g['saved']));
  final due = s(g['due']);
  if (due.isEmpty) return GoalPace(left, 0, 0, false);
  final days = parseISO(due).difference(parseISO(todayISO())).inDays;
  final months = math.max(0.0, days / 30.44);
  return GoalPace(left, months > .1 && left > 0 ? left / months : left, days, days < 0 && left > 0);
}

J? goalOf(String id) {
  for (final g in Store.i.goals) {
    if (g['id'] == id) return g;
  }
  return null;
}

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    double sv = 0, tg = 0;
    for (final g in st.goals) {
      sv += n(g['saved']);
      tg += n(g['target']);
    }
    return SubPage([
      TopBar(t('Мақсаттар'),
          sub: st.goals.length > 1 ? '${t('Барлығы')} ${st.moneyShort(sv)} / ${st.moneyShort(tg)}' : null, right: RoundBtn('plus', onTap: () => openGoal(context))),
      if (st.goals.isEmpty) ...[
        Empty('target', '${t('Мақсат әлі жоқ.')}\n${t('Жинайтын сомаңызды белгілеп қойыңыз.')}'),
        QBtn(t('Мақсат қосу'), onTap: () => openGoal(context)),
      ],
      for (final g in st.goals)
        Builder(builder: (_) {
          final target = n(g['target']);
          final pct = target > 0 ? math.min(1.0, n(g['saved']) / target) : 0.0;
          final pc = goalPace(g);
          final due = s(g['due']);
          return QCard(
            onTap: () => viewGoal(context, s(g['id'])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(s(g['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: kNum)),
              ]),
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: [
                TextSpan(text: st.money(n(g['saved'])), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6, fontFeatures: kNum)),
                TextSpan(text: '  / ${st.moneyShort(target)}', style: TextStyle(color: p.mute, fontSize: 14)),
              ])),
              const SizedBox(height: 10),
              QProg(pct, color: pct >= 1 ? p.pos : null),
              if (due.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    pct >= 1 ? '${t('Орындалды')} ✓' : pc.late ? t('Мерзімі өтті') : '${fullDate(due)} · ${t('айына')} ${st.money(pc.need)}',
                    style: TextStyle(color: pc.late && pct < 1 ? p.neg : p.mute, fontSize: 12.5),
                  ),
                ),
            ]),
          );
        }),
    ]);
  }
}

Future<String?> pickDate(BuildContext context, String? cur) async {
  final d = await showDatePicker(
    context: context,
    initialDate: cur != null && cur.isNotEmpty ? parseISO(cur) : DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return d == null ? null : iso(d);
}

class DateField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool clearable;
  const DateField({super.key, required this.value, required this.onChanged, this.clearable = true});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.sf2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await pickDate(context, value);
          if (d != null) onChanged(d);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Text(value != null && value!.isNotEmpty ? fullDate(value) : '—',
                  style: TextStyle(fontSize: 16, color: value != null && value!.isNotEmpty ? p.ink : p.mute)),
            ),
            if (clearable && value != null && value!.isNotEmpty)
              GestureDetector(onTap: () => onChanged(null), child: QIcon('x', size: 18, color: p.mute))
            else
              QIcon('cal', size: 18, color: p.mute),
          ]),
        ),
      ),
    );
  }
}

/// Шот таңдау (тізім түрінде)
class AccPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  const AccPicker({super.key, required this.value, required this.onChanged, this.allowNone = true});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    return Wrap(children: [
      if (allowNone) QChip(t('Шотсыз — тек белгілеу'), on: value == null || value!.isEmpty, onTap: () => onChanged(null)),
      for (final a in st.assets) QChip(s(a['name']), sub: st.moneyShort(n(a['bal']), st.curSym(a)), on: value == a['id'], onTap: () => onChanged(s(a['id']))),
    ]);
  }
}

void openGoal(BuildContext context, {String? id}) {
  final st = Store.i;
  final g = id != null ? goalOf(id) : null;
  final f = <String, dynamic>{
    'name': g?['name'] ?? '',
    'target': g != null ? '${n(g['target']).round()}' : '',
    'saved': g != null ? '${n(g['saved']).round()}' : '',
    'due': g?['due'],
  };
  openSheet(context, title: g != null ? t('Мақсатты өзгерту') : t('Жаңа мақсат'), builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(t('Атауы'), QInput(initial: s(f['name']), hint: t('Мысалы, Көлік'), onChanged: (v) => f['name'] = v)),
      Row(children: [
        Expanded(child: Field(t('Мақсат сомасы'), QInput(initial: s(f['target']), number: true, onChanged: (v) => f['target'] = v))),
        const SizedBox(width: 10),
        Expanded(child: Field(t('Жиналған'), QInput(initial: s(f['saved']), number: true, onChanged: (v) => f['saved'] = v))),
      ]),
      Field(t('Мерзімі (міндетті емес)'), DateField(value: f['due'] as String?, onChanged: (v) => set(() => f['due'] = v))),
      const SizedBox(height: 8),
      QBtn(t('Сақтау'), icon: 'check', onTap: () {
        if (s(f['name']).trim().isEmpty) {
          toast('Атауын жазыңыз');
          return;
        }
        if (parseNum(s(f['target'])) <= 0) {
          toast('Мақсат сомасын жазыңыз');
          return;
        }
        final x = g ?? <String, dynamic>{'id': newId(), 'hist': <dynamic>[]};
        x['name'] = s(f['name']).trim();
        x['target'] = parseNum(s(f['target']));
        x['saved'] = parseNum(s(f['saved']));
        x['due'] = f['due'];
        if (g == null) st.goals.add(x);
        st.save();
        Navigator.pop(ctx);
        toast(g != null ? 'Сақталды' : 'Мақсат қосылды');
      }),
    ]);
  });
}

void viewGoal(BuildContext context, String id) {
  final st = Store.i;
  String amt = '';
  String? accId = s(st.pref['goalAcc']).isEmpty ? null : s(st.pref['goalAcc']);
  openSheet(context, title: s(goalOf(id)?['name']), builder: (ctx, set) {
    final p = ctx.pal;
    final g = goalOf(id);
    if (g == null) return const SizedBox();
    final target = n(g['target']);
    final pct = target > 0 ? math.min(1.0, n(g['saved']) / target) : 0.0;
    final pc = goalPace(g);
    final hist = (g['hist'] is List ? (g['hist'] as List) : const []).whereType<Map>().toList().reversed.take(12).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(st.money(n(g['saved'])), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: kNum)),
      const SizedBox(height: 8),
      QProg(pct),
      Kv(t('Мақсат'), st.money(target)),
      Kv(t('Қалды'), st.money(pc.left)),
      if (s(g['due']).isNotEmpty) ...[Kv(t('Мерзімі'), fullDate(s(g['due']))), Kv(t('Айына салу керек'), st.money(pc.need))],
      QCard(
        color: p.sf2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Салым қосу'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: '0 ${st.sym}', fillColor: p.sf),
            onChanged: (v) => amt = v,
          ),
          const SizedBox(height: 10),
          AccPicker(value: accId, onChanged: (v) => set(() => accId = v)),
          QBtn(t('Қосу'), icon: 'plus', kind: BtnKind.lime, onTap: () {
            final v = parseNum(amt);
            if (v <= 0) {
              toast('Соманы жазыңыз');
              return;
            }
            final a = st.acc(accId);
            if (a != null) a['bal'] = n(a['bal']) - st.toAcc(a, v);
            g['saved'] = n(g['saved']) + v;
            (g['hist'] is List ? g['hist'] as List : (g['hist'] = <dynamic>[])).add({'date': todayISO(), 'acc': accId, 'amt': v});
            st.pref['goalAcc'] = accId;
            st.save();
            Navigator.pop(ctx);
            toast(n(g['saved']) >= target ? 'Мақсат орындалды!' : 'Салым қосылды');
          }),
        ]),
      ),
      if (hist.isNotEmpty) ...[
        SecHead(t('Салым тарихы')),
        for (final x in hist)
          Kv('${fullDate(s(x['date']))}${st.acc(x['acc']) != null ? ' · ${s(st.acc(x['acc'])!['name'])}' : ''}', '${n(x['amt']) < 0 ? '' : '+'}${st.money(n(x['amt']))}'),
      ],
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: QBtn(t('Түзету'), icon: 'edit', kind: BtnKind.line, onTap: () {
            Navigator.pop(ctx);
            openGoal(context, id: id);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: QBtn(t('Өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
            if (!await ask(ctx, 'Мақсат өшіріледі. Жалғастырасыз ба?', ok: 'Өшіру')) return;
            st.goals = st.goals.where((x) => x['id'] != id).toList();
            st.save();
            if (ctx.mounted) Navigator.pop(ctx);
            toast('Өшірілді');
          }),
        ),
      ]),
    ]);
  });
}

// ======================= ҚАРЫЗДАР =======================

final debtDirNotifier = ValueNotifier<String>('out');

J? debtOf(String id) {
  for (final d in Store.i.debts) {
    if (d['id'] == id) return d;
  }
  return null;
}

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: debtDirNotifier,
      builder: (ctx, dir, _) {
        final st = Store.i;
        final p = ctx.pal;
        final T = st.debtTotals();
        final td = todayISO();
        final list = st.debts.where((d) => d['dir'] == dir).toList()
          ..sort((a, b) {
            final c = st.debtLeft(b).compareTo(st.debtLeft(a));
            return c != 0 ? c : s(b['date']).compareTo(s(a['date']));
          });
        Widget mini(String label, double v) => Expanded(
              child: QCard(
                margin: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(color: p.mute, fontSize: 13)),
                  Text(st.moneyShort(v), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: v < 0 ? p.neg : p.ink, fontFeatures: kNum)),
                ]),
              ),
            );
        return SubPage([
          TopBar(t('Қарыздар'), right: RoundBtn('plus', onTap: () => openDebt(ctx))),
          const SizedBox(height: 8),
          Row(children: [mini(t('Маған қарыз'), T.lent), const SizedBox(width: 10), mini(t('Менің қарызым'), -T.owed)]),
          const SizedBox(height: 14),
          QSeg(items: [['out', t('Мен бердім')], ['in', t('Мен алдым')]], value: dir, onChanged: (v) => debtDirNotifier.value = v),
          if (list.isEmpty)
            Empty('people', t('Жазба жоқ.'))
          else
            QList([
              for (final d in list)
                Builder(builder: (_) {
                  final l = st.debtLeft(d);
                  final amt = n(d['amt']);
                  final pct = amt > 0 ? math.min(1.0, n(d['paid']) / amt) : 0.0;
                  final due = s(d['due']);
                  final late = l > 0 && due.isNotEmpty && due.compareTo(td) < 0;
                  final who = s(d['who']).trim();
                  return QRow(
                    lead: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: p.sf2, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Text(who.isEmpty ? '?' : who.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    title: who,
                    sub: l <= 0
                        ? '${t('Жабылды')} ✓'
                        : late
                            ? '${t('Мерзімі өтті')} · ${fullDate(due)}'
                            : (due.isNotEmpty ? '${t('Мерзімі')} ${fullDate(due)}' : fullDate(s(d['date']))),
                    trail: SizedBox(
                      width: 110,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Amt(st.money(l), small: '/ ${st.moneyShort(amt)}', color: late ? p.neg : null),
                        const SizedBox(height: 4),
                        SizedBox(height: 4, child: QProg(pct, color: p.pos)),
                      ]),
                    ),
                    onTap: () => viewDebt(ctx, s(d['id'])),
                  );
                }),
            ]),
        ]);
      },
    );
  }
}

void openDebt(BuildContext context) {
  final st = Store.i;
  final f = <String, dynamic>{'dir': debtDirNotifier.value, 'who': '', 'amt': '', 'acc': null, 'date': todayISO(), 'due': null, 'note': ''};
  openSheet(context, title: t('Жаңа қарыз'), builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QSeg(items: [['out', t('Мен бердім')], ['in', t('Мен алдым')]], value: s(f['dir']), onChanged: (v) => set(() => f['dir'] = v)),
      Field(f['dir'] == 'out' ? t('Кімге') : t('Кімнен'), QInput(initial: s(f['who']), hint: t('Аты'), onChanged: (v) => f['who'] = v)),
      Field(t('Сома'), QInput(initial: s(f['amt']), hint: '0 ${st.sym}', number: true, onChanged: (v) => f['amt'] = v)),
      Field(t('Шот'), AccPicker(value: f['acc'] as String?, onChanged: (v) => set(() => f['acc'] = v))),
      Row(children: [
        Expanded(child: Field(t('Күні'), DateField(value: f['date'] as String?, clearable: false, onChanged: (v) => set(() => f['date'] = v ?? todayISO())))),
        const SizedBox(width: 10),
        Expanded(child: Field(t('Қайтару мерзімі'), DateField(value: f['due'] as String?, onChanged: (v) => set(() => f['due'] = v)))),
      ]),
      Field(t('Түсініктеме'), QInput(initial: '', onChanged: (v) => f['note'] = v)),
      const SizedBox(height: 8),
      QBtn(t('Сақтау'), icon: 'check', onTap: () {
        if (s(f['who']).trim().isEmpty) {
          toast('Кім екенін жазыңыз');
          return;
        }
        final amt = parseNum(s(f['amt']));
        if (amt <= 0) {
          toast('Соманы жазыңыз');
          return;
        }
        final d = <String, dynamic>{
          'id': newId(), 'dir': f['dir'], 'who': s(f['who']).trim(), 'amt': amt, 'paid': 0, 'date': f['date'] ?? todayISO(),
          'due': f['due'], 'note': s(f['note']).trim(), 'acc': f['acc'], 'hist': <dynamic>[],
        };
        final a = st.acc(d['acc']);
        if (a != null) a['bal'] = n(a['bal']) + st.toAcc(a, d['dir'] == 'out' ? -amt : amt);
        st.debts.add(d);
        debtDirNotifier.value = s(d['dir']);
        st.save();
        Navigator.pop(ctx);
        toast(d['dir'] == 'out' ? 'Қарызға берілді' : 'Қарыз алынды');
      }),
    ]);
  });
}

void viewDebt(BuildContext context, String id) {
  final st = Store.i;
  String amt = '';
  String? accId = s(debtOf(id)?['acc']).isEmpty ? null : s(debtOf(id)?['acc']);
  final amtCtl = TextEditingController();
  openSheet(context, title: s(debtOf(id)?['who']), builder: (ctx, set) {
    final p = ctx.pal;
    final d = debtOf(id);
    if (d == null) return const SizedBox();
    final l = st.debtLeft(d);
    final a = st.acc(d['acc']);
    final out = d['dir'] == 'out';
    final hist = (d['hist'] is List ? d['hist'] as List : const []).whereType<Map>().toList().reversed.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(st.money(l), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: kNum)),
      Text(out ? t('маған қайтаруы керек') : t('мен қайтаруым керек'), style: TextStyle(color: p.mute)),
      const SizedBox(height: 6),
      Kv(out ? t('Бердім') : t('Алдым'), st.money(n(d['amt']))),
      Kv(t('Қайтарылды'), st.money(n(d['paid']))),
      Kv(t('Күні'), fullDate(s(d['date']))),
      if (s(d['due']).isNotEmpty) Kv(t('Қайтару мерзімі'), fullDate(s(d['due']))),
      if (a != null) Kv(t('Шот'), s(a['name'])),
      if (s(d['note']).isNotEmpty) Kv(t('Түсініктеме'), s(d['note'])),
      if (l > 0)
        QCard(
          color: p.sf2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(out ? t('Маған қайтарған сома') : t('Мен қайтарған сома'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: '${nf(l)} ${st.sym}', fillColor: p.sf),
              onChanged: (v) => amt = v,
            ),
            const SizedBox(height: 10),
            AccPicker(value: accId, onChanged: (v) => set(() => accId = v)),
            Row(children: [
              Expanded(
                child: QBtn(t('Толық'), kind: BtnKind.line, onTap: () {
                  amt = '${l.round()}';
                  amtCtl.text = amt;
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QBtn(t('Жазу'), icon: 'check', kind: BtnKind.lime, onTap: () {
                  var v = parseNum(amt);
                  if (v <= 0) {
                    toast('Соманы жазыңыз');
                    return;
                  }
                  v = math.min(v, l);
                  final pa = st.acc(accId);
                  if (pa != null) pa['bal'] = n(pa['bal']) + st.toAcc(pa, out ? v : -v);
                  d['paid'] = n(d['paid']) + v;
                  (d['hist'] is List ? d['hist'] as List : (d['hist'] = <dynamic>[])).add({'date': todayISO(), 'amt': v, 'acc': accId});
                  st.save();
                  Navigator.pop(ctx);
                  toast(st.debtLeft(d) <= 0 ? 'Толық жабылды' : 'Төлем жазылды');
                }),
              ),
            ]),
          ]),
        ),
      if (hist.isNotEmpty) ...[
        SecHead(t('Төлем тарихы')),
        for (final x in hist) Kv('${fullDate(s(x['date']))}${st.acc(x['acc']) != null ? ' · ${s(st.acc(x['acc'])!['name'])}' : ''}', st.money(n(x['amt']))),
      ],
      QBtn(t('Өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
        if (!await ask(ctx, 'Жазба өшіріледі, шот қалдықтары бастапқы күйге қайтарылады. Жалғастырасыз ба?', ok: 'Өшіру')) return;
        final a0 = st.acc(d['acc']);
        if (a0 != null) a0['bal'] = n(a0['bal']) + st.toAcc(a0, out ? n(d['amt']) : -n(d['amt']));
        for (final x in hist) {
          final pa = st.acc(x['acc']);
          if (pa != null) pa['bal'] = n(pa['bal']) + st.toAcc(pa, out ? -n(x['amt']) : n(x['amt']));
        }
        st.debts = st.debts.where((x) => x['id'] != id).toList();
        st.save();
        if (ctx.mounted) Navigator.pop(ctx);
        toast('Өшірілді');
      }),
    ]);
  });
}

// ======================= ТҰРАҚТЫ ТӨЛЕМДЕР =======================

class RecurPage extends StatelessWidget {
  const RecurPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final R = st.recurState();
    final key = ym(DateTime.now());
    final list = List<J>.from(st.recur)
      ..sort((a, b) {
        final pa = a['paid'] == key ? 1 : 0, pb = b['paid'] == key ? 1 : 0;
        return pa != pb ? pa - pb : n(a['day']).compareTo(n(b['day']));
      });
    Widget mini(String label, double v) => Expanded(
          child: QCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: p.mute, fontSize: 13)),
              Text(st.moneyShort(v), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFeatures: kNum)),
            ]),
          ),
        );
    return SubPage([
      TopBar(t('Тұрақты төлемдер'), sub: monName(DateTime.now().month - 1), right: RoundBtn('plus', onTap: () => openRecur(context))),
      const SizedBox(height: 8),
      Row(children: [mini(t('Айына'), R.total), const SizedBox(width: 10), mini(t('Төленбеген'), R.unpaid)]),
      if (st.recur.isEmpty) ...[
        Empty('repeat', t('Ай сайынғы төлемдерді (интернет, жалдау, жазылым) осында қосыңыз.')),
        QBtn(t('Төлем қосу'), onTap: () => openRecur(context)),
      ] else ...[
        QList([
          for (final x in list)
            QRow(
              lead: CatIcon(s(x['cat'])),
              title: s(x['name']),
              sub: '${t('Айдың')} ${n(x['day']).round()} ${t('күні')} · ${st.money(n(x['amt']))}',
              onTap: () => openRecur(context, id: s(x['id'])),
              trail: x['paid'] == key
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: p.pos, borderRadius: BorderRadius.circular(99)),
                      child: Text(t('Төленді'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    )
                  : QBtn(t('Төледім'), kind: BtnKind.lime, small: true, onTap: () => payRecur(s(x['id']))),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
          child: Text(t('«Төледім» басқанда шығын жазылады және шот қалдығы азаяды.'), style: TextStyle(color: p.mute, fontSize: 12.5)),
        ),
      ],
    ]);
  }
}

void payRecur(String id) {
  final st = Store.i;
  J? r;
  for (final x in st.recur) {
    if (x['id'] == id) r = x;
  }
  if (r == null) return;
  final a = st.acc(r['acc']) ?? (st.assets.isNotEmpty ? st.assets.first : null);
  if (a == null) {
    toast('Алдымен шот қосыңыз');
    return;
  }
  final x = <String, dynamic>{'id': newId(), 'type': 'out', 'cat': r['cat'], 'amt': n(r['amt']), 'date': todayISO(), 'note': r['name'], 'acc': a['id'], 'loan': null, 'to': null};
  st.txs.add(x);
  st.applyTx(x, 1);
  r['paid'] = ym(DateTime.now());
  st.save();
  tap();
  final rr = r;
  toast('Төлем жазылды', undo: () {
    st.txs = st.txs.where((y) => y['id'] != x['id']).toList();
    st.applyTx(x, -1);
    rr['paid'] = null;
    st.save();
  });
}

void openRecur(BuildContext context, {String? id}) {
  final st = Store.i;
  J? r;
  for (final x in st.recur) {
    if (x['id'] == id) r = x;
  }
  final f = <String, dynamic>{
    'name': r?['name'] ?? '',
    'amt': r != null ? '${n(r['amt']).round()}' : '',
    'day': r != null ? '${n(r['day']).round()}' : '',
    'cat': r?['cat'] ?? 'Байланыс',
    'acc': r?['acc'] ?? (st.assets.isNotEmpty ? st.assets.first['id'] : null),
  };
  openSheet(context, title: r != null ? t('Төлемді өзгерту') : t('Жаңа төлем'), builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(t('Атауы'), QInput(initial: s(f['name']), hint: t('Мысалы, Интернет'), onChanged: (v) => f['name'] = v)),
      Row(children: [
        Expanded(child: Field(t('Сома'), QInput(initial: s(f['amt']), number: true, onChanged: (v) => f['amt'] = v))),
        const SizedBox(width: 10),
        Expanded(child: Field(t('Айдың күні (1–31)'), QInput(initial: s(f['day']), number: true, onChanged: (v) => f['day'] = v))),
      ]),
      Field(t('Санат'), Wrap(children: [for (final c in kCats['out']!) QChip(t(c), on: f['cat'] == c, onTap: () => set(() => f['cat'] = c))])),
      Field(t('Шот'), AccPicker(value: f['acc'] as String?, allowNone: false, onChanged: (v) => set(() => f['acc'] = v))),
      const SizedBox(height: 8),
      QBtn(t('Сақтау'), icon: 'check', onTap: () {
        final amt = parseNum(s(f['amt']));
        final day = parseNum(s(f['day'])).round();
        if (s(f['name']).trim().isEmpty) {
          toast('Атауын жазыңыз');
          return;
        }
        if (amt <= 0) {
          toast('Соманы жазыңыз');
          return;
        }
        if (day < 1 || day > 31) {
          toast('Айдың қай күні екенін жазыңыз (1–31)');
          return;
        }
        var x = r;
        if (x == null) {
          x = <String, dynamic>{'id': newId(), 'paid': null};
          st.recur.add(x);
        }
        x['name'] = s(f['name']).trim();
        x['amt'] = amt;
        x['day'] = day;
        x['cat'] = f['cat'];
        x['acc'] = f['acc'];
        st.save();
        Navigator.pop(ctx);
        toast('Сақталды');
      }),
      if (r != null)
        QBtn(t('Өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
          if (!await ask(ctx, 'Төлем тізімнен өшіріледі. Бұрын жазылған операциялар қалады. Жалғастырасыз ба?', ok: 'Өшіру')) return;
          st.recur = st.recur.where((x) => x['id'] != id).toList();
          st.save();
          if (ctx.mounted) Navigator.pop(ctx);
          toast('Өшірілді');
        }),
    ]);
  });
}
