import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const kAppVersion = '1.1.0';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final lb = DateTime.tryParse(s(st.db['lastBackup']));
    final days = lb != null ? DateTime.now().difference(lb).inDays : null;
    final fc = <String>{for (final a in st.accounts) if (st.foreign(a)) st.curOf(a)};
    if (st.base != 'USD') fc.add('USD');
    final fx = st.db['fx'];
    final rate = st.db['rate'];
    final updAt = fx is Map ? s(fx['at']) : rate is Map ? s(rate['at']) : '';

    Widget link(String icon, String title, String sub, VoidCallback onTap, {Color? titleColor}) => QRow(
          lead: IconBox(icon),
          title: title,
          sub: sub,
          trail: QIcon('right', color: p.mute),
          onTap: onTap,
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + MediaQuery.of(context).padding.bottom),
      children: [
        TopBar(t('Профиль'), back: false),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(26)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              QIcon('lock', size: 18, color: p.heroMute),
              const SizedBox(width: 8),
              Text(t('Деректер тек осы телефонда'), style: TextStyle(color: p.heroMute, fontSize: 14)),
            ]),
            const SizedBox(height: 10),
            Text('${st.txs.length} ${t('операция')} · ${st.accounts.length} ${t('шот')}', style: TextStyle(color: p.heroInk, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(days == null ? t('Көшірме әлі жасалмаған') : '${t('Соңғы көшірме')}: ${days == 0 ? t('бүгін') : '$days ${t('күн бұрын')}'}',
                style: TextStyle(color: p.heroMute, fontSize: 13)),
          ]),
        ),
        SecHead(t('Деректер')),
        QList([
          link('download', t('Деректі сақтау'), t('Файлды Drive-қа немесе поштаға сақтап қойыңыз'), () => exportData(context)),
          link('upload', t('Деректі ашу'), t('Бұрын сақталған файлдан қайтару'), () => importBackup(context)),
          link('history', t('Автокөшірмелер'), t('Соңғы 7 күн'), () => openSnaps(context)),
        ]),
        QCard(
          color: p.sf2,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            QIcon('info', color: p.mute),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('Ескі нұсқадан көшу: ескі қосымшада Профиль → «Деректі сақтау» басып, файлды осында «Деректі ашу» арқылы ашыңыз.'),
                style: TextStyle(color: p.mute, fontSize: 13.5, height: 1.4),
              ),
            ),
          ]),
        ),
        SecHead(t('Көрініс')),
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('Тақырып'), style: TextStyle(color: p.mute, fontSize: 13.5)),
            const SizedBox(height: 8),
            QSeg(
              items: [['auto', t('Авто')], ['light', t('Ашық')], ['dark', t('Қараңғы')]],
              value: st.theme,
              onChanged: (v) {
                st.db['theme'] = v;
                st.save();
              },
            ),
            const SizedBox(height: 14),
            Text(t('Тіл'), style: TextStyle(color: p.mute, fontSize: 13.5)),
            const SizedBox(height: 8),
            QSeg(
              items: [['kk', 'Қазақша'], ['ru', 'Русский'], ['en', 'English']],
              value: gLang,
              onChanged: (v) {
                st.db['lang'] = v;
                gLang = v;
                st.save();
              },
            ),
          ]),
        ),
        SecHead(t('Валюта')),
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('Негізгі валюта'), style: TextStyle(color: p.mute, fontSize: 13.5)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: st.base,
              isExpanded: true,
              items: [
                for (final c in [st.base, ...kCurs.keys.where((c) => c != st.base)])
                  DropdownMenuItem(value: c, child: Text('${symOf(c)} · $c — ${t(kCurs[c]![1])}')),
              ],
              onChanged: (v) => v == null ? null : setBase(context, v),
            ),
            for (final c in fc) Kv(c, st.fxLine(c)),
            Kv(t('Жаңартылды'), updAt.length >= 10 ? fullDate(updAt.substring(0, 10)) : '—'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: QBtn(t('Жаңарту'), icon: 'repeat', kind: BtnKind.line, small: true, onTap: () async {
                  toast(await st.fetchRate(manual: true) ? 'Курс жаңартылды' : 'Курс алынбады — интернетті тексеріңіз');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(child: QBtn(t('Қолмен'), icon: 'edit', kind: BtnKind.line, small: true, onTap: () => openRate(context, fc.toList()))),
            ]),
          ]),
        ),
        SecHead(t('Қосымша')),
        QList([
          QRow(lead: const IconBox('info'), title: 'Qarzhy $kAppVersion', sub: t('Офлайн жұмыс істейді · сервер жоқ · жарнама жоқ')),
          QRow(
            lead: IconBox('trash', fg: p.neg),
            title: t('Барлық деректі өшіру'),
            sub: t('Қайтару мүмкін емес'),
            trail: QIcon('right', color: p.mute),
            onTap: () => wipeAll(context),
          ),
        ]),
      ],
    );
  }
}

Future<void> exportData(BuildContext context) async {
  final st = Store.i;
  st.db['lastBackup'] = DateTime.now().toUtc().toIso8601String();
  await st.flush();
  final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(st.db)));
  try {
    final path = await FilePicker.saveFile(
      dialogTitle: t('Деректі сақтау'),
      fileName: 'qarzhy-${todayISO()}.json',
      bytes: bytes,
    );
    if (path != null) {
      st.save();
      toast('Сақталды');
    }
  } catch (e) {
    toast('Файл сақталмады');
  }
}

Future<void> importBackup(BuildContext context) async {
  try {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final d = jsonDecode(utf8.decode(await file.readAsBytes()));
    if (d is! Map || d['tx'] is! List) throw const FormatException();
    if (!context.mounted) return;
    if (!await ask(context, 'Қазіргі деректің орнына файлдағы дерек қойылады. Жалғастырасыз ба?', ok: 'Ашу')) return;
    Store.i.replaceAll(Map<String, dynamic>.from(d), keepLang: gLang);
    toast('Дерек ашылды');
  } catch (_) {
    toast('Файл оқылмады');
  }
}

Future<void> openSnaps(BuildContext context) async {
  final list = await Store.i.snaps();
  if (!context.mounted) return;
  openSheet(context, title: t('Автокөшірмелер'), builder: (ctx, set) {
    final p = ctx.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('Қосымша күн сайын деректің көшірмесін өзі жасайды.'), style: TextStyle(color: p.mute, fontSize: 13.5)),
      if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(t('Әзірге көшірме жоқ.'), style: TextStyle(color: p.mute)))),
      for (final x in list)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            Expanded(child: Text('${fullDate(x.day)} · ${x.count} ${t('операция')}')),
            QBtn(t('Қайтару'), kind: BtnKind.line, small: true, onTap: () async {
              if (!await ask(ctx, 'Осы күнгі күйге қайтарамыз ба?', ok: 'Қайтару')) return;
              final ok = await Store.i.restoreSnap(x.day);
              if (ctx.mounted) Navigator.pop(ctx);
              toast(ok ? 'Қайтарылды' : 'Көшірме табылмады');
            }),
          ]),
        ),
    ]);
  });
}

Future<void> setBase(BuildContext context, String code) async {
  final st = Store.i;
  if (code == st.base) return;
  final hasData = st.txs.isNotEmpty || st.accounts.any((a) => n(a['bal']) != 0);
  if (hasData && !await ask(context, 'Негізгі валюта ауысады. Бұрынғы сомалар қайта есептелмейді — тек белгісі өзгереді. Жалғастырасыз ба?', ok: 'Ауыстыру')) {
    st.save();
    return;
  }
  final old = st.base;
  st.pref['base'] = code;
  for (final a in st.accounts) {
    if (a['cur'] == null || a['cur'] == old) a['cur'] = code;
  }
  st.db['fx'] = null;
  st.save();
  st.fetchRate();
  toast('Сақталды');
}

void openRate(BuildContext context, List<String> codes) {
  final st = Store.i;
  final vals = <String, String>{for (final c in codes) c: st.fxRate(c) > 0 ? '${double.parse(st.fxRate(c).toStringAsFixed(4))}' : ''};
  openSheet(context, title: t('Курсты қолмен жазу'), builder: (ctx, set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in codes) Field('1 ${symOf(c)} ($c) = ? ${st.sym}', QInput(initial: vals[c], number: true, onChanged: (v) => vals[c] = v)),
      const SizedBox(height: 8),
      QBtn(t('Сақтау'), icon: 'check', onTap: () {
        final b = st.base;
        final fx = st.db['fx'];
        final r = (fx is Map && fx['base'] == b && fx['r'] is Map) ? Map<String, dynamic>.from(fx['r'] as Map) : <String, dynamic>{};
        final rate = st.db['rate'];
        if (b == 'KZT' && r['USD'] == null && rate is Map && n(rate['v']) > 0) r['USD'] = n(rate['v']);
        vals.forEach((c, v) {
          final x = parseNum(v);
          if (x > 0) r[c] = x;
        });
        final at = DateTime.now().toUtc().toIso8601String();
        st.db['fx'] = {'base': b, 'at': at, 'src': 'manual', 'r': r};
        if (b == 'KZT' && r['USD'] != null) st.db['rate'] = {'v': r['USD'], 'at': at, 'src': 'manual'};
        st.save();
        Navigator.pop(ctx);
        toast('Курс сақталды');
      }),
    ]);
  });
}

Future<void> wipeAll(BuildContext context) async {
  final st = Store.i;
  if (!await ask(context, 'Барлық операция, шот, мақсат және қарыз өшіріледі. Қайтару мүмкін емес. Жалғастырасыз ба?', ok: 'Өшіру')) return;
  if (!context.mounted) return;
  if (!await ask(context, 'Сенімдісіз бе? Алдымен «Деректі сақтау» жасаған жөн.', ok: 'Өшіру')) return;
  st.replaceAll({'lang': st.db['lang'], 'theme': st.db['theme'], 'rate': st.db['rate'], 'fx': st.db['fx'], 'pref': {'base': st.base}});
  toast('Барлығы өшірілді');
}
