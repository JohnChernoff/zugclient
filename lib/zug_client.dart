library zugclient;

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zug_net/oauth_client.dart';
import 'package:zug_net/zug_sock.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_option.dart';
import 'zug_fields.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

class UniqueName {
  final String name, source;
  const UniqueName(this.name,this.source);
  factory UniqueName.fromData(Map<String,dynamic>? data, {defaultName = const UniqueName("?","?"),}) {
    if (data == null) return defaultName;
    return UniqueName(data[fieldUniqueName]?[fieldName] ?? "?",data[fieldUniqueName]?[fieldAuthSource] ?? "?");
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

class Message {
  UniqueName? uName;
  bool fromServ;
  String message;
  Color color;
  bool hidden;
  Message(this.uName,this.message,this.color,this.hidden) : fromServ = uName == null;
}

class MessageList {
  static Color foregroundColor = Colors.white;
  Map<UniqueName?,Color> userColorMap = {};
  List<Message> messages = [];
  int newMessages = 0;

  MessageList() {
    userColorMap.putIfAbsent(null, () => foregroundColor);
  }

  void addMessage(data) {
    dynamic userData = data[fieldOccupant]?[fieldUser] ?? data[fieldUser];
    UniqueName? uName = userData != null ? UniqueName.fromData(userData) : null;
    Color color = data[fieldOccupant]?[fieldChatColor] != null
        ? HexColor.fromHex(data[fieldOccupant]?[fieldChatColor])
        : userColorMap.putIfAbsent(uName, () => HexColor.rndColor(pastel: true));
    messages.add(Message(uName,data[fieldMsg],color,data[fieldHidden] ?? false));
    newMessages++;
  }

  Message? getLastServMsg() {
    Iterable<Message> adminMsgs = messages.where((msg) => msg.fromServ);
    return adminMsgs.isNotEmpty ? adminMsgs.last : null;
  }

}

abstract class Room with Timerable {
  late final String title;
  MessageList messages = MessageList();
  Map<UniqueName,dynamic> occupantMap = {};

  Room(dynamic data) {
    title = data?[fieldTitle] ?? ZugClient.noAreaTitle;
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

abstract class Area extends Room {
  dynamic listData = {};
  Map<String,ZugOption> options = {};
  bool exists = true;
  Room? currentRoom;
  Area(dynamic data) : super(data);

  bool updateArea(Map<String,dynamic> data) {
    listData = data; //TODO: eeeeh
    return true; //updateOccupants(data);
  }
}

class FunctionWaiter {
  final Enum funEnum;
  final Completer<bool> completer = Completer();
  FunctionWaiter(this.funEnum);
}

enum ZugOpt {sound,soundVol,music,musicVol}
enum LoginType {none,lichess}

abstract class ZugClient extends ChangeNotifier {
  static const optPrefix = "ZugClientOption";
  static final log = Logger('ClientLogger');
  static const noAreaTitle = "";
  static const servString = "serv";
  static const LoginType defLogType = LoginType.lichess;

  bool showServMess;
  bool localServer;
  bool noServer = false;
  String clientName = "ZugClient";
  PackageInfo? packageInfo;
  String domain;
  int port;
  String remoteEndpoint;
  UniqueName? userName;
  String areaName = "Area";
  bool isConnected = false;
  bool isLoggedIn = false;
  bool authenticating = false;
  ZugSock? sock;
  oauth2.Client? authClient; // = oauth2.Client(oauth2.Credentials(""));
  Map<String,Area> areas = {};
  MessageList messages = MessageList();
  late final Area noArea;
  late Area currentArea; //Area(noAreaTitle);
  final Map<Enum,Function> _functionMap = {};
  FunctionWaiter? _funWaiter;
  PageType switchPage = PageType.none;
  PageType selectedPage = PageType.none;
  SharedPreferences? prefs;
  final Map<String,ZugOption> _options = {};
  LoginType? loginType;
  String? serverVersion;
  final clipPlayer = AudioPlayer();
  final trackPlayer = AudioPlayer();
  double volume = .5;
  static bool defaultSound = false;
  int? id;
  bool autoLog = false;
  String? autoJoinTitle;
  StreamSubscription<void>? _endClipListener,_endTrackListener;
  Area createArea(dynamic data);

  ZugClient(this.domain,this.port,this.remoteEndpoint, this.prefs, {this.showServMess = false, this.localServer = false}) {
    //_endClipListener = clipPlayer.onPlayerComplete.listen((v) => log.info("done"));
    log.info("Prefs: ${prefs.toString()}");
    loadOptions([
      ZugOption.fromEnum(ZugOpt.sound,false),
      ZugOption.fromEnum(ZugOpt.soundVol,50,min: 0, max: 100, inc: 1,label: "Sound Volume"),
      ZugOption.fromEnum(ZugOpt.music,false),
      ZugOption.fromEnum(ZugOpt.musicVol,50,min: 0, max: 100, inc: 1,label: "Music Volume"),
    ]);
    noArea = createArea(null);
    currentArea = noArea;
    PackageInfo.fromPlatform().then((PackageInfo info) {
      packageInfo = info;
      log.info(info.toString());
      notifyListeners(); //why?
    });
    addFunctions({
      ServMsg.none: handleNoFun,
      ServMsg.ping: handlePing,
      ServMsg.obs: handleObs,
      ServMsg.unObs: handleUnObs,
      ServMsg.reqLogin: handleLogin,
      ServMsg.noLog: loggedOut,
      ServMsg.logOK: loggedIn,
      ServMsg.errMsg: handleErrorMsg,
      ServMsg.alertMsg: handleAlertMsg,
      ServMsg.privMsg: handlePrivMsg,
      ServMsg.servMsg: handleServMsg,
      ServMsg.servUserMsg: handleServMsg,
      ServMsg.areaMsg: handleAreaMsg,
      ServMsg.areaUserMsg: handleAreaMsg,
      ServMsg.areaList: handleAreaList,
      ServMsg.joinArea : handleJoin,
      ServMsg.partArea : handlePart,
      ServMsg.startArea : handleStart,
      ServMsg.updateArea: handleUpdateArea,
      ServMsg.createArea : handleCreateArea,
      ServMsg.updateOccupant: handleUpdateOccupant,
      ServMsg.updateOccupants: handleUpdateOccupants,
      ServMsg.updateOptions: handleUpdateOptions,
      ServMsg.updateAreaList: handleUpdateAreaList,
      ServMsg.version: handleVersion,
    });
    connect();
  }

  void addFunctions(Map<Enum, Function> functions) {
    _functionMap.addAll(functions);
  }

  Map<Enum,Function> getFunctions() { return _functionMap; }

  Future<bool> awaitMsg(Enum msgEnum) {
    if (_funWaiter?.completer.isCompleted == false) _funWaiter?.completer.complete(false);
    _funWaiter = FunctionWaiter(msgEnum);
    return _funWaiter!.completer.future;
  }

  void newArea({String? title}) {
    if (title != null) {
      send(ClientMsg.newArea, data: {fieldTitle: title});
    }
    else {
      ZugDialogs.getString('Choose Game Title',userName?.name ?? "?")
          .then((t) => send(ClientMsg.newArea, data: {fieldTitle: t}));
    }
  }

  void seekArea() {
    send(ClientMsg.joinArea);
  }

  void joinArea(String title) {
    areaCmd(ClientMsg.joinArea,title: title);
  }

  void partArea() {
    areaCmd(ClientMsg.partArea);
  }

  void startArea() {
    areaCmd(ClientMsg.startArea);
  }

  void handleCmdMsg(List<String> msgs) {
      if (msgs.isNotEmpty) {
        if (msgs.first == "!srv") send(ClientMsg.updateServ);
      }
  }

  Area getOrCreateArea(dynamic data) {
    return areas.putIfAbsent(data?[fieldTitle] ?? noAreaTitle, () {
      return createArea(data);
    });
  }

  void areaCmd(Enum cmd, { String? title, Map<String,dynamic> data = const {}}) {
    if (data.isEmpty) {
      send(cmd,data: { fieldTitle : title ??  currentArea.title});
    } else {
      Map<String,dynamic> args = Map<String,dynamic>.from(data);
      args[fieldTitle] = title ?? currentArea.title;
      send(cmd,data:args);
    }
  }

  void setSwitchPage(PageType p) {
    switchPage = p;
  }

  void switchArea(String? title) {
    final t = title ?? noAreaTitle;
    if (currentArea.title != t) {
      if (areas[t] != null) {
        if (currentArea.exists) send(ClientMsg.unObs,data:{ fieldTitle : currentArea.title });
        currentArea = areas[t]!; // ?? noGame;
        if (currentArea.exists ) {
          send(ClientMsg.obs,data:{fieldTitle:currentArea.title});
          send(ClientMsg.updateArea,data:{fieldTitle:title});
        }
      }
      else {
        currentArea = noArea;
        update(); //TODO: can this be done for all games?
      }
      log.info("Switched to game: ${currentArea.title}");
    }
  }

  Enum handleMsg(dynamic msg) {
    if (showServMess) {
      log.info("Incoming msg: $msg"); //print(msg); print(""); print("***"); print("");
    }
    else {
      log.fine("Incoming msg: $msg");
    }
    final json = jsonDecode(msg);
    String type = json[fieldType]; //logMsg("Handling: $type");
    Enum funEnum = _functionMap.keys.singleWhere((element) => element.name == type, orElse: () => ClientMsg.none);
    Function? fun = _functionMap[funEnum];
    if (fun != null) {
      if (fun.runtimeType != bool) {
        fun(json[fieldData]); notifyListeners();
      } else if (fun(json[fieldData])) {
        notifyListeners();
      }
      if (_funWaiter?.funEnum == funEnum) {
        _funWaiter?.completer.complete(true);
      }
    } else {
      log.warning("Function not found: $type");
    }
    return funEnum;
  }

  void handleNoFun(data) {
    log.warning("Ergh");
  }

  bool handlePing(data) {
    send(ClientMsg.pong);
    return false;
  }

  void handleVersion(data) { //print(data);
    serverVersion = data[fieldMsg];
  }

  void handleObs(data) {
    log.info("Observing: ${data[fieldTitle]}");
  }

  void handleUnObs(data) {
    log.info("No longer observing: ${data[fieldTitle]}");
  }

  bool handleCreateArea(data) { //print("Created Area: $data"); //TODO: create defaultJoin property?
    //joinArea(data[fieldTitle]); //send(ClientMsg.joinArea,data : {fieldTitle: }); Area area = getOrCreateArea(data);
    log.info("Created: $data");
    return true;
  }

  bool handleUpdateOccupant(data) { log.fine("Occupant update: $data");
    Area area = getOrCreateArea(data);
    area.occupantMap.putIfAbsent(UniqueName.fromData(data["user"]), () => data);
    return true;
  }

  bool handleUpdateArea(data) { log.fine("Update Area: $data");
    Area area = getOrCreateArea(data);
    handleUpdateOccupants(data,area : area); //TODO: why use named argument?
    handleUpdateOptions(data,area : area);
    area.updateArea(data);
    return true;
  }

  bool handleUpdateOccupants(data, {Area? area}) {
    area = area ?? getOrCreateArea(data);
    return area.updateOccupants(data);
  }

  bool handleUpdateOptions(data, {Area? area}) { //print("Options: $data");
    if (data[fieldOptions] != null) {
      area = area ?? getOrCreateArea(data);

      Map<String,dynamic> optionList = data[fieldOptions] as Map<String,dynamic>;
      area.options.clear();

      print(optionList.keys);

      for (String field in optionList.keys) {
        print ("key: $field");
        print(optionList[field].toString());
        area.options[field] = ZugOption.fromJson(optionList[field]) ?? ZugOption("?", null);
      }
      return true;
    }
    return false;
  }
  
  void fetchOptions(Function onOption, {int timeLimit = 5000}) async {
    awaitMsg(ServMsg.updateOptions)
        .timeout(Duration(milliseconds: timeLimit))
        .then((b) => onOption.call())
        .catchError((e) => ZugDialogs.popup("Error Fetching Options: $e"));
    areaCmd(ClientMsg.getOptions);
  }

  void addAreaMsg(String msg, String title, {hidden = false}) {
    handleAreaMsg({
      fieldMsg : msg,
      fieldTitle : title,
      fieldHidden : hidden
    });
  }

  bool handleAreaMsg(data, {Area? area}) { //print(data);
    area = area ?? getOrCreateArea(data);
    area.messages.addMessage(data);
    return true;
  }

  void addServMsg(String msg, {hidden = false}) {
    handleServMsg({
      fieldMsg : msg,
      fieldHidden : hidden
    });
  }

  bool handleServMsg(data) {
    messages.addMessage(data);
    return true;
  }

  bool handlePrivMsg(data) { //print("Private message from: ${data[fieldUser]}");
    addServMsg("Private Message from ${UniqueName.fromData(data[fieldUser])}: ${data[fieldMsg]}");
    return true;
  }

  bool handleErrorMsg(data) {
    ZugDialogs.popup("Error: ${data[fieldMsg]}");
    return true;
  }

  bool handleAlertMsg(data) {
    ZugDialogs.popup("Alert: ${data[fieldMsg]}");
    return true;
  }

  void handleJoin(data) { //print("Joining");
    switchArea(data[fieldTitle]);
  }

  void handlePart(data) { //print("Parting: $data");
    addServMsg("Leaving: ${data[fieldTitle]}");
  }

  void handleStart(data) {
    handleUpdateArea(data);
    switchPage = PageType.main;
  }

  bool handleAreaList(data) { //print("Area List: $data");
    for (Area area in areas.values) {
      area.exists = false;
    }
    for (var area in data[fieldAreas]) {
      Area a = getOrCreateArea(area);
      a.exists = true;
      a.updateOccupants(area); //a.updateArea(area);
    }
    areas.removeWhere((key, value) => !value.exists);
    if (currentArea != noArea && !currentArea.exists) {
      currentArea = noArea;
    }
    return true;
  }

  bool handleUpdateAreaList(data) { //print("Area List Update: $data");
    Area area = getOrCreateArea(data[fieldArea]);
    if (data[fieldAreaChange] == AreaChange.created.name) {
      area.exists = true;
      area.updateOccupants(data[fieldArea]); //area.updateArea(data[fieldArea]);
    }
    else if (data[fieldAreaChange] == AreaChange.deleted.name) { //print("Removing: ${area.title}");
      areas.remove(area.title);
      if (currentArea.title == area.title) switchArea(noAreaTitle);
    }
    else if (data[fieldAreaChange] == AreaChange.updated.name) {
      area.updateOccupants(data[fieldArea]); //area.updateArea(data[fieldArea]);
    }
    return true;
  }

  void checkRedirect(String host) {
    checkRedirectOauth(OauthClient(host,clientName));
  }
  //TODO: generalize
  void checkRedirectOauth(OauthClient oauthClient) {
    if (kIsWeb) {
      String code = Uri.base.queryParameters["code"]?.toString() ?? "";
      if (code.isNotEmpty) {
        authenticating = true;
        html.window.history.pushState(null, 'home', Uri.base.path);
        log.info("Redirecting login...");
        oauthClient.decode(code, handleAuthClient);
      }
      else {
        checkGoto();
      }
    }
  }

  void checkGoto() {
    String goto = Uri.base.queryParameters["goto"]?.toString() ?? "";
    if (goto.isNotEmpty) {
      html.window.history.pushState(null, 'home', Uri.base.path);
      autoJoinTitle = goto;
      log.info("Autologging into game: $autoJoinTitle");
      autoLogin();
    }
  }

  void autoLogin() {
     autoLog = true;
     LoginType logType = defLogType;
     String? prevLogType = prefs?.getString(fieldLoginType);
     for (LoginType lt in LoginType.values) {
       if (lt != LoginType.none && lt.name == prevLogType) logType = lt;
     }
     login(logType);
  }

  void authenticate(OauthClient oauthClient) {
    log.info("Authenticating");
    authenticating = true;
    oauthClient.authenticate(handleAuthClient);
  }

  void handleAuthClient(oauth2.Client? client) {
    log.info("Handling auth client...");
    authClient = client;
    authenticating = false;
    if (!isLoggedIn) { //TODO: handle other login types
      login(LoginType.lichess);
    }
  }

  bool handleLogin(data) { //TODO: create login dialog?
    id = data[fieldID]; log.info("Connection ID: $id");
    if (!autoLog && loginType != null) {
      login(loginType);
    }
    return false;
  }

  void login(LoginType? lt) {
    //autoLog = false;
    if (isConnected) {
      prefs?.setString(fieldLoginType, lt.toString());
      loginType = lt ?? LoginType.none;
      if (loginType == LoginType.lichess) {
        if (isAuthenticated()) {
          log.info("Logging in with token");
          send(ClientMsg.login, data: { fieldLoginType: LoginType.lichess.name, fieldToken : authClient?.credentials.accessToken });
        }
        else {
          authenticate(OauthClient("lichess.org", clientName));
        }
      }
      else if (loginType == LoginType.none) {
        log.info("Logging in as guest");
        send(ClientMsg.login, data: { fieldLoginType: LoginType.none.name });
      }
      notifyListeners();
    }
    else {
      ZugDialogs.popup("Not connected to server");
    }
  }

  void update() {
    notifyListeners();
  }

  void connect()  {
    String address = getWebSockAddress();
    log.info("Connecting to $address");
    sock = ZugSock(address,connected,handleMsg,disconnected);
  }

  bool isAuthenticated() {
    return authClient?.credentials.accessToken.isNotEmpty ?? false;
  }

  void connected() { log.info("Connected!");
    isConnected = true;
    if (autoLog) autoLogin();
  }

  void disconnected() {
    isConnected = false; isLoggedIn = false;
    log.info("Disconnected: $userName");
    tryReconnect();
  }

  void tryReconnect() {
    ZugDialogs.popup("Disconnected - click to reconnect").then((ok) { connect(); });
  }

  Future<bool> loggedIn(data) async {
    log.info("Logged in: ${data.toString()}");
    userName = UniqueName.fromData(data);
    isLoggedIn = true;
    if (autoJoinTitle != null && await confirmGoto(autoJoinTitle!)) {
      joinArea(autoJoinTitle!);
      autoJoinTitle = null;
    }
    return true;
  }

  Future<bool> confirmGoto(String title) async {
    return await ZugDialogs.confirm("Join $title ?");
  }

  bool loggedOut(data) {
    log.info("Logged out: $userName");
    isLoggedIn = false;
    ZugDialogs.popup("Logged out - click to log back in").then((ok) { login(loginType); });
    return true;
  }

  void send(Enum type, { var data = "" }) {
    if (showServMess) log.info("Sending: $type, $data");
    if (noServer) {
      log.fine("Sending: ${type.toString()} -> ${data.toString()}");
    }
    else if (isConnected && sock != null) {
      sock!.send(jsonEncode( { fieldType: type.name, fieldData: data } ) );
    }
    else { //playClip("doink");
      tryReconnect();
    }
  }

  String getDomain() {
    if (!localServer) {
      return domain;
    } else if (!kIsWeb && Platform.isAndroid) {
      return "10.0.2.2";
    } else {
      return "localhost";
    }
  }

  String getWebSockAddress() {
    StringBuffer sBuff = StringBuffer(localServer ? "ws://" : "wss://");
    sBuff.write(getDomain());
    sBuff.write(localServer ? ":$port" : "/$remoteEndpoint");
    return sBuff.toString();
  }

  String getSourceDomain(String? source) {
    return switch(source) {
      "lichess" => "lichess.org",
      String() => "error.com",
      null => "null.com",
    };
  }

  void deleteToken() {
    if (authClient?.credentials.accessToken.isNotEmpty ?? false) {
      OauthClient(getSourceDomain(userName?.source), clientName).deleteToken(authClient?.credentials.accessToken);
      authClient = oauth2.Client(oauth2.Credentials(""));
      if (kIsWeb) {
        ZugDialogs.popup("Token deleted, reload page to login again");
      } else {
        ZugDialogs.popup("Token deleted, restart app to login again");
      }
    }
  }

  void loadOptions(List<ZugOption> list) {
    for (var option in list) {
      _options[option.name] = ZugOption.fromJson(
          jsonDecode(prefs?.getString(optPrefix + option.name) ?? "{}")) ?? option;
    }
  }

  ZugOption? getOption(Enum key) => _options[key];

  Iterable<ZugOption> getOptions() => _options.values;

  void setOption(String key, ZugOption option) {
    _options[key] = option; prefs?.setString(optPrefix + key,option.toString());
  }
  void setOptionFromEnum(Enum key, ZugOption option) {
    setOption(key.name, option);
  }

  Completer<void>? playTrack(String track) {
    Completer<void> trackCompleter = Completer();
    if (getOption(ZugOpt.music)?.getBool() == true) {
      _endTrackListener?.cancel();
      _endTrackListener = trackPlayer.onPlayerComplete.listen((event) { //print("Finished clip: $clip");
        if (!trackCompleter.isCompleted) trackCompleter.complete();
      });
      trackPlayer.play(AssetSource('audio/tracks/$track.mp3'), volume: volume);
      return trackCompleter;
    }
    return null;
  }

  Completer<void>? playClip(String clip, {interruptTrack = true}) { //print("Playing clip: $clip");
    Completer<void> clipCompleter = Completer();
    if (getOption(ZugOpt.sound)?.getBool() == true) {
      if (interruptTrack && trackPlayer.state == PlayerState.playing) trackPlayer.pause();
      _endClipListener?.cancel();
      _endClipListener = clipPlayer.onPlayerComplete.listen((event) { //print("Finished clip: $clip");
        if (trackPlayer.state == PlayerState.paused) trackPlayer.resume();
        if (!clipCompleter.isCompleted) clipCompleter.complete();
      });
      clipPlayer.play(AssetSource('audio/clips/$clip.mp3'), volume: volume);
      return clipCompleter;
    }
    return null;
  }
}
