import 'package:flutter/material.dart';
import 'package:zugclient/dialogs.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

class LobbyPage extends StatefulWidget {
  final ZugClient client;
  const LobbyPage(this.client, {super.key});

  @override
  State<StatefulWidget> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {

  @override
  void initState() {
    super.initState();
    widget.client.areaCmd(ClientMsg.setMute,data:{fieldMuted:true}); //TODO: put in main.dart
  }

  @override
  Widget build(BuildContext context) {
    //final double screenWidth = MediaQuery.of(context).size.width; final double screenHeight = MediaQuery.of(context).size.height;
    List<DropdownMenuItem<String>> games = List.empty(growable: true);

    games.add(const DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: Text(ZugClient.noAreaTitle)));
    games.addAll(widget.client.areas.keys.map<DropdownMenuItem<String>>((String title) {  //print("Adding: $title");
      return DropdownMenuItem<String>(
        value: title,
        child: Text(title),
      );
    }).toList());

    return Column(
      children: [ //Text(widget.client.userName),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Select Game:"),
            const SizedBox(width: 8,),
            DropdownButton(
                value: widget.client.currentArea.exists ? widget.client.currentArea.title : null,
                items: games,
                onChanged: (String? title) {
                  setState(() {
                    widget.client.switchArea(title); //client.update();
                  });
                }),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                  style: getButtonStyle(Colors.greenAccent,Colors.redAccent),
                  onPressed: () => Dialogs.getString('Choose Game Title',widget.client.userName)
                      .then((title) => widget.client.send(ClientMsg.newArea, data: {fieldTitle: title})),
                  child: const Text("New"),
                )),
            Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                  style: getButtonStyle(Colors.redAccent, Colors.purpleAccent),
                  onPressed: () => widget.client.areaCmd(ClientMsg.startArea),
                  child: const Text("Start")),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                  style: getButtonStyle(Colors.blueAccent, Colors.greenAccent),
                  onPressed: () => widget.client.areaCmd(ClientMsg.joinArea),
                  child: const Text("Join")),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                  style: getButtonStyle(Colors.black12, Colors.orangeAccent),
                  onPressed: () => widget.client.areaCmd(ClientMsg.partArea),
                  child: const Text("Leave")),
            ),],
        ),
        Expanded(
          child: ListView(
            children: List.generate(widget.client.currentArea.occupants.values.length, (i) {
              dynamic player = widget.client.currentArea.occupants.values.elementAt(i);
              return Text("${player['user']['name']}");
            }),
          ),
        ),
      ],
    );
  }

  ButtonStyle getButtonStyle(Color c1, Color c2) {
    return ButtonStyle(backgroundColor:
    MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) return c2;
      return c1;
    }));
  }

}

