import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:zugclient/zug_client.dart';

//final zugclientDialogNavigatorKey = GlobalKey<NavigatorState>(); //currently unused

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
    if (widget.client.soundCheck()) {
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




