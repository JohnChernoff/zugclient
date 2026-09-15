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
  final String? splashLandImgPath; //= "images/splash_land.png",
  final String? splashPortImgPath; //= "images/splash_port.png",
  late final List<ZugPage> pageList = stockPages();

  ZugApp(this.model, this.appName, {
    this.colorSeed = Colors.green,
    this.isDark = true,
    super.key,
    Level logLevel = Level.INFO,
    this.noNavBar = false,
    this.splashLandImgPath, this.splashPortImgPath,
  }) : colorScheme = isDark ? const ColorScheme.dark() : const ColorScheme.light() { //}ColorScheme.fromSeed(seedColor: colorSeed) {
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

  List<ZugPage> stockPages() => [
    ZugPage(const Icon(Icons.center_focus_strong), (model) => createMainPage(model),
        type: PageType.main, label: "Main"),
    ZugPage(const Icon(Icons.local_bar), (model) => createLobbyPage(model),
        type: PageType.lobby, label: "Lobby"),
    ZugPage(const Icon(Icons.settings), (model) => createOptionsPage(model),
        type: PageType.options, label: "Settings"),
  ];

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
    List<LoginType> allowedLoginTypes = LoginType.values,
  }) {
    return SplashPage(model,
        imgLandscape: splashLandImgPath != null ? Image(image: ZugUtils.getAssetImage(splashLandImgPath!),fit: BoxFit.fill) : null,
        imgPortrait: splashPortImgPath != null ? Image(image: ZugUtils.getAssetImage(splashPortImgPath!),fit: BoxFit.fill) : null,
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
}

class ZugHome extends StatefulWidget {
  final ZugApp app;
  final bool noNavBar;

  const ZugHome({super.key, required this.app, this.noNavBar = false});

  @override
  State<ZugHome> createState() => _ZugHomeState();

  Widget getNavBar(ZugModel model, {
    Decoration? decoration = const BoxDecoration(color: Colors.black),
    Color? iconColor = Colors.white,
    Color? indicatorColor = Colors.grey,
    Color? tintColor = Colors.cyanAccent,
    Axis orientation = Axis.vertical}) => ZugNavBar(
    pages: app.pageList,
    model: model,
    decoration: decoration,
    iconColor: iconColor,
    indicatorColor: indicatorColor,
    tintColor: tintColor,
    orientation: orientation,
  );
}

enum PageType { main,lobby,options,splash,none }

class ZugPage {
  Icon icon;
  Enum type;
  String label;
  Widget Function(ZugModel model) destination;
  bool Function(ZugModel model)? visible;

  ZugPage(this.icon, this.destination, {
    this.type = PageType.none,
    this.label = "",
    this.visible,
  });

  bool isVisible(ZugModel model) => visible?.call(model) ?? true;
}

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
        child: ValueListenableBuilder<Enum>(
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

  Widget _buildPageForType(ZugModel model, Enum pageType) {
    if (!model.isLoggedIn) return widget.app.createSplashPage(model);
    if (pageType == PageType.splash || pageType == PageType.none) {
      return widget.app.createSplashPage(model);
    }
    for (ZugPage page in widget.app.pageList) {
      if (page.type == pageType) return page.destination(model);
    }
    return widget.app.createSplashPage(model);
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
