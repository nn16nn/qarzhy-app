import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/i18n.dart';
import 'core/pro.dart';
import 'core/store.dart';
import 'pages/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.load();
  await Pro.i.init();
  runApp(const QarzhyApp());
  // Курсты фонда жаңарту (тәулігіне бір рет)
  final fx = Store.i.db['fx'];
  final at = fx is Map ? DateTime.tryParse('${fx['at']}') : null;
  if (at == null || DateTime.now().difference(at).inHours > 20) Store.i.fetchRate();
}

class QarzhyApp extends StatefulWidget {
  const QarzhyApp({super.key});
  @override
  State<QarzhyApp> createState() => _QarzhyAppState();
}

class _QarzhyAppState extends State<QarzhyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) Store.i.flush();
    if (state == AppLifecycleState.resumed) Pro.i.sync();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final th = Store.i.theme;
        gLang = '${Store.i.db['lang']}';
        final mode = th == 'dark' ? ThemeMode.dark : th == 'light' ? ThemeMode.light : ThemeMode.system;
        return MaterialApp(
          title: 'Qarzhy',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          theme: buildTheme(Pal.light),
          darkTheme: buildTheme(Pal.darkPal),
          themeMode: mode,
          builder: (ctx, child) {
            final dark = Theme.of(ctx).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: ctx.pal.bg),
              child: child!,
            );
          },
          home: Shell(),
        );
      },
    );
  }
}
