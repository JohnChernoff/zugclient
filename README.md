<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Basic Flutter/Dart Client Package for the ZugServ Library

## Features

Enables the rapid creation of a client to connect to and manage responses from a ZugServ.

## Getting started

For creating a ZugClient: pub get zugclient <br>
For creating a ZugServ: https://github.com/JohnChernoff/ZugServ

## Usage

```dart
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

  void whee(data) { print("Received message tyoe 'Whee' from Server"); }

  @override
  Area createArea(String title) {
    return TestArea(title);
  }

}
```

## Additional information

Very early version - project is rapidly developing, expect updates soon
