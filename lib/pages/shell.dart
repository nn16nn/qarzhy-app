import 'package:flutter/material.dart';

import '../core/i18n.dart';
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

class ShellState extends State<Shell> {
  int tab = 0;
  bool fan = false;

  void go(int i) => setState(() {
        tab = i;
        fan = false;
      });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pages = const [HomePage(), AccountsPage(), StatsPage(), MorePage()];
    return PopScope(
      canPop: tab == 0 && !fan,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (fan) {
          setState(() => fan = false);
        } else {
          go(0);
        }
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(children: [
          SafeArea(bottom: false, child: IndexedStack(index: tab, children: pages)),
          if (fan) _fanLayer(context),
          Positioned(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, child: _dock(context)),
        ]),
      ),
    );
  }

  Widget _dock(BuildContext context) {
    final p = context.pal;
    Widget item(int i, String icon) {
      final on = tab == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            tap();
            go(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: on ? p.lime : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Center(child: QIcon(icon, size: 23, color: on ? const Color(0xFF141412) : p.dockInk.withValues(alpha: .55))),
          ),
        ),
      );
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.dock,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(children: [
        item(0, 'home'),
        item(1, 'wallet'),
        GestureDetector(
          onTap: () {
            tap();
            setState(() => fan = !fan);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 64,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: p.lime, borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: AnimatedRotation(
                turns: fan ? .125 : 0,
                duration: const Duration(milliseconds: 220),
                child: const QIcon('plus', size: 28, color: Color(0xFF141412), stroke: 2.2),
              ),
            ),
          ),
        ),
        item(2, 'pie'),
        item(3, 'user'),
      ]),
    );
  }

  Widget _fanLayer(BuildContext context) {
    final p = context.pal;
    final items = [
      ['out', 'out', 'Шығын'],
      ['in', 'in', 'Кіріс'],
      ['tr', 'swap', 'Аударым'],
      ['scan', 'receipt', 'Чек'],
      ['import', 'upload', 'Жүктеу'],
    ];
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => fan = false),
        child: Container(
          color: Colors.black.withValues(alpha: .35),
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.only(bottom: 104 + MediaQuery.of(context).padding.bottom, left: 16, right: 16),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (ctx, v, child) => Transform.translate(offset: Offset(0, 30 * (1 - v)), child: Opacity(opacity: v.clamp(0, 1), child: child)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: p.sf, borderRadius: BorderRadius.circular(26)),
              child: Row(children: [
                for (final x in items)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        tap();
                        setState(() => fan = false);
                        Future.delayed(const Duration(milliseconds: 120), () {
                          if (!context.mounted) return;
                          if (x[0] == 'scan' || x[0] == 'import') {
                            toast('Бұл бөлім келесі жаңартуда');
                          } else {
                            openTx(context, type: x[0]);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(children: [
                          IconBox(x[1], size: 46, bg: x[0] == 'out' ? p.lime : p.sf2, fg: x[0] == 'out' ? const Color(0xFF141412) : p.ink),
                          const SizedBox(height: 6),
                          Text(t(x[2]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.ink)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
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
          listenable: Store.i,
          builder: (ctx, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: children),
        ),
      ),
    );
  }
}

void pushPage(BuildContext context, Widget Function(BuildContext) builder) {
  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ListenableBuilder(listenable: Store.i, builder: (c, _) => builder(c))));
}
