import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import "package:universal_html/html.dart" as html;
import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_area.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_model.dart';

//TODO: create buttonColumn for portrait mode
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
  final double commandAreaWidth, commandAreaHeight;

  const LobbyPage(this.model, {
    this.backgroundImage,
    this.areaName = "Area",
    this.bkgCol,
    this.buttonsBkgCol,
    this.style = LobbyStyle.normal,
    this.width,
    this.borderWidth  = 0,
    this.borderCol = Colors.black,
    this.zugChat,
    this.seekButt = true,
    this.createButt = true,
    this.startButt = true,
    this.joinButt = true,
    this.partButt = true,
    this.portFlex = 2,
    this.commandAreaHeight = 72,
    this.commandAreaWidth = 128,
    super.key});

  Widget selectedArea(BuildContext context, {Color? bkgCol, Color? txtCol, Iterable<dynamic>? occupants}) {
    Iterable<dynamic> occupantList = occupants ?? model.currentArea.occupantMap.values;
    return Container(
        decoration: BoxDecoration(
          color: bkgCol ?? Colors.black,
          border: Border.all(color: txtCol ?? borderCol, width: borderWidth),
        ),
        child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: getOccupantHeaders(),
          rows: List.generate(occupantList.length, (i) {
            UniqueName uName = UniqueName.fromData(occupantList.elementAt(i)[fieldUser]); //model.currentArea.occupantMap.keys.elementAt(i);
            return getOccupantData(uName, occupantList.elementAt(i)); //model.currentArea.occupantMap[uName]
          })),
      )),
    );
  }

  List<DataColumn> getOccupantHeaders({Color color = Colors.white}) {
    return [
      DataColumn(label: Text("Name",style: TextStyle(color: color)))
    ];
  }

  DataRow getOccupantData(UniqueName uName, Map<String,dynamic> json, {Color color = Colors.black}) {
    return DataRow(cells: [
      DataCell(DecoratedBox(decoration: const BoxDecoration(
        boxShadow:  [
          BoxShadow(
            color: Colors.greenAccent,
            offset: Offset(
              5.0,
              5.0,
            ),
            blurRadius: 10.0,
            spreadRadius: 2.0,
          ), //BoxShadow
          BoxShadow(
            color: Colors.white,
            offset: Offset(0.0, 0.0),
            blurRadius: 0.0,
            spreadRadius: 0.0,
          ), //BoxShadow
        ],
      ),
      child: Text(
          model.currentArea.getOccupantName(uName),
          style: TextStyle(color: color)
      )))
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

  CommandButtonData getHelpButton(String helpPage, {Color normCol = Colors.cyan}) {
    return CommandButtonData("Help",normCol,() {
      if (kIsWeb) {
        html.window.open(helpPage, 'new tab');
      } else {
        ZugUtils.launch(helpPage, isNewTab: true);
      }
    });
  }

  CommandButtonData getSeekButton({Color normCol = Colors.orangeAccent}) {
    return CommandButtonData("Seek",normCol,model.seekArea);
  }

  CommandButtonData getJoinButton({Color normCol = Colors.blueAccent}) { //}ChatScopeController chatScopeController) {
    return CommandButtonData("Join",normCol,() => model.joinArea(model.currentArea.id));
  }

  CommandButtonData getPartButton({Color normCol = Colors.grey}) {
    return CommandButtonData("Leave",normCol,model.partArea);
  }

  CommandButtonData getStartButton({Color normCol = Colors.redAccent}) {
    return CommandButtonData("Start",normCol,model.startArea);
  }

  CommandButtonData getCreateButton({Color normCol = Colors.greenAccent}) {
    return CommandButtonData("New",normCol,model.newArea);
  }

  List<CommandButtonData> getExtraCmdButtons(BuildContext context) {
    return [];
  }

  ButtonStyle getButtonStyle(Color normCol, { Color? hoverCol }) {
    return ButtonStyle(backgroundColor:
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.hovered)) return hoverCol ?? normCol.withAlpha(200);
      return normCol;
    }));
  }

  TextStyle getButtonTextStyle() {
    return const TextStyle(color: Colors.black, fontSize: 36);
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
          children: [
            widget.style == LobbyStyle.tersePort ? Expanded(flex: widget.portFlex, child: getCommandArea(context)) : getCommandArea(context),
            Center(
              child: Container(
              color: widget.bkgCol,
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Select ${widget.areaName}: ", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,fontSize: 24)),
                  const SizedBox(width: 8),
                  DropdownButton(
                      dropdownColor: Theme.of(context).colorScheme.primary,
                      value: selectedTitle,
                      items: games,
                      onChanged: (String? title) {
                        setState(() {
                          widget.model.switchArea(title); //model.update();
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
        width: widget.style == LobbyStyle.tersePort ? widget.commandAreaWidth : null,
        height: widget.style == LobbyStyle.tersePort ? null : widget.commandAreaHeight,
        child: EqualButtonRow(buttData: getCmdButtons(context)),
      );
  }

  List<CommandButtonData?> getCmdButtons(BuildContext context, {
    double padding = 4.0,
    CommandButtonData? seekButt,
    CommandButtonData? createButt,
    CommandButtonData? startButt,
    CommandButtonData? joinButt,
    CommandButtonData? partButt,
    CommandButtonData? helpButt,
    List<CommandButtonData>? extraButts}) {
    List<CommandButtonData> extraList = extraButts ?? widget.getExtraCmdButtons(context);
    List<CommandButtonData?> buttons = [
      widget.seekButt ? widget.getSeekButton() : null,
      widget.createButt ? widget.getCreateButton() : null,
      widget.startButt ? widget.getStartButton() : null,
      widget.joinButt ? widget.getJoinButton() : null,
      widget.partButt ? widget.getPartButton() : null,
    ];
    buttons.addAll(extraList);
    return buttons;
  }

}

class CommandButtonData {
  final String text;
  final VoidCallback callback;
  final Color color;
  const CommandButtonData(this.text,this.color,this.callback);
}

class EqualButtonRow extends StatelessWidget {
  final List<CommandButtonData?> buttData;
  final TextStyle textStyle;
  final double spacing;

  const EqualButtonRow({
    Key? key,
    required this.buttData,
    this.textStyle = const TextStyle(fontSize: 24, color: Colors.black),
    this.spacing = 36.0,
  }) : super(key: key);

  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Find the longest text width
        double maxTextWidth = 0;
        for (CommandButtonData? datButt in buttData) {
          double width = _calculateTextWidth(datButt?.text ?? "", textStyle);
          if (width > maxTextWidth) {
            maxTextWidth = width;
          }
        }

        // Calculate button width accounting for padding and spacing
        const double buttonPadding = 32; // Horizontal padding inside button
        const double minButtonWidth = 80; // Minimum button width

        double totalSpacing = spacing * (buttData.length - 1);
        double availableWidth = constraints.maxWidth - totalSpacing;

        // Calculate optimal button width
        double calculatedWidth = maxTextWidth + buttonPadding;
        double equalWidth = availableWidth / buttData.length;

        // Use the larger of calculated width or equal distribution
        double buttonWidth = math.max(
          math.max(calculatedWidth, minButtonWidth),
          equalWidth,
        );

        // If calculated width exceeds available space, use equal distribution
        if (buttonWidth * buttData.length + totalSpacing > constraints.maxWidth) {
          buttonWidth = equalWidth;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttData.asMap().entries.map((entry) {
            return SizedBox(
              width: buttonWidth,
              height: constraints.maxHeight * .5,
              child: ElevatedButton(
                style: getButtonStyle(entry.value?.color ?? Colors.white),
                onPressed: entry.value?.callback,
                child: Text(
                  entry.value?.text ?? "",
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  ButtonStyle getButtonStyle(Color normCol, { Color? hoverCol }) {
    return ButtonStyle(backgroundColor:
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.hovered)) return hoverCol ?? normCol.withAlpha(200);
      return normCol;
    }));
  }
}
