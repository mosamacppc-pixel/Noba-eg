import 'package:flutter/material.dart';

const green = Color(0xFF04694B);
const greenD = Color(0xFF034B37);
const gold = Color(0xFFC9A24A);
const cream = Color(0xFFFBF7EE);

bool isAr(BuildContext c) => Localizations.localeOf(c).languageCode == 'ar';
String tr(BuildContext c, String ar, String en) => isAr(c) ? ar : en;
