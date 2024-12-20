import 'package:flutter/cupertino.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_client.dart';

void main() {
  TestClient testClient = TestClient("example.com", 9999, "test",localServer : true, null);
  runApp(TestApp(testClient,"TestApp"));
}

class TestApp extends ZugApp {
  TestApp(super.client, super.appName, {super.key});

  @override
  Widget createMainPage(client) {
    return const Text("Main Page");
  }

}

class TestClient extends ZugClient {
  TestClient(super.domain, super.port, super.remoteEndpoint, super.prefs, {super.localServer}) {
    checkRedirect("lichess.org");
  }

  @override
  Area createArea(dynamic data) {
    return TestArea(data);
  }

}

class TestArea extends Area {
  TestArea(super.title);
}
