import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'shell.dart';

/// Әлі көшірілмеген бөлімдер үшін уақытша бет
void openSoon(BuildContext context, String title) {
  pushPage(
    context,
    (ctx) => SubPage([
      TopBar(t(title)),
      QCard(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          IconBox('repeat', size: 52, bg: ctx.pal.lime, fg: const Color(0xFF141412)),
          const SizedBox(height: 12),
          Text(t('Бұл бөлім келесі жаңартуда'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('Деректеріңіз сақталған, ештеңе жоғалмайды.'), textAlign: TextAlign.center, style: TextStyle(color: ctx.pal.mute)),
        ]),
      ),
    ]),
  );
}
