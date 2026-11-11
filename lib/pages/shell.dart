import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/pro.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'accounts.dart';
import 'home.dart';
import 'more.dart';
import 'stats.dart';
import 'tx_sheet.dart';

final shellKey = GlobalKey<ShellState>();

class Shell extends StatefulWidget {
  Shell() : super(key: shellKey);
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  int tab = 0;
  bool fan = false;
  late final AnimationController fanC = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), reverseDuration: const Duration(milliseconds: 300));

  static const _fanItems = [
    ['out', 'out', 'Шығын'],
    ['in', 'in', 'Кіріс'],
    ['tr', 'swap', 'Аударым'],
    ['scan', 'receipt', 'Чек'],
    ['import', 'upload', 'Жүктеу'],
  ];

  @override
  void dispose() {
    fanC.dispose();
    super.dispose();
  }

  void setFan(bool on) {
    if (on == fan) return;
    setState(() => fan = on);
    if (on) {
      fanC.forward();
    } else {
      fanC.reverse();
    }
  }

  void go(int i) {
    setFan(false);
    if (i != tab) setState(() => tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PopScope(
      canPop: tab == 0 && !fan,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (fan) {
          setFan(false);
        } else {
          go(0);
        }
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(children: [
          SafeArea(
            bottom: false,
            // Дерек өзгерген сайын беттер қайта салынады (жаңа шот, операция т.б. бірден көрінеді)
            child: ListenableBuilder(
              listenable: Listenable.merge([Store.i, Pro.i]),
              builder: (ctx, _) {
                // ignore: prefer_const_constructors, prefer_const_literals_to_create_immutables
                final pages = <Widget>[HomePage(), AccountsPage(), StatsPage(), MorePage()];
                return IndexedStack(index: tab, children: [
                  for (var i = 0; i < pages.length; i++) _TabPage(active: tab == i, child: pages[i]),
                ]);
              },
            ),
          ),
          _fanLayer(context),
          Positioned(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, child: _dock(context)),
        ]),
      ),
    );
  }

  // ---------- dock: жылжитын лайм пилюля ----------
  Widget _dock(BuildContext context) {
    final p = context.pal;
    const icons = ['home', 'wallet', 'pie', 'user'];
    const addW = 72.0, pillW = 56.0, pillH = 44.0;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.dock,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: LayoutBuilder(builder: (ctx, c) {
        final w = (c.maxWidth - addW) / 4;
        double cx(int i) => i < 2 ? w * i + w / 2 : addW + w * i + w / 2;
        Widget item(int i) {
          final on = tab == i;
          return SizedBox(
            width: w,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                tap();
                go(i);
              },
              child: Center(
                child: Pop(
                  enabled: on,
                  trigger: tab,
                  from: .7,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: on ? const Color(0xFF141412) : p.dockInk.withValues(alpha: .55)),
                    duration: const Duration(milliseconds: 200),
                    builder: (ctx, col, _) => QIcon(icons[i], size: 23, color: col),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(clipBehavior: Clip.none, children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: kSpring,
            left: cx(tab) - pillW / 2,
            top: (72 - pillH) / 2,
            width: pillW,
            height: pillH,
            child: DecoratedBox(decoration: BoxDecoration(color: p.lime, borderRadius: BorderRadius.circular(15))),
          ),
          Row(children: [
            item(0),
            item(1),
            SizedBox(
              width: addW,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    tap();
                    setFan(!fan);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 60,
                    height: 54,
                    decoration: BoxDecoration(color: fan ? p.sf : p.lime, borderRadius: BorderRadius.circular(20)),
                    child: Center(
                      child: AnimatedRotation(
                        turns: fan ? .375 : 0,
                        duration: const Duration(milliseconds: 420),
                        curve: kSpring,
                        child: QIcon('plus', size: 28, color: fan ? p.ink : const Color(0xFF141412), stroke: 2.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(2),
            item(3),
          ]),
        ]);
      }),
    );
  }

  // ---------- + мәзірі: желпуіш ----------
  Widget _fanLayer(BuildContext context) {
    final p = context.pal;
    final bottom = MediaQuery.of(context).padding.bottom;
    final n = _fanItems.length;
    return AnimatedBuilder(
      animation: fanC,
      builder: (ctx, _) {
        final v = fanC.value;
        if (v == 0 && !fan) return const SizedBox.shrink();
        final opening = fanC.status == AnimationStatus.forward || fanC.status == AnimationStatus.completed;
        return Positioned.fill(
          child: Stack(children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setFan(false),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6 * v.clamp(0.0, 1.0), sigmaY: 6 * v.clamp(0.0, 1.0)),
                    child: Container(color: Colors.black.withValues(alpha: .38 * v.clamp(0.0, 1.0))),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < n; i++) _fanBtn(ctx, p, i, n, v, opening, bottom),
          ]),
        );
      },
    );
  }

  Widget _fanBtn(BuildContext context, Pal p, int i, int n, double v, bool opening, double bottom) {
    final x = _fanItems[i];
    // әр түйменің өз кешігуі: ашылғанда солдан оңға, жабылғанда керісінше
    final delay = opening ? i * 0.07 : (n - 1 - i) * 0.05;
    final span = 1 - (n - 1) * (opening ? 0.07 : 0.05);
    final lin = ((v - delay) / span).clamp(0.0, 1.0);
    final t2 = opening ? kSpring.transform(lin) : Curves.easeIn.transform(lin);
    final a = (-160 + i * (140 / (n - 1))) * math.pi / 180;
    // доға dock-тың үстінде тұрады, сонда шеткі түймелер мен жазулар панельдің астында қалмайды
    const r = 120.0;
    final up = -math.sin(a) * r; // 41…120
    final dx = math.cos(a) * r * 1.12 * t2;
    final rise = (71 + up) * t2; // + түймесінің ортасынан доғаға дейін
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: size.width / 2 - 36 + dx,
      bottom: 16 + bottom + 9 + rise,
      width: 72,
      child: Opacity(
        opacity: lin,
        child: Transform.scale(
          scale: .3 + .7 * t2,
          child: GestureDetector(
            onTap: () {
              tap();
              setFan(false);
              if (x[0] == 'scan' || x[0] == 'import') {
                toast('Бұл бөлім келесі жаңартуда');
              } else {
                openTx(context, type: x[0]);
              }
            },
            child: Press(
              scale: .92,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: i == 0 ? p.lime : p.sf,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 26, offset: Offset(0, 10), spreadRadius: -8)],
                  ),
                  child: Center(child: QIcon(x[1], size: 24, color: i == 0 ? const Color(0xFF141412) : p.ink)),
                ),
                const SizedBox(height: 6),
                Text(
                  t(x[2]),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, shadows: [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Таб ауысқанда бет жұмсақ пайда болады (веб: pgIn .28s).
class _TabPage extends StatefulWidget {
  final bool active;
  final Widget child;
  const _TabPage({required this.active, required this.child});
  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  @override
  void didUpdateWidget(covariant _TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        child: widget.child,
        builder: (ctx, child) {
          final v = kEase.transform(c.value);
          return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child));
        },
      );
}

/// Беттің ортақ қаңқасы: айналатын тізім, асты dock үшін бос
class PageList extends StatelessWidget {
  final List<Widget> children;
  const PageList(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + MediaQuery.of(context).padding.bottom),
      children: children,
    );
  }
}

/// Ішкі бет (артқа батырмасы бар)
class SubPage extends StatelessWidget {
  final List<Widget> children;
  const SubPage(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([Store.i, Pro.i]),
          builder: (ctx, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: children),
        ),
      ),
    );
  }
}

void pushPage(BuildContext context, Widget Function(BuildContext) builder) {
  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ListenableBuilder(listenable: Listenable.merge([Store.i, Pro.i]), builder: (c, _) => builder(c))));
}
