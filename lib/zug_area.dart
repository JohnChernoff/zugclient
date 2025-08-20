import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_model.dart';
import 'package:zugclient/zug_option.dart';

class UniqueName {
  final String name, source;
  const UniqueName(this.name,this.source);
  factory UniqueName.fromData(Map<String,dynamic>? data, {defaultName = const UniqueName("?","?"),}) {
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

const emojiTag = "@@@";
class Message {
  UniqueName? uName;
  DateTime dateTime;
  bool fromServ;
  String message;
  Color color;
  bool hidden;

  Message(this.uName,this.message,this.dateTime,this.color,this.hidden) : fromServ = uName == null;
}

class MessageList {
  static Color foregroundColor = Colors.white;
  Map<String?,Color> userColorMap = {};
  List<Message> messages = [];
  int newMessages = 0;

  MessageList() {
    userColorMap.putIfAbsent(null, () => foregroundColor);
  }

  void addZugMsg(data) {
    StringBuffer txtBuff = StringBuffer();
    for (dynamic el in (data[fieldZugTxt] as List<dynamic>)) {
      txtBuff.write(el[fieldTxtAscii] ?? "$emojiTag${el[fieldTxtEmoji]}$emojiTag");
    }
    UniqueName uName = UniqueName.fromData(data[fieldMsgUser]);

    messages.add(Message(
        uName,
        txtBuff.toString(),
        DateTime.fromMillisecondsSinceEpoch(data[fieldMsgDate] * 1000),
        getMsgColor(uName,data),
        data[fieldHidden] ?? false));

  }

  void addMessage(data) {
    if (data[fieldZugMsg] != null) {
      addZugMsg(data[fieldZugMsg]);
    } else {
      dynamic userData = data[fieldOccupant]?[fieldUser] ?? data[fieldUser];
      UniqueName? uName = userData != null ? UniqueName.fromData(userData) : null;
      messages.add(Message(
          uName,
          data[fieldMsg],
          DateTime.now(),
          getMsgColor(uName,data),
          data[fieldHidden] ?? false));
    }
    newMessages++;
  }

  Color getMsgColor(UniqueName? uName, data) { //print("Fetching ColorMap: $userColorMap for $uName");
    return data[fieldOccupant]?[fieldChatColor] != null
        ? HexColor.fromHex(data[fieldOccupant]?[fieldChatColor])
        : userColorMap.putIfAbsent(uName.toString(), () => HexColor.rndColor(pastel: true)); //TODO: exclude server color
  }

  Message? getLastServMsg() {
    Iterable<Message> adminMsgs = messages.where((msg) => msg.fromServ);
    return adminMsgs.isNotEmpty ? adminMsgs.last : null;
  }

}

abstract class Room with Timerable {
  late final String id;
  MessageList messages = MessageList();
  Map<UniqueName,dynamic> occupantMap = {};

  Room(dynamic data) {
    id = data?[fieldAreaID] ?? ZugModel.noAreaTitle;
  }

  String getOccupantName(UniqueName name) {
    for (UniqueName uniqueName in occupantMap.keys) {
      if (uniqueName.source != name.source &&
          uniqueName.name.toLowerCase() == name.name.toLowerCase()) {
        return name.toString();
      }
    }
    return name.name;
  }

  String parseOccupantName(Map<String,dynamic> data) {
    return getOccupantName(UniqueName.fromData(data));
  }

  bool updateOccupants(Map<String,dynamic> data) {
    if (data[fieldOccupants] == null) return false;
    occupantMap.clear();
    for (dynamic occupant in data[fieldOccupants]) {
      UniqueName uname = UniqueName.fromData(occupant[fieldUser]);
      occupantMap.putIfAbsent(uname, () => occupant);
    }
    return true;
  }

  dynamic getOccupant(UniqueName? name) {
    for (UniqueName uname in occupantMap.keys) {
      if (uname.eq(name)) return occupantMap[uname];
    }
    return null;
  }

  bool containsOccupant(UniqueName? name) {
    return getOccupant(name) != null;
  }
}

enum ZugPhase {undefined}

abstract class Area extends Room {
  dynamic upData = {};
  int phaseTime = 0;
  int phaseStamp = DateTime.now().millisecondsSinceEpoch;
  Enum phase = ZugPhase.undefined;
  Map<String,ZugOption> options = {};
  bool exists = true;
  Room? currentRoom;
  Area(dynamic data) : super(data);

  List<Enum> getPhases();

  void setPhase(String p) {
    for (Enum e in getPhases()) {
      if (e.name == p) {
        phase = e; return;
      }
    }
    phase = ZugPhase.undefined;
  }

  bool updateArea(Map<String,dynamic> data) {
    upData = data; //TODO: clarify how this works
    return true; //updateOccupants(data);
  }

  void updatePhase(Map<String,dynamic> data) {
    phaseStamp = data[fieldPhaseStamp] ?? DateTime.now().millisecondsSinceEpoch;
    phaseTime = max(data[fieldPhaseTimeRemaining] ?? 0,0);
    setPhase(data[fieldPhase]);
    ZugModel.log.fine("Updating phase: $phase,$phaseTime");
  }

  int phaseTimeRemaining() => max(phaseTime - (DateTime.now().millisecondsSinceEpoch - phaseStamp),0);
  double phaseProgress() => 1 - (phaseTime > 0 ? (phaseTimeRemaining() / phaseTime) : 0);
  bool inPhase() => phaseTimeRemaining() > 0;
}

class FunctionWaiter {
  final Enum funEnum;
  final Completer<bool> completer = Completer();
  FunctionWaiter(this.funEnum);
}

class ShuffleInfo {
  Random rng = Random();
  bool shuffling;
  int? _tracks;
  int currentTrack = 0;
  final String prefix;
  final String format;
  ShuffleInfo({this.shuffling = false,this.prefix = "lobby",String? format}) :
        format = format ?? ".mp3";

  Future<int> countTracks() async {
    _tracks ??= await _countTracks();
    return _tracks ?? 0;
  }

  Future<int> _countTracks() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    return manifestMap.keys
        .where((String key) => key.startsWith('assets/audio/tracks/$prefix') &&
        key.endsWith(format)).length;
  }

  Future<int> getRandomTrack() async {
    int tracks = await countTracks();
    while(true) {
      int n = rng.nextInt(tracks) + 1;
      if (tracks < 2 || n != currentTrack) return n;
    }
  }

  @override
  String toString() {
    return "Shuffling: $shuffling, pfx: $prefix, ext: $format";
  }
}