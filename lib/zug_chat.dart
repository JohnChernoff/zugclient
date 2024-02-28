import 'package:flutter/material.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_utils.dart';

class ZugChat extends StatefulWidget {
  final ZugClient client;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color cmdTxtColor;
  final Color cmdBkgColor;
  final Color borderColor;
  final double borderWidth;
  final bool chatCommandOnTop;
  final bool autoScroll;

  const ZugChat(this.client, {this.foregroundColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.borderColor = Colors.greenAccent,
    this.borderWidth = 2,
    this.cmdTxtColor = Colors.greenAccent,
    this.cmdBkgColor = Colors.brown,
    this.chatCommandOnTop = false,
    this.autoScroll = true,
    super.key});

  bool usingRooms() { return false; }
  String serverName() { return "Server"; }
  String areaName() { return "Area"; }
  String roomName() { return "Room"; }

  Text buildMessage(dynamic msgData) {
    if (msgData[fieldOccupant] != null) {
      return Text("${msgData[fieldOccupant][fieldUser][fieldName]}: "
          "${msgData[fieldMsg]}",
        style: TextStyle(
            color: HexColor.fromHex(msgData[fieldOccupant][fieldChatColor],defaultColor: foregroundColor),
      ));
    }
    else {
      return Text(msgData[fieldMsg], style: TextStyle(color: foregroundColor));
    }
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
  bool filterServerMessages = false;

  @override
  void initState() {
    super.initState();
    filterServerMessages = false;
    //WidgetsBinding.instance.addPostFrameCallback((_) { scrollDown(500); });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoScroll) scrollDown(250,delay: 750);

    Area cg = widget.client.currentArea;

    List<dynamic> messageList = switch(cg.msgScope) {
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
            value: cg.msgScope,
            onChanged: (MessageScope? newScope) {
              setState(() {
                cg.msgScope = newScope ?? MessageScope.area;
              });
            },
            items: [
              DropdownMenuItem(
                value: MessageScope.room,
                enabled: widget.usingRooms(),
                child: widget.usingRooms()
                    ? Text("${widget.roomName()} Message: ")
                    : const SizedBox.shrink(),
              ),
              DropdownMenuItem(
                  value: MessageScope.area,
                  child: Text("${widget.areaName()} Message: ")),
              DropdownMenuItem(
                  value: MessageScope.server,
                  child: Text("${widget.serverName()} Message: ")),
            ]),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
              color: widget.cmdBkgColor,
              child: TextField(
                style: TextStyle(
                    color: widget.cmdTxtColor,
                    backgroundColor: widget.cmdBkgColor),
                onSubmitted: (txt) {
                  widget.client.send(
                      switch (cg.msgScope) {
                        MessageScope.room => ClientMsg.roomMsg,
                        MessageScope.area => ClientMsg.areaMsg,
                        MessageScope.server => ClientMsg.servMsg,
                      },
                      data: {fieldTitle: cg.title, fieldMsg: txt});
                },
              )),
        ),
        IconButton(
            onPressed: () => widget.client.areaCmd(ClientMsg.updateArea),
            icon: const Icon(Icons.update) //,size: iconHeight-16)
        ),
      ],
    );
  }

  scrollDown(int millis, {int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay)).then((value) {
      if (scrollController.hasClients) { //in case user switched away
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: Duration(milliseconds: millis),
        );
      }
    });
  }

}