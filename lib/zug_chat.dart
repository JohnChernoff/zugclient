import 'package:flutter/material.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_utils.dart';

class ZugChat extends StatefulWidget {
  static Map<String,Color> userColorMap = {};
  final ZugClient client;
  final double? width;
  final double? height;
  final Color foregroundColor; //no longer used?
  final Color backgroundColor;
  final Color cmdTxtColor;
  final Color cmdBkgColor;
  final Color borderColor;
  final double borderWidth;
  final bool chatCommandOnTop;
  final bool autoScroll;
  final bool usingServer,usingRooms,usingAreas;
  final String serverName,areaName,roomName;
  final MessageScope defScope;

  ZugChat(this.client, {this.foregroundColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.borderColor = Colors.greenAccent,
    this.borderWidth = 2,
    this.cmdTxtColor = Colors.greenAccent,
    this.cmdBkgColor = Colors.brown,
    this.chatCommandOnTop = false,
    this.autoScroll = true,
    this.usingAreas = true,
    this.usingRooms = false,
    this.usingServer = true,
    this.areaName = "Area",
    this.roomName = "Room",
    this.serverName = "Server",
    this.defScope = MessageScope.room,
    this.width,
    this.height,
    super.key}) {
    userColorMap.putIfAbsent("", () => foregroundColor);
  }

  Text buildMessage(dynamic msgData) { //print("New message: " + msgData.toString());
    String name = msgData[fieldOccupant]?[fieldUser]?[fieldName] ?? msgData[fieldUser]?[fieldName] ?? "";
    String nameStr = name.isEmpty ? name : "$name:";
    Color color = msgData[fieldOccupant]?[fieldChatColor] != null ?
    HexColor.fromHex(msgData[fieldOccupant]?[fieldChatColor]) : userColorMap.putIfAbsent(name, () => HexColor.rndColor(pastel: true));
    return Text("$nameStr ${msgData[fieldMsg]}", style: TextStyle(color: color));
  }

  static BoxDecoration getDecoration({Color color = Colors.grey, Color borderColor = Colors.grey, double borderWidth = 2, Color shadowColor = Colors.black, bool shadow = false}) {
    return BoxDecoration(
      color: color,
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
      boxShadow: shadow ? [
        BoxShadow(
          color: shadowColor,
          offset: const Offset(-8, -8),
          blurRadius: 8,
        ),
      ] : [],
    );
  }

  @override
  State<StatefulWidget> createState() => ZugChatState();

}

class ZugChatState extends State<ZugChat> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController textInputController = TextEditingController();
  final FocusNode textInputFocus = FocusNode();
  final Map<MessageScope,bool> scopeMap = {};
  MessageScope msgScope = MessageScope.room;
  bool filterServerMessages = false;

  @override
  void initState() {
    super.initState();
    filterServerMessages = false;
    scopeMap.putIfAbsent(MessageScope.room, () => widget.usingRooms);
    scopeMap.putIfAbsent(MessageScope.area, () => widget.usingAreas);
    scopeMap.putIfAbsent(MessageScope.server, () => widget.usingServer);
    msgScope = widget.defScope;
    if (!(scopeMap[msgScope] ?? false)) {
      msgScope = MessageScope.room;
      if (!widget.usingRooms) {
        msgScope = MessageScope.area;
        if (!widget.usingAreas) msgScope = MessageScope.server;
      }
    }
    //WidgetsBinding.instance.addPostFrameCallback((_) { scrollDown(500); });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoScroll) ZugUtils.scrollDown(scrollController,250,delay: 750);

    Area cg = widget.client.currentArea;

    List<dynamic> messageList = switch(msgScope) {
      MessageScope.room => cg.currentRoom?.messages ?? [],
      MessageScope.area => cg.messages,
      MessageScope.server => widget.client.messages,
    };

    List<Widget> widgetMsgList = [];
    for (var msg in messageList) {
      if (!filterServerMessages || msg[fieldOccupant] != null) {
        widgetMsgList.add(Center(child: widget.buildMessage(msg)));
      }
    }

    return Container(
      decoration: ZugChat.getDecoration(borderColor: widget.borderColor, borderWidth: widget.borderWidth),
      width: widget.width,
      height: widget.height,
      //margin:  const EdgeInsets.only(left: 16.0, right: 0.0),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Filter Server Messages"),
              Checkbox(value: filterServerMessages, onChanged: (b) => setState(() {
                filterServerMessages = b ?? false;
              })),
            ],
          ),
          widget.chatCommandOnTop ? getChatControl(cg) : const SizedBox.shrink(),
          Expanded(
            child: Container(
                color: widget.backgroundColor,
                child: ListView(
                    controller: scrollController,
                    scrollDirection: Axis.vertical,
                    children: widgetMsgList
                    ),
          )),
          Container(color: widget.borderColor,height: widget.borderWidth),
          widget.chatCommandOnTop ? const SizedBox.shrink() : getChatControl(cg)
        ],
      ),
    );
  }

  Widget getChatControl(Area cg) {
    return Row(
      children: [
        DropdownButton(
            value: msgScope,
            onChanged: (MessageScope? newScope) {
              setState(() {
                msgScope = newScope ?? MessageScope.area;
              });
            },
            items: [
              DropdownMenuItem(
                value: MessageScope.room,
                enabled: widget.usingRooms,
                child: widget.usingRooms
                    ? Text("${widget.roomName} Message: ")
                    : const SizedBox.shrink(),
              ),
              DropdownMenuItem(
                  value: MessageScope.area,
                  enabled: widget.usingAreas,
                  child: widget.usingAreas
                      ? Text("${widget.areaName} Message: ")
                      : const SizedBox.shrink(),
              ),
              DropdownMenuItem(
                  value: MessageScope.server,
                  enabled: widget.usingServer,
                  child: widget.usingServer
                      ? Text("${widget.serverName} Message: ")
                      : const SizedBox.shrink(),
              ),
            ]),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
              color: widget.cmdBkgColor,
              child: TextField(
                controller: textInputController,
                focusNode: textInputFocus,
                autofocus: true,
                style: TextStyle(
                    color: widget.cmdTxtColor,
                    backgroundColor: widget.cmdBkgColor),
                onSubmitted: (txt) {
                  widget.client.send(
                      switch (msgScope) {
                        MessageScope.room => ClientMsg.roomMsg,
                        MessageScope.area => ClientMsg.areaMsg,
                        MessageScope.server => ClientMsg.servMsg,
                      },
                      data: {fieldTitle: cg.title, fieldMsg: txt});
                  setState(() {
                    textInputController.text = "";
                  });
                  textInputFocus.requestFocus();
                },
              )),
        ),
        msgScope == MessageScope.area ? IconButton(
            onPressed: () => widget.client.areaCmd(ClientMsg.updateArea),
            icon: const Icon(Icons.update) //,size: iconHeight-16)
        ) : const SizedBox.shrink(),
      ],
    );
  }

}

