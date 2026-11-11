import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/pro.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _perks = [
  ['upload', 'Шексіз импорт', 'Kaspi, Freedom үзінділері, несие анықтамасы'],
  ['receipt', 'Чекті сканерлеу', 'Суретке түсір — сомасы өзі жазылады'],
  ['lock', 'Зейнетақы (ЕНПФ)', 'Жинақ, кіріс, жұмыс берушілер'],
  ['card', 'Несиені жабу жоспары', 'Қайсысын бірінші жабу тиімді'],
  ['pie', 'Терең талдау', 'Кеңестер, капитал тарихы, шығын картасы, жылдық қорытынды'],
  ['bell', 'Санат лимиттері', 'Шектен асса — ескертеді'],
  ['percent', 'Калькуляторлар', 'Депозит, инвестиция, ЖК салығы'],
];

/// Pro болса true қайтарады, әйтпесе төлем бетін ашады.
bool proGate(BuildContext context) {
  if (Pro.i.isPro) return true;
  openPaywall(context);
  return false;
}

String _plan = 'year';

void openPaywall(BuildContext context) {
  final pro = Pro.i;
  if (pro.products.isEmpty) pro.loadProducts();
  openSheet(context, title: 'Qarzhy Pro', builder: (ctx, set) {
    return ListenableBuilder(
      listenable: pro,
      builder: (ctx, _) {
        final p = ctx.pal;
        final paid = pro.paid, tl = pro.trialLeft;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (paid)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                QIcon('check', color: p.lime),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Pro белсенді'), style: TextStyle(color: p.heroInk, fontWeight: FontWeight.w700, fontSize: 17)),
                    if (pro.planName.isNotEmpty) Text(pro.planName, style: TextStyle(color: p.heroMute, fontSize: 13.5)),
                  ]),
                ),
              ]),
            )
          else
            Text(
              tl > 0 ? '${t('Тегін сынақ')}: $tl ${t('күн қалды')}' : t('Барлық мүмкіндікті ашыңыз. Деректеріңіз бұрынғыдай тек телефонда.'),
              style: TextStyle(color: p.mute, fontSize: 14),
            ),
          const SizedBox(height: 8),
          for (final x in _perks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                IconBox(x[0], size: 40, bg: p.lime, fg: const Color(0xFF141412)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t(x[1]), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(t(x[2]), style: TextStyle(color: p.mute, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          if (!paid) ...[
            Row(children: [
              for (final pl in [['month', 'Айлық', ''], ['year', 'Жылдық', '−50%'], ['life', 'Мәңгілік', t('бір рет')]])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _PlanTile(
                      on: _plan == pl[0],
                      title: t(pl[1]),
                      price: ProCfg.price[pl[0]] ?? '',
                      badge: pl[2],
                      onTap: () => set(() => _plan = pl[0]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            QBtn(pro.busy ? '…' : t('Сатып алу'), icon: 'check', kind: BtnKind.lime, onTap: pro.busy ? null : () => pro.buy(_plan)),
            if (pro.st['trialStart'] == null) ...[
              const SizedBox(height: 8),
              QBtn(t('7 күн тегін көру'), kind: BtnKind.line, onTap: () {
                if (pro.startTrial()) {
                  Navigator.of(ctx).pop();
                  toast(t('7 күн тегін Pro басталды'));
                }
              }),
            ],
          ] else if (pro.st['life'] != true && !pro.isTest)
            QBtn(t('Жазылымды басқару'), kind: BtnKind.line, onTap: pro.manage),
          const SizedBox(height: 8),
          QBtn(t('Сатып алуды қалпына келтіру'), icon: 'repeat', kind: BtnKind.line, small: true, onTap: pro.restore),
          const SizedBox(height: 10),
          Text(
            t('Жазылым Google Play арқылы. Кез келген уақытта Google Play → Жазылымдар бөлімінен тоқтатуға болады. Телефон ауыстырсаңыз, сол Google аккаунтымен «Қалпына келтіру» басыңыз.'),
            style: TextStyle(color: p.mute, fontSize: 12, height: 1.45),
          ),
        ]);
      },
    );
  });
}

class _PlanTile extends StatelessWidget {
  final bool on;
  final String title, price, badge;
  final VoidCallback onTap;
  const _PlanTile({required this.on, required this.title, required this.price, required this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      onTap: () {
        tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: kEase,
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          color: on ? p.lime.withValues(alpha: .18) : p.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? p.lime : p.line, width: on ? 2 : 1.5),
        ),
        child: Column(children: [
          Text(title, style: TextStyle(color: p.mute, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(child: Text(price, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFeatures: kNum))),
          if (badge.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: p.lime, borderRadius: BorderRadius.circular(99)),
              child: Text(badge, style: const TextStyle(color: Color(0xFF141412), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Профильдегі Pro карточкасы
class ProCard extends StatelessWidget {
  const ProCard({super.key});
  @override
  Widget build(BuildContext context) {
    final pro = Pro.i;
    if (!ProCfg.on && !kDebugMode) return const SizedBox.shrink();
    final p = context.pal;
    final paid = pro.paid, tl = pro.trialLeft;
    final dark = !paid;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: dark ? p.hero : p.sf,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openPaywall(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconBox(paid ? 'check' : 'gift', size: 40, bg: p.lime, fg: const Color(0xFF141412)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Qarzhy Pro${paid && pro.planName.isNotEmpty ? ' · ${pro.planName}' : ''}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: dark ? p.heroInk : p.ink)),
                  Text(
                    !ProCfg.on
                        ? t('Құлып өшірулі (тест)')
                        : paid
                            ? t('Белсенді')
                            : tl > 0
                                ? '${t('Тегін сынақ')}: $tl ${t('күн қалды')}'
                                : t('Импорт, чек, талдау — барлығы шексіз'),
                    style: TextStyle(fontSize: 12.5, color: dark ? p.heroMute : p.mute),
                  ),
                ]),
              ),
              QIcon('right', color: dark ? p.heroMute : p.mute),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Жабық беттің орнына көрсетілетін карточка
class LockedCard extends StatelessWidget {
  final String title;
  const LockedCard(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return QCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          IconBox('lock', size: 52, bg: p.lime, fg: const Color(0xFF141412)),
          const SizedBox(height: 12),
          Text(t(title), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 4),
          Text(t('Бұл мүмкіндік Qarzhy Pro-да'), style: TextStyle(color: p.mute, fontSize: 13.5)),
          const SizedBox(height: 14),
          QBtn(t('Pro-ны ашу'), kind: BtnKind.lime, onTap: () => openPaywall(context)),
        ]),
      ),
    );
  }
}

/// Кішкентай «Pro» белгісі
class ProTag extends StatelessWidget {
  const ProTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: context.pal.lime, borderRadius: BorderRadius.circular(6)),
        child: const Text('Pro', style: TextStyle(color: Color(0xFF141412), fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

/// Әзірлеуші мәзірі: Профильдегі нұсқа жолын ұзақ басқанда ашылады.
void openProTest(BuildContext context) {
  final pro = Pro.i;
  openSheet(context, title: 'Pro · тест', builder: (ctx, set) {
    return ListenableBuilder(
      listenable: pro,
      builder: (ctx, _) {
        final p = ctx.pal;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Kv('Құлып (gating)', ProCfg.on ? 'қосулы' : 'өшірулі'),
          Kv('Pro', pro.paid ? (pro.isTest ? 'тест' : pro.planName) : 'жоқ'),
          Kv('Сынақ', pro.trialLeft < 0 ? 'басталмаған' : '${pro.trialLeft} күн'),
          Kv('Тегін импорт', '${pro.importsLeft}'),
          Kv('Google Play', pro.available ? 'қолжетімді · ${pro.products.length} тариф' : 'жоқ'),
          if (s(pro.st['sku']).isNotEmpty) Kv('SKU', s(pro.st['sku'])),
          const SizedBox(height: 12),
          QBtn(ProCfg.on ? 'Құлыпты өшіру' : 'Құлыпты қосу', kind: BtnKind.line, onTap: () => pro.testSet(gate: !ProCfg.on)),
          const SizedBox(height: 8),
          QBtn(pro.isTest ? 'Тест Pro-ны алу' : 'Тест Pro беру', kind: BtnKind.line, onTap: () => pro.testSet(pro: !pro.isTest)),
          const SizedBox(height: 8),
          QBtn('Сынақ пен импорт квотасын нөлдеу', kind: BtnKind.line, onTap: () => pro.testSet(resetTrial: true, resetImports: true)),
          const SizedBox(height: 8),
          QBtn('Google Play-мен тексеру', icon: 'repeat', kind: BtnKind.line, onTap: () async {
            await pro.loadProducts();
            await pro.restore();
          }),
          const SizedBox(height: 10),
          Text('Бұл мәзір тек тексеруге арналған.', style: TextStyle(color: p.mute, fontSize: 12)),
        ]);
      },
    );
  });
}
