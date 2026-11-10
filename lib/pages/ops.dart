import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home.dart';
import 'tx_sheet.dart';

class OpsPage extends StatefulWidget {
  final String? accId;
  final String? cat;
  final String? mon;
  final String? type;
  const OpsPage({super.key, this.accId, this.cat, this.mon, this.type});
  @override
  State<OpsPage> createState() => _OpsPageState();
}

class _OpsPageState extends State<OpsPage> {
  String type = 'all', acc = '', q = '', cat = '', mon = '';
  int limit = 150;

  @override
  void initState() {
    super.initState();
    acc = widget.accId ?? '';
    cat = widget.cat ?? '';
    mon = widget.mon ?? '';
    type = widget.type ?? 'all';
  }

  List<J> _filtered() {
    final st = Store.i;
    final qq = q.trim().toLowerCase();
    return Store.sortTx(st.txs.where((x) {
      if (type != 'all' && x['type'] != type) return false;
      if (acc.isNotEmpty && x['acc'] != acc && x['to'] != acc && x['loan'] != acc) return false;
      if (cat.isNotEmpty && x['cat'] != cat) return false;
      if (mon.isNotEmpty && !s(x['date']).startsWith(mon)) return false;
      if (qq.isNotEmpty) {
        final a = st.acc(x['acc']);
        final str = [x['note'], x['cat'], t(s(x['cat'])), a?['name'], n(x['amt']).round(), x['date']].map(s).join(' ').toLowerCase();
        if (!str.contains(qq)) return false;
      }
      return true;
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.i;
    final p = context.pal;
    final list = _filtered();
    final groups = <String, List<J>>{};
    for (final x in list.take(limit)) {
      groups.putIfAbsent(s(x['date']), () => []).add(x);
    }
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          TopBar(t('Операциялар'), sub: '${st.txs.length} ${t('жазба')}'),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: t('Іздеу: атау, санат, сома'),
              prefixIcon: Padding(padding: const EdgeInsets.all(12), child: QIcon('search', color: p.mute)),
              fillColor: p.sf,
            ),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final x in [['all', 'Барлығы'], ['out', 'Шығын'], ['in', 'Кіріс'], ['tr', 'Аударым']])
                QChip(t(x[1]), on: type == x[0], onTap: () => setState(() => type = x[0])),
              QChip(acc.isEmpty ? t('Барлық шот') : s(st.acc(acc)?['name']), on: acc.isNotEmpty, onTap: () => _pickAcc(context)),
            ]),
          ),
          if (cat.isNotEmpty || mon.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: QChip('${t(cat)}${mon.isNotEmpty ? ' · ${monName(int.parse(mon.substring(5)) - 1)}' : ''}  ✕',
                  on: true, onTap: () => setState(() { cat = ''; mon = ''; })),
            ),
          if (list.isEmpty) Empty('search', t('Операция табылмады.')),
          for (final d in groups.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
              child: Row(children: [
                Expanded(child: Text(dayTitle(d), style: TextStyle(color: p.mute, fontWeight: FontWeight.w600, fontSize: 13.5))),
                Builder(builder: (_) {
                  double sum = 0;
                  for (final x in groups[d]!) {
                    if (x['type'] == 'in') sum += n(x['amt']);
                    if (x['type'] == 'out') sum -= n(x['amt']);
                  }
                  return Text(sum == 0 ? '' : '${sum > 0 ? '+' : '−'}${nf(sum)} ${st.sym}', style: TextStyle(color: p.mute, fontSize: 13.5, fontFeatures: kNum));
                }),
              ]),
            ),
            QList([
              for (final x in groups[d]!)
                Dismissible(
                  key: ValueKey(x['id']),
                  background: Container(color: p.sf2, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: Text(t('Түзету'))),
                  secondaryBackground: Container(color: p.neg, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Text(t('Өшіру'), style: const TextStyle(color: Colors.white))),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.startToEnd) {
                      openTx(context, editId: s(x['id']));
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (_) => delTx(context, s(x['id']), quick: true),
                  child: TxRow(x),
                ),
            ]),
          ],
          if (list.length > limit)
            QBtn('${t('Тағы көрсету')} (${list.length - limit})', kind: BtnKind.line, onTap: () => setState(() => limit += 200)),
        ]),
      ),
    );
  }

  void _pickAcc(BuildContext context) {
    final st = Store.i;
    openSheet(context, title: t('Шот'), builder: (ctx, set) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        QList([
          QRow(lead: const IconBox('wallet'), title: t('Барлық шот'), onTap: () {
            setState(() => acc = '');
            Navigator.pop(ctx);
          }),
          for (final a in st.accounts)
            QRow(lead: AccBadge(a), title: s(a['name']), onTap: () {
              setState(() => acc = s(a['id']));
              Navigator.pop(ctx);
            }),
        ]),
      ]);
    });
  }
}
