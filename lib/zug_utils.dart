import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ini/ini.dart';

class ZugUtils {
  static Future<Config> getIniConfig(String assetPath) {
    return rootBundle.loadString(assetPath).then((value) => Config.fromString(value));
  }

  static Future<Map<String,String>> getIniDefaults(String assetPath) {
    return rootBundle.loadString(assetPath).then((value) => Config.fromString(value)).then((config) => config.defaults());
  }

  static double getActualScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height - (AppBar().preferredSize.height + kBottomNavigationBarHeight) - 8;
  }
}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String? hexString, {Color defaultColor = Colors.white}) {
    if (hexString == null) return defaultColor;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static Color rndColor() {
    return Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
