import 'package:flutter/material.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

class LobbyPage extends StatefulWidget {
  final ZugClient client;
  final String areaName;
  final Color foregroundColor, backgroundColor;

  const LobbyPage(this.client, {this.areaName = "Area", this.foregroundColor = Colors.white, this.backgroundColor = Colors.black, super.key});

  Widget selectedArea(BuildContext context) {
    return ListView(
      children: List.generate(client.currentArea.occupants.values.length, (i) {
        dynamic player = client.currentArea.occupants.values.elementAt(i);
        return Text("${player['user']['name']}");
      }),
    );
  }

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    List<DropdownMenuItem<String>> games = List.empty(growable: true);

    games.add(const DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: Text(ZugClient.noAreaTitle)));
    games.addAll(widget.client.areas.keys.map<DropdownMenuItem<String>>((String title) {  //print("Adding: $title");
      return DropdownMenuItem<String>(
        value: title,
        child: Text(title,style: TextStyle(backgroundColor: widget.backgroundColor, color: widget.foregroundColor)),
      );
    }).toList());

    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [ //Text(widget.client.userName),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Select ${widget.areaName}",style: TextStyle(color: widget.foregroundColor)),
              const SizedBox(width: 8,),
              DropdownButton(
                  style: TextStyle(color: widget.foregroundColor, backgroundColor: widget.backgroundColor),
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
                    onPressed: () => widget.client.newArea(),
                    child: const Text("New"),
                  )),
              Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                    style: getButtonStyle(Colors.redAccent, Colors.purpleAccent),
                    onPressed: () => widget.client.startArea(),
                    child: const Text("Start")),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                    style: getButtonStyle(Colors.blueAccent, Colors.greenAccent),
                    onPressed: () => widget.client.joinArea(),
                    child: const Text("Join")),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                    style: getButtonStyle(Colors.black12, Colors.orangeAccent),
                    onPressed: () => widget.client.partArea(),
                    child: const Text("Leave")),
              ),],
          ),
          Expanded(child: widget.selectedArea(context)),
        ],
      )
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

