library zugclient;

import 'package:logging/logging.dart';

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

abstract class Area {
  final String title;
  List<dynamic> messages = [];
  Map<String,dynamic> occupants = {};
  Map<String,dynamic> options = {};
  MessageScope msgScope = MessageScope.area;
  int newMessages = 0;
  bool exists = true;
  Area(this.title);
}

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
  String userName = "";
  bool isConnected = false;
  bool isLoggedIn = false;
  bool loggingIn = false;
  ZugSock? sock;
  oauth2.Client authClient = oauth2.Client(oauth2.Credentials(""));
  Map<String,Area> areas = {};
  int newMessages = 0;
  List<dynamic> messages = [];
  late final Area noArea;
  late Area currentArea; //Area(noAreaTitle);
  final Map<String,Function> _functionMap = {};

  Area createArea(String title);

  ZugClient(this.domain,this.port,this.remoteEndpoint, {this.localServer = false}) {
    noArea = createArea(noAreaTitle);
    currentArea = noArea;
    PackageInfo.fromPlatform().then((PackageInfo info) {
      packageInfo = info;
      log.info(info.toString());
    });
    addFunctions({
      ServMsg.reqLogin.name: handleLogin,
      ServMsg.noLog.name: loggedOut,
      ServMsg.logOK.name: loggedIn,
      ServMsg.errMsg.name: handleErrorMsg,
      ServMsg.servMsg.name: handleServMsg,
      ServMsg.areaMsg.name: handleAreaMsg,
      ServMsg.updateAreas.name: handleAreaList,
      ServMsg.updateArea.name: handleUpdateArea,
      ServMsg.updateOccupant.name: handleUpdateOccupant,
      ServMsg.updateOccupants.name : handleUpdateOccupants,
      ServMsg.updateOptions.name : handleUpdateOptions,
    });
  }

  void addFunctions(Map<String, Function> functions) {
    _functionMap.addAll(functions);
  }

  Area getOrCreateArea(String title) {
    return areas.putIfAbsent(title, () {
      return createArea(title);
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

  void switchArea(String? title) {
    final t = title ?? noAreaTitle;
    if (currentArea.title != t) {
      if (areas[t] != null) {
        if (currentArea.exists) send(ClientMsg.unObs,data:{ fieldTitle : currentArea.title });
        currentArea = areas[t]!; // ?? noGame;
        if (currentArea.exists ) send(ClientMsg.updateArea,data:{fieldTitle:title}); //send(ClientTypes.obs,data: { fieldTitle : currentGame.title });
      }
      else {
        currentArea = noArea;
      }
      log.info("Switched to game: ${currentArea.title}");
    }
  }

  void handleMsg(String msg) {
    log.fine("Incoming msg: $msg");
    final json = jsonDecode(msg);
    String type = json[fieldType]; //logMsg("Handling: $type");
    Function? fun = _functionMap[type];
    if (fun != null) {
      fun(json[fieldData]);
      notifyListeners();
    } else {
      log.warning("Function not found: $type");
    }
  }

  void handleUpdateOccupant(data) { log.info("Occupant update: $data");
    Area area = getOrCreateArea(data[fieldTitle]);
    area.occupants[data["user"]["name"]] = data;
  }

  void handleUpdateArea(data) { log.info("Update Area: $data");
    Area area = getOrCreateArea(data[fieldTitle]);
    handleUpdateOccupants(data,area : area);
    handleUpdateOptions(data,area : area);
  }

  void handleUpdateOccupants(data, {Area? area}) {
    area = area ?? getOrCreateArea(data[fieldTitle]);
    area.occupants.clear();
    for (dynamic occupant in data["occupants"]) {
      area.occupants.putIfAbsent(occupant["user"]["name"], () => occupant);
    }
  }

  void handleUpdateOptions(data, {Area? area}) { //print("Options: $data");
    area = area ?? getOrCreateArea(data[fieldTitle]);
    area.options = data["options"] ?? {};
  }

  void handleAreaMsg(data, {Area? area}) {
    area = area ?? getOrCreateArea(data[fieldTitle]);
    area.messages.add(data[fieldMsg]); area.newMessages++;
  }

  void handleServMsg(data) {
    messages.add(data[fieldMsg]); newMessages++;
  }

  void handleErrorMsg(data) {
    Dialogs.popup("Error: ${data[fieldMsg]}");
  }

  void handleAreaList(data) {
    for (Area area in areas.values) {
      area.exists = false;
    }
    for (var area in data[fieldAreas]) {
      getOrCreateArea(area[fieldTitle]).exists = true;
    }
    areas.removeWhere((key, value) => !value.exists);
    if (currentArea != noArea && !currentArea.exists) {
      currentArea = noArea;
    }
  }

  void checkRedirect(OauthClient oauthClient) {
    if (kIsWeb) {
      String code = Uri.base.queryParameters["code"]?.toString() ?? "";
      if (code.isNotEmpty) {
        loggingIn = true;
        html.window.history.pushState(null, 'home', Uri.base.path);
        oauthClient.decode(code, setAuthClient);
      }
    }
  }

  //TODO: option to remove stored token
  void authenticate(OauthClient oauthClient) {
    log.info("Authenticating");
    loggingIn = true;
    oauthClient.authenticate(setAuthClient);
  }

  void setAuthClient(oauth2.Client client) {
    authClient = client;
    if (!isConnected) {
      connect();
    } else if (!isLoggedIn) { //shouldn't occur
      login();
    }
  }

  void handleLogin(data) { login(); }
  void login() {
    if (isAuthenticated()) {
      log.info("Logging in with token");
      send(ClientMsg.loginLichess, data: { fieldToken : authClient.credentials.accessToken });
      notifyListeners(); //TODO: handle server login issues?
    }
    else {
      log.info("Logging in as guest");
      send(ClientMsg.loginGuest);
      notifyListeners();
    }
  }

  void connect()  {
    loggingIn = true;
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
    log.info("Disconnected: $userName");
    tryReconnect();
  }

  void tryReconnect() {
    Dialogs.popup("Disconnected - click to reconnect").then((ok) { connect(); });
  }

  void loggedIn(data) {
    log.info("Logged in: ${data.toString()}");
    userName = data["name"];
    loggingIn = false;
    isLoggedIn = true;

  }

  void loggedOut(data) {
    log.info("Logged out: $userName");
    isLoggedIn = false;
    Dialogs.popup("Logged out - click to log back in").then((ok) { login(); });
  }

  void send(Enum type, { var data = "" }) {
    if (noServer) {
      log.fine("Sending: ${type.toString()} -> ${data.toString()}");
    }
    else if (isConnected && sock != null) {
      sock!.send(jsonEncode( { fieldType: type.name, fieldData: data } ) );
    }
    else { //playClip("doink");
      if (!loggingIn) tryReconnect();
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

}
