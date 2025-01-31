import 'package:flutter/material.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zug_utils/zug_utils.dart';
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
  void initState() {
    super.initState();
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
        widget.header,
        Container(
            color: widget.optionsBackgroundColor,
            //height: 72,
            child: Center(child: Text("${widget.client.areaName} Options",style: TextStyle(
                fontSize: 24,
                color: widget.optionsTextColor,
                //backgroundColor: widget.optionsBackgroundColor
            ),))
        ),
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
                ElevatedButton(onPressed: () => widget.client.areaCmd(ClientMsg.setOptions, data: { fieldOptions : newOptions } ),
                    child: Text("Update ${widget.client.areaName} Options")),
                ElevatedButton(onPressed: () =>  widget.client.areaCmd(ClientMsg.getOptions),  //setState(() => loadOptions()),
                    child: Text("Reset ${widget.client.areaName} Options")),
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
      entryWidget = TextButton(onPressed: () {
        ZugDialogs.getString('Enter new $field',val).then((txt) {
          setState(() {
            newOptions[field][fieldOptVal] = txt;
          });
        });
      }, child: Text("$field: $val",style: TextStyle(color:  widget.optionsTextColor)));
    }
    else if (val is double) { //or int
      double range = entry[fieldOptMax] - entry[fieldOptMin];
      double div = (range/entry[fieldOptInc]);
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$field : $val",style: TextStyle(color:  widget.optionsTextColor)),
          Slider(
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
          Text(field,style: TextStyle(color:  widget.optionsTextColor)),
          Checkbox(value: val, onChanged: (newValue) => setState(() { newOptions[field][fieldOptVal] = newValue; }))
        ],
      );
    }
    return Center(child: entryWidget);
  }


}
