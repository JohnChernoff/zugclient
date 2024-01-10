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
```

## Additional information

Very early version - project is rapidly developing, expect updates soon
