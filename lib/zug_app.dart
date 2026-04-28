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
import 'package:zugclient/zug_nav.dart';
import 'lobby_page.dart';
import 'options_page.dart';

final zugAppNavigatorKey = GlobalKey<NavigatorState>();

abstract class ZugApp extends StatelessWidget {
  final String appName;
  final ZugModel model;
  final Color colorSeed;
  final bool isDark;
  final ColorScheme colorScheme;
  final bool noNavBar;

  ZugApp(this.model, this.appName, {
    this.colorSeed = Colors.green,
    this.isDark = true,
    super.key, Level logLevel = Level.INFO, this.noNavBar = false}) : colorScheme = isDark ? const ColorScheme.dark() : const ColorScheme.light() { //}ColorScheme.fromSeed(seedColor: colorSeed) {
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
    return ZugHome(app:app,noNavBar: noNavBar);
  }

  Widget createOptionsPage(ZugModel model) {
    return OptionsPage(model, scope: OptionScope.general);
  }

  Widget createLobbyPage(ZugModel model) {
    return LobbyPage(model,zugChat: ZugChat(model)); //,
        //foregroundColor: colorScheme.onSurface, backgroundColor: colorScheme.surface)
  }

  Widget createSplashPage(ZugModel model, {
    String landImgPath = "images/splash_land.png",
    String portImgPath = "images/splash_port.png",
    List<LoginType> allowedLoginTypes = LoginType.values,
  }) {
    return SplashPage(model,
        imgLandscape: Image(image: ZugUtils.getAssetImage(landImgPath),fit: BoxFit.fill),
        imgPortrait: Image(image: ZugUtils.getAssetImage(portImgPath),fit: BoxFit.fill),
        allowedLoginTypes: allowedLoginTypes
    );
  }

  Widget createMainPage(ZugModel model);

  AppBar? createStatusBar(BuildContext context, ZugModel model, {Widget? txt, Color? color}) {
    Text defaultTxt = noNavBar
        ? Text("Hello, ${model.userName?.name ?? "Unknown User"}!")
        : Text("${model.userName}: ${model.currentArea.exists ? model.currentArea.id : "-"}");
    return AppBar(
      backgroundColor: color ?? Theme.of(context).colorScheme.inversePrimary,
      title: txt ?? defaultTxt,
    );
  }

  NavItem getMainNavigationBarItem() {
    return NavItem(
      page: PageType.main,
      destination: const NavigationDestination(
      icon: Icon(Icons.center_focus_strong),
      label: 'Main',
      ));
  }

  NavItem getLobbyNavigationBarItem() {
    return NavItem(
      page: PageType.lobby,
      destination: const NavigationDestination(
        icon: Icon(Icons.local_bar),
        label: 'Lobby',
    ));
  }

  NavItem getSettingsNavigationBarItem() {
    return NavItem(
      page: PageType.options,
      destination: const NavigationDestination(
        icon: Icon(Icons.settings),
        label: 'Settings',
    ));
  }
}

class ZugHome extends StatefulWidget {
  final ZugApp app;
  final bool noNavBar;

  const ZugHome({super.key, required this.app, this.noNavBar = false});

  @override
  State<ZugHome> createState() => _ZugHomeState();

  List<NavItem> get destinations => [
      app.getMainNavigationBarItem(),
      app.getLobbyNavigationBarItem(),
      app.getSettingsNavigationBarItem(),
    ];

  Widget getNavBar(ZugModel model, {
        Decoration? decoration = const BoxDecoration(color: Colors.black),
        Color? iconColor = Colors.white,
        Color? indicatorColor = Colors.grey,
        Color? tintColor = Colors.cyanAccent,
        orientation = Axis.vertical}) => ZugNavBar(
      items: destinations,
      model: model,
      decoration: decoration,
      iconColor: iconColor,
      indicatorColor: indicatorColor,
      tintColor: tintColor,
      orientation: orientation,
  );
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
              if (!widget.noNavBar) widget.getNavBar(model),
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
    if (kIsWeb) {
      return SafeArea(child: widget.app.createStatusBar(context,model) ?? const SizedBox.shrink());
    } else {
      return SafeArea(child:  widget.getNavBar(model));
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