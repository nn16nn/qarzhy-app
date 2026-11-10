import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ops.dart';
import 'shell.dart';

final statsKindNotifier = ValueNotifier<String>('out');

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _CatSum {
  final String cat;
  double v = 0;
  int n = 0;
  _CatSum(this.cat);
}

class _StatsPageState extends State<StatsPage> {
  DateTime mon = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<_CatSum> _catTotals(String key, String type) {
    final m = <String, _CatSum>{};
    for (final x in Store.i.txs) {
      if (x['type'] == type && s(x['date']).startsWith(key)) {
        final c = s(x['cat']).isEmpty ? 'Басқа' : s(x['cat']);
        final e = m.putIfAbsent(c, () => _CatSum(c));
        e.v += n(x['amt']);
        e.n++;
      }
    }
    return m.values.toList()..sort((a, b) => b.v.compareTo(a.v));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: statsKindNotifier,
      builder: (ctx, kind, _) => _build(ctx, kind),
    );
  }

  Widget _build(BuildContext context, String kind) {
    final st = Store.i;
    final p = context.pal;
    final key = ym(mon);
    final M = st.monthSum(key);
    final items = _catTotals(key, kind);
    final total = items.fold<double>(0, (a, b) => a + b.v);
    final limits = st.db['limits'] as Map;

    // 6 ай
    final months = <MapEntry<DateTime, MonthSum>>[];
    double mx = 1;
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(mon.year, mon.month - i, 1);
      final ms = st.monthSum(ym(d));
      months.add(MapEntry(d, ms));
      mx = math.max(mx, math.max(ms.inc, ms.out));
    }
    // көрсеткіштер
    double avg = 0;
    int cnt = 0;
    for (var j = 1; j <= 3; j++) {
      final ms = st.monthSum(ym(DateTime(mon.year, mon.month - j, 1)));
      if (ms.count > 0) {
        avg += ms.out;
        cnt++;
      }
    }
    avg = cnt > 0 ? avg / cnt : M.out;
    final T = st.totals();
    final rate = M.inc > 0 ? (M.inc - M.out) / M.inc * 100 : 0.0;
    final runway = avg > 0 ? T.banks / avg : 0.0;
    final lim = n(st.pref['monthLimit']);

    return PageList([
      TopBar(t('Нәтиже'), back: false),
      const SizedBox(height: 8),
      Row(children: [
        RoundBtn('left', onTap: () => setState(() => mon = DateTime(mon.year, mon.month - 1, 1))),
        Expanded(child: Center(child: Text('${monName(mon.month - 1)} ${mon.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
        RoundBtn('right', onTap: () => setState(() => mon = DateTime(mon.year, mon.month + 1, 1))),
      ]),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          QSeg(items: [['out', t('Шығын')], ['in', t('Кіріс')]], value: kind, onChanged: (v) => statsKindNotifier.value = v),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                Opacity(opacity: .6, child: QIcon('pie', size: 30, color: p.mute)),
                const SizedBox(height: 8),
                Text(t('Бұл айда дерек жоқ.'), style: TextStyle(color: p.mute)),
              ]),
            )
          else ...[
            const SizedBox(height: 16),
            Center(child: _Donut(items: items, total: total, label: kind == 'out' ? t('Барлық шығын') : t('Барлық кіріс'))),
            const SizedBox(height: 10),
            for (final x in items)
              InkWell(
                onTap: () => pushPage(context, (_) => OpsPage(cat: x.cat, mon: key, type: kind)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    CatIcon(x.cat),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t(x.cat), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Builder(builder: (_) {
                          final l = kind == 'out' ? n(limits[x.cat]) : 0.0;
                          final w = l > 0 ? x.v / l : x.v / total;
                          final c = l > 0 ? (x.v > l ? p.neg : x.v >= l * .8 ? p.warn : catMeta(x.cat).color) : catMeta(x.cat).color;
                          return SizedBox(height: 4, child: QProg(w, color: c));
                        }),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Amt(st.money(x.v), small: '${(x.v / total * 100).toStringAsFixed(x.v / total < .1 ? 1 : 0).replaceAll('.', ',')}% · ${x.n}'),
                  ]),
                ),
              ),
          ],
        ]),
      ),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Соңғы 6 ай'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => mon = months[i].key),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Expanded(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _bar(months[i].value.inc / mx, p.pos, i == 5 ? 1 : .55),
                          const SizedBox(width: 3),
                          _bar(months[i].value.out / mx, p.ink, i == 5 ? 1 : .55),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text(monShort(months[i].key.month - 1), style: TextStyle(fontSize: 12, color: i == 5 ? p.ink : p.mute, fontWeight: i == 5 ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Көрсеткіштер'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Kv(t('Айлық орташа шығын'), st.moneyShort(avg)),
          Kv(t('Жинақ үлесі'), '${rate.round()}%', vColor: rate < 0 ? p.neg : p.pos),
          Kv(t('Қаражат жетеді'), runway > 0 ? '${runway.toStringAsFixed(1).replaceAll('.', ',')} ${t('ай')}' : '—'),
          Kv('${t('Ай қалдығы')} (${t('кіріс')} − ${t('шығын')})', '${M.inc - M.out > 0 ? '+' : ''}${st.money(M.inc - M.out)}', vColor: M.inc - M.out < 0 ? p.neg : p.pos),
          InkWell(
            onTap: () => openLimitSheet(context),
            child: Kv(t('Айлық шығын жоспары'), lim > 0 ? '${st.money(lim)} ✎' : t('қою')),
          ),
        ]),
      ),
    ]);
  }

  Widget _bar(double v, Color c, double op) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: 9,
        height: math.max(2, 100 * v.clamp(0, 1)),
        decoration: BoxDecoration(color: c.withValues(alpha: op), borderRadius: BorderRadius.circular(4)),
      );
}

class _Donut extends StatelessWidget {
  final List<_CatSum> items;
  final double total;
  final String label;
  const _Donut({required this.items, required this.total, required this.label});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (ctx, k, _) => SizedBox(
        width: 210,
        height: 210,
        child: CustomPaint(
          painter: _DonutPainter(items, total, p.sf2, k),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(color: p.mute, fontSize: 13)),
              const SizedBox(height: 2),
              Text(Store.i.moneyShort(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.5, fontFeatures: kNum)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_CatSum> items;
  final double total;
  final Color track;
  final double k;
  _DonutPainter(this.items, this.total, this.track, this.k);
  @override
  void paint(Canvas canvas, Size size) {
    const sw = 22.0;
    final r = size.width / 2 - sw / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = track);
    var start = -math.pi / 2;
    for (final x in items) {
      final sweep = x.v / total * 2 * math.pi * k;
      final gap = items.length > 1 ? math.min(.025, sweep * .3) : 0.0;
      canvas.drawArc(rect, start, math.max(0, sweep - gap), false, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = catMeta(x.cat).color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.k != k || o.total != total || o.items != items;
}

void openLimitSheet(BuildContext context) {
  final st = Store.i;
  var v = n(st.pref['monthLimit']) > 0 ? '${n(st.pref['monthLimit']).round()}' : '';
  openSheet(context, title: t('Айлық шығын жоспары'), builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('Айына қанша жұмсауды жоспарлайсыз? Басты бетте «Бүгін жұмсауға болады» көрсетіледі. 0 — өшіру.'), style: TextStyle(color: ctx.pal.mute, fontSize: 14)),
      const SizedBox(height: 10),
      QInput(initial: v, hint: '0 ${st.sym}', number: true, autofocus: true, onChanged: (x) => v = x),
      QBtn(t('Сақтау'), icon: 'check', onTap: () {
        st.pref['monthLimit'] = parseNum(v);
        st.save();
        Navigator.pop(ctx);
        toast('Сақталды');
      }),
    ]);
  });
}
