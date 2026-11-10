import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens.dart';
import 'shopify.dart';
import 'util.dart';
import 'state.dart';

void main() => runApp(const NobaApp());

class NobaApp extends StatelessWidget {
  const NobaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOBA',
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (l, supported) {
        final ar = l?.languageCode == 'ar';
        apiLang = ar ? 'AR' : 'EN';
        return ar ? const Locale('ar') : const Locale('en');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green, secondary: gold),
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: greenD, elevation: 0),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white),
      ),
      home: const Boot(),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  @override
  void initState() {
    super.initState();
    CartStore.i.load();
    GiftStore.i.load();
  }

  @override
  Widget build(BuildContext context) => const Shell();
}
