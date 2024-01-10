import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:zugclient/zug_client.dart';
import 'oauth_client.dart';

class SplashPage extends StatelessWidget {
  final ZugClient client;
  final Image? splashImage;

  const SplashPage(this.client,this.splashImage,{super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (!client.loggingIn) client.connect();
              },
              child: const Padding(padding: EdgeInsets.all(8), child: Text("Login as Guest")),
            ),
            ElevatedButton(
              onPressed: () {
                if (!client.loggingIn) client.authenticate(OauthClient("lichess.org", client.clientName));
              },
              child: const Padding(padding: EdgeInsets.all(8), child: Text("Login with Lichess")),
            ),
          ],
        ),
        Expanded(
          child: !kIsWeb && client.loggingIn
              ? WebViewWidget(controller: OauthClient.webViewController)
              : splashImage ?? const SizedBox(),
        ),
      ],
    );
  }

}