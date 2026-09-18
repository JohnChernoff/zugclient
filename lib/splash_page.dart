import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:zug_net/oauth_client.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_model.dart';

class NormalizedRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const NormalizedRect(
      this.x,
      this.y,
      this.width,
      this.height,
      );
}

class SplashWidget {
  final NormalizedRect? landscape;
  final NormalizedRect? portrait;
  final Color? color;
  final Widget child;

  const SplashWidget({
    this.landscape,
    this.portrait,
    this.color,
    required this.child,
  });
}

class SplashPage2 extends StatelessWidget {
  final ZugModel model;
  final String? imgLandscape;
  final String? imgPortrait;
  final Map<LoginType, SplashWidget> loginWidgets;

  const SplashPage2(
      this.model, {
        this.imgLandscape,
        this.imgPortrait,
        this.loginWidgets = const {},
        super.key,
      });

  @override
  Widget build(BuildContext context) {
    final entries = loginWidgets.entries;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final port = constraints.maxHeight > constraints.maxWidth;
        final safe = MediaQuery.of(ctx).padding;

        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight - safe.bottom;

        return Container(
          width: maxW,
          height: maxH,
          decoration: getDecor(
            port ? imgPortrait : imgLandscape,
          ),
          child: Stack(
            children: [
              for (final e in entries)
                _buildPositionedWidget(
                  e.key,
                  e.value,
                  port,
                  maxW,
                  maxH,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionedWidget(
      LoginType loginType,
      SplashWidget widget,
      bool portrait,
      double maxW,
      double maxH,
      ) {
    final rect = portrait
        ? widget.portrait
        : widget.landscape;

    return Positioned(
      left: rect == null ? null : rect.x * maxW,
      top: rect == null ? null : rect.y * maxH,
      width: rect == null ? null : rect.width * maxW,
      height: rect == null ? null : rect.height * maxH,
      child: InkWell(
        onTap: () => model.login(loginType),
        child: Container(
          color: widget.color,
          child: Center(
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Decoration getDecor(String? imgPath) {
    return imgPath == null
        ? const BoxDecoration(color: Colors.green)
        : BoxDecoration(
      image: DecorationImage(
        fit: BoxFit.fill,
        image: AssetImage(imgPath),
      ),
    );
  }
}

class SplashPage extends StatelessWidget {
  final ZugModel model;
  final Image? imgLandscape, imgPortrait;
  final List<LoginType> allowedLoginTypes;
  const SplashPage(this.model,{this.imgLandscape,this.imgPortrait,super.key, this.allowedLoginTypes = LoginType.values});

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
            if (allowedLoginTypes.contains(LoginType.none)) ElevatedButton(
              onPressed: () {
                model.login(LoginType.none);
              },
              style: buttonStyle,
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login as Guest",style: txtStyle))
            ),
            const SizedBox(width: 36),
            if (allowedLoginTypes.contains(LoginType.google)) ElevatedButton(
              onPressed: () {
                model.login(LoginType.google);
              },
              style: buttonStyle,
              child: Padding(padding: const EdgeInsets.all(8), child: Text("Login with Google",style: txtStyle)),
            ),
            const SizedBox(width: 36),
            if (allowedLoginTypes.contains(LoginType.lichess)) ElevatedButton(
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
              : SizedBox(child: img ?? const Center(child: Text("Welcome to ZugClient"))), //?? const SizedBox()
        ),
      ],
    )));
  }

}