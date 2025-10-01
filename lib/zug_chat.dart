import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_area.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_mess.dart';
import 'package:zugclient/zug_model.dart';

class ZugChat extends StatefulWidget {
  final ZugModel model;
  final double? width;
  final double? height;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color servColor;
  final Color cmdTxtColor;
  final Color cmdBkgColor;
  final Color borderColor;
  final double borderWidth;
  final bool chatCommandOnTop;
  final bool autoScroll;
  final bool usingServer, usingRooms, usingAreas;
  final String serverName, areaName, roomName;
  final MessageScope defScope;

  const ZugChat(
      this.model, {
        this.foregroundColor = Colors.white,
        this.backgroundColor = const Color(0xFF1E1E2E), // Modern dark blue
        this.borderColor = const Color(0xFF313244), // Subtle border
        this.borderWidth = 1,
        this.cmdTxtColor = const Color(0xFFCDD6F4), // Light text
        this.cmdBkgColor = const Color(0xFF181825), // Darker input background
        this.servColor = const Color(0xFFA6E3A1), // Green for server messages
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
        super.key,
      });

  static BoxDecoration getDecoration({
    Color color = const Color(0xFF1E1E2E),
    Color borderColor = const Color(0xFF313244),
    double borderWidth = 1,
    Color shadowColor = Colors.black26,
    bool shadow = true,
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
      boxShadow: shadow
          ? [
        BoxShadow(
          color: shadowColor,
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ]
          : [],
    );
  }

  @override
  State<StatefulWidget> createState() => ZugChatState();
}

class ZugChatState extends State<ZugChat> with SingleTickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  final TextEditingController textInputController = TextEditingController();
  final FocusNode textInputFocus = FocusNode();
  final Map<MessageScope, bool> scopeMap = {};
  bool filterServerMessages = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    filterServerMessages = false;
    scopeMap.putIfAbsent(MessageScope.room, () => widget.usingRooms);
    scopeMap.putIfAbsent(MessageScope.area, () => widget.usingAreas);
    scopeMap.putIfAbsent(MessageScope.server, () => widget.usingServer);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    scrollController.dispose();
    textInputController.dispose();
    textInputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ValueListenableBuilder<MessageScope>(
        valueListenable: widget.model.chatScope,
        builder: (context, scope, _) {
          MessageList? messageList = switch (scope) {
            MessageScope.room => widget.model.currentArea.currentRoom?.messages,
            MessageScope.area => widget.model.currentArea.messages,
            MessageScope.server => widget.model.messages,
          };
          return buildChatUI(context, messageList);
        },
      ),
    );
  }

  Widget buildChatUI(BuildContext context, MessageList? messageList) {
    Area currArea = widget.model.currentArea;
    if (widget.autoScroll) {
      ZugUtils.scrollDown(scrollController, 250, delay: 750);
    }

    List<Widget> widgetMsgList = [];
    if (messageList != null) {
      for (int i = 0; i < messageList.messages.length; i++) {
        Message msg = messageList.messages[i];
        if (!filterServerMessages || !msg.fromServ) {
          widgetMsgList.add(
            AnimatedContainer(
              duration: Duration(milliseconds: 300 + (i * 50)),
              curve: Curves.easeOutQuart,
              child: ZugChatLine(
                msg.fromServ ? msg.message : "${msg.uName}: ${msg.message}",
                msg.dateTime,
                msg.fromServ ? widget.servColor : msg.color,
                msg.hidden,
                isFromServer: msg.fromServ,
              ),
            ),
          );
        }
      }
    }

    return Container(
      decoration: ZugChat.getDecoration(
        borderColor: widget.borderColor,
        borderWidth: widget.borderWidth,
        color: widget.backgroundColor,
      ),
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          // Modern header with filter toggle
          _buildHeader(),

          // Chat command on top if enabled
          if (widget.chatCommandOnTop)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: getChatControl(currArea),
            ),

          // Messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(widgetMsgList),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  widget.borderColor.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Chat input at bottom if not on top
          if (!widget.chatCommandOnTop)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: getChatControl(currArea),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
        border: Border(
          bottom: BorderSide(
            color: widget.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.forum_outlined,
            color: widget.foregroundColor.withOpacity(0.7),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            "Chat",
            style: TextStyle(
              color: widget.foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Modern toggle switch for server message filter
          Row(
            children: [
              Text(
                "Filter Server",
                style: TextStyle(
                  color: widget.foregroundColor.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  filterServerMessages = !filterServerMessages;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: filterServerMessages
                        ? const Color(0xFF89B4FA)
                        : const Color(0xFF45475A),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: filterServerMessages
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget getChatControl(Area currArea) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181825),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF313244),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Scope dropdown
          Expanded(
            flex: 2,
            child: ValueListenableBuilder<MessageScope>(
              valueListenable: widget.model.chatScope,
              builder: (context, scope, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<MessageScope>(
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    value: scope,
                    dropdownColor: const Color(0xFF181825),
                    style: TextStyle(
                      color: widget.cmdTxtColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: widget.cmdTxtColor.withOpacity(0.7),
                    ),
                    onChanged: (MessageScope? newScope) {
                      widget.model.chatScope.value = newScope ?? MessageScope.area;
                    },
                    items: [
                      if (widget.usingRooms)
                        DropdownMenuItem(
                          value: MessageScope.room,
                          child: Row(
                            children: [
                              Icon(
                                Icons.meeting_room,
                                size: 16,
                                color: widget.cmdTxtColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text("${widget.roomName}"),
                            ],
                          ),
                        ),
                      if (widget.usingAreas)
                        DropdownMenuItem(
                          value: MessageScope.area,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: widget.cmdTxtColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text("${widget.areaName}"),
                            ],
                          ),
                        ),
                      if (widget.usingServer)
                        DropdownMenuItem(
                          value: MessageScope.server,
                          child: Row(
                            children: [
                              Icon(
                                Icons.dns,
                                size: 16,
                                color: widget.cmdTxtColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text("${widget.serverName}"),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Vertical divider
          Container(
            width: 1,
            height: 32,
            color: const Color(0xFF313244),
          ),

          // Text input
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Type a message...",
                  hintStyle: TextStyle(
                    color: widget.cmdTxtColor.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                controller: textInputController,
                focusNode: textInputFocus,
                autofocus: true,
                style: TextStyle(
                  color: widget.cmdTxtColor,
                  fontSize: 14,
                ),
                onSubmitted: (txt) {
                  txt.startsWith("!")
                      ? widget.model.handleCmdMsg(txt.split(" "))
                      : widget.model.send(
                    switch (widget.model.chatScope.value) {
                      MessageScope.room => ClientMsg.roomMsg,
                      MessageScope.area => ClientMsg.areaMsg,
                      MessageScope.server => ClientMsg.servMsg,
                    },
                    data: {
                      fieldAreaID: currArea.id,
                      fieldZugTxt: getZugTxt(txt)
                    },
                  );
                  setState(() {
                    textInputController.text = "";
                  });
                  textInputFocus.requestFocus();
                },
              ),
            ),
          ),

          // Update button for area scope
          if (widget.model.chatScope.value == MessageScope.area)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.model.areaCmd(ClientMsg.updateArea),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.refresh,
                      size: 20,
                      color: widget.cmdTxtColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

class ZugChatLine extends StatefulWidget {
  final String text;
  final DateTime date;
  final Color color;
  final bool hidden;
  final bool isFromServer;

  const ZugChatLine(
      this.text,
      this.date,
      this.color,
      this.hidden, {
        this.isFromServer = false,
        super.key,
      });

  @override
  State<StatefulWidget> createState() => ZugChatLineState();
}

class ZugChatLineState extends State<ZugChatLine>
    with SingleTickerProviderStateMixin {
  bool hidden = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    hidden = widget.hidden;
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('HH:mm');

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {
          if (widget.hidden) {
            setState(() {
              hidden = !hidden;
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isFromServer
                ? const Color(0xFF181825).withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isFromServer
                ? Border.all(
              color: const Color(0xFF313244).withOpacity(0.3),
              width: 1,
            )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatter.format(widget.date),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Server indicator
              if (widget.isFromServer) ...[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],

              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.hidden && !hidden) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF45475A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Hidden message (tap to reveal)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        hidden ? "(hidden)" : widget.text,
                        style: TextStyle(
                          color: widget.color,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: widget.isFromServer
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
