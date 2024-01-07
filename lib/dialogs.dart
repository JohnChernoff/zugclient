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

  static Future<int> getItem(String prompt, List<dynamic> itemList, bool shopping ) async {
    BuildContext? ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return 0;
    dialog = true; contexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
           return Center(child: ItemSelect(itemList,shopping));
        }).then((itemIndex) {
      dialog = false; contexts.remove(ctx);
      return itemIndex ?? 0;
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

class ItemSelect extends StatelessWidget {

  final List<dynamic> itemList;
  final bool shopping;
  const ItemSelect(this.itemList, this.shopping, {super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return SimpleDialog(
      children: [
        IconButton(onPressed: () {Navigator.pop(context,-1);}, icon: const Icon(Icons.cancel)),
        SizedBox(
          width : screenWidth,
          height: screenHeight,
          child: ListView(
            scrollDirection: Axis.vertical,
            children:
            List.generate(itemList.length, (index) =>
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    shopping ? Text("(x${itemList[index]["count"]})") : const Text(" "),
                    makeItem(itemList[index]["item"]),
                    ElevatedButton(
                      onPressed: () { Navigator.pop(context,itemList[index]["item"]["id"]); },
                      child: Text(shopping ? "\$${itemList[index]["item"]["cost"].toString()}" : "Use"),
                    ),
                  ],
                )
            ),
          ),
        )
      ],
    );
  }

  Widget makeItem(data) {
    if (data["name"].toString().startsWith("Mine")) {
      return Row(
        children: [
          const Icon(Icons.dashboard),
          Text(" ${data["name"]}, \n Dam: ${data["damage"]}, Cond: ${data["condition"]}"),
        ],
      );
    }
    else {
      return Row(
        children: [
          const Icon(Icons.science_outlined),
          Text(" ${data["name"]}, \n Dur: ${data["duration"]}, Pow: ${data["power"]}"),
        ],
      );
    }
  }

}