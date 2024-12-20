import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zugclient/options_page.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  LoxClient testClient = LoxClient("zugaddict.com", 9999, "test", null);
  testClient.localServer = true;
  testClient.connect();
  runApp(LoxApp(testClient));
}

class LoxApp extends StatelessWidget {
  final LoxClient client;
  const LoxApp(this.client,{super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => client,
      child: MaterialApp( //navigatorKey: zugclientDialogNavigatorKey,
          title: 'Test',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: const LoxHome()
      ),
    );
  }
}

class LoxHome extends StatelessWidget {
  const LoxHome({super.key});
  @override
  Widget build(BuildContext context) {
    var client = context.watch<LoxClient>();
    return Scaffold(
      body: OptionsPage(client),
    );
  }
}

class LoxClient extends ZugClient {
  LoxClient(super.domain, super.port, super.remoteEndpoint, super.prefs) {
    checkRedirect("lichess.org");
  }

  @override
  Future<bool> loggedIn(data) async {
    super.loggedIn(data);
    send(ClientMsg.newArea,data: {fieldTitle : "testArea"});
    Future.delayed(const Duration(seconds: 5)).then((value) {
      switchArea("testArea");
      areaCmd(ClientMsg.getOptions);
      notifyListeners();
    });
    return true;
  }

  @override
  Area createArea(dynamic data) {
    return LoxArea(data);
  }

}

class LoxArea extends Area {
  LoxArea(super.title);
}
