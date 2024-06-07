import 'package:flutter/foundation.dart';
import "package:universal_html/html.dart" as html;
import 'package:flutter/material.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_utils.dart';

class LobbyPage extends StatefulWidget {
  final ZugClient client;
  final String areaName;
  final Color foregroundColor, backgroundColor;
  final ImageProvider? backgroundImage;
  final String helpPage;
  final double widthFactor;

  const LobbyPage(this.client, {
    this.backgroundImage,
    this.areaName = "Area",
    this.foregroundColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.helpPage = "",
    this.widthFactor = 1,
    super.key});

  Widget selectedArea(BuildContext context) {
    return ListView(
      children: List.generate(client.currentArea.occupants.values.length, (i) {
        return Text(client.currentArea.getOccupantName(client.currentArea.occupants.keys.elementAt(i)));
      }),
    );
  }

  Widget getAreaItem(String? title) {
    return Text(title ?? "",style: TextStyle(backgroundColor: backgroundColor, color: foregroundColor));
  }

  Widget getHelp(BuildContext context, Widget buttons) { //TODO: make abstract
    return buttons;
  }

  Widget getSocialMediaButtons() {
    return const SizedBox.shrink();
  }

  Widget getJoinButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.blueAccent, Colors.greenAccent),
        onPressed: () => client.joinArea(),
        child: const Text("Join"));
  }

  Widget getPartButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.black26, Colors.orangeAccent),
        onPressed: () => client.partArea(),
        child: const Text("Leave"));
  }

  Widget getStartButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.redAccent, Colors.purpleAccent),
        onPressed: () => client.startArea(),
        child: const Text("Start"));
  }

  Widget getCreateButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.greenAccent, Colors.redAccent),
        onPressed: () => client.newArea(),
        child: const Text("New"));
  }

  ButtonStyle getButtonStyle(Color c1, Color c2) {
    return ButtonStyle(backgroundColor:
    MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) return c2;
      return c1;
    }));
  }

  @override
  State<StatefulWidget> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {

  bool showHelp = false;

  @override
  void initState() {
    super.initState();
    widget.client.areaCmd(ClientMsg.setMute,data:{fieldMuted:true}); //TODO: put in main.dart
  }



  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width * widget.widthFactor;

    if (showHelp) return widget.getHelp(context, getCommandButtons(width));

    List<DropdownMenuItem<String>> games = []; //List.empty(growable: true);

    //games.add(const DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: Text(ZugClient.noAreaTitle)));
    games.add(DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: widget.getAreaItem(ZugClient.noAreaTitle)));
    games.addAll(widget.client.areas.keys.map<DropdownMenuItem<String>>((String title) {  //print("Adding: $title");
      return DropdownMenuItem<String>(
        value: title,
        child: widget.getAreaItem(title),
      );
    }).toList());

    return Container(
        width: width,
        decoration: BoxDecoration(
        color: widget.backgroundColor,
        image: widget.backgroundImage != null ? DecorationImage(
            image: widget.backgroundImage!,
            fit: BoxFit.cover
        ) : null,
      ),
      child: Column(
        children: [ //Text(widget.client.userName),
          Center(child: Container(
            color: Colors.white,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Select ${widget.areaName}: ",style: TextStyle(color: widget.foregroundColor)),
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
          )),
          getCommandButtons(width),
          Expanded(child: widget.selectedArea(context)),
        ],
      )
    );
  }

  Widget getHelpButton() {
    return ElevatedButton(
        style: widget.getButtonStyle(Colors.cyan, Colors.lightBlueAccent),
        onPressed: ()  {
          if (widget.helpPage.isNotEmpty) {
            if (kIsWeb) {
              html.window.open(widget.helpPage, 'new tab');
            } else {
              ZugUtils.launch(widget.helpPage, isNewTab: true);
            }
          }
          else {
            setState(() { showHelp = true; });
          }
        },
        child: const Text("Help"));
  }

  Widget getCommandButtons(double width, {double padding = 4}) {
    return Container(
        width: width,
        height: 50,
        color: Colors.white,
        child: showHelp ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                style: widget.getButtonStyle(Colors.cyan, Colors.lightBlueAccent),
                onPressed: () =>  setState(() {
                  showHelp = false;
                }),
                child: const Text("Return")),
          ],
        )
            : Center(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          //mainAxisAlignment: MainAxisAlignment.center,
          child: Row(children: [
            Padding(padding: EdgeInsets.all(padding),child: widget.getCreateButton()),
            Padding(padding: EdgeInsets.all(padding),child: widget.getStartButton()),
            Padding(padding: EdgeInsets.all(padding),child: widget.getJoinButton()),
            Padding(padding: EdgeInsets.all(padding),child: widget.getPartButton()),
            Padding(padding: EdgeInsets.all(padding),child: getHelpButton()),
            Padding(padding: EdgeInsets.all(padding),child: widget.getSocialMediaButtons()),
          ],
        ))),
      );
  }

}

