import 'package:flutter/foundation.dart';
import "package:universal_html/html.dart" as html;
import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_area.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_model.dart';

enum LobbyStyle {normal,terseLand,tersePort}

class LobbyPage extends StatefulWidget {
  final ZugModel model;
  final String areaName;
  final Color? bkgCol;
  final Color? buttonsBkgCol;
  final ImageProvider? backgroundImage;
  final LobbyStyle style;
  final double? width;
  final double borderWidth;
  final Color borderCol;
  final ZugChat? zugChat;
  final bool seekButt, createButt, startButt, joinButt, partButt;
  final int portFlex;

  const LobbyPage(this.model, {
    this.backgroundImage,
    this.areaName = "Area",
    this.bkgCol,
    this.buttonsBkgCol,
    this.style = LobbyStyle.normal,
    this.width,
    this.borderWidth  = 1,
    this.borderCol = Colors.white,
    this.zugChat,
    this.seekButt = true,
    this.createButt = true,
    this.startButt = true,
    this.joinButt = true,
    this.partButt = true,
    this.portFlex = 2,
    super.key});

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
          rows: List.generate(model.currentArea.occupantMap.values.length, (i) {
            UniqueName uName = model.currentArea.occupantMap.keys.elementAt(i);
            return getOccupantData(uName, model.currentArea.occupantMap[uName]);
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
          model.currentArea.getOccupantName(uName),
          style: TextStyle(color: color)
      ))
    ]);
  }

  Widget getAreaItem(String? title, BuildContext context) {
    return Text(title ?? "", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary));
  }

  int compareAreas(Area? a, Area? b) {
    if (a == null || b == null) return 0;
    return a.id.compareTo(b.id);
  }


  Widget getHelp(BuildContext context, Widget buttons) { //TODO: make abstract
    return buttons;
  }

  Widget getHelpButton(String helpPage, {Color normCol = Colors.cyan,  pressedCol = Colors.lightBlueAccent}) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: ()  {
          if (kIsWeb) {
            html.window.open(helpPage, 'new tab');
          } else {
            ZugUtils.launch(helpPage, isNewTab: true);
          }
        },
        child: Text("Help",style: getButtonTextStyle()));
  }

  Widget getSeekButton({Color normCol = Colors.orangeAccent,  pressedCol = Colors.greenAccent}) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: () => model.seekArea(),
        child: Text("Seek",style: getButtonTextStyle()));
  }

  Widget getJoinButton({Color normCol = Colors.blueAccent,  pressedCol = Colors.greenAccent}) { //}ChatScopeController chatScopeController) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: () {
          model.joinArea(model.currentArea.id); //chatScopeController.setScope(MessageScope.area);
        },
        child: Text("Join",style: getButtonTextStyle()));
  }

  Widget getPartButton({Color normCol = Colors.grey,  pressedCol = Colors.orangeAccent}) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: () => model.partArea(),
        child: Text("Leave",style: getButtonTextStyle()));
  }

  Widget getStartButton({Color normCol = Colors.redAccent,  pressedCol = Colors.purpleAccent}) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: () => model.startArea(),
        child: Text("Start",style: getButtonTextStyle()));
  }

  Widget getCreateButton({Color normCol = Colors.greenAccent,  pressedCol = Colors.redAccent}) {
    return ElevatedButton(
        style: getButtonStyle(normCol,pressedCol),
        onPressed: () => model.newArea(),
        child: Text("New",style: getButtonTextStyle()));
  }

  List<Widget> getExtraCmdButtons(BuildContext context) {
    return [];
  }

  ButtonStyle getButtonStyle(Color normCol, Color pressedCol) {
    return ButtonStyle(backgroundColor:
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) return pressedCol;
      return normCol;
    }));
  }

  TextStyle getButtonTextStyle() {
    return const TextStyle(color: Colors.black);
  }

  @override
  State<StatefulWidget> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {

  @override
  void initState() {
    super.initState();
  }

  Widget getMainArea(BuildContext context) {
    Set<DropdownMenuItem<String>> gameset = {}; //List.empty(growable: true);
    //gameset.add(DropdownMenuItem<String>(value:ZugClient.noAreaTitle, child: widget.getAreaItem(ZugClient.noAreaTitle,context)));
    gameset.addAll(widget.model.areas.keys.where((key) => widget.model.areas[key]?.exists ?? false).map<DropdownMenuItem<String>>((String title) {  //print("Adding: $title");
      return DropdownMenuItem<String>(
        value: title,
        child: widget.getAreaItem(title,context),
      );
    }).toList());
    List<DropdownMenuItem<String>> games = gameset.toList();
    games.sort((a,b) => widget.compareAreas(widget.model.areas[a.value],widget.model.areas[b.value]));
    String selectedTitle = widget.model.currentArea.exists ? widget.model.currentArea.id : widget.model.noArea.id;  //print("Selected: $selectedTitle");

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
            widget.style == LobbyStyle.tersePort ? Expanded(flex: widget.portFlex, child: getCommandArea(context)) : getCommandArea(context),
            Center(
              child: Container(
              color: widget.bkgCol,
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Select ${widget.areaName}: ", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  const SizedBox(width: 8),
                  DropdownButton(
                      dropdownColor: Theme.of(context).colorScheme.primary,
                      value: selectedTitle,
                      items: games,
                      onChanged: (String? title) {
                        setState(() {
                          widget.model.switchArea(title); //client.update();
                        });
                      }),
                ],
              )),
            )),
            //TODO: optional headers?
            Expanded(flex: 1, child: widget.selectedArea(context)),
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints constraints) => Flex(
      direction: widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal,
      children: [
        SizedBox(
            width: widget.style == LobbyStyle.tersePort ? null : constraints.maxWidth * .75,
            height: widget.style == LobbyStyle.tersePort ? constraints.maxHeight/2 : null,
            child: getMainArea(context)
        ),
        //Expanded(flex: widget.areaFlex, child: getAreaArea(context)),
        Expanded(flex: 1, child: widget.zugChat ?? const SizedBox.shrink()),
      ],
    ));
  }

  Widget getCommandArea(BuildContext context) {
    Axis axis = widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal;
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
        child: Center(child: SingleChildScrollView(
          scrollDirection: axis,
          child: Flex(
            direction: axis,
            children: getCmdButtons(context),
        ))),
      );
  }

  List<Widget> getCmdButtons(BuildContext context, {
      double padding = 4.0,
      Widget? seekButt,
      Widget? createButt,
      Widget? startButt,
      Widget? joinButt,
      Widget? partButt,
      Widget? helpButt,
      List<Widget>? extraButts}) {
    List<Widget> buttons = [
      widget.seekButt ? Padding(padding: EdgeInsets.all(padding),child: seekButt ?? widget.getSeekButton()) : const SizedBox.shrink(),
      widget.createButt ? Padding(padding: EdgeInsets.all(padding),child: createButt ?? widget.getCreateButton()) : const SizedBox.shrink(),
      widget.startButt ? Padding(padding: EdgeInsets.all(padding),child: startButt ?? widget.getStartButton()) : const SizedBox.shrink(),
      widget.joinButt ? Padding(padding: EdgeInsets.all(padding),child: joinButt ?? widget.getJoinButton()) : const SizedBox.shrink(),
      widget.partButt ? Padding(padding: EdgeInsets.all(padding),child: partButt ?? widget.getPartButton()) : const SizedBox.shrink(),
      //if (widget.helpPage != null) Padding(padding: EdgeInsets.all(padding),child: helpButt ?? widget.getHelpButton()),
    ];
    List<Widget> extraList = extraButts ?? widget.getExtraCmdButtons(context);
    buttons.addAll(List.generate(extraList.length, (index) => Padding(padding: EdgeInsets.all(padding),child: extraList.elementAt(index))));
    return buttons;
  }

}

