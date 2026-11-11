import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/i18n.dart';
import '../core/store.dart';
import 'icons_data.dart';
import 'theme.dart';

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Веб-нұсқадағы ic() — сызықтық белгіше
class QIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final double stroke;
  const QIcon(this.name, {super.key, this.size = 20, this.color, this.stroke = 1.8});

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? context.pal.ink;
    final path = kIcons[name] ?? kIcons['other']!;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(c)}" stroke-width="$stroke" '
        'stroke-linecap="round" stroke-linejoin="round">$path</svg>';
    return SizedBox(width: size, height: size, child: SvgPicture.string(svg, width: size, height: size));
  }
}

/// Санат белгішесі (түсті шаршы)
class CatIcon extends StatelessWidget {
  final String? cat;
  final double size;
  const CatIcon(this.cat, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final m = catMeta(cat);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: m.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .35)),
      alignment: Alignment.center,
      child: QIcon(m.icon, size: size * .48, color: m.color),
    );
  }
}

class IconBox extends StatelessWidget {
  final String icon;
  final Color? bg, fg;
  final double size;
  const IconBox(this.icon, {super.key, this.bg, this.fg, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? p.sf2, borderRadius: BorderRadius.circular(size * .35)),
      alignment: Alignment.center,
      child: QIcon(icon, size: size * .48, color: fg ?? p.ink),
    );
  }
}

/// Шот белгішесі: банк логотипі немесе белгіше
class AccBadge extends StatelessWidget {
  final J? a;
  final double size;
  const AccBadge(this.a, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final b = bankOf(a?['name']?.toString());
    if (b != null && b.logo != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .35), border: Border.all(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/banks/${b.logo}.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
      );
    }
    if (b != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: b.bg, borderRadius: BorderRadius.circular(size * .35)),
        alignment: Alignment.center,
        child: Text(b.short, style: TextStyle(color: b.fg, fontWeight: FontWeight.w700, fontSize: 14)),
      );
    }
    if (a?['kind'] == 'debt') return const IconBox('card', bg: Color(0x1FB9750F), fg: Color(0xFFB9750F));
    final ic = a?['icon']?.toString();
    return IconBox(ic != null && kIcons.containsKey(ic) ? ic : 'wallet');
  }
}

/// Ақ карточка
class QCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsets margin;
  const QCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.margin = const EdgeInsets.only(top: 12)});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? p.sf,
        borderRadius: BorderRadius.circular(22),
        boxShadow: p.dark ? null : const [BoxShadow(color: Color(0x14141412), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -14)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap == null ? null : () { tap(); onTap!(); },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return box;
  }
}

void tap() => HapticFeedback.selectionClick();

/// Тізім (бір карточка ішінде бірнеше жол)
class QList extends StatelessWidget {
  final List<Widget> children;
  const QList(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(Divider(height: 1, thickness: 1, color: p.line.withValues(alpha: .7), indent: 0));
      out.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: p.sf,
        borderRadius: BorderRadius.circular(22),
        boxShadow: p.dark ? null : const [BoxShadow(color: Color(0x14141412), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -14)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: out),
    );
  }
}

/// Тізім жолы: белгіше · атау/сипаттама · сома
class QRow extends StatelessWidget {
  final Widget lead;
  final String title;
  final String? sub;
  final Widget? trail;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const QRow({super.key, required this.lead, required this.title, this.sub, this.trail, this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap == null ? null : () { tap(); onTap!(); },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            lead,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink)),
                if (sub != null && sub!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.mute, fontFeatures: kNum)),
                  ),
              ]),
            ),
            if (trail != null) ...[const SizedBox(width: 10), trail!],
          ]),
        ),
      ),
    );
  }
}

/// Оң жақтағы сома (+ кіші жазу)
class Amt extends StatelessWidget {
  final String text;
  final Color? color;
  final String? small;
  const Amt(this.text, {super.key, this.color, this.small});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color ?? p.ink, fontFeatures: kNum, letterSpacing: -.2)),
      if (small != null && small!.isNotEmpty) Text(small!, style: TextStyle(fontSize: 12, color: p.mute, fontFeatures: kNum)),
    ]);
  }
}

/// Бөлім тақырыбы (+ оң жақтағы сілтеме)
class SecHead extends StatelessWidget {
  final String title;
  final String? action;
  final String? actionIcon;
  final VoidCallback? onAction;
  const SecHead(this.title, {super.key, this.action, this.actionIcon, this.onAction});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 0, 0),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -.2))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: p.mute, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (actionIcon != null) ...[QIcon(actionIcon!, size: 17, color: p.mute), const SizedBox(width: 4)],
              Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
      ]),
    );
  }
}

/// Кілт — мән жолы
class Kv extends StatelessWidget {
  final String k;
  final String v;
  final Color? vColor;
  const Kv(this.k, this.v, {super.key, this.vColor});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withValues(alpha: .7)))),
      child: Row(children: [
        Expanded(child: Text(k, style: TextStyle(color: p.mute, fontSize: 14.5))),
        const SizedBox(width: 12),
        Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: vColor ?? p.ink, fontFeatures: kNum))),
      ]),
    );
  }
}

enum BtnKind { main, lime, line, red }

class QBtn extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool small;
  const QBtn(this.label, {super.key, this.icon, this.onTap, this.kind = BtnKind.main, this.small = false});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case BtnKind.main:
        bg = p.ink;
        fg = p.bg;
      case BtnKind.lime:
        bg = p.lime;
        fg = p.limeInk;
      case BtnKind.line:
        bg = Colors.transparent;
        fg = p.ink;
        side = BorderSide(color: p.line, width: 1.5);
      case BtnKind.red:
        bg = p.neg.withValues(alpha: .1);
        fg = p.neg;
    }
    return Padding(
      padding: EdgeInsets.only(top: small ? 0 : 10),
      child: SizedBox(
        width: small ? null : double.infinity,
        height: small ? 42 : 54,
        child: TextButton(
          onPressed: onTap == null ? null : () { tap(); onTap!(); },
          style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 14 : 18), side: side),
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[QIcon(icon!, size: small ? 17 : 19, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: small ? 14 : 16, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

class QChip extends StatefulWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? sub;
  const QChip(this.label, {super.key, required this.on, required this.onTap, this.sub});
  @override
  State<QChip> createState() => _QChipState();
}

class _QChipState extends State<QChip> with SingleTickerProviderStateMixin {
  // таңдалғанда серпімді секіреді; виджет ағашы өзгермейді, сондықтан басу ешқашан жоғалмайды
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: 1);
  late final Animation<double> sc = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: .88, end: 1.06).chain(CurveTween(curve: Curves.easeOut)), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
  ]).animate(c);

  @override
  void didUpdateWidget(covariant QChip old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final on = widget.on;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ScaleTransition(
        scale: sc,
        child: Material(
          color: on ? p.ink : p.sf2,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () {
              tap();
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: widget.label, style: TextStyle(color: on ? p.bg : p.ink, fontWeight: FontWeight.w500, fontSize: 14)),
                if (widget.sub != null) TextSpan(text: '  ${widget.sub}', style: TextStyle(color: (on ? p.bg : p.ink).withValues(alpha: .6), fontSize: 12, fontFeatures: kNum)),
              ])),
            ),
          ),
        ),
      ),
    );
  }
}

/// Сегменттелген ауыстырғыш (Шығын | Кіріс | Аударым)
class QSeg extends StatelessWidget {
  final List<List<String>> items; // [[value, label], ...]
  final String value;
  final ValueChanged<String> onChanged;
  const QSeg({super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final idx = items.indexWhere((x) => x[0] == value).clamp(0, items.length - 1);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.sf2, borderRadius: BorderRadius.circular(15)),
      child: LayoutBuilder(builder: (ctx, c) {
        final w = c.maxWidth / items.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: kSpring,
            left: idx * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                color: p.dark ? p.sf : Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1))],
              ),
            ),
          ),
          Row(children: [
            for (final x in items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { tap(); onChanged(x[0]); },
                  child: Center(
                    child: Text(x[1], style: TextStyle(fontWeight: x[0] == value ? FontWeight.w600 : FontWeight.w500, color: x[0] == value ? p.ink : p.mute, fontSize: 14.5)),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Прогресс жолағы
class QProg extends StatelessWidget {
  final double value;
  final Color? color;
  const QProg(this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 7,
        color: p.sf2,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: value.clamp(0.0, 1.0), child: Container(color: color ?? p.ink)),
      ),
    );
  }
}

class Empty extends StatelessWidget {
  final String icon;
  final String text;
  const Empty(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return QCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(children: [
        Opacity(opacity: .6, child: QIcon(icon, size: 30, color: p.mute)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.mute, fontSize: 14, height: 1.4)),
      ]),
    );
  }
}

/// Бет тақырыбы (артқа батырмасымен)
class TopBar extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? right;
  final bool back;
  const TopBar(this.title, {super.key, this.sub, this.right, this.back = true});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(children: [
        if (back) ...[
          RoundBtn('left', onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: back ? 26 : 34, fontWeight: FontWeight.w700, letterSpacing: -.8, color: p.ink, height: 1.1)),
            if (sub != null) Text(sub!, style: TextStyle(color: p.mute, fontSize: 14, fontFeatures: kNum)),
          ]),
        ),
        if (right != null) right!,
      ]),
    );
  }
}

class RoundBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const RoundBtn(this.icon, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.sf,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () { tap(); onTap(); },
        child: SizedBox(width: 46, height: 46, child: Center(child: QIcon(icon, size: 21, color: p.ink))),
      ),
    );
  }
}

// ================= ПАРАҚ, ХАБАР, СҰРАҚ =================

/// Төменнен шығатын парақ
Future<T?> openSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext ctx, StateSetter set) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 420), reverseDuration: Duration(milliseconds: 240)),
    backgroundColor: context.pal.sf,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final p = ctx.pal;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .92),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.5, color: p.ink))),
                  Material(
                    color: p.sf2,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: SizedBox(width: 38, height: 38, child: Center(child: QIcon('x', size: 18, color: p.ink))),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Appear(delayMs: 60, child: builder(ctx, set)),
              ]),
            ),
          ),
        );
      },
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String msg, {VoidCallback? undo}) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(t(msg)),
    duration: Duration(milliseconds: undo != null ? 4500 : 2000),
    action: undo != null ? SnackBarAction(label: t('Қайтару'), onPressed: undo, textColor: Pal.light.lime) : null,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
  ));
}

Future<bool> ask(BuildContext context, String msg, {String ok = 'Иә'}) async {
  final p = context.pal;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(t(msg), style: TextStyle(fontSize: 16, height: 1.4, color: p.ink)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Болдырмау'), style: TextStyle(color: p.mute))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(backgroundColor: p.neg, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(t(ok)),
        ),
      ],
    ),
  );
  return r == true;
}

/// Жазу өрісі (атауымен)
class Field extends StatelessWidget {
  final String label;
  final Widget child;
  const Field(this.label, this.child, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: TextStyle(color: context.pal.mute, fontSize: 13.5, fontWeight: FontWeight.w500))),
        child,
      ]),
    );
  }
}

class QInput extends StatelessWidget {
  final String? initial;
  final String? hint;
  final bool number;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const QInput({super.key, this.initial, this.hint, this.number = false, required this.onChanged, this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      autofocus: autofocus,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(hintText: hint),
      style: TextStyle(fontSize: 16, color: context.pal.ink, fontFeatures: kNum),
      onChanged: onChanged,
    );
  }
}

// ---------- анимациялар (веб нұсқадағы --spring, --ease) ----------
const Curve kSpring = Cubic(.34, 1.56, .64, 1);
const Curve kEase = Cubic(.2, .8, .2, 1);

/// Пайда болу: мөлдірліктен шығып, сәл төменнен көтеріледі (веб: pgIn / stg).
class Appear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  final int ms;
  const Appear({super.key, required this.child, this.delayMs = 0, this.dy = 10, this.ms = 380});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: kEase);
  @override
  void initState() {
    super.initState();
    if (widget.delayMs <= 0) {
      c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) c.forward();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        child: widget.child,
        builder: (ctx, child) => Opacity(
          opacity: a.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, widget.dy * (1 - a.value)), child: child),
        ),
      );
}

/// Серпімді «секіру» (веб: pop / icPop). [trigger] өзгерген сайын қайталанады.
class Pop extends StatelessWidget {
  final Widget child;
  final Object? trigger;
  final bool enabled;
  final double from;
  const Pop({super.key, required this.child, this.trigger, this.enabled = true, this.from = .85});
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: from, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: kSpring,
      child: child,
      builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
    );
  }
}

/// Басқанда сәл кішірейеді (веб: .row:active scale(.985)).
class Press extends StatefulWidget {
  final Widget child;
  final double scale;
  const Press({super.key, required this.child, this.scale = .97});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => down = true),
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(scale: down ? widget.scale : 1, duration: const Duration(milliseconds: 150), curve: kEase, child: widget.child),
      );
}
