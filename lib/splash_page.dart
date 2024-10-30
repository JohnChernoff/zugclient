import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:zug_net/oauth_client.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_client.dart';

class SplashPage extends StatelessWidget {
  final ZugClient client;
  final Image? imgLandscape, imgPortrait;
  final bool dark;

  const SplashPage(this.client,{this.imgLandscape,this.imgPortrait,this.dark = true,super.key});

  @override
  Widget build(BuildContext context) {
    final dim = ZugUtils.getScreenDimensions(context);
    final Image? img = dim.getMainAxis() == Axis.horizontal ? imgLandscape : imgPortrait;
    final txtStyle = TextStyle(color: dark ? Colors.black : Colors.white);

    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints constraints) =>
      Container(color: dark ? Colors.black : Colors.white, width: constraints.maxWidth, height: constraints.maxHeight, child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                client.login(LoginType.none);
              },
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login as Guest",style: txtStyle)),
             // style: ButtonStyle(backgroundColor: dark ? Colors.black : Colors.white, foregroundColor: dark ? Colors.white : Colors.black)
            ),
            ElevatedButton(
              onPressed: () {
                client.login(LoginType.lichess);
              },
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login with Lichess",style: txtStyle)),
            ),
          ],
        ),
        Expanded(
          child: !kIsWeb && client.authenticating
              ? WebViewWidget(controller: OauthClient.webViewController)
              : SizedBox(child: img), //?? const SizedBox()
        ),
      ],
    )));
  }

}