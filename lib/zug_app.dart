import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/splash_page.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_model.dart';
import 'lobby_page.dart';
import 'options_page.dart';

final zugAppNavigatorKey = GlobalKey<NavigatorState>();

abstract class ZugApp extends StatelessWidget {
  final String appName;
  final ZugModel model;
  final Color colorSeed;
  final ColorScheme colorScheme;
  final String splashLandscapeImgPath, splashPortraitImgPath;
  final bool noNav;

  ZugApp(this.model, this.appName, {
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
        create: (context) => model,
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

  Widget createOptionsPage(ZugModel model) {
    return OptionsPage(model, scope: OptionScope.general);
  }

  Widget createLobbyPage(ZugModel model) {
    return LobbyPage(model); //,
        //foregroundColor: colorScheme.onSurface, backgroundColor: colorScheme.surface)
  }

  Widget createSplashPage(ZugModel model) {
    return SplashPage(model,
        imgLandscape: Image(image: ZugUtils.getAssetImage(splashLandscapeImgPath),fit: BoxFit.fill),
        imgPortrait: Image(image: ZugUtils.getAssetImage(splashPortraitImgPath),fit: BoxFit.fill),
    );
  }

  Widget createMainPage(ZugModel model);

  AppBar createAppBar(BuildContext context, ZugModel model, {Widget? txt, Color? color}) {
    Text defaultTxt = noNav
        ? Text("Hello, ${model.userName?.name ?? "Unknown User"}!")
        : Text("${model.userName}: ${model.currentArea.exists ? model.currentArea.id : "-"}");
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
    ZugModel model = context.watch<ZugModel>();
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    Widget page = widget.app.createSplashPage(model);

    if (model.isLoggedIn) {
      if (widget.noNav) {
        selectedPage = model.selectedPage = PageType.main;
        page = widget.app.createMainPage(model);
      }
      else {
        page = switch(model.switchPage) {
          PageType.main => widget.app.createMainPage(model),
          PageType.lobby => widget.app.createLobbyPage(model),
          PageType.options => widget.app.createOptionsPage(model),
          PageType.none => switch (selectedPage) {
            PageType.main || PageType.none => widget.app.createMainPage(model),
            PageType.lobby => widget.app.createLobbyPage(model),
            PageType.options => widget.app.createOptionsPage(model),
          }
        };
        if (model.switchPage != PageType.none) {
          selectedPage = model.switchPage;
          model.switchPage = PageType.none;
        }
        model.selectedPage = selectedPage;
      }
      if (selectedPage != PageType.main) {
        model.areaCmd(ClientMsg.setDeaf,data:{fieldDeafened:true});
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
      appBar: widget.app.createAppBar(context,model),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(child: mainArea),
              if (!widget.noNav) getSafeArea(model),
            ],
          );
        },),
    );
  }

  SafeArea getSafeArea(ZugModel model) {
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
          //if (ZugDialogs.currentContexts.isEmpty)
          //if (selectedPage == PageType.options && model.currentArea.exists) { widget.app.model.areaCmd(ClientMsg.getOptions);
          setState(() {
            selectedIndex = value;
            PageType newPage = PageType.values.elementAt(selectedIndex);
            selectedPage = newPage;
          });
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