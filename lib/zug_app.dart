import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/splash_page.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'lobby_page.dart';
import 'options_page.dart';

final zugAppNavigatorKey = GlobalKey<NavigatorState>();

abstract class ZugApp extends StatelessWidget {
  final String appName;
  final ZugClient client;
  final Color colorSeed;
  final ColorScheme colorScheme;
  final String splashLandscapeImgPath, splashPortraitImgPath;
  final bool noNav;

  ZugApp(this.client, this.appName, {
    this.colorSeed = Colors.green,
    this.splashLandscapeImgPath = "images/splash_land.png",
    this.splashPortraitImgPath = "images/splash_port.png",
    super.key, Level logLevel = Level.INFO, this.noNav = false}) : colorScheme = ColorScheme.fromSeed(seedColor: colorSeed) {
    ZugDialogs.setNavigatorKey(zugAppNavigatorKey);
    Logger.root.level = logLevel;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
    WidgetsFlutterBinding.ensureInitialized();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => client,
        child: MaterialApp(
          scrollBehavior: ZugScrollBehavior(),
          navigatorKey: zugAppNavigatorKey,
          title: appName,
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
          ),
          home: createHomePage(this),
        )
    );
  }

  Widget createHomePage(ZugApp app) {
    return ZugHome(app:app,noNav: noNav);
  }

  Widget createOptionsPage(client) {
    return OptionsPage(client, scope: OptionScope.general);
  }

  Widget createLobbyPage(client) {
    return LobbyPage(client,chatArea: ZugChat(client, defScope: MessageScope.server)); //,
        //foregroundColor: colorScheme.onSurface, backgroundColor: colorScheme.surface)
  }

  Widget createSplashPage(client) {
    return SplashPage(client,
        imgLandscape: Image(image: ZugUtils.getAssetImage(splashLandscapeImgPath),fit: BoxFit.fill),
        imgPortrait: Image(image: ZugUtils.getAssetImage(splashPortraitImgPath),fit: BoxFit.fill),
    );
  }

  Widget createMainPage(client);

  AppBar createAppBar(BuildContext context, ZugClient client, {Widget? txt, Color? color}) {
    Text defaultTxt = noNav
        ? Text("Hello, ${client.userName?.name ?? "Unknown User"}!")
        : Text("${client.userName}: ${client.currentArea.exists ? client.currentArea.title : "-"}");
    return AppBar(
      backgroundColor: color ?? Theme.of(context).colorScheme.inversePrimary,
      title: txt ?? defaultTxt,
    );
  }

  BottomNavigationBarItem getMainNavigationBarItem() {
    return const BottomNavigationBarItem(
      icon: Icon(Icons.center_focus_strong),
      label: 'Main',
    );
  }
}

class ZugHome extends StatefulWidget {
  final ZugApp app;
  final bool noNav;

  const ZugHome({super.key, required this.app, this.noNav = false});

  @override
  State<ZugHome> createState() => _ZugHomeState();

}

enum PageType { main,lobby,options,none }

class _ZugHomeState extends State<ZugHome> {
  var selectedIndex = 1;
  late PageType selectedPage;
  PageType get defaultPage => widget.noNav ? PageType.main : PageType.lobby;

  @override
  void initState() {
    super.initState();
    selectedPage = defaultPage;
  }

  @override
  Widget build(BuildContext context) {
    ZugClient client = context.watch<ZugClient>();
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    Widget page = widget.app.createSplashPage(client);

    if (client.isLoggedIn) {
      if (widget.noNav) {
        selectedPage = client.selectedPage = PageType.main;
        page = widget.app.createMainPage(client);
      }
      else {
        page = switch(client.switchPage) {
          PageType.main => widget.app.createMainPage(client),
          PageType.lobby => widget.app.createLobbyPage(client),
          PageType.options => widget.app.createOptionsPage(client),
          PageType.none => switch (selectedPage) {
            PageType.main || PageType.none => widget.app.createMainPage(client),
            PageType.lobby => widget.app.createLobbyPage(client),
            PageType.options => widget.app.createOptionsPage(client),
          }
        };
        if (client.switchPage != PageType.none) {
          selectedPage = client.switchPage;
          client.switchPage = PageType.none;
        }
        client.selectedPage = selectedPage;
      }
      if (selectedPage != PageType.main) {
        client.areaCmd(ClientMsg.setDeaf,data:{fieldDeafened:true});
      }
    }

    // The container for the current page, with its background color
    // and subtle switching animation.
    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: widget.noNav ? page : AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      appBar: widget.app.createAppBar(context,client),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(child: mainArea),
              if (!widget.noNav) getSafeArea(client),
            ],
          );
        },),
    );
  }

  SafeArea getSafeArea(ZugClient client) {
    return SafeArea(
      child: BottomNavigationBar(
        fixedColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        items: [
          widget.app.getMainNavigationBarItem(),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_bar),
            label: 'Lobby',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: (value) {
          if (!ZugDialogs.dialog) {
            setState(() {
              selectedIndex = value;
              PageType newPage = PageType.values.elementAt(selectedIndex);
              selectedPage = newPage;
              if (selectedPage == PageType.options && client.currentArea.exists) {
                widget.app.client.areaCmd(ClientMsg.getOptions);
              }
            });
          }
        },
      ),
    );
  }
}

class ZugScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}