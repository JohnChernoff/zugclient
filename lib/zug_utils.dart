import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ini/ini.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zugclient/zug_client.dart';
import 'package:http/http.dart' as http;
import 'package:zugclient/zug_fields.dart';

class ScreenDim {
  final double width,height;
  ScreenDim(this.width,this.height);
}

class ZugUtils {
  static Future<Config> getIniConfig(String assetPath) {
    return rootBundle.loadString(assetPath).then((value) => Config.fromString(value));
  }

  static Future<Map<String,String>> getIniDefaults(String assetPath) {
    return rootBundle.loadString(assetPath)
        .then((value) => Config.fromString(value), onError: (argh) => Config.fromString(""))
        .then((config) => config.defaults());
  }

  static double getActualScreenHeight(BuildContext context) { //rename to approxScreenHeight?
    return MediaQuery.of(context).size.height - (AppBar().preferredSize.height + kBottomNavigationBarHeight) - 8;
  }

  static ScreenDim getScreenDimensions(BuildContext context) {
    return ScreenDim(MediaQuery.of(context).size.width,getActualScreenHeight(context));
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

  static String getOccupantName(dynamic occupant, {short = false}) {
    return getUserName(occupant[fieldUser],short: short);
  }

  static String getUserName(dynamic user, {short = false}) {
    String name = user?[fieldUniqueName]?[fieldName] ?? "";
    return short || name.isEmpty ? name : "$name@${user?[fieldUniqueName]?[fieldAuthSource] ?? "?"}";
  }

  //TODO: remove?
  static Row checkRow(ZugClient client, String caption, String prop, bool defaultValue, Function onChange, {Function? onTrue, Function? onFalse}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("$caption:"),
        Checkbox(
            value: client.prefs?.getBool(prop) ?? defaultValue,
            onChanged: (b) {
              client.prefs?.setBool(prop, b ?? defaultValue).then((value) {
                ZugClient.log.info("Setting $caption: $b");
                onChange();
              });
              if ((b ?? false)) {
                if (onTrue != null) onTrue();
              } else {
                if (onFalse != null) { //ZugClient.log.info(onFalse.toString());
                  onFalse();
                }
              }
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

  static Future<String?> getIP() async {
    try {
      if (kIsWeb) {
        var response =
            await http.get(Uri(scheme: "https", host: 'api.ipify.org'));
        if (response.statusCode == 200) {
          ZugClient.log.fine(response.body);
          return response.body;
        } else {
          ZugClient.log.info(response.body);
          return null;
        }
      } else {
          List<NetworkInterface> list = await NetworkInterface.list();
          return list.first.addresses.first.address;
      }
    } catch (exception) {
      ZugClient.log.info(exception);
      return null;
    }
  }

  static Future<SharedPreferences?> getPrefs() async {
    return await SharedPreferences.getInstance();
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

  static Color rndColor({pastel = false}) {
    if (pastel) {
      return Color.fromRGBO(
          Random().nextInt(128) + 128,
          Random().nextInt(128) + 128,
          Random().nextInt(128) + 128, 1.0);
    }
    else {
      return Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
    }
  }



  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
