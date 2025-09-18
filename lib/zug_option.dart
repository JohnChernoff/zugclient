import 'package:zugclient/zug_fields.dart';

enum ValType { int, double, bool, string, enumeration }

class UnknownValueTypeException implements Exception {
  final dynamic value;
  UnknownValueTypeException(this.value);
}

class ZugVal {
  late final ValType? _valType;
  late final int? _intVal;
  late final double? _dblVal;
  late final bool? _boolVal;
  late final String? _strVal; // used for string and enum

  ZugVal(dynamic val) {
    if (val is bool) {
      _valType = ValType.bool;
      _boolVal = val;
      _intVal = _dblVal = _strVal = null;
    } else if (val is int) {
      _valType = ValType.int;
      _intVal = val;
      _dblVal = _boolVal = _strVal = null;
    } else if (val is double) {
      _valType = ValType.double;
      _dblVal = val;
      _intVal = _boolVal = _strVal = null;
    } else if (val is String) {
      _valType = ValType.string;
      _strVal = val;
      _intVal = _dblVal = _boolVal = null;
    } else if (val is Enum) {
      _valType = ValType.enumeration;
      _strVal = val.name;
      _intVal = _dblVal = _boolVal = null;
    } else if (val == null) {
      _valType = null;
      _intVal = _dblVal = _boolVal = _strVal = null;
    } else {
      throw UnknownValueTypeException(val);
    }
  }

  dynamic getVal() {
    return switch (_valType) {
      ValType.int => _intVal,
      ValType.double => _dblVal,
      ValType.bool => _boolVal,
      ValType.string => _strVal,
      ValType.enumeration => _strVal, // enum stored as string
      null => null,
    };
  }

  ValType? getType() => _valType;
  bool isNumeric() => _valType == ValType.int || _valType == ValType.double;
  @override
  String toString() => "${getVal()}";
}

/// --- Enum registration ---
final Map<Type, List<Enum>> _enumValuesMap = {};

void registerEnum<T extends Enum>(List<T> values) {
  _enumValuesMap[T] = values;
}

/// --- ZugOption class ---
class ZugOption {
  final String label;
  final String desc;
  final ZugVal zugVal;
  final num? min, max, inc;
  final List<String>? enums;

  /// Generic constructor (only int, double, bool, string allowed)
  ZugOption(
      dynamic v, {
        required this.label,
        this.min,
        this.max,
        this.inc,
        this.enums,
        String? desc,
      })  : zugVal = ZugVal(v),
        desc = desc ?? label {
    if (v is Enum) {
      throw StateError(
          "Direct enum values are not allowed. Use `.asOption()` instead."
      );
    }
  }

  /// Private constructor for enum values (called from .asOption)
  ZugOption._fromEnum(
      Enum v, {
        required this.label,
        String? desc,
        required List<String> this.enums,
      })  : zugVal = ZugVal(v),
        desc = desc ?? label, inc = null, min = null, max = null;

  /// JSON serialization
  Map<String, dynamic> toJson() => {
    fieldOptDesc: desc,
    fieldOptLabel: label,
    fieldOptVal: zugVal.getVal(),
    fieldOptMin: min,
    fieldOptMax: max,
    fieldOptInc: inc,
    fieldOptEnum: enums,
  };

  static ZugOption fromJson(Map<String, dynamic> json) {
    final val = json[fieldOptVal];
    final enumNames = (json[fieldOptEnum] as List?)
        ?.map((e) => e.toString())
        .toList();
    if (enumNames != null && val is String) {
      // Caller must map back to enum type with getEnum<T>()
    }
    return ZugOption(
      val,
      label: json[fieldOptLabel],
      desc: json[fieldOptDesc],
      min: json[fieldOptMin],
      max: json[fieldOptMax],
      inc: json[fieldOptInc],
      enums: enumNames,
    );
  }

  dynamic getVal() => zugVal.getVal();
  bool getBool() => (zugVal.getVal() ?? false) as bool;
  int getInt() => zugVal.getVal() as int;
  double getDbl() => zugVal.getVal() as double;
  num getNum() => zugVal.getVal() as num;
  String getString() => zugVal.getVal() as String;

  /// Convert stored string back to enum
  T getEnum<T extends Enum>(List<T> values) {
    final val = zugVal.getVal();
    if (val is String) return values.byName(val);
    throw StateError("Cannot convert $val to enum of type $T");
  }

  ZugOption fromValue(dynamic val) => ZugOption(
    val,
    min: min,
    max: max,
    inc: inc,
    enums: enums,
    desc: desc,
    label: label,
  );

  ZugOption copy() => ZugOption(
    zugVal.getVal(),
    min: min,
    max: max,
    inc: inc,
    enums: enums,
    desc: desc,
    label: label,
  );

  @override
  String toString() => "${getVal()}";
}

/// --- Enum helper extension ---
extension AutoEnumOption<T extends Enum> on T {
  ZugOption asOption({required String label, String? desc}) {
    final allValues = _enumValuesMap[T] as List<T>?;
    if (allValues == null) {
      throw StateError("Enum values not registered for type $T");
    }
    return ZugOption._fromEnum(
      this,
      label: label,
      desc: desc,
      enums: allValues.map((e) => e.name).toList(),
    );
  }
}
