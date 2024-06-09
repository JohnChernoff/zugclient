library zugclient;

import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zugclient/zug_app.dart';
import 'zug_fields.dart';
import 'zug_sock.dart';
import 'dialogs.dart';
import 'oauth_client.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UniqueName {
  final String name, source;
  UniqueName(this.name,this.source);
  factory UniqueName.fromData(Map<String,dynamic> data) {
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
    return "$name($source)";
  }
}

abstract class Room {
  late final String title;
  dynamic jsonData = {};
  List<dynamic> messages = [];
  int newMessages = 0;
  Map<UniqueName,dynamic> occupants = {};

  Room(dynamic data) {
    title = data?[fieldTitle] ?? ZugClient.noAreaTitle;
  }

  String getOccupantName(UniqueName name) {
    for (UniqueName uniqueName in occupants.keys) {
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
}

abstract class Area extends Room {
  dynamic listData = {};
  Map<String,dynamic> options = {};
  bool exists = true;
  Room? currentRoom;
  Area(dynamic data) : super(data);
}

enum LoginType {guest,lichess}
abstract class ZugClient extends ChangeNotifier {

  static final log = Logger('ClientLogger');
  static const noAreaTitle = "";
  static const servString = "serv";

  bool localServer;
  bool noServer = false;
  String clientName = "ZugClient";
  PackageInfo? packageInfo;
  String domain;
  int port;
  String remoteEndpoint;
  //String userName = "";
  //String userSource = "";
  UniqueName? user;
  String areaName = "Area";
  bool isConnected = false;
  bool isLoggedIn = false;
  bool authenticating = false;
  ZugSock? sock;
  oauth2.Client authClient = oauth2.Client(oauth2.Credentials(""));
  Map<String,Area> areas = {};
  int newMessages = 0;
  List<dynamic> messages = [];
  late final Area noArea;
  late Area currentArea; //Area(noAreaTitle);
  final Map<Enum,Function> _functionMap = {};
  PageType switchPage = PageType.none;
  PageType selectedPage = PageType.none;
  SharedPreferences? defaults;
  LoginType? loginType;
  String? serverVersion;
  final audio = AudioPlayer();
  double volume = .5;
  static bool defaultSound = false;
  int? id;

  Area createArea(dynamic data);

  ZugClient(this.domain,this.port,this.remoteEndpoint, {this.localServer = false}) {
    noArea = createArea(null); //noAreaTitle);
    currentArea = noArea;
    PackageInfo.fromPlatform().then((PackageInfo info) {
      packageInfo = info;
      log.info(info.toString());
      notifyListeners();
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
      ServMsg.updateArea: handleUpdateArea,
      ServMsg.updateOccupant: handleUpdateOccupant,
      ServMsg.updateOccupants: handleUpdateOccupants,
      ServMsg.updateOptions: handleUpdateOptions,
      ServMsg.createArea: handleCreateArea,
      ServMsg.updateAreaList: handleUpdateAreaList,
      ServMsg.version: handleVersion,
    });
    SharedPreferences.getInstance().then((prefs) => defaults = prefs);
    connect();
  }

  void addFunctions(Map<Enum, Function> functions) {
    _functionMap.addAll(functions);
  }

  Map<Enum,Function> getFunctions() { return _functionMap; }

  void newArea() {
    Dialogs.getString('Choose Game Title',user?.name ?? "?")
        .then((title) => send(ClientMsg.newArea, data: {fieldTitle: title}));
  }

  void joinArea() {
    areaCmd(ClientMsg.joinArea);
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

  Enum handleMsg(String msg) {
    log.fine("Incoming msg: $msg");
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
    send(ClientMsg.joinArea,data : {fieldTitle: data[fieldTitle]});
    return true;
  }

  bool handleUpdateOccupant(data) { log.fine("Occupant update: $data");
    Area area = getOrCreateArea(data);
    area.occupants.putIfAbsent(UniqueName.fromData(data["user"]), () => data);
    return true;
  }

  bool handleUpdateArea(data) { log.fine("Update Area: $data");
    Area area = getOrCreateArea(data);
    handleUpdateOccupants(data,area : area); //TODO: why use named argument?
    handleUpdateOptions(data,area : area);
    return true;
  }

  bool handleUpdateOccupants(data, {Area? area}) {
    if (data[fieldOccupants] != null) {
      area = area ?? getOrCreateArea(data);
      area.occupants.clear();
      for (dynamic occupant in data[fieldOccupants]) {
        area.occupants.putIfAbsent(UniqueName.fromData(occupant["user"]), () => occupant);
      }
      return true;
    }
    return false;
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

  void addAServMsg(String msg, {hidden = false}) {
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
    addAServMsg("Private Message from ${UniqueName.fromData(data[fieldUser])}: ${data[fieldMsg]}");
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

  bool handleAreaList(data) {
    for (Area area in areas.values) {
      area.exists = false;
    }
    for (var area in data[fieldAreas]) {
      Area a = getOrCreateArea(area);
      a.exists = true;
      a.listData = area; //print("Area: $area");
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
      area.listData = data[fieldArea];  //print("Area List Data: ${area.listData}");
    }
    else if (data[fieldAreaChange] == AreaChange.deleted.name) {
      areas.remove(area.title);
      if (currentArea.title == area.title) switchArea(noAreaTitle); //TODO: delete from gamelist somehow
    }
    else if (data[fieldAreaChange] == AreaChange.updated.name) {
      area.listData = data[fieldArea];
    }
    return true;
  }

  void checkRedirect(OauthClient oauthClient) {
    if (kIsWeb) {
      String code = Uri.base.queryParameters["code"]?.toString() ?? "";
      if (code.isNotEmpty) {
        authenticating = true;
        html.window.history.pushState(null, 'home', Uri.base.path);
        oauthClient.decode(code, handleAuthClient);
      }
    }
  }

  void authenticate(OauthClient oauthClient) {
    log.info("Authenticating");
    authenticating = true;
    oauthClient.authenticate(handleAuthClient);
  }

  void handleAuthClient(oauth2.Client client) {
    authClient = client;
    authenticating = false;
    if (!isLoggedIn) { //TODO: handle other login types
      login(LoginType.lichess);
    }
  }

  bool handleLogin(data) { //TODO: create login dialog?
    id = data[fieldID]; log.info("Connection ID: $id");
    if (loginType != null) login(loginType);
    return false;
  }

  void login(LoginType? lt) {
    if (isConnected) {
      loginType = lt ?? LoginType.guest;
      if (loginType == LoginType.lichess) {
        if (isAuthenticated()) {
          log.info("Logging in with token");
          send(ClientMsg.loginLichess, data: { fieldToken : authClient.credentials.accessToken });
        }
        else {
          authenticate(OauthClient("lichess.org", clientName));
        }
      }
      else if (loginType == LoginType.guest) {
        log.info("Logging in as guest");
        send(ClientMsg.loginGuest);
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
    return authClient.credentials.accessToken.isNotEmpty;
  }

  void connected() { log.info("Connected!");
    isConnected = true;
  }

  void disconnected() {
    isConnected = false; isLoggedIn = false;
    log.info("Disconnected: $user");
    tryReconnect();
  }

  void tryReconnect() {
    Dialogs.popup("Disconnected - click to reconnect").then((ok) { connect(); });
  }

  bool loggedIn(data) {
    log.info("Logged in: ${data.toString()}");
    user = UniqueName.fromData(data);
    //userName = data["name"]; userSource = data["source"];
    isLoggedIn = true;
    return true;
  }

  bool loggedOut(data) {
    log.info("Logged out: $user");
    isLoggedIn = false;
    Dialogs.popup("Logged out - click to log back in").then((ok) { login(loginType); });
    return true;
  }

  void send(Enum type, { var data = "" }) {
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
    if (authClient.credentials.accessToken.isNotEmpty) {
      OauthClient(getSourceDomain(user?.source), clientName).deleteToken(authClient.credentials.accessToken);
      authClient = oauth2.Client(oauth2.Credentials(""));
      if (kIsWeb) {
        Dialogs.popup("Token deleted, reload page to login again");
      } else {
        Dialogs.popup("Token deleted, restart app to login again");
      }
    }
  }

  bool soundCheck() {
    return defaults?.getBool("sound") ?? defaultSound;
  }

  void playTrack(track) {
    if (soundCheck()) audio.play(AssetSource('audio/tracks/$track.mp3'), volume: volume);
  }

  void playClip(clip) {
    if (soundCheck()) audio.play(AssetSource('audio/clips/$clip.mp3'), volume: volume);
  }

}
