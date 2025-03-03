import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

class ChatScopeController extends ChangeNotifier {
  MessageScope scope = MessageScope.server;
  void setScope(MessageScope s) {
    scope = s;
    notifyListeners();
  }
}

class ZugChat extends StatefulWidget {

  final ZugClient client;
  final double? width;
  final double? height;
  final Color foregroundColor; //no longer used?
  final Color backgroundColor;
  final Color servColor;
  final Color cmdTxtColor;
  final Color cmdBkgColor;
  final Color borderColor;
  final double borderWidth;
  final bool chatCommandOnTop;
  final bool autoScroll;
  final bool usingServer,usingRooms,usingAreas;
  final String serverName,areaName,roomName;
  final MessageScope defScope;

  const ZugChat(this.client, {this.foregroundColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.borderColor = Colors.white,
    this.borderWidth = 1,
    this.cmdTxtColor = Colors.greenAccent,
    this.cmdBkgColor = Colors.black,
    this.servColor = Colors.white,
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
    super.key});

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
  bool filterServerMessages = false;

  @override
  void initState() {
    super.initState();
    filterServerMessages = false;
    scopeMap.putIfAbsent(MessageScope.room, () => widget.usingRooms);
    scopeMap.putIfAbsent(MessageScope.area, () => widget.usingAreas);
    scopeMap.putIfAbsent(MessageScope.server, () => widget.usingServer);
  }

  @override
  Widget build(BuildContext context) {

    ChatScopeController chatScopeController = Provider.of(context);
    if (widget.autoScroll) ZugUtils.scrollDown(scrollController,250,delay: 750);

    Area currArea = widget.client.currentArea;

    MessageList? messageList = switch(chatScopeController.scope) {
      MessageScope.room => currArea.currentRoom?.messages,
      MessageScope.area => currArea.messages,
      MessageScope.server => widget.client.messages,
    };

    List<Widget> widgetMsgList = [];
    if (messageList != null) {
      for (Message msg in messageList.messages) {
        if (!filterServerMessages || !msg.fromServ) {
          widgetMsgList.add(ZugChatLine(msg.fromServ
              ? msg.message
              : "${msg.uName}: ${msg.message}",
              msg.dateTime,
              msg.fromServ ? widget.servColor : msg.color, msg.hidden));
        }
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
          widget.chatCommandOnTop ? getChatControl(currArea,chatScopeController) : const SizedBox.shrink(),
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
          widget.chatCommandOnTop ? const SizedBox.shrink() : getChatControl(currArea,chatScopeController)
        ],
      ),
    );
  }

  Widget getChatControl(Area currArea, ChatScopeController chatScopeController) {
    return Row(
      children: [
        DropdownButton(
            value: chatScopeController.scope,
            onChanged: (MessageScope? newScope) { //print("Changing: $newScope");
              chatScopeController.setScope(newScope ?? MessageScope.area); //setState(() {});
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
                  txt.startsWith("!") ? widget.client.handleCmdMsg(txt.split(" ")) :
                  widget.client.send(
                      switch (chatScopeController.scope) {
                        MessageScope.room => ClientMsg.roomMsg,
                        MessageScope.area => ClientMsg.areaMsg,
                        MessageScope.server => ClientMsg.servMsg,
                      },
                      data: {fieldAreaID: currArea.id, fieldZugTxt: getZugTxt(txt)});
                  setState(() {
                    textInputController.text = "";
                  });
                  textInputFocus.requestFocus();
                },
              )),
        ),
        chatScopeController.scope == MessageScope.area ? IconButton(
            onPressed: () => widget.client.areaCmd(ClientMsg.updateArea),
            icon: const Icon(Icons.update) //,size: iconHeight-16)
        ) : const SizedBox.shrink(),
      ],
    );
  }

  List<Object> getZugTxt(String txt) {
    List<Object> eList = [];
    bool emojiStart = txt.startsWith(emojiTag);
    List<String> elements = txt.split(emojiTag);
    for (int i = 0; i < elements.length; i++) {
      if (i % 2 == (emojiStart ? 1 : 0)) {
        eList.add(elements.elementAt(i));
      } else {
        eList.add(int.tryParse(elements.elementAt(i)) ?? 0);
      }
    }
    return eList;
  }

}

//TODO: support Emojis
class ZugChatLine extends StatefulWidget {
  final String text;
  final DateTime date;
  final Color color;
  final bool hidden;
  const ZugChatLine(this.text, this.date, this.color, this.hidden, {super.key});

  @override
  State<StatefulWidget> createState() => ZugChatLineState();

}

//TODO: use RichText for dates,etc.
class ZugChatLineState extends State<ZugChatLine> {
  bool hidden = false;

  @override
  void initState() {
    super.initState();
    hidden = widget.hidden;
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MM-dd H:mm');
    StringBuffer txtBuff = StringBuffer("${formatter.format(widget.date)} | ");
    txtBuff.write(hidden ? "(hidden)" : widget.text);
    return GestureDetector(
      onTap: () {
        if (widget.hidden) {
          setState(() {
            hidden = !hidden;
          });
        }
      },
      child: Text(txtBuff.toString(), style: TextStyle(color: widget.color)),
    );
  }
}
