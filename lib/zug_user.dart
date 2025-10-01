import 'package:zugclient/zug_fields.dart';
import 'package:flutter/cupertino.dart';
import 'package:zugclient/zug_model.dart';

class UniqueName {
  final String name;
  final LoginType source;
  const UniqueName(this.name,this.source);
  factory UniqueName.fromData(Map<String,dynamic>? data, {defaultName = const UniqueName("?",LoginType.none),}) {
    if (data == null) return defaultName;

    return UniqueName(
        data[fieldUniqueName]?[fieldName] ?? data[fieldName] ?? "?",
        data[fieldUniqueName]?[fieldAuthSource] ?? data[fieldAuthSource] ?? "?"
    );
  }

  bool eq(UniqueName? uName) {
    if (uName == null) return false;
    return (uName.name == name && uName.source == source);
  }

  dynamic toJSON() {
    return { fieldName : name, fieldAuthSource : source };
  }

  @override
  String toString() {
    return "$name@$source";
  }
}

class UserWidget extends StatelessWidget {
  final UniqueName uName;
  final double? width, height;

  const UserWidget({super.key, required this.uName, this.width, this.height});

  String _getAuthIconPath() {
    return switch (uName.source) {
      LoginType.none => 'assets/images/google_logo.jpg',
      LoginType.bot => 'assets/images/lichess_logo.jpg',
      LoginType.lichess => 'assets/images/bot_logo.png',
      LoginType.google => 'assets/images/guest_logo.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style;
    final fontSize = textStyle.fontSize ?? 14.0;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: uName.name),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Image.asset(
                _getAuthIconPath(),
                height: fontSize * 1.2, // Slightly larger than text
                width: fontSize * 1.2,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

