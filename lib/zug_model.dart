library zugclient;

import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zug_net/oauth_client.dart';
import 'package:zug_net/zug_sock.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_area.dart';
import 'package:zugclient/zug_option.dart';
import 'zug_fields.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

enum AudioOpt {sound,soundVol,music,musicVol}
enum ZugClientOpt {debug}
enum LoginType {none,lichess,google}

abstract class ZugModel extends ChangeNotifier {
  final ValueNotifier<PageType> pageNotifier;
  static const optPrefix = "ZugClientOption";
  static final log = Logger('ClientLogger');
  static const noAreaTitle = "-";
  static const servString = "serv";
  static const LoginType defLogType = LoginType.lichess;

  bool showServMess;
  bool localServer;
  bool noServer = false;
  String modelName = "ZugClient";
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
  SharedPreferences? prefs;
  final Map<String,ZugOption> _options = {};
  LoginType? loginType;
  String? serverVersion;
  final clipPlayer = AudioPlayer();
  final trackPlayer = AudioPlayer();
  ShuffleInfo _currentShuffle = ShuffleInfo();
  Random rng = Random();
  double volume = .5;
  static bool defaultSound = false;
  int? id;
  bool autoLog = false;
  bool localDebug = true;
  bool errPopup = false;
  bool javalinServer;
  bool helpMode = false;
  String? autoJoinTitle;
  final ValueNotifier<MessageScope> chatScope = ValueNotifier(MessageScope.server);
  Map<String,ValueNotifier<bool?>> dialogTracker = {};

  Area createArea(dynamic data);

  ZugModel(this.domain,this.port,this.remoteEndpoint, this.prefs, {
    FirebaseOptions? firebaseOptions, this.showServMess = false, this.localServer = false, this.javalinServer = false}) : pageNotifier = ValueNotifier<PageType>(PageType.lobby) {
    //_endClipListener = clipPlayer.onPlayerComplete.listen((v) => log.info("done"));
    trackPlayer.stop();
    log.info("Prefs: ${prefs.toString()}");
    loadOptions([
      (AudioOpt.sound,ZugOption(true,label: "Sound")),
      (AudioOpt.soundVol,ZugOption(50,min: 0, max: 100, inc: 1,label: "Sound Volume")),
      (AudioOpt.music,ZugOption(false,label: "Music")),
      (AudioOpt.musicVol,ZugOption(50,min: 0, max: 100, inc: 1,label: "Music Volume")),
    ]);
    //if (localServer) loadOptions([(ZugClientOpt.debug,ZugOption(localDebug,label: "Debug"))]);
    noArea = getOrCreateArea(null);
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
      ServMsg.phase : handleNewPhase,
      ServMsg.reqResponse : handleResponseRequest,
      ServMsg.cancelledResponse : handleCompletedRequest,
      ServMsg.completedResponse : handleCancelledRequest,
      ServMsg.version: handleVersion,
      ServMsg.updateServ : handleUpdateServ
    });
    if (firebaseOptions != null) initFirebase(firebaseOptions);
    connect();
  }

  void addFunctions(Map<Enum, Function> functions) {
    _functionMap.addAll(functions);
  }

  Map<Enum,Function> getFunctions() { return _functionMap; }

  void goToPage(PageType page) {
    pageNotifier.value = page;
  }

  Future<bool> awaitMsg(Enum msgEnum) {
    if (_funWaiter?.completer.isCompleted == false) _funWaiter?.completer.complete(false);
    _funWaiter = FunctionWaiter(msgEnum);
    return _funWaiter!.completer.future;
  }

  Future<void> initFirebase(FirebaseOptions fireOpts) async {
    //await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
    await Firebase.initializeApp(options: fireOpts);
    FirebaseAuth.instance
        .authStateChanges()
        .listen((User? user) {
      if (user == null) {
        log.info('User is currently signed out!');
      } else {
        log.info('${user.displayName} is signed in!');
      }
    });
  }

  void newArea({String? title, autoJoin = true}) {
    if (title != null) {
      send(ClientMsg.newArea, data: {fieldAreaID: title});
    }
    else {
      ZugDialogs.getString('Choose Title',userName?.name ?? "?")
          .then((t) => send(ClientMsg.newArea, data: {fieldAreaID: t, fieldAutoJoin: autoJoin}));
    }
  }

  void seekArea() {
    send(ClientMsg.joinArea);
  }

  void joinArea(String id) {
    areaCmd(ClientMsg.joinArea,id: id);
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
    return areas.putIfAbsent(data?[fieldAreaID] ?? noAreaTitle, () { //print(areas.keys); print("Adding area: $data");
      return createArea(data);
    });
  }

  void areaCmd(Enum cmd, { String? id, Map<String,dynamic> data = const {}}) {
    if (data.isEmpty) {
      send(cmd,data: { fieldAreaID : id ??  currentArea.id});
    } else {
      Map<String,dynamic> args = Map<String,dynamic>.from(data);
      args[fieldAreaID] = id ?? currentArea.id;
      send(cmd,data:args);
    }
  }

  void switchArea(String? title) {
    final t = title ?? noAreaTitle;
    if (currentArea.id != t) {
      if (areas[t] != null) {
        if (currentArea.exists) send(ClientMsg.unObs,data:{ fieldAreaID : currentArea.id });
        currentArea = areas[t]!; // ?? noGame;
        if (currentArea.exists ) {
          send(ClientMsg.obs,data:{fieldAreaID:currentArea.id});
          send(ClientMsg.updateArea,data:{fieldAreaID:title});
        }
      }
      else {
        currentArea = noArea;
        update(); //TODO: can this be done for all games?
      }
      log.info("Switched to game: ${currentArea.id}"); //update();
    }
  }

  Enum handleMsg(dynamic msg) {
    if (showServMess || (getOption(ZugClientOpt.debug)?.getBool() ?? false)) {
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
    log.info("Observing: ${data[fieldAreaID]}");
  }

  void handleUnObs(data) {
    log.info("No longer observing: ${data[fieldAreaID]}");
  }

  bool handleCreateArea(data) { //print("Created Area: $data"); //TODO: create defaultJoin property?
    return true;
  }

  bool handleUpdateOccupant(data) { log.fine("Occupant update: $data");
    Area area = getOrCreateArea(data);
    area.occupantMap.putIfAbsent(UniqueName.fromData(data[fieldUser]), () => data);
    return true;
  }

  bool handleNewPhase(data) {
    getOrCreateArea(data).updatePhase(data);
    return true;
  }

  void handleUpdateServ(data) {
    handleUpdateMessages(data,serv: true);
  }

  void handleUpdateArea(data) { log.fine("Update Area: $data");
    Area area = getOrCreateArea(data);
    handleUpdateOccupants(data,area : area); //TODO: why use named argument?
    handleUpdateOptions(data,area : area);
    handleUpdateMessages(data, area: area);
    if (data[fieldPhase] != null) area.updatePhase(data);
    area.updateArea(data);
  }

  bool handleUpdateOccupants(data, {Area? area}) {
    return updateOccupants(area ?? getOrCreateArea(data),data);
  }

  bool handleUpdateOptions(data, {Area? area}) { //print("Options: $data");
    if (data[fieldOptions] != null) {
      area = area ?? getOrCreateArea(data);
      Map<String,dynamic> optionList = data[fieldOptions] as Map<String,dynamic>;
      area.options.clear(); //print(optionList.keys);
      for (String field in optionList.keys) { //print ("key: $field");print(optionList[field].toString());
        area.options[field] = ZugOption.fromJson(optionList[field]);
      }
      return true;
    }
    return false;
  }

  void handleUpdateMessages(data, {Area? area, bool serv = false}) {
    if (data[fieldMsgHistory] != null) {
      if (serv) {
        messages.messages.clear(); //print("Message History: ${data[fieldMsgHistory]}");
        for (dynamic msg in data[fieldMsgHistory]) {
          messages.addZugMsg(msg[fieldZugMsg]);
        }
      }
      else {
        area = area ?? getOrCreateArea(data);
        area.messages.messages.clear(); //print("Message History: ${data[fieldMsgHistory]}");
        for (dynamic msg in data[fieldMsgHistory]) {
          area.messages.addZugMsg(msg[fieldZugMsg]);
        }
      }
    }
  }

  void fetchOptions(Function onOption, {int timeLimit = 5000}) async {
    awaitMsg(ServMsg.updateOptions)
        .timeout(Duration(milliseconds: timeLimit))
        .then((b) => onOption.call())
        .catchError((e) => ZugDialogs.popup("Error Fetching Options: $e"));
    areaCmd(ClientMsg.getOptions);
  }

  Future<bool> awaitResponse(Enum query, Enum reply, {int timeLimit = 5000}) async {
    Completer<bool> completer = Completer();
    awaitMsg(reply)
        .timeout(Duration(milliseconds: timeLimit))
        .then((b) => completer.complete(true))
        .catchError((e) => completer.complete(false));
    areaCmd(query);
    return completer.future;
  }

  void addAreaMsg(String msg, String id, {hidden = false}) {
    handleAreaMsg({
      fieldMsg : msg,
      fieldAreaID : id,
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

  bool handleRoomMsg(data) {
    currentArea.currentRoom?.messages.addMessage(data);
    return true;
  }

  bool handleGenericMsg(data) {
    switch(chatScope.value) {
      case MessageScope.room: handleRoomMsg(data); break;
      case MessageScope.area: handleAreaMsg(data); break;
      case MessageScope.server: handleServMsg(data); break;
    }
    return true;
  }

  bool handleErrorMsg(data) {
    if (errPopup) {
      ZugDialogs.popup("Error: ${data[fieldMsg]}");
      return true;
    }
    return handleGenericMsg(data);
  }

  bool handleAlertMsg(data) {
    ZugDialogs.popup("Alert: ${data[fieldMsg]}");
    return true;
  }

  void handleJoin(data) { //print("Joining: $data");
    switchArea(data[fieldAreaID]);
    handleUpdateArea(data);
    chatScope.value = MessageScope.area;
  }

  void handlePart(data) { //print("Parting: $data");
    addServMsg("Leaving: ${data[fieldAreaID]}");
    switchArea(noAreaTitle);
  }

  void handleStart(data) {
    handleUpdateArea(data);
    goToPage(PageType.main);
  }

  bool handleAreaList(data) { //print("Area List: $data");
    for (Area area in areas.values) {
      if (area != noArea) area.exists = false;
    }
    for (var areaData in data[fieldAreas]) {
      Area a = getOrCreateArea(areaData);
      a.exists = true;
      updateOccupants(a,areaData); //a.updateArea(areaData);
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
      updateOccupants(area,data[fieldArea]);
    }
    else if (data[fieldAreaChange] == AreaChange.deleted.name) { //print("Removing: ${area.title}");
      areas.remove(area.id);
      if (currentArea.id == area.id) switchArea(noAreaTitle);
    }
    else if (data[fieldAreaChange] == AreaChange.updated.name) {
      updateOccupants(area,data[fieldArea]);
    }
    return true;
  }

  bool updateOccupants(Room room, data) {
    bool b = room.updateOccupants(data); //if (!b || !room.occupantMap.keys.any((uname) => uname.eq(userName))) switchArea(noAreaTitle); //ergh, probably bad idea
    return b;
  }

  void handleResponseRequest(data) {
    ValueNotifier<bool?> canceller = ValueNotifier<bool?>(null);
    dialogTracker.putIfAbsent(data[fieldResponseType], () => canceller);
  }

  void handleCancelledRequest(data) {
    dialogTracker[data[fieldResponseType]]?.value = false;
    dialogTracker.remove(data[fieldResponseType]);
  }

  void handleCompletedRequest(data) {
    dialogTracker[data[fieldResponseType]]?.value = true;
    dialogTracker.remove(data[fieldResponseType]);
  }

  void checkRedirect(String host) {
    checkRedirectOauth(OauthClient(host,modelName));
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
      login(LoginType.lichess, token: authClient?.credentials.accessToken);
    }
  }

  bool handleLogin(data) { //TODO: create login dialog?
    id = data[fieldConnID]; log.info("Connection ID: $id");
    if (!autoLog && loginType != null) {
      login(loginType);
    }
    return false;
  }

  void login(LoginType? lt, {String? token}) {
    //autoLog = false;
    if (isConnected) {
      prefs?.setString(fieldLoginType, lt.toString());
      loginType = lt ?? LoginType.none;
      if (loginType == LoginType.lichess) {
        if (token != null) {
          log.info("Logging in with lichess token");
          send(ClientMsg.login, data: { fieldLoginType: LoginType.lichess.name, fieldToken : token });
        }
        else {
          authenticate(OauthClient("lichess.org", modelName));
        }
      } else if (loginType == LoginType.google) {
        if (token != null) {
          send(ClientMsg.login, data: { fieldLoginType: LoginType.google.name, fieldToken : token });
        } else {
          signInWithGoogle().then((cred) async {
            String? idToken = await cred.user?.getIdToken();
            login(LoginType.google,token: idToken);
          });
        }
      } else if (loginType == LoginType.none) {
        log.info("Logging in as guest");
        send(ClientMsg.login, data: { fieldLoginType: LoginType.none.name });
      }
      notifyListeners();
    }
    else {
      ZugDialogs.popup("Not connected to server");
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    // Create a new provider
    GoogleAuthProvider googleProvider = GoogleAuthProvider();
    // googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
    googleProvider.setCustomParameters({'login_hint': 'user@example.com'});

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(googleProvider);

    // Or use signInWithRedirect
    // return await FirebaseAuth.instance.signInWithRedirect(googleProvider);
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
    if (showServMess || (getOption(ZugClientOpt.debug)?.getBool() ?? false)) log.info("Sending: $type, $data");
    if (noServer) {
      log.fine("Sending: ${type.toString()} -> ${data.toString()}");
    }
    else if (isConnected && sock != null) {
      sock!.send(jsonEncode( { fieldType: type.name, fieldData: data } ) );
    }
    else {
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
    if (javalinServer) {
      sBuff.write(localServer ? ":$port/$remoteEndpoint" : "/$remoteEndpoint");
    } else {
      sBuff.write(localServer ? ":$port" : "/$remoteEndpoint");
    }
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
      OauthClient(getSourceDomain(userName?.source), modelName).deleteToken(authClient?.credentials.accessToken);
      authClient = oauth2.Client(oauth2.Credentials(""));
      if (kIsWeb) {
        ZugDialogs.popup("Token deleted, reload page to login again");
      } else {
        ZugDialogs.popup("Token deleted, restart app to login again");
      }
    }
  }

  void loadOptions(List<(Enum, ZugOption)> list) {
    for (var option in list) {
      try {
        final key = option.$1.name;
        final defOpt = option.$2;
        final optionPref = prefs?.getString(optPrefix + key);

        if (optionPref == null) {
          setOption(key, defOpt);
        } else {
          final loadedOpt = ZugOption.fromJson(jsonDecode(optionPref));

          // If enum, rehydrate by creating a new option with a valid enum value
          if (loadedOpt.enums != null && defOpt.zugVal.getType() == ValType.enumeration) {
            final correctedVal = defOpt.enums!.firstWhere(
                  (name) => name == loadedOpt.getVal(),
              orElse: () => defOpt.enums!.first,
            );
            _options[key] = defOpt.fromValue(correctedVal);
          } else {
            _options[key] = loadedOpt;
          }
        }
      } catch (e) {
        log.info("Error parsing: $option -> $e");
      }
    }
  }


  ZugOption? getOption(Enum key) => _options[key.name];

  Map<String, ZugOption> getOptions() => _options;

  /// Generic edit that works for any type
  void editOption(Enum key, dynamic val) {
    final option = getOption(key);
    if (option == null) return;
    // If enum, ensure it's a valid choice from registered values
    if (option.enums != null) {
      final strVal = val.toString();
      final validVal = option.enums!.contains(strVal) ? strVal : option.enums!.first;
      setOptionFromEnum(key, option.fromValue(validVal));
    } else {
      setOptionFromEnum(key, option.fromValue(val));
    }
  }

  void setOption(String key, ZugOption option) {
    _options[key] = option;
    prefs?.setString(optPrefix + key, jsonEncode(option.toJson()));

    // Audio hooks (optional)
    for (AudioOpt opt in AudioOpt.values) {
      if (key == opt.name) {
        updateAudio(opt);
        return;
      }
    }
  }

  void setOptionFromEnum(Enum key, ZugOption option) {
    setOption(key.name, option);
  }

  void updateAudio(AudioOpt opt) {
    if (opt == AudioOpt.musicVol) {
      trackPlayer.setVolume(getMusicVolume()/100.0);
    }
    else if (opt == AudioOpt.music) {
      if (musicCheck()) {
        if (_currentShuffle.shuffling) {
          startShuffle();
        } else {
          trackPlayer.resume();
        }
      } else {
        trackPlayer.pause();
      }
    }

  }

  Future<void> startShuffle({int? initialTrack, String? prefix, String? format, bool override = true}) async {
    if (!_currentShuffle.shuffling || override) {
      _currentShuffle = ShuffleInfo(shuffling: true,
          prefix: prefix ?? _currentShuffle.prefix,
          format: format ?? _currentShuffle.format);
      log.info("Shuffling: $_currentShuffle");
      while (_currentShuffle.shuffling && await playRandomTrack(forceTrack: initialTrack)) {
        initialTrack = null;
      }
      log.info("Finished shuffle");
    }
  }

  void stopShuffle() {
    _currentShuffle.shuffling = false; trackPlayer.stop();
  }

  Future<bool> playRandomTrack({ShuffleInfo? shuffInfo, int? forceTrack}) async {
    ShuffleInfo info = shuffInfo ?? _currentShuffle;
    info.currentTrack = forceTrack ?? await info.getRandomTrack();
    return playAudio(AssetSource('audio/tracks/${info.prefix}${info.currentTrack}${info.format}'));
  }

  //returns true when track completes, false when stopped or no sound
  Future<bool> playAudio(AssetSource src, {bool clip = false, bool? pauseCurrentTrack, bool? resumeCurrentTrack}) async {
    bool pauseTrack = pauseCurrentTrack ?? clip; //weird behavior if clip = false and pauseCurrentTrack = true?
    bool resumeTrack = resumeCurrentTrack ?? pauseTrack;
    Completer<bool> completer = Completer();
    Source? prevSrc;
    PlayerState prevState = trackPlayer.state;
    if (!clip && prevState == PlayerState.playing || prevState == PlayerState.paused) {
      prevSrc = trackPlayer.source;
    }
    if (clip ? soundCheck() : musicCheck()) {
      if (pauseTrack) {
        await trackPlayer.pause();
      } else {
        if (!clip) await trackPlayer.stop();
      }
      AudioPlayer player = clip ? clipPlayer : trackPlayer;
      StreamSubscription<void>? sub;
      sub = player.onPlayerStateChanged.listen((state) async {
        log.fine("Audio State: $state, clip: $clip, src: ${player.source.toString()}, prev: ${prevSrc?.toString()}");
        if (state == PlayerState.completed) {
          if (resumeTrack) {
            await prevSrc?.setOnPlayer(trackPlayer);
            if (musicCheck()) await trackPlayer.resume();
          }
          completer.complete(true); sub?.cancel();
        }
        else if (state == PlayerState.stopped || state == PlayerState.disposed) {
          completer.complete(false); sub?.cancel();
        }
      });
      player.play(src);
    }
    else {
      completer.complete(false);
    }
    return completer.future;
  }

  bool musicCheck() => getOption(AudioOpt.music)?.getBool() ?? false;
  bool soundCheck() => getOption(AudioOpt.sound)?.getBool() ?? false;
  num getMusicVolume() => getOption(AudioOpt.musicVol)?.getNum() ?? 50;
  num getSoundVolume() => getOption(AudioOpt.soundVol)?.getNum() ?? 50;

  void setHelpMode(bool b) {
    helpMode = b;
    notifyListeners();
  }

  bool isGuest() => userName?.source == "none";

}

//extension StrComp on Enum { bool eq(dynamic s) { return (s is String) ? name == s : false; } }

