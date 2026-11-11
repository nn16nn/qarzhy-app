// Qarzhy Pro — Google Play арқылы жазылым / сатып алу.
//
// Сатып алу жоғалмауы үшін ережелер:
// 1. Pro күйі деректен бөлек екі файлда сақталады (support + documents).
//    «Барлық деректі өшіру» немесе көшірмеден ашу Pro-ға тимейді.
// 2. Шешуші дерек көзі — Google Play (queryPastPurchases). Қосымшаны қайта
//    орнатса немесе телефон ауыстырса, сол Google аккаунтымен өзі қалпына келеді.
// 3. Қате / интернет жоқ кезде Pro ешқашан алынбайды. Google «сатып алу жоқ»
//    деп нақты жауап берсе ғана алынады.
// 4. Төлем өткен сәтте токен бірден файлға жазылады, содан кейін Google-да
//    расталады (acknowledge). Растау үзілсе, келесі ашылғанда қайталанады —
//    3 күн ішінде расталмаса Google ақшаны қайтарып береді.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/widgets.dart' show toast;
import 'fmt.dart';
import 'i18n.dart';

typedef PJ = Map<String, dynamic>;

class ProCfg {
  /// false болса — барлық мүмкіндік тегін ашық (Pro құлпы жоқ).
  static bool on = true;
  static const trialDays = 7;
  static const freeImports = 1; // тегін нұсқада айына банк үзіндісі
  static const graceDays = 7; // интернетсіз Pro қанша күн сақталады
  static const pkg = 'io.github.nn16nn.qarzhy';
  static const skus = {'month': 'qarzhy_pro_month', 'year': 'qarzhy_pro_year', 'life': 'qarzhy_pro_life'};
  static final price = <String, String>{'month': '990 ₸', 'year': '5 990 ₸', 'life': '14 990 ₸'};
}

/// Pro-ға жабық есептегіштер
const kProCalcs = {'dep', 'inv', 'payoff', 'tax'};

class Pro extends ChangeNotifier {
  Pro._();
  static final Pro i = Pro._();

  PJ st = {};
  File? _f1, _f2;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool available = false;
  bool busy = false;
  final Map<String, ProductDetails> products = {};
  DateTime _syncAt = DateTime.fromMillisecondsSinceEpoch(0);

  InAppPurchase get _iap => InAppPurchase.instance;
  bool get _android => !kIsWeb && Platform.isAndroid;

  // ---------- сақтау ----------
  Future<void> init() async {
    try {
      final a = await getApplicationSupportDirectory();
      final b = await getApplicationDocumentsDirectory();
      _f1 = File('${a.path}/qarzhy_pro.json');
      _f2 = File('${b.path}/qarzhy_pro.json');
      st = merge(await _read(_f1!), await _read(_f2!));
      final t = st['test'];
      if (t is Map && t['gate'] == false) ProCfg.on = false;
    } catch (_) {}
    if (_android) {
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      unawaited(_boot());
    }
  }

  Future<void> _boot() async {
    try {
      available = await _iap.isAvailable();
      if (!available) return;
      await loadProducts();
      await sync(force: true);
    } catch (_) {}
  }

  Future<PJ> _read(File f) async {
    try {
      if (!await f.exists()) return {};
      final d = jsonDecode(await f.readAsString());
      return d is Map ? Map<String, dynamic>.from(d) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save() async {
    final txt = jsonEncode(st);
    for (final f in [_f1, _f2]) {
      if (f == null) continue;
      try {
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(txt, flush: true);
        await tmp.rename(f.path);
      } catch (_) {}
    }
  }

  /// Екі көзден ең «жақсы» күйді алады — ешнәрсе жоғалмайды.
  static PJ merge(PJ a, PJ b) {
    final r = Map<String, dynamic>.from(a);
    if (b['trialStart'] != null && (r['trialStart'] == null || n(b['trialStart']) < n(r['trialStart']))) r['trialStart'] = b['trialStart'];
    if (b['sku'] != null && (r['sku'] == null || n(b['checkedAt']) > n(r['checkedAt']))) {
      for (final k in ['sku', 'token', 'life', 'checkedAt']) {
        r[k] = b[k];
      }
    }
    if (b['pending'] != null && r['pending'] == null) r['pending'] = b['pending'];
    final bi = b['imp'], ri = r['imp'];
    if (bi is Map && (ri is! Map || s(bi['m']).compareTo(s(ri['m'])) > 0 || (bi['m'] == ri['m'] && n(bi['n']) > n(ri['n'])))) r['imp'] = bi;
    if (b['test'] != null && r['test'] == null) r['test'] = b['test'];
    return r;
  }

  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  // ---------- күй ----------
  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// -1 — сынақ әлі басталмаған, 0 — бітті, >0 — қалған күн.
  int get trialLeft {
    if (st['trialStart'] == null) return -1;
    final d = ProCfg.trialDays - ((_now - n(st['trialStart'])) / 864e5).floor();
    return d > 0 ? d : 0;
  }

  bool get paid {
    final t = st['test'];
    if (t is Map && t['pro'] == true) return true;
    if (st['sku'] == null) return false;
    if (st['life'] == true) return true;
    return _now - n(st['checkedAt']) < ProCfg.graceDays * 864e5;
  }

  bool get isPro => !ProCfg.on || paid || trialLeft > 0;
  bool get isTest => st['test'] is Map && (st['test'] as Map)['pro'] == true;

  String get planName {
    final k = ProCfg.skus.entries.where((e) => e.value == st['sku']).map((e) => e.key).firstOrNull;
    if (isTest && k == null) return 'Test';
    return {'month': t('Айлық'), 'year': t('Жылдық'), 'life': t('Мәңгілік')}[k] ?? '';
  }

  // ---------- тегін импорт квотасы ----------
  int get importsLeft {
    if (isPro) return 999;
    final m = todayISO().substring(0, 7);
    final imp = st['imp'];
    final used = imp is Map && imp['m'] == m ? n(imp['n']).toInt() : 0;
    return (ProCfg.freeImports - used).clamp(0, ProCfg.freeImports);
  }

  void useImport() {
    if (isPro) return;
    final m = todayISO().substring(0, 7);
    final imp = st['imp'];
    st['imp'] = {'m': m, 'n': (imp is Map && imp['m'] == m ? n(imp['n']).toInt() : 0) + 1};
    _changed();
  }

  // ---------- сынақ ----------
  bool startTrial() {
    if (st['trialStart'] != null) return false;
    st['trialStart'] = _now;
    _changed();
    return true;
  }

  // ---------- Google Play ----------
  Future<void> loadProducts() async {
    try {
      final r = await _iap.queryProductDetails(ProCfg.skus.values.toSet());
      for (final d in r.productDetails) {
        products.putIfAbsent(d.id, () => d);
        final k = ProCfg.skus.entries.where((e) => e.value == d.id).map((e) => e.key).firstOrNull;
        if (k != null && d.price.isNotEmpty) ProCfg.price[k] = d.price;
      }
      notifyListeners();
    } catch (_) {}
  }

  void _apply(String sku, String token) {
    st['sku'] = sku;
    st['token'] = token;
    st['checkedAt'] = _now;
    st['life'] = sku == ProCfg.skus['life'];
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!ProCfg.skus.values.contains(p.productID)) continue;
      final token = p.verificationData.serverVerificationData;
      switch (p.status) {
        case PurchaseStatus.pending:
          st['pending'] = {'sku': p.productID, 'token': token, 'at': _now};
          _changed();
          toast(t('Төлем күтілуде. Расталғанда Pro өзі қосылады.'));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // ЕҢ АЛДЫМЕН сақтаймыз — кейін не болса да сатып алу жоғалмайды
          final was = paid;
          st['pending'] = {'sku': p.productID, 'token': token, 'at': _now};
          _apply(p.productID, token);
          await _save();
          await _ack(p);
          _changed();
          busy = false;
          if (!was) toast(t('Qarzhy Pro қосылды'));
          break;
        case PurchaseStatus.error:
          busy = false;
          notifyListeners();
          toast('${t('Төлем өтпеді')}: ${p.error?.message ?? ''}');
          break;
        case PurchaseStatus.canceled:
          busy = false;
          notifyListeners();
          break;
      }
    }
  }

  /// Google-да растау (acknowledge). Сәтсіз болса — келесі sync-те қайталанады.
  Future<void> _ack(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) {
      st.remove('pending');
      return;
    }
    try {
      await _iap.completePurchase(p);
      st.remove('pending');
    } catch (_) {}
  }

  /// Google Play-дағы нақты сатып алуларды тексереді.
  Future<void> sync({bool force = false}) async {
    if (!_android || !available) return;
    if (!force && DateTime.now().difference(_syncAt).inMinutes < 60) return;
    _syncAt = DateTime.now();
    try {
      final add = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await add.queryPastPurchases();
      if (r.error != null) return; // қате — ештеңе өзгертпейміз
      final mine = r.pastPurchases.where((p) => ProCfg.skus.values.contains(p.productID) && p.status != PurchaseStatus.pending).toList();
      if (mine.isEmpty) {
        // Google нақты «жоқ» деді
        if (st['sku'] != null) {
          st.remove('sku');
          st.remove('token');
          st.remove('life');
        }
        st.remove('pending');
        _changed();
        return;
      }
      mine.sort((a, b) => (b.productID == ProCfg.skus['life'] ? 1 : 0) - (a.productID == ProCfg.skus['life'] ? 1 : 0));
      final best = mine.first;
      _apply(best.productID, best.verificationData.serverVerificationData);
      await _save();
      for (final p in mine) {
        await _ack(p);
      }
      _changed();
    } catch (_) {}
  }

  Future<void> buy(String key) async {
    if (!_android) {
      toast(t('Сатып алу Play Market нұсқасында ғана'));
      return;
    }
    if (!available) {
      available = await _iap.isAvailable();
      if (!available) {
        toast(t('Google Play қолжетімсіз. Play Market-ке кіріп, қайта көріңіз.'));
        return;
      }
    }
    if (products.isEmpty) await loadProducts();
    final prod = products[ProCfg.skus[key]];
    if (prod == null) {
      toast(t('Бұл тариф Google Play-де әлі ашылмаған'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: prod));
    } catch (e) {
      busy = false;
      notifyListeners();
      toast('${t('Төлем өтпеді')}: $e');
    }
  }

  Future<void> restore() async {
    if (!_android || !available) {
      toast(t('Қалпына келтіру Play Market нұсқасында ғана'));
      return;
    }
    final was = paid;
    await sync(force: true);
    toast(paid ? (was ? t('Pro белсенді') : t('Pro қалпына келтірілді')) : t('Бұл Google аккаунтында сатып алу табылмады'));
  }

  Future<void> manage() async {
    final sku = st['sku'] != null && st['life'] != true ? '&sku=${st['sku']}' : '';
    final u = Uri.parse('https://play.google.com/store/account/subscriptions?package=${ProCfg.pkg}$sku');
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ---------- тест (тек әзірлеушіге) ----------
  void testSet({bool? gate, bool? pro, bool resetTrial = false, bool resetImports = false}) {
    final t0 = st['test'] is Map ? Map<String, dynamic>.from(st['test'] as Map) : <String, dynamic>{};
    if (gate != null) {
      t0['gate'] = gate;
      ProCfg.on = gate;
    }
    if (pro != null) t0['pro'] = pro;
    st['test'] = t0;
    if (resetTrial) st.remove('trialStart');
    if (resetImports) st.remove('imp');
    _changed();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
