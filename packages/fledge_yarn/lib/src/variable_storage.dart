import 'expression.dart';

/// Storage for Yarn dialogue variables.
///
/// Variables in Yarn are prefixed with `$` (e.g., `$hasKey`, `$friendship`).
/// This class stores variable values and provides type-safe access.
///
/// Example:
/// ```dart
/// final storage = VariableStorage();
/// storage.setNumber('friendship', 50);
/// storage.setBool('hasKey', true);
/// storage.setString('playerName', 'Alex');
///
/// print(storage.getNumber('friendship')); // 50
/// print(storage.getBool('hasKey')); // true
/// ```
class VariableStorage {
  final Map<String, dynamic> _variables = {};
  late final ExpressionEvaluator _evaluator =
      ExpressionEvaluator((name) => _variables[_normalize(name)]);

  /// All variable names in storage.
  Iterable<String> get variableNames => _variables.keys;

  /// Get a variable value as a number.
  ///
  /// Returns [defaultValue] if the variable doesn't exist or isn't a number.
  double getNumber(String name, [double defaultValue = 0]) {
    final value = _variables[_normalize(name)];
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  /// Get a variable value as an integer.
  ///
  /// Returns [defaultValue] if the variable doesn't exist or isn't a number.
  int getInt(String name, [int defaultValue = 0]) {
    final value = _variables[_normalize(name)];
    if (value is num) return value.toInt();
    return defaultValue;
  }

  /// Get a variable value as a boolean.
  ///
  /// Returns [defaultValue] if the variable doesn't exist.
  bool getBool(String name, [bool defaultValue = false]) {
    final value = _variables[_normalize(name)];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.isNotEmpty && value.toLowerCase() != 'false';
    }
    return defaultValue;
  }

  /// Get a variable value as a string.
  ///
  /// Returns [defaultValue] if the variable doesn't exist.
  String getString(String name, [String defaultValue = '']) {
    final value = _variables[_normalize(name)];
    if (value != null) return value.toString();
    return defaultValue;
  }

  /// Get the raw value of a variable.
  dynamic getValue(String name) => _variables[_normalize(name)];

  /// Check if a variable exists.
  bool hasVariable(String name) => _variables.containsKey(_normalize(name));

  /// Set a number variable.
  void setNumber(String name, num value) {
    _variables[_normalize(name)] = value;
  }

  /// Set a boolean variable.
  void setBool(String name, bool value) {
    _variables[_normalize(name)] = value;
  }

  /// Set a string variable.
  void setString(String name, String value) {
    _variables[_normalize(name)] = value;
  }

  /// Set a variable value (auto-detects type).
  void setValue(String name, dynamic value) {
    _variables[_normalize(name)] = value;
  }

  /// Remove a variable.
  void remove(String name) {
    _variables.remove(_normalize(name));
  }

  /// Clear all variables.
  void clear() {
    _variables.clear();
  }

  /// Export all variables to a map (for serialization).
  Map<String, dynamic> toJson() => Map.from(_variables);

  /// Import variables from a map (for deserialization).
  void loadFromJson(Map<String, dynamic> json) {
    _variables.clear();
    _variables.addAll(json);
  }

  /// Normalize variable name (remove $ prefix if present).
  String _normalize(String name) {
    return name.startsWith('\$') ? name.substring(1) : name;
  }

  /// Evaluate a Yarn expression and return its boolean result.
  ///
  /// Supports:
  /// - Variable references: `$varName`
  /// - Arithmetic: `+`, `-`, `*`, `/`, `%` (with standard precedence)
  /// - Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
  /// - Boolean operators: `and`, `or`, `not`
  /// - Literals: numbers, strings, `true`, `false`, `null`
  /// - Parentheses for grouping
  ///
  /// Malformed expressions return `false` rather than throwing, matching the
  /// tolerant behaviour of the previous evaluator. Use [ExpressionEvaluator]
  /// directly when you want hard failures.
  bool evaluateCondition(String expression) {
    try {
      return _evaluator.evaluateBool(expression);
    } on FormatException {
      return false;
    }
  }

  /// Execute a set command (e.g., `$var = value`, `$var += 5`, `$var = $a * 2`).
  ///
  /// Malformed expressions are silently ignored.
  void executeSet(String expression) {
    try {
      _evaluator.executeSet(expression, (name, value) {
        _variables[_normalize(name)] = value;
      });
    } on FormatException {
      // Intentionally swallowed — matches the tolerant semantics of the
      // previous evaluator. Malformed scripts will simply not update state.
    }
  }
}
