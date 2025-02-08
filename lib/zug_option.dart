import 'dart:convert';

import 'package:zugclient/zug_fields.dart';

enum ValType {int,double,bool,string}

class UnknownValueTypeException implements Exception {
  dynamic value;
  UnknownValueTypeException(this.value);
}

class ZugVal {
  late final ValType? _valType;
  late final int? _intVal;
  late final double? _dblVal;
  late final bool? _boolVal;
  late final String? _strVal;

  ZugVal(dynamic val) {
    if (val is bool) {
      _valType = ValType.bool; _boolVal = val;
      _intVal = _dblVal = _strVal = null;
    }
    else if (val is int) {
      _valType = ValType.int; _intVal = val;
      _boolVal = _dblVal = _strVal = null;
    }
    else if (val is double) {
      _valType = ValType.double; _dblVal = val;
      _intVal = _boolVal = _strVal = null;
    }
    else if (val is String) {
      _valType = ValType.string; _strVal = val;
      _intVal = _dblVal = _boolVal = null;
    }
    else if (val == null) {
      _valType = _boolVal = _intVal = _dblVal = _strVal = null;
    }
    else { //print(val);
      throw UnknownValueTypeException(val);
    }
  }

  dynamic getVal() {
    return switch (_valType) {
      ValType.int => _intVal,
      ValType.double => _dblVal,
      ValType.bool => _boolVal,
      ValType.string => _strVal,
      null => null,
    };
  }

  ValType? getType() => _valType;

  bool isNumeric() => (_valType == ValType.int) || (_valType == ValType.double);

}

class ZugOption {
  final String name;
  final String desc;
  final String label;
  final ZugVal zugVal;
  final num? min, max, inc;
  final List<dynamic>? enums;

  ZugOption(this.name, v, {
    this.min,this.max,this.inc,
    this.enums,
    String? desc,
    String? label,
  }) : zugVal = ZugVal(v), desc = desc ?? name, label = label ?? name;


  ZugOption.fromEnum(Enum e, v, {
    this.min,this.max,this.inc,
    this.enums,
    String? desc,
    String? label,
  }) : name = e.name, zugVal = ZugVal(v), desc = desc ?? e.name, label = label ?? e.name;

  Map<String,dynamic> toJson() => {
      fieldOptName : name,
      fieldOptDesc : desc,
      fieldOptLabel : label,
      fieldOptVal : getVal(),
      fieldOptMin : min,
      fieldOptMax : max,
      fieldOptInc : inc,
      fieldOptEnum : enums
    };


  dynamic getVal() => zugVal.getVal();
  bool getBool() => zugVal.getVal() as bool;
  int getInt() =>  zugVal.getVal() as int;
  double getDbl() =>  zugVal.getVal() as double;
  String getString() =>  zugVal.getVal() as String;

  static ZugOption? fromJson(Map<String,dynamic> json) {
    if (json.isEmpty) return null; //print("Decoding: $json");
    return ZugOption(json[fieldOptName], json[fieldOptVal],
      desc: json[fieldOptDesc],
      label: json[fieldOptLabel],
      min: json[fieldOptMin],
      max: json[fieldOptMax],
      inc: json[fieldOptInc],
      enums: json[fieldOptEnum],
    );
  }

  ZugOption fromValue(dynamic val) => ZugOption(name, val,min: min, max: max, inc: inc, enums: enums, desc: desc, label: label);

}
