library zugclient;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_oauth/flutter_oauth.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zug_net/zug_sock.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_app.dart';
import 'zug_fields.dart';
//import 'zug_sock.dart';
import 'dialogs.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
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

abstract class Room with Timerable {
  late final String title;
  List<dynamic> messages = [];
  int newMessages = 0;
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

  dynamic getOccupant(UniqueName name) {
    for (UniqueName uname in occupantMap.keys) {
      if (uname.eq(name)) return occupantMap[uname];
    }
    return null;
  }
}

abstract class Area extends Room {
  dynamic listData = {};
  Map<String,dynamic> options = {};
  bool exists = true;
  Room? currentRoom;
  Area(dynamic data) : super(data);

  bool updateArea(Map<String,dynamic> data) {
    listData = data; //TODO: eeeeh
    return updateOccupants(data);
  }
}

enum LoginType {none,lichess}

abstract class ZugClient extends ChangeNotifier {
  static final log = Logger('ClientLogger');
  static const noAreaTitle = "";
  static const servString = "serv";

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
  int newMessages = 0;
  List<dynamic> messages = [];
  late final Area noArea;
  late Area currentArea; //Area(noAreaTitle);
  final Map<Enum,Function> _functionMap = {};
  PageType switchPage = PageType.none;
  PageType selectedPage = PageType.none;
  SharedPreferences? prefs;
  LoginType? loginType;
  String? serverVersion;
  final audio = AudioPlayer();
  double volume = .5;
  static bool defaultSound = false;
  int? id;
  bool autoLog = false;
  String? autoJoinTitle;

  Area createArea(dynamic data);

  ZugClient(this.domain,this.port,this.remoteEndpoint, this.prefs, {this.showServMess = false, this.localServer = false}) {
    log.info("Prefs: ${prefs.toString()}");
    noArea = createArea(null); //noAreaTitle);
    currentArea = noArea;
    PackageInfo.fromPlatform().then((PackageInfo info) {
      packageInfo = info;
      log.info(info.toString());
      notifyListeners(); //why?
    });
    addFunctions({
      //ServMsg.createArea: handleCreateArea,
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

  void newArea({String? title}) {
    if (title != null) {
      send(ClientMsg.newArea, data: {fieldTitle: title});
    }
    else {
      Dialogs.getString('Choose Game Title',userName?.name ?? "?")
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

  void handleMsg(dynamic msg) {
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
    } else {
      log.warning("Function not found: $type");
    }
    //return funEnum;
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
    //if (data[fieldPhaseTimeRemaining] != null && data[fieldPhaseTimeRemaining] > 0) { area.setTimer(data[fieldPhaseTimeRemaining], 1000); }
    return true;
  }

  bool handleUpdateOccupants(data, {Area? area}) {
    area = area ?? getOrCreateArea(data);
    return area.updateOccupants(data);
  }

  bool handleUpdateOptions(data, {Area? area}) { //print("Options: $data");
    if (data[fieldOptions] != null) {
      area = area ?? getOrCreateArea(data);
      area.options = data[fieldOptions] ?? {};
      return true;
    }
    return false;
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
    area.messages.add(data);
    area.newMessages++;
    return true;
  }

  void addServMsg(String msg, {hidden = false}) {
    handleServMsg({
      fieldMsg : msg,
      fieldHidden : hidden
    });
  }

  bool handleServMsg(data) {
    messages.add(data);
    newMessages++;
    return true;
  }

  bool handlePrivMsg(data) { //print("Private message from: ${data[fieldUser]}");
    addServMsg("Private Message from ${UniqueName.fromData(data[fieldUser])}: ${data[fieldMsg]}");
    return true;
  }

  bool handleErrorMsg(data) {
    Dialogs.popup("Error: ${data[fieldMsg]}");
    return true;
  }

  bool handleAlertMsg(data) {
    Dialogs.popup("Alert: ${data[fieldMsg]}");
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
      a.updateArea(area);
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
      area.updateArea(data[fieldArea]);
    }
    else if (data[fieldAreaChange] == AreaChange.deleted.name) { //print("Removing: ${area.title}");
      areas.remove(area.title);
      if (currentArea.title == area.title) switchArea(noAreaTitle);
    }
    else if (data[fieldAreaChange] == AreaChange.updated.name) {
      area.updateArea(data[fieldArea]);
    }
    return true;
  }

  //TODO: generalize
  void checkRedirect(OauthClient oauthClient) {
    if (kIsWeb) {
      String code = Uri.base.queryParameters["code"]?.toString() ?? "";
      if (code.isNotEmpty) {
        authenticating = true;
        html.window.history.pushState(null, 'home', Uri.base.path);
        oauthClient.decode(code, handleAuthClient);
      }
      else {
        String goto = Uri.base.queryParameters["goto"]?.toString() ?? "";
        if (goto.isNotEmpty) {
          html.window.history.pushState(null, 'home', Uri.base.path);
          autoJoinTitle = goto;
          log.info("Autologging into game: $autoJoinTitle");
          autoLogin();
        }
      }
    }
  }

  void autoLogin() {
     autoLog = true;
     String? prevLogType = prefs?.getString(fieldLoginType);
     LoginType logType = LoginType.lichess; //TODO: generalize?
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
      Dialogs.popup("Not connected to server");
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
    Dialogs.popup("Disconnected - click to reconnect").then((ok) { connect(); });
  }

  bool loggedIn(data) {
    log.info("Logged in: ${data.toString()}");
    userName = UniqueName.fromData(data);
    isLoggedIn = true;
    if (autoJoinTitle != null) {
      joinArea(autoJoinTitle!); //send(ClientMsg.joinArea,data: { fieldTitle : autoJoinTitle});
      autoJoinTitle = null;
    }
    return true;
  }

  bool loggedOut(data) {
    log.info("Logged out: $userName");
    isLoggedIn = false;
    Dialogs.popup("Logged out - click to log back in").then((ok) { login(loginType); });
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
        Dialogs.popup("Token deleted, reload page to login again");
      } else {
        Dialogs.popup("Token deleted, restart app to login again");
      }
    }
  }

  bool soundCheck() {
    return prefs?.getBool("sound") ?? defaultSound;
  }

  void playTrack(String track) {
    if (soundCheck()) audio.play(AssetSource('audio/tracks/$track.mp3'), volume: volume);
  }

  void playClip(String clip) {
    if (soundCheck()) audio.play(AssetSource('audio/clips/$clip.mp3'), volume: volume);
  }

}
