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

  /// Evaluate a simple expression and return the result.
  ///
  /// Supports:
  /// - Variable references: `$varName`
  /// - Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
  /// - Boolean operators: `and`, `or`, `not`
  /// - Literals: numbers, strings, `true`, `false`
  bool evaluateCondition(String expression) {
    expression = expression.trim();

    // Handle 'not' prefix
    if (expression.startsWith('not ')) {
      return !evaluateCondition(expression.substring(4));
    }

    // Handle 'or' first (lower precedence = outer operation)
    // This ensures correct precedence: not > and > or
    final orIndex = expression.indexOf(' or ');
    if (orIndex > 0) {
      final left = expression.substring(0, orIndex);
      final right = expression.substring(orIndex + 4);
      return evaluateCondition(left) || evaluateCondition(right);
    }

    // Handle 'and' (higher precedence than 'or')
    final andIndex = expression.indexOf(' and ');
    if (andIndex > 0) {
      final left = expression.substring(0, andIndex);
      final right = expression.substring(andIndex + 5);
      return evaluateCondition(left) && evaluateCondition(right);
    }

    // Handle comparisons
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      final opIndex = expression.indexOf(op);
      if (opIndex > 0) {
        final left = _evaluateValue(expression.substring(0, opIndex).trim());
        final right =
            _evaluateValue(expression.substring(opIndex + op.length).trim());
        return _compare(left, right, op);
      }
    }

    // Single value (truthy check)
    final value = _evaluateValue(expression);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    return false;
  }

  dynamic _evaluateValue(String expr) {
    expr = expr.trim();

    // Boolean literals
    if (expr == 'true') return true;
    if (expr == 'false') return false;

    // Variable reference
    if (expr.startsWith('\$')) {
      return getValue(expr);
    }

    // Number
    final num? number = num.tryParse(expr);
    if (number != null) return number;

    // Quoted string
    if ((expr.startsWith('"') && expr.endsWith('"')) ||
        (expr.startsWith("'") && expr.endsWith("'"))) {
      return expr.substring(1, expr.length - 1);
    }

    // Unquoted string
    return expr;
  }

  bool _compare(dynamic left, dynamic right, String op) {
    // Null handling
    if (left == null || right == null) {
      return switch (op) {
        '==' => left == right,
        '!=' => left != right,
        _ => false,
      };
    }

    // Number comparison
    if (left is num && right is num) {
      return switch (op) {
        '==' => left == right,
        '!=' => left != right,
        '<' => left < right,
        '>' => left > right,
        '<=' => left <= right,
        '>=' => left >= right,
        _ => false,
      };
    }

    // String comparison
    final leftStr = left.toString();
    final rightStr = right.toString();
    return switch (op) {
      '==' => leftStr == rightStr,
      '!=' => leftStr != rightStr,
      '<' => leftStr.compareTo(rightStr) < 0,
      '>' => leftStr.compareTo(rightStr) > 0,
      '<=' => leftStr.compareTo(rightStr) <= 0,
      '>=' => leftStr.compareTo(rightStr) >= 0,
      _ => false,
    };
  }

  /// Execute a set command (e.g., `$var = value`, `$var += 5`).
  void executeSet(String expression) {
    expression = expression.trim();

    // Handle compound operators
    for (final op in ['+=', '-=', '*=', '/=']) {
      final opIndex = expression.indexOf(op);
      if (opIndex > 0) {
        final varName = expression.substring(0, opIndex).trim();
        final value = _evaluateValue(expression.substring(opIndex + 2).trim());
        final current = getNumber(varName);

        // Validate that value is numeric for compound operations
        if (value is! num) return;

        final newValue = switch (op) {
          '+=' => current + value,
          '-=' => current - value,
          '*=' => current * value,
          '/=' => current / value,
          _ => current,
        };
        setNumber(varName, newValue);
        return;
      }
    }

    // Simple assignment
    final eqIndex = expression.indexOf('=');
    if (eqIndex > 0) {
      final varName = expression.substring(0, eqIndex).trim();
      final value = _evaluateValue(expression.substring(eqIndex + 1).trim());
      setValue(varName, value);
    }
  }
}
