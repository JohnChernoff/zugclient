import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_option.dart';

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
  Map<String,ZugOption> areaOptions = {};
  TextStyle? optTxtStyle;

  @override
  void initState() {
    super.initState();
    optTxtStyle = TextStyle(color: widget.optionsTextColor);
  }

  @override
  Widget build(BuildContext context) {
    areaOptions = widget.client.currentArea.options; //print("Options: $areaOptions");
    Map<String,Widget> widgets = {};
    List<String> optionFields = areaOptions.keys.toList();
    optionFields.sort((a, b) {
      int fieldCmp = areaOptions[a]?.zugVal.getType()?.index.compareTo(areaOptions[b]?.zugVal.getType()?.index as num) ?? 0;
      return fieldCmp == 0 ? a.compareTo(b) : fieldCmp;
    });

    for (String field in optionFields) {
      widgets[field] = parseOptionEntry(areaOptions[field]!,false);
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
                  widget.client.areaCmd(ClientMsg.setOptions, data: { fieldOptions : areaOptionsToJson() }); //()
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

  Map<String,dynamic> areaOptionsToJson() {
    Map<String,dynamic> optionMap = {};
    for (String field in areaOptions.keys) {
      optionMap[field] = areaOptions[field]?.toJson();
    }
    return optionMap;
  }

  void setOption(ZugOption option, dynamic val, bool general) {
    setState(() {
      if (general) {
        widget.client.setOption(option.name, option.fromValue(val));
      }
      else {
        areaOptions[option.name] = option.fromValue(val);
      }
    });
  }

  Widget enumeratedOptionWidget(ZugOption option, bool general) {
    return DropdownButton<dynamic>(
        dropdownColor: widget.optionsDropdownCBkgCol, //.withOpacity(.5),
        value: option.getVal(),
        items: List.generate(option.enums!.length, (i) => DropdownMenuItem<dynamic>(
            value: option.enums!.elementAt(i),
            child: Text(option.enums!.elementAt(i),style: optTxtStyle))
        ),
        onChanged: (dynamic val) => setOption(option, val, general));
  }

  Widget parseOptionEntry(ZugOption option, bool general) { //print(entry.toString());
    Widget entryWidget = const Text("?");
    if (option.enums != null && option.enums!.isNotEmpty) {
      entryWidget = enumeratedOptionWidget(option, general);
    }
    else if (option.zugVal.getType() == ValType.string) {
      entryWidget = TextButton(onPressed: () {
        ZugDialogs.getString('Enter new ${option.label}',
            option.getString()).then((txt) => setOption(option, txt, general));
      }, child: Text("${option.label}: ${option.getVal()}",style: optTxtStyle));
    }
    else if (option.zugVal.isNumeric()) {
      num range = (option.max ?? option.getInt()) - (option.min ?? 0);
      double div = (range/(option.inc ?? 1));
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${option.label} : ${option.getVal()}",style: optTxtStyle),
          Slider(
            thumbColor: widget.optionsTextColor,
            value: option.getVal() as double,
            min: option.min as double,
            max: option.max as double,
            divisions: div.toInt(),
            label: option.label,
            onChanged: (double value) => setOption(option, value, general),
          ),
        ],
      );
    }
    else if (option.zugVal.getType() == ValType.bool) {
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(option.label,style: optTxtStyle),
          Checkbox(value: option.getBool(), onChanged: (newValue) => setOption(option, newValue, general)),
        ],
      );
    }
    return Center(child: entryWidget);
  }


}
