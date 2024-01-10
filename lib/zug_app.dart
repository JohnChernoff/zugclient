import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zugclient/splash_page.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'dialogs.dart';
import 'lobby_page.dart';
import 'options_page.dart';

abstract class ZugApp extends StatelessWidget {
  final ZugClient client;
  ZugApp(this.client, { super.key, Level logLevel = Level.ALL }) {
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
          navigatorKey: globalNavigatorKey,
          title: 'LoxBall',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: ZugHome(app:this),
        )
    );
  }

  Widget createOptionsPage(client) {
    return OptionsPage(client);
  }

  Widget createLobbyPage(client) {
    return LobbyPage(client);
  }

  Widget createSplashPage(client) {
    return SplashPage(client,const Image(image: AssetImage("images/splash.jpg")));
  }

  Widget createMainPage(client);
}

class ZugHome extends StatefulWidget {
  final ZugApp app;

  const ZugHome({super.key, required this.app});

  @override
  State<ZugHome> createState() => _ZugHomeState();
}

enum Pages { main,lobby,options }

class _ZugHomeState extends State<ZugHome> {
  var selectedIndex = 0;
  Pages selectedPage = Pages.lobby;

  @override
  Widget build(BuildContext context) {
    var client = context.watch<ZugClient>();
    SafeArea safeArea = getSafeArea(client);
    var colorScheme = Theme
        .of(context)
        .colorScheme;

    Widget page = widget.app.createSplashPage(client);

    if (client.isLoggedIn) {
      page = switch (selectedPage) {
        Pages.main => widget.app.createMainPage(client),
        Pages.lobby => widget.app.createLobbyPage(client),
        Pages.options => widget.app.createOptionsPage(client),
      };
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
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text("${client.userName}: ${client.currentArea.exists ? client.currentArea.title : "-"}"),
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
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_bar),
            label: 'Lobby',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: (value) {
          if (!Dialogs.dialog) {
            setState(() {
              selectedIndex = value;
              Pages newPage = Pages.values.elementAt(selectedIndex);
              selectedPage = newPage;
              if (selectedPage == Pages.options && client.currentArea.exists) {
                widget.app.client.send(ClientMsg.getOptions,data: widget.app.client.currentArea.title);
              }
            });
          }
        },
      ),
    );
  }

}

