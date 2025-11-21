import 'package:zugclient/zug_fields.dart';
import 'package:flutter/material.dart';
import 'package:zugclient/zug_model.dart';

class UniqueName {
  final String name;
  final LoginType source;
  const UniqueName(this.name,this.source);
  factory UniqueName.fromData(Map<String,dynamic>? data, {defaultName = const UniqueName("?",LoginType.none),}) {
    if (data == null) return defaultName;

    return UniqueName(
        data[fieldUniqueName]?[fieldName] ?? data[fieldName] ?? "?",
        LoginType.fromString(data[fieldUniqueName]?[fieldAuthSource] ?? data[fieldAuthSource] ?? "?") ?? LoginType.none);
  }

  bool eq(UniqueName? uName) {
    if (uName == null) return false;
    return (uName.name == name && uName.source == source);
  }

  dynamic toJSON() {
    return { fieldName : name, fieldAuthSource : source.name };
  }

  Widget toWidget({ Color? color, Color? bkgColor}) {
    return Row(children: [
      source.icon,
      Text(name,style: TextStyle(color: color, backgroundColor: bkgColor)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (other is UniqueName) return eq(other);
    return false;
  }

  @override
  String toString() {
    return "$name@${source.name}";
  }

  @override
  // TODO: implement hashCode
  int get hashCode => name.hashCode + source.hashCode;

}

class UserWidget extends StatelessWidget {
  final UniqueName uName;
  final double? width, height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final double scale; // font size vs box height
  final double minFontSize;

  const UserWidget({
    super.key,
    required this.uName,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.scale = 0.6,
    this.minFontSize = 10, // 👈 never shrink below this
  });

  String _getAuthIconPath() {
    String name = switch (uName.source) {
      LoginType.none => 'guest.png',
      LoginType.bot => 'bot.png',
      LoginType.lichess => 'lichess_logo.png',
      LoginType.google => 'google_logo.png',
    };
    return 'images/$name';
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle =
    color == null ? DefaultTextStyle.of(context).style : TextStyle(color: color);

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints bc) {
        // Compute effective height
        final effectiveHeight = bc.maxHeight < (height ?? 1024)
            ? bc.maxHeight
            : height ??
            (bc.hasBoundedHeight && bc.maxHeight < double.infinity
                ? bc.maxHeight
                : (baseStyle.fontSize ?? 14.0) * 2);

        // Scale font size, but clamp it so it’s never too tiny
        final fontSize = (effectiveHeight * scale).clamp(minFontSize, double.infinity);

        return SizedBox(
          width: width,
          height: height,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: uName.name,
                  style: baseStyle.copyWith(fontSize: fontSize),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.ideographic,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Image.asset(
                      _getAuthIconPath(),
                      package: "zugclient",
                      height: fontSize * 1.2,
                      width: fontSize * 1.2,
                      fit: BoxFit.contain,
                      color: (uName.source == LoginType.google) ? null : color ?? baseStyle.color,
                      colorBlendMode: colorBlendMode,
                    ),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
