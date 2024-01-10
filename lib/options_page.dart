import 'dart:math';
import 'package:flutter/material.dart';
import 'package:zugclient/dialogs.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';

class OptionsPage extends StatefulWidget {
  static int doubleDecimals = 2;
  final Color optionsBackgroundColor = Colors.black;
  final Color optionsTextColor = Colors.green;
  final ZugClient client;
  final Widget header;

  const OptionsPage(this.client, {
    this.header = const SizedBox(height: 128, child: Center(child: Text("Options"))),
    super.key
  });

  @override
  State<StatefulWidget> createState() => _OptionsPageState();

}

class _OptionsPageState extends State<OptionsPage> {
  Map<String,dynamic> newOptions = {};

  @override
  Widget build(BuildContext context) {
    newOptions = widget.client.currentArea.options; //print("Options: $newOptions");
    Map<String,Widget> widgets = {};
    for (String field in newOptions.keys) {
      widgets[field] = parseOptionEntry(field, newOptions[field]);
    }
    return Column(
      children: [
        widget.header,
        Expanded(
            child: Container(
          color: widget.optionsBackgroundColor,
          child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(widgets.values.length,
                  (index) => widgets.values.elementAt(index))),
        )),
        SizedBox(
            height: 128,
            child: Center(child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: () => widget.client.areaCmd(ClientMsg.setOptions, data: { fieldOptions : newOptions } ),
                    child: const Text("Update")),
                ElevatedButton(onPressed: () =>  widget.client.areaCmd(ClientMsg.getOptions),  //setState(() => loadOptions()),
                    child: const Text("Revert")),
              ],
            )),
        ),
      ],
    );
  }

  Widget parseOptionEntry(String field, Map<String,dynamic> entry) {
    //print(entry.toString());
    Widget entryWidget = const Text("?");
    dynamic val = entry[fieldOptVal];
    if (val is String) {
      entryWidget = TextButton(onPressed: () {
        Dialogs.getString('Enter new $field',val).then((txt) {
          setState(() {
            newOptions[field][fieldOptVal] = txt;
          });
        });
      }, child: Text("$field: $val",style: TextStyle(color:  widget.optionsTextColor)));
    }
    else if (val is double) { //or int
      double range = entry[fieldOptMax] - entry[fieldOptMin];
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$field : $val",style: TextStyle(color:  widget.optionsTextColor)),
          Slider(
            value: val,
            min: entry[fieldOptMin] as double,
            max: entry[fieldOptMax] as double,
            divisions: (entry[fieldOptInt] ? range as int : null),
            label: newOptions[field][fieldOptVal].toString(),
            onChanged: (double value) { //print(value);
              if (value >= entry[fieldOptMin] && value <= entry[fieldOptMax]) {
                setState(() { //print("Setting double field: $field -> $value");
                  newOptions[field][fieldOptVal] = roundNumber(value,OptionsPage.doubleDecimals);
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
          Text(field,style: TextStyle(color:  widget.optionsTextColor)),
          Checkbox(value: val, onChanged: (newValue) => setState(() { newOptions[field][fieldOptVal] = newValue; }))
        ],
      );
    }
    return Center(child: entryWidget);
  }

  double roundNumber(double value, int places) {
    num val = pow(10.0, places);
    return ((value * val).round().toDouble() / val);
  }
}
