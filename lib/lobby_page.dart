import 'package:flutter/foundation.dart';
import "package:universal_html/html.dart" as html;
import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_client.dart';

enum LobbyStyle {normal,terseLand,tersePort}

class LobbyPage extends StatefulWidget {
  final ZugClient client;
  final String areaName;
  final Color? bkgCol;
  final Color? buttonsBkgCol; //,areaSelectColorTheme;
  final ImageProvider? backgroundImage;
  final ZugChat? chatArea;
  final LobbyStyle style;
  final double? width;
  final double borderWidth;
  final Color borderCol;
  final int areaFlex;

  const LobbyPage(this.client, {
    this.backgroundImage,
    this.areaName = "Area",
    this.bkgCol,
    this.buttonsBkgCol,
    this.style = LobbyStyle.normal,
    this.width,
    this.borderWidth  = 1,
    this.borderCol = Colors.white,
    this.areaFlex  = 3,
    super.key, this.chatArea});

  Widget selectedArea(BuildContext context, {Color? bkgCol, Color? txtCol}) {
    return Container(
        decoration: BoxDecoration(
          color: bkgCol ?? Colors.black,
          border: Border.all(color: txtCol ?? borderCol, width: borderWidth),
        ),
        child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: getOccupantHeaders(),
          rows: List.generate(client.currentArea.occupantMap.values.length, (i) {
            UniqueName uName = client.currentArea.occupantMap.keys.elementAt(i);
            return getOccupantData(uName, client.currentArea.occupantMap[uName]);
          })),
      )),
    );
  }

  List<DataColumn> getOccupantHeaders({Color color = Colors.white}) {
    return [
      DataColumn(label: Text("Name",style: TextStyle(color: color)))
    ];
  }

  DataRow getOccupantData(UniqueName uName, Map<String,dynamic> json, {Color color = Colors.white}) {
    return DataRow(cells: [
      DataCell(Text(
          client.currentArea.getOccupantName(uName),
          style: TextStyle(color: color)
      ))
    ]);
  }

  Widget getAreaItem(String? title, BuildContext context) {
    return Text(title ?? "", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary));
  }

  int compareAreas(Area? a, Area? b) {
    if (a == null || b == null) return 0;
    return a.title.compareTo(b.title);
  }


  Widget getHelp(BuildContext context, Widget buttons) { //TODO: make abstract
    return buttons;
  }

  Widget getHelpButton(String helpPage) {
    return ElevatedButton(
        style: getButtonStyle(Colors.cyan, Colors.lightBlueAccent),
        onPressed: ()  {
          if (kIsWeb) {
            html.window.open(helpPage, 'new tab');
          } else {
            ZugUtils.launch(helpPage, isNewTab: true);
          }
        },
        child: Text("Help",style: getButtonTextStyle()));
  }

  Widget getSeekButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.orangeAccent, Colors.greenAccent),
        onPressed: () => client.seekArea(),
        child: Text("Seek",style: getButtonTextStyle()));
  }

  Widget getJoinButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.blueAccent, Colors.greenAccent),
        onPressed: () => client.joinArea(client.currentArea.title),
        child: Text("Join",style: getButtonTextStyle()));
  }

  Widget getPartButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.grey, Colors.orangeAccent),
        onPressed: () => client.partArea(),
        child: Text("Leave",style: getButtonTextStyle()));
  }

  Widget getStartButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.redAccent, Colors.purpleAccent),
        onPressed: () => client.startArea(),
        child: Text("Start",style: getButtonTextStyle()));
  }

  Widget getCreateButton() {
    return ElevatedButton(
        style: getButtonStyle(Colors.greenAccent, Colors.redAccent),
        onPressed: () => client.newArea(),
        child: Text("New",style: getButtonTextStyle()));
  }

  List<Widget> getExtraCmdButtons() {
    return [];
  }

  ButtonStyle getButtonStyle(Color c1, Color c2) {
    return ButtonStyle(backgroundColor:
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) return c2;
      return c1;
    }));
  }

  TextStyle getButtonTextStyle() {
    return const TextStyle(color: Colors.black);
  }

  @override
  State<StatefulWidget> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {

  bool showHelp = false;

  @override
  void initState() {
    super.initState();
  }

  Widget getAreaArea(BuildContext context) {
    if (showHelp) return widget.getHelp(context, getCommandArea());

    List<DropdownMenuItem<String>> games = []; //List.empty(growable: true);

    games.add(DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: widget.getAreaItem(ZugClient.noAreaTitle,context)));
    games.addAll(widget.client.areas.keys.map<DropdownMenuItem<String>>((String title) {  //print("Adding: $title");
      return DropdownMenuItem<String>(
        value: title,
        child: widget.getAreaItem(title,context),
      );
    }).toList());

    games.sort((a,b) => widget.compareAreas(widget.client.areas[a.value],widget.client.areas[b.value]));

    return Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.bkgCol ?? Theme.of(context).primaryColor,
          border: Border.all(color: widget.borderCol, width: widget.borderWidth),
          image: widget.backgroundImage != null ? DecorationImage(
              image: widget.backgroundImage!,
              fit: BoxFit.cover
          ) : null,
        ),
        child: Column(
          children: [ //Text(widget.client.userName),
            getCommandArea(),
            Center(
              child: Container(
              color: Theme.of(context).primaryColor, //widget.areaSelectBkgColor,
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Select ${widget.areaName}: ", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  const SizedBox(width: 8),
                  DropdownButton(
                      dropdownColor: Theme.of(context).colorScheme.primary,
                      value: widget.client.currentArea.exists ? widget.client.currentArea.title : null,
                      items: games,
                      onChanged: (String? title) {
                        setState(() {
                          widget.client.switchArea(title); //client.update();
                        });
                      }),
                ],
              )),
            )),
            Expanded(child: widget.selectedArea(context)),
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal,
      children: [
        Expanded(flex: widget.areaFlex, child: getAreaArea(context)),
        Expanded(flex: 1, child: widget.chatArea ?? const SizedBox.shrink()),
      ],
    );
  }

  Widget getCommandArea() {
    return Container(
        decoration: BoxDecoration(
            color: widget.buttonsBkgCol ?? Colors.white,
            border: Border.all(
              color: widget.borderCol,
              width: widget.borderWidth
            )
        ),
        width: widget.style == LobbyStyle.tersePort ? 128 : null,
        height: widget.style == LobbyStyle.tersePort ? null : 50,
        child: showHelp ? Flex(
          direction: widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                style: widget.getButtonStyle(Colors.cyan, Colors.lightBlueAccent),
                onPressed: () =>  setState(() {
                  showHelp = false;
                }),
                child: Text("Return",style: widget.getButtonTextStyle())),
          ],
        )
            : Center(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          //mainAxisAlignment: MainAxisAlignment.center,
          child: Flex(
            direction: widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal,
            children: getCmdButtons(),
        ))),
      );
  }

  List<Widget> getCmdButtons({
      double padding = 4.0,
      Widget? seekButt,
      Widget? createButt,
      Widget? startButt,
      Widget? joinButt,
      Widget? partButt,
      Widget? helpButt,
      List<Widget>? extraButts}) {
    List<Widget> buttons = [
      Padding(padding: EdgeInsets.all(padding),child: seekButt ?? widget.getSeekButton()),
      Padding(padding: EdgeInsets.all(padding),child: createButt ?? widget.getCreateButton()),
      Padding(padding: EdgeInsets.all(padding),child: startButt ?? widget.getStartButton()),
      Padding(padding: EdgeInsets.all(padding),child: joinButt ?? widget.getJoinButton()),
      Padding(padding: EdgeInsets.all(padding),child: partButt ?? widget.getPartButton()),
      //if (widget.helpPage != null) Padding(padding: EdgeInsets.all(padding),child: helpButt ?? widget.getHelpButton()),
    ];
    List<Widget> extraList = extraButts ?? widget.getExtraCmdButtons();
    buttons.addAll(List.generate(extraList.length, (index) => Padding(padding: EdgeInsets.all(padding),child: extraList.elementAt(index))));
    return buttons;
  }

}

