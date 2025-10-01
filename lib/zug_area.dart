import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_mess.dart';
import 'package:zugclient/zug_model.dart';
import 'package:zugclient/zug_option.dart';
import 'package:zugclient/zug_user.dart';

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

abstract class Area extends Room{
  dynamic upData = {};
  int phaseTime = 0;
  int phaseStamp = DateTime.now().millisecondsSinceEpoch;
  Enum phase = ZugPhase.undefined;
  Map<String,ZugOption> options = {};
  bool exists = true;
  Room? currentRoom;
  int servTimeDiff = 0;

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
    ZugModel.log.fine("Phase Data: $data");
    phaseStamp = data[fieldPhaseStamp] ?? DateTime.now().millisecondsSinceEpoch;
    if (data[fieldPhaseCurrtime] != null) { //HOLY TIME KLUDGE BATMAN
      servTimeDiff = data[fieldPhaseCurrtime] - DateTime.now().millisecondsSinceEpoch;
      ZugModel.log.fine("Serv time diff: $servTimeDiff");
    }
    phaseTime = max(data[fieldPhaseTimeRemaining] ?? 0,0);
    setPhase(data[fieldPhase]);
    ZugModel.log.fine("Updating phase: $phase,$phaseTime");
  }

  int phaseTimeRemaining() => max(phaseTime - (DateTime.now().millisecondsSinceEpoch - phaseStamp),0) - servTimeDiff;
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