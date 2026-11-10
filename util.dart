import 'package:flutter/material.dart';

const ink = Color(0xFF252525);
const soft = Color(0xFFF4F4F4);
const line = Color(0xFFE3E3E3);
// gift box accents (the homepage gift feature)
const green = Color(0xFF04694B);
const greenD = Color(0xFF034B37);
const gold = Color(0xFFC9A24A);

final appLocale = ValueNotifier<Locale?>(null);

bool isAr(BuildContext c) => Localizations.localeOf(c).languageCode == 'ar';
String tr(BuildContext c, String ar, String en) => isAr(c) ? ar : en;
