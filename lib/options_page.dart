import 'package:flutter/material.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

class OptionsPage extends StatefulWidget {
  static int doubleDecimals = 2;
  final Color optionsBackgroundColor;
  final Color optionsTextColor;
  final Color optionsDropdownCBkgCol;
  final ZugClient client;
  final double headerHeight;
  final Widget? customHeader;
  final String headerTxt;
  final bool isDialog;

  const OptionsPage(this.client, {
    this.customHeader,
    this.headerHeight = 128,
    this.headerTxt = "Options",
    this.isDialog = false,
    this.optionsBackgroundColor = Colors.black,
    this.optionsTextColor = Colors.cyan,
    this.optionsDropdownCBkgCol = Colors.blueGrey, // Color.fromRGBO(222, 222, 0, .5),
    super.key
  });

  @override
  State<StatefulWidget> createState() => _OptionsPageState();

}

class _OptionsPageState extends State<OptionsPage> {
  Map<String,dynamic> newOptions = {};
  TextStyle? optTxtStyle;

  @override
  void initState() {
    super.initState();
    optTxtStyle = TextStyle(color: widget.optionsTextColor);
  }

  @override
  Widget build(BuildContext context) {
    newOptions = widget.client.currentArea.options; //print("Options: $newOptions");
    Map<String,Widget> widgets = {};
    List<String> optionFields = newOptions.keys.toList();
    optionFields.sort((a, b) {
      int fieldCmp = newOptions[a][fieldOptVal].runtimeType.hashCode.compareTo(newOptions[b][fieldOptVal].runtimeType.hashCode);
      if (fieldCmp == 0) {
        return a.compareTo(b);
      } else {
        return fieldCmp;
      }
    });

    for (String field in optionFields) { //newOptions.keys
      widgets[field] = parseOptionEntry(field, newOptions[field]);
    }

    return Column(
      children: [
        widget.customHeader ?? SizedBox(height: widget.headerHeight, child: Center(child: Text(widget.headerTxt))),
        Expanded(
            child: Container(
          color: widget.optionsBackgroundColor,
          child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(widgets.values.length,
                  (index) => widgets.values.elementAt(index))),
        )),
        Container(
            color: widget.optionsBackgroundColor,
            height: 72,
            child: Center(child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: () {
                  widget.client.areaCmd(ClientMsg.setOptions, data: { fieldOptions : newOptions });
                  if (widget.isDialog) Navigator.pop(context);
                },
                 child: const Text("Update")),
                ElevatedButton(onPressed: () =>  widget.client.fetchOptions(() => setState((){})),
                 child: const Text("Reset")),
              ],
            )),
        ),
      ],
    );
  }

  Widget parseOptionEntry(String field, Map<String,dynamic> entry) { //print(entry.toString());
    Widget entryWidget = const Text("?");
    dynamic val = entry[fieldOptVal];
    if (val is String) {
      List<dynamic> enums = entry[fieldOptEnum] as List<dynamic>;
      if (enums.isNotEmpty) {
        entryWidget = DropdownButton<String>(
            dropdownColor: widget.optionsDropdownCBkgCol, //.withOpacity(.5),
            value: val,
            items: List.generate(enums.length, (i) => DropdownMenuItem<String>(
                value: enums.elementAt(i) as String,
                child: Text(enums.elementAt(i),style: optTxtStyle))
            ),
            onChanged: (String? str) => setState(() {
              newOptions[field][fieldOptVal] = str;
            })
        );
      }
      else {
        entryWidget = TextButton(onPressed: () {
          ZugDialogs.getString('Enter new $field',val).then((txt) {
            setState(() {
              newOptions[field][fieldOptVal] = txt;
            });
          });
        }, child: Text("$field: $val",style: optTxtStyle));
      }
    }
    else if (val is double) { //or int
      double range = entry[fieldOptMax] - entry[fieldOptMin];
      double div = (range/entry[fieldOptInc]);
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$field : $val",style: optTxtStyle),
          Slider(
            thumbColor: widget.optionsTextColor,
            value: val,
            min: entry[fieldOptMin] as double,
            max: entry[fieldOptMax] as double,
            divisions: div.toInt(),
            label: newOptions[field][fieldOptVal].toString(),
            onChanged: (double value) { //print(value);
              if (value >= entry[fieldOptMin] && value <= entry[fieldOptMax]) {
                setState(() { //print("Setting double field: $field -> $value");
                  newOptions[field][fieldOptVal] = ZugUtils.roundNumber(value,OptionsPage.doubleDecimals);
                });
              }
            },
          ),
        ],
      );
    }
    else if (val is bool) {
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(field,style: optTxtStyle),
          Checkbox(value: val, onChanged: (newValue) => setState(() { newOptions[field][fieldOptVal] = newValue; }))
        ],
      );
    }
    return Center(child: entryWidget);
  }


}
