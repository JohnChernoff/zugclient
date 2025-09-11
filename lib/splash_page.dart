import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:zug_net/oauth_client.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_model.dart';

class SplashPage extends StatelessWidget {
  final ZugModel model;
  final Image? imgLandscape, imgPortrait;

  const SplashPage(this.model,{this.imgLandscape,this.imgPortrait,super.key});

  @override
  Widget build(BuildContext context) { //TODO: generalize
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = ZugUtils.getScreenDimensions(context);
    final Image? img = dim.getMainAxis() == Axis.horizontal ? imgLandscape : imgPortrait;
    final txtStyle = TextStyle(color: isDark ? Colors.black : Colors.blue);
    final buttonStyle = ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.cyanAccent);

    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints constraints) =>
      Container(color: isDark ? Colors.black : Colors.white, width: constraints.maxWidth, height: constraints.maxHeight, child: Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                model.login(LoginType.none);
              },
              style: buttonStyle,
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login as Guest",style: txtStyle))
            ),
            const SizedBox(width: 36),
            ElevatedButton(
              onPressed: () {
                model.login(LoginType.google);
              },
              style: buttonStyle,
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login with Google",style: txtStyle)),
            ),
            const SizedBox(width: 36),
            ElevatedButton(
              onPressed: () {
                model.login(LoginType.lichess);
              },
              style: buttonStyle,
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login with Lichess",style: txtStyle)),
            ),
          ],
        ),
        Expanded(
          child: !kIsWeb && model.authenticating
              ? WebViewWidget(controller: OauthClient.webViewController)
              : SizedBox(child: img), //?? const SizedBox()
        ),
      ],
    )));
  }

}