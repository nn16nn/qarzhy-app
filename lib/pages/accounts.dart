import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ops.dart';
import 'shell.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final T = st.totals();
    final bs = st.assets;
    final ls = st.accsOf('debt');
    Widget mini(String label, double v) => Expanded(
          child: QCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: p.mute, fontSize: 13)),
              Text(st.moneyShort(v), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: v < 0 ? p.neg : p.ink, fontFeatures: kNum)),
            ]),
          ),
        );
    return PageList([
      TopBar(t('Менің қаржым'), back: false),
      if (T.lent > 0 || T.owed > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            if (T.lent > 0) mini(t('Маған қарыз'), T.lent),
            if (T.lent > 0 && T.owed > 0) const SizedBox(width: 10),
            if (T.owed > 0) mini(t('Менің қарызым'), -T.owed),
          ]),
        ),
      SecHead(t('Банк шоттары'), action: t('Қосу'), actionIcon: 'plus', onAction: () => openAccSheet(context, 'asset')),
      bs.isNotEmpty ? QList([for (final a in bs) AccRow(a)]) : Empty('wallet', t('Банк шоты жоқ.')),
      SecHead(t('Несиелер'), action: t('Қосу'), actionIcon: 'plus', onAction: () => openAccSheet(context, 'debt')),
      ls.isNotEmpty ? QList([for (final a in ls) AccRow(a)]) : Empty('card', t('Несие жоқ — тамаша.')),
    ]);
  }
}

class AccRow extends StatelessWidget {
  final J a;
  const AccRow(this.a, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final isDebt = a['kind'] == 'debt';
    String small = '';
    if (st.foreign(a) && st.fxRate(st.curOf(a)) > 0) small = '≈ ${st.moneyShort(st.toBase(a))}';
    if (isDebt) {
      final lm = st.loanLeft(a);
      small = [
        if (n(a['pay']) > 0) '${t('айына')} ${st.moneyShort(n(a['pay']))}',
        if (lm > 0) '$lm ${t('ай қалды')}',
      ].join(' · ');
    }
    return QRow(
      lead: AccBadge(a),
      title: s(a['name']),
      sub: isDebt ? '${n(a['rate']) > 0 ? '${_pct(n(a['rate']))}% · ' : ''}${t('Несие')}' : st.curOf(a),
      trail: Amt(st.money(isDebt ? -n(a['bal']) : n(a['bal']), st.curSym(a), st.foreign(a)), color: isDebt ? p.neg : null, small: small),
      onTap: () => viewAcc(context, s(a['id'])),
    );
  }
}

String _pct(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', ',');

void openAccSheet(BuildContext context, String kind, {String? id}) {
  final st = Store.i;
  final a = id != null ? st.acc(id) : null;
  final f = <String, dynamic>{
    'kind': a?['kind'] ?? kind,
    'name': a?['name'] ?? '',
    'bal': a != null ? nf(n(a['bal']), true).replaceAll(thin, '') : '',
    'cur': a != null ? st.curOf(a) : st.base,
    'rate': a != null && n(a['rate']) > 0 ? '${a['rate']}' : '',
    'pay': a != null && n(a['pay']) > 0 ? '${a['pay']}' : '',
    'payDay': a?['payDay'] != null ? '${a!['payDay']}' : '',
    'left': a != null && a['kind'] == 'debt' && a['end'] != null ? '${st.loanLeft(a)}' : '',
  };
  final nameCtl = TextEditingController(text: s(f['name']));
  final isLoan = f['kind'] == 'debt';
  openSheet(
    context,
    title: a != null ? t('Шотты өзгерту') : (isLoan ? t('Жаңа несие') : t('Жаңа шот')),
    builder: (ctx, set) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!isLoan && a == null)
          Field(
            t('Банкті таңдаңыз'),
            Wrap(children: [
              for (final b in kBanks)
                QChip(t(b.name), on: f['name'] == b.name, onTap: () => set(() {
                      f['name'] = b.name;
                      nameCtl.text = b.name;
                    })),
            ]),
          ),
        Field(
          t('Атауы'),
          TextField(controller: nameCtl, decoration: InputDecoration(hintText: isLoan ? t('Мысалы, Kaspi Red') : 'Kaspi Gold'), onChanged: (v) => f['name'] = v),
        ),
        Field(isLoan ? t('Несие қалдығы') : t('Қазіргі қалдық'), QInput(initial: s(f['bal']), hint: '0', number: true, onChanged: (v) => f['bal'] = v)),
        if (!isLoan)
          Field(
            t('Валюта'),
            DropdownButtonFormField<String>(
              initialValue: s(f['cur']),
              isExpanded: true,
              items: [
                for (final c in [st.base, ...kCurs.keys.where((c) => c != st.base)])
                  DropdownMenuItem(value: c, child: Text('${symOf(c)} · $c — ${t(kCurs[c]![1])}')),
              ],
              onChanged: (v) => f['cur'] = v,
            ),
          )
        else ...[
          Row(children: [
            Expanded(child: Field(t('Мөлшерлеме, %'), QInput(initial: s(f['rate']), number: true, onChanged: (v) => f['rate'] = v))),
            const SizedBox(width: 10),
            Expanded(child: Field(t('Айлық төлем'), QInput(initial: s(f['pay']), number: true, onChanged: (v) => f['pay'] = v))),
          ]),
          Row(children: [
            Expanded(child: Field(t('Төлем күні (1–31)'), QInput(initial: s(f['payDay']), number: true, onChanged: (v) => f['payDay'] = v))),
            const SizedBox(width: 10),
            Expanded(child: Field(t('Қанша ай қалды'), QInput(initial: s(f['left']), hint: t('мысалы, 12'), number: true, onChanged: (v) => f['left'] = v))),
          ]),
        ],
        const SizedBox(height: 8),
        QBtn(t('Сақтау'), icon: 'check', onTap: () {
          final name = s(f['name']).trim();
          if (name.isEmpty) {
            toast('Атауын жазыңыз');
            return;
          }
          final x = a ?? <String, dynamic>{'id': newId(), 'kind': f['kind'], 'icon': isLoan ? 'card' : 'wallet'};
          x['name'] = name;
          x['bal'] = parseNum(s(f['bal']));
          if (!isLoan) x['cur'] = f['cur'];
          if (isLoan) {
            x['rate'] = parseNum(s(f['rate']));
            x['pay'] = parseNum(s(f['pay']));
            final pd = parseNum(s(f['payDay'])).round();
            x['payDay'] = pd >= 1 && pd <= 31 ? pd : null;
            final k = parseNum(s(f['left'])).round();
            if (k > 0) {
              final now = DateTime.now();
              final d = DateTime(now.year, now.month + k - 1, 1);
              x['end'] = '${d.year}-${d.month.toString().padLeft(2, '0')}';
              if (!(n(x['pay']) > 0) && n(x['bal']) > 0) {
                final r = n(x['rate']) / 1200;
                x['pay'] = (r > 0 ? n(x['bal']) * r / (1 - math.pow(1 + r, -k)) : n(x['bal']) / k).round();
              }
            } else {
              x.remove('end');
            }
          }
          if (a == null) st.accounts.add(x);
          st.save();
          Navigator.of(ctx).pop();
          toast(a != null ? 'Сақталды' : (isLoan ? 'Несие қосылды' : 'Шот қосылды'));
        }),
        if (a != null)
          QBtn(t('Шотты өшіру'), icon: 'trash', kind: BtnKind.red, onTap: () async {
            if (!await ask(ctx, 'Шот өшіріледі. Операциялары сақталады, бірақ шотсыз қалады. Жалғастырасыз ба?', ok: 'Өшіру')) return;
            st.accounts = st.accounts.where((y) => y['id'] != id).toList();
            for (final x in st.txs) {
              if (x['acc'] == id) x['acc'] = null;
              if (x['to'] == id) x['to'] = null;
              if (x['loan'] == id) x['loan'] = null;
            }
            st.save();
            if (ctx.mounted) Navigator.of(ctx).pop();
            toast('Өшірілді');
          }),
      ]);
    },
  );
}

void viewAcc(BuildContext context, String id) {
  final st = Store.i;
  openSheet(
    context,
    title: s(st.acc(id)?['name']),
    builder: (ctx, set) {
      final p = ctx.pal;
      final a = st.acc(id);
      if (a == null) return const SizedBox();
      final isDebt = a['kind'] == 'debt';
      final rows = <Widget>[];
      if (st.foreign(a)) {
        rows.add(Kv(t('Негізгі валютада'), st.fxRate(st.curOf(a)) > 0 ? st.money(st.toBase(a)) : '—'));
        rows.add(Kv(t('Курс'), st.fxLine(st.curOf(a))));
      }
      Widget? tip;
      if (isDebt) {
        rows.add(Kv(t('Мөлшерлеме'), '${_pct(n(a['rate']))}%'));
        rows.add(Kv(t('Айлық төлем'), st.money(n(a['pay']))));
        if (a['payDay'] != null) rows.add(Kv(t('Төлем күні'), '${a['payDay']}'));
        final lm = st.loanLeft(a);
        if ((n(a['bal']) > 0 && lm != -1) || n(a['pay']) > 0) {
          rows.add(Kv(t('Қалған мерзім'), lm > 0 ? '$lm ${t('ай')} · ${st.loanEnd(a, lm)}' : t('есептелмеді')));
        }
        if (n(a['pay']) > 0 && n(a['bal']) > 0) {
          final m = Store.monthsLeft(n(a['bal']), n(a['rate']), n(a['pay']));
          if (m > 0) {
            final m2 = Store.monthsLeft(n(a['bal']), n(a['rate']), n(a['pay']) * 1.25);
            final saved = n(a['pay']) * m - n(a['pay']) * 1.25 * m2;
            tip = QCard(
              color: p.sf2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Айына 25% артық төлесеңіз'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${m - m2} ${t('ай ерте жабылады')}${saved >= 1 ? ' · ${t('үнем')} ≈ ${st.money(saved)}' : ''}', style: TextStyle(color: p.mute, fontSize: 13.5)),
              ]),
            );
          }
        }
      }
      final cnt = st.txs.where((x) => x['acc'] == id || x['to'] == id || x['loan'] == id).length;
      rows.add(Kv(t('Операция'), '$cnt'));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AccBadge(a, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(st.money(isDebt ? -n(a['bal']) : n(a['bal']), st.curSym(a), st.foreign(a)),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: kNum)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ...rows,
        if (tip != null) tip,
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: QBtn(t('Операциялар'), icon: 'receipt', kind: BtnKind.line, onTap: () {
              Navigator.of(ctx).pop();
              pushPage(context, (_) => OpsPage(accId: id));
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QBtn(t('Түзету'), icon: 'edit', kind: BtnKind.line, onTap: () {
              Navigator.of(ctx).pop();
              openAccSheet(context, s(a['kind']), id: id);
            }),
          ),
        ]),
      ]);
    },
  );
}
