import 'package:flutter/material.dart';

void main() => runApp(const QarzhyApp());

class QarzhyApp extends StatelessWidget {
  const QarzhyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qarzhy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Onest',
        scaffoldBackgroundColor: const Color(0xFFEFECE4),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4F45B)),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('qarzhy', style: TextStyle(fontFamily: 'Serif', fontSize: 64, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
