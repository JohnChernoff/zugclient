import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_user.dart';

const emojiTag = "@@@";
class Message {
  UniqueName? uName;
  DateTime dateTime;
  bool fromServ;
  String message;
  Color color;
  bool hidden;
  bool err;

  Message(this.uName,this.message,this.dateTime,this.color,this.hidden, {this.err = false}) : fromServ = uName == null;
}

class MessageList {
  static Color foregroundColor = Colors.white;
  Map<String?,Color> userColorMap = {};
  List<Message> messages = [];
  int newMessages = 0;

  MessageList() {
    userColorMap.putIfAbsent(null, () => foregroundColor);
  }

  Message addZugMsg(data, {err = false}) {
    StringBuffer txtBuff = StringBuffer();
    for (dynamic el in (data[fieldZugTxt] as List<dynamic>)) {
      txtBuff.write(el[fieldTxtAscii] ?? "$emojiTag${el[fieldTxtEmoji]}$emojiTag");
    }
    UniqueName uName = UniqueName.fromData(data[fieldMsgUser]);
    final msg = Message(
        uName,
        txtBuff.toString(),
        DateTime.fromMillisecondsSinceEpoch(data[fieldMsgDate] * 1000),
        getMsgColor(uName,data),
        data[fieldHidden] ?? false,
        err: err);
    messages.add(msg);
    return msg;
  }

  Message addMessage(data, {Color? color, err = false}) {
    Message message;
    if (data[fieldZugMsg] != null) {
      message = addZugMsg(data[fieldZugMsg]);
    } else {
      dynamic userData = data[fieldOccupant]?[fieldUser] ?? data[fieldUser];
      UniqueName? uName = userData != null ? UniqueName.fromData(userData) : null;
      message = Message(
          uName,
          data[fieldMsg],
          DateTime.now(),
          color ?? getMsgColor(uName,data),
          data[fieldHidden] ?? false,
          err: err);
      messages.add(message);
    }
    newMessages++;
    return message;
  }

  Color getMsgColor(UniqueName? uName, data) { //print("Fetching ColorMap: $userColorMap for $uName");
    return data[fieldOccupant]?[fieldChatColor] != null
        ? HexColor.fromHex(data[fieldOccupant]?[fieldChatColor])
        : userColorMap.putIfAbsent(uName.toString(), () => HexColor.rndColor(pastel: true)); //TODO: exclude server color
  }

  Message? getLastServMsg() {
    Iterable<Message> adminMsgs = messages.where((msg) => msg.fromServ);
    return adminMsgs.isNotEmpty ? adminMsgs.last : null;
  }

}
