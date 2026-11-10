import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens.dart';
import 'shopify.dart';
import 'util.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final p = await SharedPreferences.getInstance();
    final l = p.getString('lang');
    if (l != null) appLocale.value = Locale(l);
  } catch (_) {}
  runApp(const NobaApp());
}

class NobaApp extends StatelessWidget {
  const NobaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocale,
      builder: (context, loc, _) => MaterialApp(
        title: 'NOBA',
        debugShowCheckedModeBanner: false,
        locale: loc,
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
          colorScheme: ColorScheme.fromSeed(seedColor: ink, primary: ink, onPrimary: Colors.white, surface: Colors.white),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: const Color(0xFFFEFEFE), shape: const RoundedRectangleBorder(), minimumSize: const Size(0, 44)),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(foregroundColor: ink, side: const BorderSide(color: ink), shape: const RoundedRectangleBorder(), minimumSize: const Size(0, 44)),
          ),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.zero), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: line))),
          chipTheme: const ChipThemeData(shape: RoundedRectangleBorder(), backgroundColor: Colors.white, selectedColor: ink, labelStyle: TextStyle(color: ink), secondaryLabelStyle: TextStyle(color: Colors.white), checkmarkColor: Colors.white),
          dividerColor: line,
        ),
        home: Boot(key: ValueKey(loc?.languageCode)),
      ),
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
  Widget build(BuildContext context) => const HomeScreen();
}
