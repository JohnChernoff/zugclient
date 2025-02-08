import 'package:flutter/material.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_client.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_option.dart';

enum OptionScope { general,area }

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
  final OptionScope scope;

  const OptionsPage(this.client, {
    this.customHeader,
    this.headerHeight = 128,
    this.headerTxt = "Options",
    this.isDialog = false,
    this.optionsBackgroundColor = Colors.black,
    this.optionsTextColor = Colors.cyan,
    this.optionsDropdownCBkgCol = Colors.blueGrey, // Color.fromRGBO(222, 222, 0, .5),
    required this.scope,
    super.key
  });

  @override
  State<StatefulWidget> createState() => _OptionsPageState();

}

class _OptionsPageState extends State<OptionsPage> {
  Map<String,ZugOption> optionMap = {};
  Map<String,Widget> optionWidgets = {};
  List<String> optionFields = [];
  TextStyle? optTxtStyle;

  @override
  void initState() {
    super.initState();
    optTxtStyle = TextStyle(color: widget.optionsTextColor);
    loadOptions();
  }

  void loadOptions() {
    optionMap.clear();
    Map<String,ZugOption> optionMapSrc = widget.scope == OptionScope.general
        ? widget.client.getOptions()
        : widget.client.currentArea.options;
    for (String key in optionMapSrc.keys) {
      optionMap[key] = optionMapSrc[key]!.copy();
    }
    optionFields = optionMap.keys.toList();
    optionFields.sort((a, b) {
      int fieldCmp = optionMap[a]?.zugVal.getType()?.index.compareTo(optionMap[b]?.zugVal.getType()?.index as num) ?? 0;
      return fieldCmp == 0 ? a.compareTo(b) : fieldCmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    for (String key in optionFields) {
      optionWidgets[key] = parseOptionEntry(optionMap[key]!,key);
    }
    return Column(
      children: [
        widget.customHeader ?? SizedBox(height: widget.headerHeight, child: Center(child: Text(widget.headerTxt))),
        Expanded(child: Container(
          color: widget.optionsBackgroundColor,
          child: ListView(
              scrollDirection: Axis.vertical,
              children: List.generate(optionWidgets.values.length,
                  (index) => optionWidgets.values.elementAt(index))),
        )),
        Container(
          color: widget.optionsBackgroundColor,
          height: 72,
          child: Center(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () => saveOptions(),
                  child: const Text("Update")),
              ElevatedButton(
                  onPressed: () => resetOptions(),
                  child: const Text("Reset")),
            ],
          )),
        ),
      ],
    );
  }

  void resetOptions() {
    loadOptions();
    setState((){});
  }

  void saveOptions() {
    if (widget.scope == OptionScope.general) {
        for (String key in optionMap.keys) {
          widget.client.setOption(key, optionMap[key]!);
        }
    }
    else {
      widget.client.areaCmd(ClientMsg.setOptions, data: { fieldOptions : areaOptionsToJson() }); //()
    }
    if (widget.isDialog) {
      Navigator.pop(context);
    } else {
      widget.client.setSwitchPage(PageType.lobby);
    }
  }

  Map<String,dynamic> areaOptionsToJson() {
    Map<String,dynamic> areaOptionMap = {};
    for (String key in optionMap.keys) {
      areaOptionMap[key] = optionMap[key]?.toJson();
    }
    return areaOptionMap;
  }

  void setOption(ZugOption option, String key, dynamic val) {
    setState(() {
      optionMap[key] = option.fromValue(val);
    });
  }

  Widget enumeratedOptionWidget(ZugOption option, String key) {
    return DropdownButton<dynamic>(
        dropdownColor: widget.optionsDropdownCBkgCol, //.withOpacity(.5),
        value: option.getVal(),
        items: List.generate(option.enums!.length, (i) => DropdownMenuItem<dynamic>(
            value: option.enums!.elementAt(i),
            child: Text(option.enums!.elementAt(i),style: optTxtStyle))
        ),
        onChanged: (dynamic val) => setOption(option, key, val));
  }

  Widget parseOptionEntry(ZugOption option, String key) { //print(entry.toString());
    Widget entryWidget = const Text("?");
    if (option.enums != null && option.enums!.isNotEmpty) {
      entryWidget = enumeratedOptionWidget(option, key);
    }
    else if (option.zugVal.getType() == ValType.string) {
      entryWidget = TextButton(onPressed: () {
        ZugDialogs.getString('Enter new ${option.label}',
            option.getString()).then((txt) => setOption(option, txt, key));
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
            onChanged: (double value) => setOption(option, key, value),
          ),
        ],
      );
    }
    else if (option.zugVal.getType() == ValType.bool) {
      entryWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(option.label,style: optTxtStyle),
          Checkbox(value: option.getBool(), onChanged: (newValue) => setOption(option, key, newValue)),
        ],
      );
    }
    return Center(child: entryWidget);
  }


}
