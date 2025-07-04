import 'package:zugclient/zug_fields.dart';

enum ValType {int,double,bool,string,enumeration}

class UnknownValueTypeException implements Exception {
  dynamic value;
  UnknownValueTypeException(this.value);
}

//TODO: fix Enums

class ZugVal {
  late final ValType? _valType;
  late final int? _intVal;
  late final double? _dblVal;
  late final bool? _boolVal;
  late final String? _strVal;
  late final Enum? _enumVal;

  ZugVal(dynamic val) {
    if (val is bool) {
      _valType = ValType.bool; _boolVal = val;
      _intVal = _dblVal = _strVal = _enumVal = null;
    }
    else if (val is int) {
      _valType = ValType.int; _intVal = val;
      _boolVal = _dblVal = _strVal = _enumVal = null;
    }
    else if (val is double) {
      _valType = ValType.double; _dblVal = val;
      _intVal = _boolVal = _strVal = _enumVal = null;
    }
    else if (val is String) {
      _valType = ValType.string; _strVal = val;
      _intVal = _dblVal = _boolVal = _enumVal = null;
    }
    else if (val is Enum) {
      _valType = ValType.string; _enumVal = val;
      _intVal = _dblVal = _boolVal = _strVal = null;
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
      ValType.enumeration => _enumVal,
      null => null,
    };
  }

  ValType? getType() => _valType;

  bool isNumeric() => (_valType == ValType.int) || (_valType == ValType.double);

  @override
  String toString() {
    return "${getVal()}";
  }
}

class ZugOption {
  final String label;
  final String desc;
  final ZugVal zugVal;
  final num? min, max, inc;
  final List<dynamic>? enums;

  ZugOption(v, {
    required this.label,
    this.min,this.max,this.inc,
    this.enums,
    String? desc,
  }) : zugVal = ZugVal(v), desc = desc ?? label;

  Map<String,dynamic> toJson() => {
      fieldOptDesc : desc,
      fieldOptLabel : label,
      fieldOptVal : getVal(),
      fieldOptMin : min,
      fieldOptMax : max,
      fieldOptInc : inc,
      fieldOptEnum : enums
    };

  dynamic getVal() => zugVal.getVal();
  bool getBool() => (zugVal.getVal() ?? false) as bool;
  int getInt() =>  zugVal.getVal() as int;
  double getDbl() =>  zugVal.getVal() as double;
  num getNum() => zugVal.getVal() as num;
  String getString() =>  zugVal.getVal() as String;
  Enum getEnum() => zugVal.getVal() as Enum;

  static ZugOption fromJson(Map<String,dynamic> json) {
    if (json.isEmpty) return ZugOption("?", label: "Null Option"); //print("Decoding: $json");
    return ZugOption(json[fieldOptVal],
      desc: json[fieldOptDesc],
      label: json[fieldOptLabel],
      min: json[fieldOptMin],
      max: json[fieldOptMax],
      inc: json[fieldOptInc],
      enums: json[fieldOptEnum],
    );
  }

  ZugOption fromValue(dynamic val) => ZugOption(val,min: min, max: max, inc: inc, enums: enums, desc: desc, label: label);
  ZugOption copy() => ZugOption(zugVal.getVal(),min: min, max: max, inc: inc, enums: enums, desc: desc, label: label); //enums?

  @override
  String toString() {
    return "${getVal()}";
  }
}
