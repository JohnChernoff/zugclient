import 'package:flutter/material.dart';
import 'package:zug_utils/zug_dialogs.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_model.dart';
import 'package:zugclient/zug_option.dart';

enum OptionScope { general, area }

class OptionsPage extends StatefulWidget {
  static const int doubleDecimals = 2;
  final Color optionsBackgroundColor;
  final Color optionsTextColor;
  final Color optionsDropdownCBkgCol;
  final double optionsPadding;
  final ZugModel model;
  final double headerHeight;
  final Widget? customHeader;
  final String headerTxt;
  final bool isDialog;
  final OptionScope scope;

  const OptionsPage(this.model, {
    this.customHeader,
    this.headerHeight = 128,
    this.headerTxt = "Options",
    this.isDialog = false,
    this.optionsBackgroundColor = Colors.black,
    this.optionsTextColor = Colors.cyan,
    this.optionsDropdownCBkgCol = Colors.blueGrey,
    this.optionsPadding = 4.0,
    required this.scope,
    super.key
  });

  @override
  State<StatefulWidget> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  bool loaded = false;
  Map<String, ZugOption> optionMap = {};
  Map<String, Widget> optionWidgets = {};
  List<String> optionFields = [];
  TextStyle? optTxtStyle;

  @override
  void initState() {
    super.initState();
    optTxtStyle = TextStyle(color: widget.optionsTextColor);
    loadOptions(); //TODO: don't do this when unnecessary
  }

  Future<void> loadOptions({reload = false}) async {
    if (widget.scope == OptionScope.general) { loaded = true;}
    else if (reload) { loaded = false; } //TODO: just use former temp vars?
    if (!loaded) { //print("Not loaded - loading...");
      widget.model.areaCmd(ClientMsg.getOptions,responseType: ServMsg.updateOptions).then((data) {
        loaded = true; loadOptions(); //print("Loaded!");
      });
      return;
    }
    optionMap.clear();
    Map<String, ZugOption> optionMapSrc = widget.scope == OptionScope.general
        ? widget.model.getOptions()
        : widget.model.currentArea.options;
    for (String key in optionMapSrc.keys) {
      optionMap[key] = optionMapSrc[key]!.copy();
    }
    optionFields = optionMap.keys.toList();
    optionFields.sort((a, b) {
      final typeA = optionMap[a]?.zugVal.getType();
      final typeB = optionMap[b]?.zugVal.getType();

      // Bool first, then sort by type index
      if (typeA == ValType.bool && typeB != ValType.bool) return -1;
      if (typeA != ValType.bool && typeB == ValType.bool) return 1;

      int fieldCmp = typeA?.index.compareTo(typeB?.index ?? 0 as num) ?? 0;
      return fieldCmp == 0 ? a.compareTo(b) : fieldCmp;
    });
    setState(() {
      loaded = true;
    });
  }

  double _calculateMaxWidth(BuildContext context) {
    const double minWidth = 300.0;
    double maxWidth = minWidth;

    for (String key in optionFields) {
      final option = optionMap[key];
      if (option != null) {
        // Estimate width needed for label + description
        final double labelWidth = _estimateTextWidth(option.label, 14);
        double descWidth = 0;
        if (option.desc.isNotEmpty && option.desc != option.label) {
          descWidth = _estimateTextWidth(option.desc, 12);
        }
        final double optionWidth = (labelWidth + descWidth).clamp(0, 500);
        if (optionWidth > maxWidth) {
          maxWidth = optionWidth;
        }
      }
    }

    // Add padding for the card and some margin
    return (maxWidth + 80).clamp(280, 600);
  }

  double _estimateTextWidth(String text, double fontSize) {
    // Rough estimation: average character width is about 0.5 * fontSize
    return text.length * fontSize * 0.5;
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Text("Loading...");

    for (String key in optionFields) {
      optionWidgets[key] = parseOptionEntry(optionMap[key]!, key);
    }

    final cardWidth = _calculateMaxWidth(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        widget.customHeader ?? SizedBox(
          height: widget.headerHeight,
          child: Center(
            child: Text(
              widget.headerTxt,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.optionsTextColor,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: widget.optionsBackgroundColor,
            child: Center(
              child: SizedBox(
                width: cardWidth,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  scrollDirection: Axis.vertical,
                  children: List.generate(optionWidgets.values.length, (index) {
                    final widget = optionWidgets.values.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: widget,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        _buildButtonBar(),
      ],
    );
  }

  Widget _buildButtonBar() {
    return Container(
      color: widget.optionsBackgroundColor,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12.0,
        children: [
          ElevatedButton.icon(
            onPressed: () => exitOptions(),
            icon: const Icon(Icons.cancel),
            label: const Text("Cancel"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => saveOptions(),
            icon: const Icon(Icons.check),
            label: const Text("Update"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => resetOptions(),
            icon: const Icon(Icons.refresh),
            label: const Text("Reset"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void resetOptions() {
    loadOptions(reload: true);
    setState(() {});
  }

  void saveOptions() {
    if (widget.scope == OptionScope.general) {
      for (String key in optionMap.keys) {
        widget.model.setOption(key, optionMap[key]!);
      }
    } else {
      widget.model.areaCmd(ClientMsg.setOptions, data: {fieldOptions: areaOptionsToJson()});
    }
    exitOptions();
  }

  void exitOptions() {
    if (widget.isDialog) {
      Navigator.pop(context);
    } else {
      widget.model.goToPage(PageType.lobby);
    }
  }


  Map<String, dynamic> areaOptionsToJson() {
    Map<String, dynamic> areaOptionMap = {};
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
    return _OptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            option.label,
            style: optTxtStyle?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (option.desc.isNotEmpty && option.desc != option.label)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                option.desc,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: optTxtStyle?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButton<dynamic>(
            isExpanded: true,
            dropdownColor: widget.optionsDropdownCBkgCol,
            value: option.getVal(),
            items: List.generate(
              option.enums!.length,
                  (i) => DropdownMenuItem<dynamic>(
                value: option.enums!.elementAt(i),
                child: Text(
                  option.enums!.elementAt(i) is String
                      ? option.enums!.elementAt(i) as String
                      : (option.enums!.elementAt(i) as Enum).name,
                  style: optTxtStyle,
                ),
              ),
            ),
            onChanged: (dynamic val) => setOption(option, key, val),
          ),
        ],
      ),
    );
  }

  Widget parseOptionEntry(ZugOption option, String key) {
    Widget entryWidget = const Text("?");

    if (option.enums != null && option.enums!.isNotEmpty) {
      entryWidget = enumeratedOptionWidget(option, key);
    } else if (option.zugVal.getType() == ValType.string) {
      entryWidget = _OptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.label,
              style: optTxtStyle?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (option.desc.isNotEmpty && option.desc != option.label)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  option.desc,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: optTxtStyle?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    option.getVal() as String,
                    style: optTxtStyle?.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ZugDialogs.getString('Enter new ${option.label}', option.getString())
                        .then((txt) => setOption(option, key, txt));
                  },
                  child: Icon(Icons.edit, size: 18, color: widget.optionsTextColor),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (option.zugVal.isNumeric()) {
      num range = (option.max ?? option.getInt()) - (option.min ?? 0);
      double div = (range / (option.inc ?? 1));
      entryWidget = _OptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  option.label,
                  style: optTxtStyle?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.optionsTextColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${option.getVal()}',
                    style: optTxtStyle?.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (option.desc.isNotEmpty && option.desc != option.label)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  option.desc,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: optTxtStyle?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Slider(
              thumbColor: widget.optionsTextColor,
              activeColor: widget.optionsTextColor.withValues(alpha: 0.7),
              inactiveColor: widget.optionsTextColor.withValues(alpha: 0.2),
              value: option.getVal() as double,
              min: option.min as double,
              max: option.max as double,
              divisions: div.toInt(),
              label: option.label,
              onChanged: (double value) => setOption(
                option,
                key,
                option.zugVal.getType() == ValType.int ? value.round() : value,
              ),
            ),
          ],
        ),
      );
    } else if (option.zugVal.getType() == ValType.bool) {
      entryWidget = _OptionCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: optTxtStyle?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (option.desc.isNotEmpty && option.desc != option.label)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        option.desc,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: optTxtStyle?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: option.getBool(),
              onChanged: (newValue) => setOption(option, key, newValue),
              activeThumbColor: widget.optionsTextColor,
              activeTrackColor: widget.optionsTextColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      );
    }

    return entryWidget;
  }
}

class _OptionCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double borderWidth;

  const _OptionCard({
    required this.child,
    this.borderColor = Colors.cyan,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
