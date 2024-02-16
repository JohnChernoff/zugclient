import 'dart:collection';
import 'package:flutter/material.dart';

final globalNavigatorKey = GlobalKey<NavigatorState>();

class Dialogs {

  static Set<BuildContext> contexts = HashSet();
  static bool dialog = false;

  Dialogs();

  static void clearDialogs() {
    for (BuildContext ctx in Dialogs.contexts) {
      Navigator.pop(ctx);
    }
    Dialogs.contexts.clear();
    dialog = false;
  }

  static Future<bool> popup (String txt, { String imgFile = "" } ) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return false;
    dialog = true;
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(
              child: NotificationDialog(txt, imageFilename: imgFile));
        }).then((ok)  {
          dialog = false;
          return ok ?? false;
        });
  }

  static Future<String> getString(String prompt,String defTxt) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return "";
    dialog = true;
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: TextDialog(prompt, defTxt));
        }).then((value) {
      dialog = false;
      return value ?? "";
    });
  }

  static Future<int> getIcon(String prompt, List<Icon> iconList) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return 0;
    dialog = true; contexts.add(ctx); //TODO: does this do anything?
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: IconSelectDialog(prompt, iconList));
        }).then((value) {
      dialog = false; contexts.remove(ctx);
      return value ?? 0;
    });
  }

  static Future<dynamic> getItem(String prompt, List<dynamic> itemList, List<String> fieldList, String actionString, {double sizeFactor = 1} ) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return 0;
    dialog = true; contexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
           return Center(child: ItemSelectDialog(itemList,fieldList, actionString, sizeFactor: sizeFactor));
        }).then((item) {
      dialog = false; contexts.remove(ctx);
      return item ?? {};
    });
  }

  static Future<Widget?> getWidget(String prompt, List<Widget> widgetList, int axisCount,
      {bool showTime = false, int seconds = 1, Offset sizeFactor = const Offset(1,1), Alignment alignment = Alignment.center, Color color = Colors.white, Color backgroundColor = Colors.black}) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return null;
    Dialogs.dialog = true; Dialogs.contexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Align(
              alignment: alignment,
              child: WidgetSelectDialog(prompt,widgetList, axisCount, showTime: showTime, seconds: seconds, sizeFactor: sizeFactor, color: color, backgroundColor: backgroundColor));
        }).then((widget) {
      Dialogs.dialog = false; Dialogs.contexts.remove(ctx);
      return widget;
    });
  }

  static Future<void> showAnimationDialog (AnimationDialog dial, {Alignment alignment = Alignment.center}) {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return Future(() => null);
    dialog = true;
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Align(alignment: alignment, child: dial);
        }).then((ok)  {
      dialog = false;
      return Future(() => null);
    });
  }

}


class TextDialog extends StatelessWidget {
  final TextEditingController titleControl = TextEditingController();
  final String prompt;
  TextDialog(this.prompt,String defTxt, {super.key}) {
    titleControl.text = defTxt;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
        backgroundColor: Colors.green,
        elevation: 10,
        title: Text(prompt),
        children: [
          TextField(
            controller: titleControl,
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context, titleControl.text);
            },
            child: const Text('Enter'),
          ),
        ],
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String txt;
  const ConfirmDialog(this.txt, {super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        Text(txt),
        SimpleDialogOption(
            onPressed: () { //print("True");
              Navigator.pop(context,true);
            },
            child: const Text('OK')),
        SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context,false);
            },
            child: const Text('Cancel')),
      ],
    );
  }
}

class NotificationDialog extends StatelessWidget {
  final String txt;
  final String imageFilename;
  const NotificationDialog(this.txt, {this.imageFilename = "", super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        InkWell(
            onTap: () {
              Navigator.pop(context, true);
            },
            child: Column(
              children: [
                Text(txt),
                imageFilename.isEmpty
                    ? const SizedBox()
                    : Image.asset("assets/images/$imageFilename"),
              ],
            )),
      ],
    );
  }
}

class IconSelectDialog extends StatelessWidget {
  final String prompt;
  final List<Icon> iconList;
  const IconSelectDialog(this.prompt,this.iconList, {super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(prompt),
            ]
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(iconList.length, (index) =>
                IconButton(
                    onPressed: () {
                      Navigator.pop(context, index);
                    },
                    icon: iconList.elementAt(index))
            ),
          )
      ],
    );
  }
}

class ItemSelectDialog extends StatelessWidget {
  final String actionString;
  final List<dynamic> itemList;
  final List<String> fieldList;
  final double sizeFactor;
  const ItemSelectDialog(this.itemList, this.fieldList, this.actionString, {this.sizeFactor = 1, super.key});

  @override
  Widget build(BuildContext context) {
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double widgetHeight = MediaQuery.of(context).size.height;

    return SimpleDialog(
      children: [
        IconButton(onPressed: () {Navigator.pop(context,-1);}, icon: const Icon(Icons.cancel)),
        Container(
          color : Colors.black,
          width : widgetWidth,
          height: widgetHeight,
          child: ListView(
            scrollDirection: Axis.vertical,
            children:
            List.generate(itemList.length, (index) =>
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    itemRow(itemList[index],fieldList),
                    ElevatedButton(
                      onPressed: () { Navigator.pop(context,itemList[index]); },
                      child: Text(actionString),
                    ),
                  ],
                )
            ),
          ),
        )
      ],
    );
  }

  Widget itemRow(data, List<String> fieldList) {
      return Row(
        children:
          List.generate(fieldList.length, (index) => Text(
              "${fieldList.elementAt(index)}: data[fieldList.elementAt(index)")
          )
      );
  }

}

abstract class TimedDialog extends StatefulWidget {
  final bool showTime;
  final int milliseconds;
  final int framerate;
  const TimedDialog(this.milliseconds,this.showTime, {this.framerate = 1000, super.key});
}

abstract class TimedDialogState extends State<TimedDialog> {
  int timeRemaining = 0;
  bool countingDown = false;

  @override
  void initState() {
    super.initState();
    countingDown = widget.milliseconds > 0;
    timeRemaining = widget.milliseconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (countingDown) countdown();
    });
  }

  Future<void> countdown() async {
    while (timeRemaining > 0) {
      await Future.delayed(Duration(milliseconds: widget.framerate)).then((value) {
        if (countingDown) {
          setState(() { timeRemaining -= widget.framerate; });
        }
      });
    } //countingDown = false;
  }

  @override
  void dispose() {
    countingDown = false;
    super.dispose();
  }

  bool checkTime() {
    if ((countingDown && timeRemaining <= 0)) {
      Navigator.pop(context,null);
      return true;
    }
    return false;
  }

  int secondsRemaining() {
    return (timeRemaining/1000).round();
  }
}

class WidgetSelectDialog extends TimedDialog {
  final Color color;
  final Color backgroundColor;
  final int axisCount;
  final double buffer;
  final String prompt;
  final Offset sizeFactor;
  final List<Widget> widgets;
  const WidgetSelectDialog(this.prompt, this.widgets, this.axisCount,
      {seconds = 0, showTime = false, this.buffer = 8, this.sizeFactor = const Offset(1, 1), this.color = Colors.white, this.backgroundColor = Colors.black, super.key}) : super(seconds * 1000, showTime);

  @override
  State<StatefulWidget> createState() => _WidgetSelectState();

}

class _WidgetSelectState extends TimedDialogState {

  @override
  Widget build(BuildContext context) {
    var w = widget;
    if (w is WidgetSelectDialog) {
      if (checkTime() || w.widgets.isEmpty) {
        return const Text("");
      }
      else {
        final double dialogWidth = MediaQuery.of(context).size.width * w.sizeFactor.dx;
        final double dialogHeight = MediaQuery.of(context).size.height * w.sizeFactor.dy;
        bool portrait = dialogWidth <= dialogHeight;
        TextStyle textStyle = TextStyle(
            backgroundColor: w.backgroundColor.withOpacity(1),
            color: w.color,
            decoration: TextDecoration.none
        );
        return Container(
            width: dialogWidth,
            height: dialogHeight,
            color: w.backgroundColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(w.prompt, style: textStyle),
                    widget.showTime ? Text(secondsRemaining().toString(),style: textStyle) : const Text("")
                  ],
                ),
                Expanded(child: GridView.count(
                    padding: EdgeInsets.all(w.buffer),
                    crossAxisSpacing: w.buffer,
                    mainAxisSpacing: w.buffer,
                    scrollDirection: portrait ? Axis.horizontal : Axis.vertical,
                    crossAxisCount: w.axisCount,
                    children: List.generate(
                        w.widgets.length,
                            (index) => GestureDetector(
                          onTap: () => Navigator.pop(
                              context, w.widgets.elementAt(index)),
                          child: w.widgets.elementAt(index),
                        )
                    )
                )),
              ],
            )
        );
      }
    }
    else {
      return const Text("Error");
    }
  }
}

class WidgetDim {
  double width, height;
  WidgetDim(this.width,this.height);
}

abstract class AnimationDialog extends TimedDialog {
  final double sizeFactor;
  const AnimationDialog(milliseconds, {this.sizeFactor = 1, framerate = 0, showTime = false, super.key}) : super(milliseconds, showTime, framerate : framerate > 0 ? framerate : milliseconds);
}

abstract class AnimationDialogState extends TimedDialogState {
  int frame = 0;

  @override
  Future<void> countdown() async {
    setState(() {}); //initial state
    super.countdown();
  }

  @override
  Widget build(BuildContext context) {
     frame++;
     return nextFrame(context);
  }

  Widget nextFrame(BuildContext context);

}
