import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/splash_page.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_model.dart';
import 'lobby_page.dart';
import 'options_page.dart';

final zugAppNavigatorKey = GlobalKey<NavigatorState>();

abstract class ZugApp extends StatelessWidget {
  final String appName;
  final ZugModel model;
  final Color colorSeed;
  final bool isDark;
  final ColorScheme colorScheme;
  final String splashLandscapeImgPath, splashPortraitImgPath;
  final bool noNav;

  ZugApp(this.model, this.appName, {
    this.colorSeed = Colors.green,
    this.splashLandscapeImgPath = "images/splash_land.png",
    this.splashPortraitImgPath = "images/splash_port.png",
    this.isDark = true,
    super.key, Level logLevel = Level.INFO, this.noNav = false}) : colorScheme = isDark ? const ColorScheme.dark() : const ColorScheme.light() { //}ColorScheme.fromSeed(seedColor: colorSeed) {
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
    return LobbyPage(model,zugChat: ZugChat(model)); //,
        //foregroundColor: colorScheme.onSurface, backgroundColor: colorScheme.surface)
  }

  Widget createSplashPage(ZugModel model) {
    return SplashPage(model,
        imgLandscape: Image(image: ZugUtils.getAssetImage(splashLandscapeImgPath),fit: BoxFit.fill),
        imgPortrait: Image(image: ZugUtils.getAssetImage(splashPortraitImgPath),fit: BoxFit.fill),
    );
  }

  Widget createMainPage(ZugModel model);

  AppBar createStatusBar(BuildContext context, ZugModel model, {Widget? txt, Color? color}) {
    Text defaultTxt = noNav
        ? Text("Hello, ${model.userName?.name ?? "Unknown User"}!")
        : Text("${model.userName}: ${model.currentArea.exists ? model.currentArea.id : "-"}");
    return AppBar(
      backgroundColor: color ?? Theme.of(context).colorScheme.inversePrimary,
      title: txt ?? defaultTxt,
    );
  }

  NavigationDestination getMainNavigationBarItem() {
    return const NavigationDestination(
      icon: Icon(Icons.center_focus_strong),
      label: 'Main',
    );
  }

  NavigationDestination getLobbyNavigationBarItem() {
    return const NavigationDestination(
      icon: Icon(Icons.local_bar),
      label: 'Lobby',
    );
  }

  NavigationDestination getSettingsNavigationBarItem() {
    return const NavigationDestination(
      icon: Icon(Icons.settings),
      label: 'Settings',
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

enum PageType { main,lobby,options,splash,none }

class _ZugHomeState extends State<ZugHome> {

  @override
  Widget build(BuildContext context) {
    ZugModel model = context.watch<ZugModel>();
    ColorScheme colorScheme = Theme.of(context).colorScheme;

  // The container for the current page, with its background color
  // and subtle switching animation.
    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
        child: ValueListenableBuilder<PageType>(
          valueListenable: model.pageNotifier,
          builder: (context, pageType, _) {
            return KeyedSubtree(
              key: ValueKey(pageType), // Important: unique key per page type
              child: _buildPageForType(model, pageType),
            );
          },
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              getNavBar(model),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: mainArea),
                    getSafeArea(model),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageForType(ZugModel model, PageType pageType) {
    if (!model.isLoggedIn) return widget.app.createSplashPage(model);
    if (widget.noNav) return widget.app.createMainPage(model);
    switch (pageType) {
      case PageType.main:
        return widget.app.createMainPage(model);
      case PageType.lobby:
        return widget.app.createLobbyPage(model);
      case PageType.options:
        return widget.app.createOptionsPage(model);
      case PageType.none || PageType.splash:
        return widget.app.createSplashPage(model);
    }
  }

  SafeArea getSafeArea(ZugModel model) {
    return SafeArea(
      child: kIsWeb ? widget.app.createStatusBar(context,model) : getNavBar(model),
    );
  }

  Widget getNavBar(ZugModel model,
      { iconColor = Colors.white,
        backgroundColor = Colors.black,
        indicatorColor = Colors.grey,
        orientation = Axis.vertical}) {

    NavigationDestination mainDestination = widget.app.getMainNavigationBarItem();
    NavigationDestination lobbyDestination = widget.app.getLobbyNavigationBarItem();
    NavigationDestination settingsDestination = widget.app.getSettingsNavigationBarItem();

    return ValueListenableBuilder<PageType>(
      valueListenable: model.pageNotifier,
      builder: (context, pageType, _) {
        final selectedIndex = pageTypeToIndex(pageType);
        return Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.all(
                TextStyle(color: iconColor),
              ),
            ),
          ),
          child: orientation == Axis.horizontal
              ? NavigationBar(
            backgroundColor: backgroundColor,
            indicatorColor: indicatorColor,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
            model.pageNotifier.value = indexToPageType(index),
            destinations: [
              mainDestination,
              lobbyDestination,
              settingsDestination
            ],
          )
              : NavigationRail(
            backgroundColor: backgroundColor,
            indicatorColor: indicatorColor,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
            model.pageNotifier.value = indexToPageType(index),
            destinations: [
              NavigationRailDestination(
                icon: mainDestination.icon,
                label: Text(mainDestination.label),
              ),
              NavigationRailDestination(
                icon: lobbyDestination.icon,
                label: Text(lobbyDestination.label),
              ),
              NavigationRailDestination(
                icon: settingsDestination.icon,
                label: Text(settingsDestination.label),
              ),
            ],
          ),
        );
      },
    );
  }

  int pageTypeToIndex(PageType pageType) {
    switch (pageType) {
      case PageType.main:
        return 0;
      case PageType.lobby:
        return 1;
      case PageType.options:
        return 2;
      default:
        return 1; // fallback
    }
  }

  PageType indexToPageType(int index) {
    switch (index) {
      case 0:
        return PageType.main;
      case 1:
        return PageType.lobby;
      case 2:
        return PageType.options;
      default:
        return PageType.lobby;
    }
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