import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_client.dart';
import "package:universal_html/html.dart" as html;
import 'options_page.dart';

class IntroDialog {
  final String appName;
  final String? tutorialUrl, discordUrl;
  final BuildContext ctx;

  IntroDialog(this.appName, this.ctx,{this.tutorialUrl, this.discordUrl});

  Future<bool?> raise() {
    return showDialog<bool?>(
        context: ctx,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text("Welcome to $appName!"),
            children: [
              if (tutorialUrl != null) SimpleDialogOption(
                  onPressed: () {
                    if (kIsWeb) {
                      html.window.open(tutorialUrl!, 'new tab');
                    } else {
                      ZugUtils.launch(tutorialUrl!, isNewTab: true);
                    }
                  },
                  child: Text('Learn $appName')),
              if (discordUrl != null) SimpleDialogOption(
                  onPressed: () {
                    if (kIsWeb) {
                      html.window.open(discordUrl!, 'new tab');
                    } else {
                      ZugUtils.launch(discordUrl!, isNewTab: true);
                    }
                  },
                  child: const Text('Visit Discord')),
              SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context,false);
                  },
                  child: const Text('Start without Music')),
              SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context,true);
                  },
                  child: const Text('Start with Music')),
            ],
          );
        });
  }
}

class MusicStackDialog extends StatefulWidget {

  final List<Widget> stack;
  final String track;
  final ZugClient client;

  const MusicStackDialog(this.client,this.track,this.stack, {super.key});

  @override
  State<StatefulWidget> createState() => MusicStackDialogState();

}

class MusicStackDialogState extends State<MusicStackDialog> {
  bool playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.client.getOption(AudioOpt.music)?.getBool() == true) {
      playTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!playing) {
      widget.stack.add(ElevatedButton(
          onPressed: () {
            playTrack();
            setState(() { widget.stack.removeLast(); });
          },
          child: const Text("Turn on sound")
      )
      );
    }

    return Dialog(
        alignment: Alignment.center,
        elevation: 10,
        child: GestureDetector(
          onTap: () {
            widget.client.clipPlayer.stop();
            Navigator.pop(context);
            },
          child: Stack(children: widget.stack),
        )
    );

  }

  void playTrack() {
    playing = true;
    widget.client.clipPlayer.play(AssetSource('audio/tracks/${widget.track}.mp3'));
  }

}

class OptionDialog {
  ZugClient client;
  BuildContext ctx;
  OptionScope scope;
  OptionDialog(this.client, this.ctx, this.scope);

  Future<void> raise() async {
    return showDialog<void>(
        context: ctx,
        builder: (BuildContext context) {
          return LayoutBuilder(builder: (BuildContext buildCtx,BoxConstraints constraints) => Dialog(
              insetPadding: EdgeInsets.symmetric(vertical: constraints.maxHeight * .25, horizontal: constraints.maxWidth * .25),
              backgroundColor: Colors.cyan,
              child: Column(children: [
                Expanded(child: OptionsPage(client,scope: scope,isDialog: true,headerHeight: 48)),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",style: TextStyle(backgroundColor: Colors.white)),
                ),
              ])));
        });
  }
}

class HelpDialog {
  ZugClient client;
  String helpTxt;
  bool helpModeOption;
  Color bkgCol, txtCol, buttCol;
  HelpDialog(this.client, this.helpTxt, {this.helpModeOption  = false, this.bkgCol = Colors.cyan, this.txtCol = Colors.black, this.buttCol = Colors.white});

  Future<void> raise() async {
    if (zugAppNavigatorKey.currentContext == null) return;
    return showDialog<void>(
        context: zugAppNavigatorKey.currentContext!,
        builder: (BuildContext context) {
          return SimpleDialog(
              backgroundColor: bkgCol,
              children: [
                Text(helpTxt, style: TextStyle(color: txtCol)),
                if (helpModeOption) HelpModeDialogOption(client),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Return",style: TextStyle(color: txtCol, backgroundColor: buttCol)),
                ),
              ]);
        });
  }
}

class HelpModeDialogOption extends StatefulWidget {
  final ZugClient client;
  const HelpModeDialogOption(this.client,{super.key});
  @override
  State<StatefulWidget> createState() => HelpModeDialogOptionState();
}

class HelpModeDialogOptionState extends State<HelpModeDialogOption> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => widget.client.setHelpMode(!widget.client.helpMode));
      },
      child: Text("${widget.client.helpMode ? 'Deactivate' : 'Activate'} Help Mode",style: const TextStyle(backgroundColor: Colors.lime)),
    );
  }
}


