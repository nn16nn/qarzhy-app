import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'accounts.dart';
import 'ops.dart';
import 'plans.dart';
import 'shell.dart';
import 'soon.dart';
import 'stats.dart';
import 'tx_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final now = DateTime.now();
    final T = st.totals();
    final M = st.monthSum(ym(now));
    final dt = st.debtTotals();
    final rc = st.recurState();
    double gSaved = 0, gTarget = 0;
    for (final g in st.goals) {
      gSaved += n(g['saved']);
      gTarget += n(g['target']);
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(children: [
          Text('qarzhy', style: TextStyle(fontFamily: 'Serif', fontSize: 38, fontWeight: FontWeight.w700, color: p.ink, height: 1, letterSpacing: -.5)),
          Container(width: 10, height: 10, margin: const EdgeInsets.only(left: 4, top: 14), decoration: BoxDecoration(color: p.lime, shape: BoxShape.circle, border: Border.all(color: p.ink, width: 1.5))),
          const Spacer(),
          RoundBtn('search', onTap: () => pushPage(context, (_) => const OpsPage())),
        ]),
      ),
      _hero(context, T.net, M),
    ];

    if (st.isFresh) {
      children.add(_welcome(context));
    } else {
      if (rc.due.isNotEmpty) {
        children.add(_alert(context, 'bell', '${t('Төлем жақындады')}: ${rc.due.map((r) => s(r['name'])).join(', ')}', () => pushPage(context, (_) => const RecurPage())));
      }
      if (dt.late > 0) children.add(_alert(context, 'people', '${t('Мерзімі өткен қарыз')}: ${dt.late}', () => pushPage(context, (_) => const DebtsPage())));
      final lim = n(st.pref['monthLimit']);
      if (lim > 0) {
        final dim = DateTime(now.year, now.month + 1, 0).day;
        final left = dim - now.day + 1;
        final canDay = ((lim - M.out) / left).clamp(0, double.infinity).toDouble();
        children.add(QCard(
          onTap: () => openLimitSheet(context),
          child: Row(children: [
            const IconBox('cal'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Бүгін жұмсауға болады'), style: TextStyle(color: p.mute, fontSize: 12.5)),
                Text(st.money(canDay), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -.3, fontFeatures: kNum)),
                const SizedBox(height: 8),
                QProg(M.out / lim, color: M.out > lim ? p.neg : null),
              ]),
            ),
          ]),
        ));
      }
      children.add(const SizedBox(height: 12));
      children.add(GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        padding: EdgeInsets.zero,
        children: [
          _tile(context, 'target', t('Мақсаттар'),
              st.goals.isNotEmpty ? '${st.moneyShort(gSaved)}${gTarget > 0 ? ' · ${(gSaved / gTarget * 100).round()}%' : ''}' : t('Әлі жоқ'), () => pushPage(context, (_) => const GoalsPage())),
          _tile(context, 'people', t('Қарыздар'), (dt.lent > 0 || dt.owed > 0) ? '↗ ${st.moneyShort(dt.lent)}  ↙ ${st.moneyShort(dt.owed)}' : t('Қарыз жоқ'),
              () => pushPage(context, (_) => const DebtsPage())),
          _tile(context, 'repeat', t('Тұрақты төлемдер'),
              st.recur.isNotEmpty ? (rc.unpaid > 0 ? '${t('Қалды')} ${st.moneyShort(rc.unpaid)}' : t('Барлығы төленді')) : t('Әлі жоқ'), () => pushPage(context, (_) => const RecurPage())),
          _tile(context, 'calc', t('Есептегіш'), t('Несие · Депозит · Салық'), () => openSoon(context, 'Есептегіш')),
        ],
      ));
      final recent = Store.sortTx(List<J>.from(st.txs)).take(6).toList();
      children.add(SecHead(t('Соңғы операциялар'),
          action: st.txs.isNotEmpty ? t('Барлығы') : null, onAction: () => pushPage(context, (_) => const OpsPage())));
      children.add(recent.isNotEmpty
          ? QList([for (final x in recent) TxRow(x)])
          : Empty('receipt', '${t('Әзірге операция жоқ.')}\n${t('Ортадағы + түймесімен бірінші шығынды қосыңыз.')}'));
    }
    return PageList(children);
  }

  Widget _hero(BuildContext context, double net, MonthSum M) {
    final p = context.pal;
    final st = Store.i;
    Widget cell(String label, Color dot, double v, String kind) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              statsKindNotifier.value = kind;
              shellKey.currentState?.go(2);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: p.heroLine), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: p.heroMute, fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(st.moneyShort(v), style: TextStyle(color: p.heroInk, fontWeight: FontWeight.w700, fontSize: 18, fontFeatures: kNum)),
                ),
              ]),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t('Таза капитал'), style: TextStyle(color: p.heroMute, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: p.dark ? p.ink : p.lime, borderRadius: BorderRadius.circular(99)),
            child: Text(monName(DateTime.now().month - 1), style: TextStyle(color: p.dark ? p.lime : const Color(0xFF141412), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: net),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (ctx, v, _) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${v < 0 ? '−' : ''}${nf(v)}', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w700, letterSpacing: -1.5, color: p.heroInk, fontFeatures: kNum)),
              TextSpan(text: ' ${st.sym}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: p.heroMute)),
            ])),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          cell(t('Кіріс'), p.pos, M.inc, 'in'),
          const SizedBox(width: 10),
          cell(t('Шығын'), p.neg, M.out, 'out'),
        ]),
      ]),
    );
  }

  Widget _tile(BuildContext context, String icon, String title, String sub, VoidCallback onTap) {
    final p = context.pal;
    return QCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconBox(icon, size: 38),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mute, fontSize: 12.5, fontFeatures: kNum)),
        ]),
      ]),
    );
  }

  Widget _alert(BuildContext context, String icon, String text, VoidCallback onTap) {
    final p = context.pal;
    return QCard(
      onTap: onTap,
      child: Row(children: [
        IconBox(icon, size: 36, bg: p.lime, fg: const Color(0xFF141412)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        QIcon('right', color: p.mute),
      ]),
    );
  }

  Widget _welcome(BuildContext context) {
    final p = context.pal;
    final st = Store.i;
    final steps = [
      ['bank', 'Банк шотын қосыңыз', 'Kaspi, Halyk, Freedom… қазіргі қалдығымен'],
      ['upload', 'Немесе үзінді жүктеңіз', 'Банк PDF/Excel үзіндісінен операциялар өзі түседі'],
      ['out', 'Бірінші шығынды жазыңыз', 'Ортадағы + түймесі — 3 секунд'],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Qarzhy-ге қош келдіңіз'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4)),
          const SizedBox(height: 6),
          Text(t('Ақшаңыз қайда кететінін көріңіз. Деректер тек осы телефонда сақталады — тіркелу де, сервер де жоқ.'), style: TextStyle(color: p.mute, fontSize: 14, height: 1.4)),
        ]),
      ),
      QList([
        for (var i = 0; i < steps.length; i++)
          QRow(
            lead: IconBox(steps[i][0], bg: i == 0 ? p.lime : null, fg: i == 0 ? const Color(0xFF141412) : null),
            title: t(steps[i][1]),
            sub: t(steps[i][2]),
            trail: QIcon('right', color: p.mute),
            onTap: () {
              if (i == 0) {
                openAccSheet(context, 'asset');
              } else if (i == 1) {
                toast('Бұл бөлім келесі жаңартуда');
              } else {
                openTx(context, type: 'out');
              }
            },
          ),
      ]),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.center, children: [
        for (final l in [['kk', 'Қазақша'], ['ru', 'Русский'], ['en', 'English']])
          QChip(l[1], on: gLang == l[0], onTap: () {
            st.db['lang'] = l[0];
            gLang = l[0];
            st.save();
          }),
      ]),
    ]);
  }
}

class TxRow extends StatelessWidget {
  final J x;
  const TxRow(this.x, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final a = st.acc(x['acc']);
    String title, sub, amt;
    Color? color;
    final type = s(x['type']);
    if (type == 'tr') {
      final to = st.acc(x['to']);
      title = t('Аударым');
      sub = '${a != null ? s(a['name']) : '—'} → ${to != null ? s(to['name']) : '—'}';
      if (n(x['amt2']) > 0 && to != null && a != null && st.curOf(a) != st.curOf(to)) {
        amt = '${nf(n(x['amtFrom']) > 0 ? n(x['amtFrom']) : n(x['amt']), true)}$nbsp${st.curSym(a)} → ${nf(n(x['amt2']), true)}$nbsp${st.curSym(to)}';
      } else {
        amt = '${nf(n(x['amt']))}$nbsp${st.sym}';
      }
      if (n(x['amt2']) > 0) title = t('Айырбас');
    } else {
      final note = s(x['note']);
      title = note.isNotEmpty ? note : t(s(x['cat']));
      sub = '${note.isNotEmpty ? '${t(s(x['cat']))} · ' : ''}${a != null ? s(a['name']) : t('Шотсыз')}';
      color = type == 'in' ? p.pos : null;
      amt = st.signed(n(x['amt']), type);
    }
    return QRow(
      lead: CatIcon(type == 'tr' ? 'Аударым' : s(x['cat'])),
      title: title,
      sub: sub,
      trail: Amt(amt, color: color),
      onTap: () => viewTx(context, s(x['id'])),
    );
  }
}
