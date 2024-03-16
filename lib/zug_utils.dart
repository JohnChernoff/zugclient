import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ini/ini.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zugclient/zug_client.dart';

class ZugUtils {
  static Future<Config> getIniConfig(String assetPath) {
    return rootBundle.loadString(assetPath).then((value) => Config.fromString(value));
  }

  static Future<Map<String,String>> getIniDefaults(String assetPath) {
    return rootBundle.loadString(assetPath)
        .then((value) => Config.fromString(value), onError: (argh) => Config.fromString(""))
        .then((config) => config.defaults());
  }

  static double getActualScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height - (AppBar().preferredSize.height + kBottomNavigationBarHeight) - 8;
  }

  static double roundNumber(double value, int places) {
    num val = pow(10.0, places);
    return ((value * val).round().toDouble() / val);
  }

  static scrollDown(ScrollController scrollController, int millis, {int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay)).then((value) {
      if (scrollController.hasClients) { //in case user switched away
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: Duration(milliseconds: millis),
        );
      }
    });
  }

  static Row checkRow(ZugClient client, State state, String caption, String prop, bool defaultValue, {Function? onTrue, Function? onFalse}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("$caption:"),
        Checkbox(
            value: client.defaults?.getBool(prop) ?? defaultValue,
            onChanged: (b) {
              client.defaults?.setBool(prop, b ?? defaultValue);
              ZugClient.log.info("Setting $caption: $b");
              if ((b ?? false)) {
                if (onTrue != null) onTrue();
              } else {
                if (onFalse != null) { //ZugClient.log.info(onFalse.toString());
                  onFalse();
                }
              }
              state.setState(() {  /* prop toggled */ });
            }),
      ],
    );
  }

  static AssetImage getAssetImage(String path) {
    return AssetImage("${(kDebugMode && kIsWeb)?"":"assets/"}$path");
  }

  static Future<void> launch(String url, {bool isNewTab = true}) async {
    await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: isNewTab ? '_blank' : '_self',
    );
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
