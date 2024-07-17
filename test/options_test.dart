import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:zugclient/dialogs.dart';
import 'package:zugclient/oauth_client.dart';
import 'package:zugclient/options_page.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  TestClient testClient = TestClient("example.com", 8000, "test",null);
  testClient.noServer = true;
  TestArea testArea = testClient.getOrCreateArea({"title" : "testArea"}) as TestArea;
  testArea.options = {
    "fooName" : { fieldOptVal : "Name" },
    "fooInt" : { fieldOptVal : 2, fieldOptMin : 0, fieldOptMax : 12, fieldOptInc : 2 },
    "fooDouble" : { fieldOptVal : 5.0, fieldOptMin : -7.34, fieldOptMax: 18.92, fieldOptInc : .25 },
    "fooBool" : { fieldOptVal: true }
  };
  testClient.currentArea = testArea;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TestApp(testClient));
}

class TestApp extends StatelessWidget {
  final TestClient client;
  const TestApp(this.client,{super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => client,
        child: MaterialApp(
          navigatorKey: globalNavigatorKey,
          title: 'Test',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: OptionsPage(client),
          )
        ),
    );
  }
}

class TestArea extends Area {
  TestArea(super.title);
}

enum TestServMsg {whee}
class TestClient extends ZugClient {

  TestClient(super.domain, super.port, super.remoteEndpoint, super.prefs) {
    addFunctions({
      TestServMsg.whee: whee,
    });
    checkRedirect(OauthClient("lichess.org", "testClient"));
  }

  void whee(data) {

  }

  @override
  Area createArea(dynamic data) {
    return TestArea(data);
  }

}
