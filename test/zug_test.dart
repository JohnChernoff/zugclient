import 'package:flutter/cupertino.dart';
import 'package:zugclient/oauth_client.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_client.dart';

void main() {
  TestClient testClient = TestClient("example.com", 9999, "test",localServer : true);
  runApp(TestApp(testClient));
}

class TestApp extends ZugApp {
  TestApp(super.client, {super.key});

  @override
  Widget createMainPage(client) {
    return const Text("Main Page");
  }

}

class TestClient extends ZugClient {
  TestClient(super.domain, super.port, super.remoteEndpoint, {super.localServer}) {
    checkRedirect(OauthClient("lichess.org", clientName));
  }

  @override
  Area createArea(String title) {
    return TestArea(title);
  }

}

class TestArea extends Area {
  TestArea(super.title);
}
