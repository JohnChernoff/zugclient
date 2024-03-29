import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zugclient/splash_page.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_utils.dart';
import 'dialogs.dart';
import 'lobby_page.dart';
import 'options_page.dart';

abstract class ZugApp extends StatelessWidget {
  final String appName;
  final ZugClient client;
  final ColorScheme defaultColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
  final String splashLandscapeImgPath, splashPortraitImgPath;

  ZugApp(this.client, this.appName, {
    this.splashLandscapeImgPath = "images/splash_land.png",
    this.splashPortraitImgPath = "images/splash_portrait.png",
    super.key, Level logLevel = Level.ALL }) {
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
          navigatorKey: globalNavigatorKey,
          title: appName,
          theme: ThemeData(
            colorScheme: defaultColorScheme,
            useMaterial3: true,
          ),
          home: createHomePage(this),
        )
    );
  }

  Widget createHomePage(ZugApp app) {
    return ZugHome(app:app);
  }

  Widget createOptionsPage(client) {
    return OptionsPage(client);
  }

  Widget createLobbyPage(client) {
    return LobbyPage(client, foregroundColor: defaultColorScheme.onBackground, backgroundColor: defaultColorScheme.background);
  }

  Widget createSplashPage(client) {
    return SplashPage(client,
        imgLandscape: Image(image: ZugUtils.getAssetImage(splashLandscapeImgPath)),
        imgPortrait: Image(image: ZugUtils.getAssetImage(splashPortraitImgPath)),
    );
  }

  Widget createMainPage(client);
}

class ZugHome extends StatefulWidget {
  final ZugApp app;

  const ZugHome({super.key, required this.app});

  @override
  State<ZugHome> createState() => ZugHomeState();

  Color getAppBarColor(BuildContext context, ZugClient client) {
    return Theme.of(context).colorScheme.inversePrimary;
  }

  Text getAppBarText(ZugClient client, {String? text, Color textColor = Colors.black}) {
    return Text(text ?? "${client.userName}: ${client.currentArea.exists ? client.currentArea.title : "-"}",
        style: TextStyle(color: textColor));
  }

  BottomNavigationBarItem getMainNavigationBarItem() {
    return const BottomNavigationBarItem(
      icon: Icon(Icons.center_focus_strong),
      label: 'Main',
    );
  }
}

enum PageType { main,lobby,options,none }

class ZugHomeState extends State<ZugHome> {
  var selectedIndex = 1;
  PageType selectedPage = PageType.lobby;

  @override
  Widget build(BuildContext context) {
    var client = context.watch<ZugClient>();
    SafeArea safeArea = getSafeArea(client);
    var colorScheme = Theme
        .of(context)
        .colorScheme;

    Widget page = widget.app.createSplashPage(client);
    if (client.isLoggedIn) {
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

    // The container for the current page, with its background color
    // and subtle switching animation.
    var mainArea = ColoredBox(
      color: colorScheme.surfaceVariant,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.getAppBarColor(context, client),
        title: widget.getAppBarText(client)
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(child: mainArea),
              SafeArea(child: safeArea),
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
          widget.getMainNavigationBarItem(),
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
          if (!Dialogs.dialog) {
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