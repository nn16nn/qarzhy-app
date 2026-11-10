import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'accounts.dart';

/// Операция қосу / түзету парағы
Future<void> openTx(BuildContext context, {String? type, String? editId}) async {
  final st = Store.i;
  if (st.assets.isEmpty) {
    toast('Алдымен шот қосыңыз');
    openAccSheet(context, 'asset');
    return;
  }
  final x = editId != null ? st.txOf(editId) : null;
  final lastAcc = st.acc(st.pref['acc']) != null ? s(st.pref['acc']) : s(st.assets.first['id']);
  final f = <String, dynamic>{
    'id': x?['id'],
    'type': x?['type'] ?? type ?? 'out',
    'cat': x?['cat'],
    'acc': x?['acc'] ?? lastAcc,
    'to': x?['to'],
    'loan': x?['loan'],
    'amt': x != null ? nf(n(x['amtFrom']) > 0 ? n(x['amtFrom']) : n(x['amt']), true).replaceAll(thin, '') : '',
    'date': x?['date'] ?? todayISO(),
    'note': x?['note'] ?? '',
  };
  if (f['cat'] == null && f['type'] != 'tr') f['cat'] = st.pref['cat_${f['type']}'] ?? kCats[f['type']]![0];
  void pickTo() {
    final o = st.assets.where((a) => a['id'] != f['acc']).toList();
    f['to'] = o.isNotEmpty ? o.first['id'] : null;
  }

  if (f['type'] == 'tr' && f['to'] == null) pickTo();
  final amtCtl = TextEditingController(text: s(f['amt']));
  final noteCtl = TextEditingController(text: s(f['note']));

  await openSheet(
    context,
    title: x != null ? t('Өзгерту') : t('Жаңа операция'),
    builder: (ctx, set) {
      final p = ctx.pal;
      final type = s(f['type']);
      final cats = List<String>.from(kCats[type] ?? const <String>[]);
      if (f['cat'] != null && type != 'tr' && !cats.contains(f['cat'])) cats.add(s(f['cat']));

      Widget accChips(String field) => Wrap(children: [
            for (final a in st.assets)
              QChip(s(a['name']),
                  on: f[field] == a['id'], sub: st.moneyShort(n(a['bal']), st.curSym(a)), onTap: () => set(() => f[field] = a['id'])),
          ]);

      final days = <String>[for (var i = 5; i >= 0; i--) iso(DateTime.now().subtract(Duration(days: i)))];
      final custom = !days.contains(f['date']);

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        QSeg(
          items: [['out', t('Шығын')], ['in', t('Кіріс')], ['tr', t('Аударым')]],
          value: type,
          onChanged: (v) => set(() {
            f['type'] = v;
            if (v != 'tr') {
              if (!kCats[v]!.contains(f['cat'])) f['cat'] = st.pref['cat_$v'] ?? kCats[v]![0];
            } else if (f['to'] == null || f['to'] == f['acc']) {
              pickTo();
            }
          }),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          IntrinsicWidth(
            child: TextField(
              controller: amtCtl,
              autofocus: x == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1.5, color: p.ink, fontFeatures: kNum),
              decoration: InputDecoration(
                hintText: '0',
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintStyle: TextStyle(color: p.mute.withValues(alpha: .5)),
              ),
              onChanged: (v) => f['amt'] = v,
            ),
          ),
          const SizedBox(width: 6),
          Text(st.sym, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: p.mute)),
        ]),
        if (type != 'tr') ...[
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: .95,
            children: [
              for (final c in cats)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    tap();
                    set(() => f['cat'] = c);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: f['cat'] == c ? p.sf2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: f['cat'] == c ? p.ink : Colors.transparent, width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CatIcon(c, size: 38),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(t(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ],
        Field(type == 'tr' ? t('Қай шоттан') : t('Шот'), accChips('acc')),
        if (type == 'tr') Field(t('Қай шотқа'), accChips('to')),
        if (type == 'out' && f['cat'] == 'Несие төлемі' && st.accsOf('debt').isNotEmpty)
          Field(
            t('Қай несие өтеледі'),
            Wrap(children: [
              QChip(t('Белгілемеу'), on: f['loan'] == null, onTap: () => set(() => f['loan'] = null)),
              for (final l in st.accsOf('debt')) QChip(s(l['name']), on: f['loan'] == l['id'], onTap: () => set(() => f['loan'] = l['id'])),
            ]),
          ),
        Field(
          t('Күні'),
          Row(children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: _DayBtn(
                  label: i == 5 ? t('Бүгін') : i == 4 ? t('Кеше') : t(kWdShort[jsDay(parseISO(days[i]))]),
                  day: parseISO(days[i]).day,
                  on: f['date'] == days[i],
                  onTap: () => set(() => f['date'] = days[i]),
                ),
              ),
            if (custom)
              Expanded(
                child: _DayBtn(label: monShort(parseISO(s(f['date'])).month - 1), day: parseISO(s(f['date'])).day, on: true, onTap: () {}),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: parseISO(s(f['date'])),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) set(() => f['date'] = iso(d));
              },
              child: Padding(padding: const EdgeInsets.all(10), child: QIcon('cal', color: p.ink)),
            ),
          ]),
        ),
        Field(
          t('Түсініктеме'),
          TextField(
            controller: noteCtl,
            decoration: InputDecoration(hintText: t('Мысалы, Magnum')),
            onChanged: (v) {
              f['note'] = v;
              if (type == 'tr' || v.isEmpty) return;
              for (var i = st.txs.length - 1; i >= 0; i--) {
                final y = st.txs[i];
                if (y['type'] == type && s(y['note']).toLowerCase() == v.toLowerCase()) {
                  final c = s(y['cat']);
                  if (c != f['cat'] && kCats[type]!.contains(c)) set(() => f['cat'] = c);
                  break;
                }
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        QBtn(t('Сақтау'), icon: 'check', onTap: () {
          if (_saveTx(f)) Navigator.of(ctx).pop();
        }),
        if (x != null)
          QBtn(t('Өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
            Navigator.of(ctx).pop();
            await delTx(context, s(x['id']));
          }),
      ]);
    },
  );
}

class _DayBtn extends StatelessWidget {
  final String label;
  final int day;
  final bool on;
  final VoidCallback onTap;
  const _DayBtn({required this.label, required this.day, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: on ? p.ink : p.sf2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Text(label, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 11, color: on ? p.bg.withValues(alpha: .75) : p.mute)),
              Text('$day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on ? p.bg : p.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

bool _saveTx(Map<String, dynamic> f) {
  final st = Store.i;
  final amt = parseNum(s(f['amt']));
  if (amt <= 0) {
    toast('Соманы жазыңыз');
    return false;
  }
  final type = s(f['type']);
  if (type == 'tr') {
    if (f['to'] == null) {
      toast('Қай шотқа екенін таңдаңыз');
      return false;
    }
    if (f['to'] == f['acc']) {
      toast('Екі түрлі шот таңдаңыз');
      return false;
    }
  }
  final x = <String, dynamic>{
    'id': f['id'] ?? newId(),
    'type': type,
    'cat': type == 'tr' ? 'Аударым' : f['cat'],
    'amt': amt.abs(),
    'date': f['date'] ?? todayISO(),
    'note': s(f['note']).trim(),
    'acc': f['acc'],
    'loan': (type == 'out' && f['cat'] == 'Несие төлемі') ? f['loan'] : null,
    'to': type == 'tr' ? f['to'] : null,
  };
  if (f['id'] != null) {
    final old = st.txOf(s(f['id']));
    if (old != null) {
      st.applyTx(old, -1);
      st.txs = st.txs.map((y) => y['id'] == old['id'] ? x : y).toList();
    }
  } else {
    st.txs.add(x);
  }
  st.applyTx(x, 1);
  st.pref['acc'] = x['acc'];
  if (type != 'tr') st.pref['cat_$type'] = x['cat'];
  st.save();
  toast(f['id'] != null ? 'Өзгертілді' : (type == 'in' ? 'Кіріс қосылды' : type == 'tr' ? 'Аударым жасалды' : 'Шығын қосылды'));
  return true;
}

Future<void> delTx(BuildContext context, String id, {bool quick = false}) async {
  final st = Store.i;
  final x = st.txOf(id);
  if (x == null) return;
  if (!quick && !await ask(context, 'Операция өшіріледі. Жалғастырасыз ба?', ok: 'Өшіру')) return;
  st.applyTx(x, -1);
  st.txs = st.txs.where((y) => y['id'] != id).toList();
  st.save();
  toast('Өшірілді', undo: () {
    st.txs.add(x);
    st.applyTx(x, 1);
    st.save();
  });
}

void viewTx(BuildContext context, String id) {
  final st = Store.i;
  final x = st.txOf(id);
  if (x == null) return;
  final type = s(x['type']);
  openSheet(
    context,
    title: type == 'in' ? t('Кіріс') : type == 'tr' ? t('Аударым') : t('Шығын'),
    builder: (ctx, set) {
      final p = ctx.pal;
      final a = st.acc(x['acc']);
      final rows = <Widget>[];
      if (type == 'tr') {
        final to = st.acc(x['to']);
        rows.addAll([Kv(t('Қайдан'), a != null ? s(a['name']) : '—'), Kv(t('Қайда'), to != null ? s(to['name']) : '—')]);
      } else {
        rows.addAll([Kv(t('Санат'), t(s(x['cat']))), Kv(t('Шот'), a != null ? s(a['name']) : t('Шотсыз'))]);
        final l = st.acc(x['loan']);
        if (l != null) rows.add(Kv(t('Несие'), s(l['name'])));
      }
      rows.add(Kv(t('Күні'), fullDate(s(x['date']))));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CatIcon(type == 'tr' ? 'Аударым' : s(x['cat']), size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.signed(n(x['amt']), type),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: type == 'in' ? p.pos : p.ink, fontFeatures: kNum)),
              Text(s(x['note']).isNotEmpty ? s(x['note']) : t(s(x['cat'])), style: TextStyle(color: p.mute)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        ...rows,
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: QBtn(t('Түзету'), icon: 'edit', kind: BtnKind.line, onTap: () {
              Navigator.of(ctx).pop();
              openTx(context, editId: id);
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QBtn(t('Өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
              Navigator.of(ctx).pop();
              await delTx(context, id);
            }),
          ),
        ]),
      ]);
    },
  );
}
