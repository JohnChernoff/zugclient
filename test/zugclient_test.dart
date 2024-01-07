import 'package:flutter_test/flutter_test.dart';
import 'package:zugclient/oauth_client.dart';
import 'package:zugclient/zug_client.dart';

void main() {
  test('construct a client', () {
    TestClient testClient = TestClient("example.com", 80, "test");
    testClient.currentArea = testClient.getOrCreateArea("testArea");
    expect(testClient.currentArea.title, "testArea");
  });
}

class TestArea extends Area {
  TestArea(super.title);
}

enum TestServMsg {whee}
class TestClient extends ZugClient {

  TestClient(super.domain, super.port, super.remoteEndpoint) {
    addFunctions({
      TestServMsg.whee.name: whee,
    });
    checkRedirect(OauthClient("lichess.org", "testClient"));
  }

  void whee(data) {

  }

  @override
  Area createArea(String title) {
    return TestArea(title);
  }

}
