/// Expression evaluator for Yarn Spinner dialogue expressions.
///
/// Implements a recursive-descent parser with standard precedence:
///
/// | Precedence | Operators              | Associativity |
/// |------------|------------------------|---------------|
/// | lowest     | `or`                   | left          |
/// |            | `and`                  | left          |
/// |            | `not`                  | right (unary) |
/// |            | `==` `!=` `<` `>` `<=` `>=` | none      |
/// |            | `+` `-`                | left          |
/// |            | `*` `/` `%`            | left          |
/// |            | unary `-` `+`          | right         |
/// | highest    | literal, variable, `( … )`         |
///
/// Variables use the `$name` syntax. String literals may use single or double
/// quotes and support `\\`, `\'`, `\"`, `\n`, `\t`, `\r` escapes. Unknown
/// identifiers evaluate to themselves as a string for backwards compatibility
/// with the previous evaluator.
class ExpressionEvaluator {
  final dynamic Function(String name) _resolveVariable;

  ExpressionEvaluator(this._resolveVariable);

  /// Evaluate [source] and return the resulting value.
  ///
  /// Throws [FormatException] on malformed input.
  dynamic evaluate(String source) {
    final tokens = _tokenize(source);
    final parser = _Parser(tokens, _resolveVariable);
    final result = parser.parseExpression();
    parser.expectEnd();
    return result;
  }

  /// Evaluate [source] as a boolean with truthy coercion.
  bool evaluateBool(String source) => _toBool(evaluate(source));

  /// Parse and execute a `<<set>>` body, e.g. `$x = 1 + 2` or `$x += 5`.
  ///
  /// Calls [assign] with the (unqualified) variable name and the resulting
  /// value. Compound operators read the current value via the constructor's
  /// variable resolver.
  void executeSet(
    String source,
    void Function(String name, dynamic value) assign,
  ) {
    final tokens = _tokenize(source);
    if (tokens.isEmpty || tokens.first.type != _TokenType.variable) {
      throw FormatException(
          'Expected variable at start of set expression: "$source"');
    }
    if (tokens.length < 3) {
      // Need at least: variable, op, rhs, end
      throw FormatException('Incomplete set expression: "$source"');
    }

    final varToken = tokens[0];
    final opToken = tokens[1];
    final name = varToken.lexeme.substring(1);

    final rhsTokens = tokens.sublist(2);
    final parser = _Parser(rhsTokens, _resolveVariable);
    final rhs = parser.parseExpression();
    parser.expectEnd();

    switch (opToken.type) {
      case _TokenType.assign:
        assign(name, rhs);
      case _TokenType.plusAssign:
        final current = _asNum(_resolveVariable(name) ?? 0);
        assign(name, current + _asNum(rhs));
      case _TokenType.minusAssign:
        final current = _asNum(_resolveVariable(name) ?? 0);
        assign(name, current - _asNum(rhs));
      case _TokenType.starAssign:
        final current = _asNum(_resolveVariable(name) ?? 0);
        assign(name, current * _asNum(rhs));
      case _TokenType.slashAssign:
        final current = _asNum(_resolveVariable(name) ?? 0);
        assign(name, current / _asNum(rhs));
      default:
        throw FormatException(
            'Expected assignment operator in "$source", got "${opToken.lexeme}"');
    }
  }
}

// ─── Tokenizer ──────────────────────────────────────────────────────────────

enum _TokenType {
  number,
  string,
  variable,
  ident,
  lparen,
  rparen,
  plus,
  minus,
  star,
  slash,
  percent,
  eq,
  neq,
  lt,
  gt,
  le,
  ge,
  assign,
  plusAssign,
  minusAssign,
  starAssign,
  slashAssign,
  end,
}

class _Token {
  final _TokenType type;
  final String lexeme;
  final dynamic literal;
  final int position;
  _Token(this.type, this.lexeme, this.position, {this.literal});
  @override
  String toString() => '$type($lexeme)';
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      i++;
      continue;
    }
    final start = i;

    if (i + 1 < n) {
      final two = source.substring(i, i + 2);
      final multi = _twoCharOp(two);
      if (multi != null) {
        tokens.add(_Token(multi, two, start));
        i += 2;
        continue;
      }
    }

    final single = _singleCharOp(c);
    if (single != null) {
      tokens.add(_Token(single, c, start));
      i++;
      continue;
    }

    if (c == '"' || c == "'") {
      final (value, end) = _readString(source, i);
      tokens.add(_Token(_TokenType.string, source.substring(start, end), start,
          literal: value));
      i = end;
      continue;
    }

    if (_isDigit(c) || (c == '.' && i + 1 < n && _isDigit(source[i + 1]))) {
      while (i < n && (_isDigit(source[i]) || source[i] == '.')) {
        i++;
      }
      final lex = source.substring(start, i);
      final value = num.parse(lex);
      tokens.add(_Token(_TokenType.number, lex, start, literal: value));
      continue;
    }

    if (c == r'$') {
      i++;
      while (i < n && _isIdentPart(source[i])) {
        i++;
      }
      tokens
          .add(_Token(_TokenType.variable, source.substring(start, i), start));
      continue;
    }

    if (_isIdentStart(c)) {
      while (i < n && _isIdentPart(source[i])) {
        i++;
      }
      tokens.add(_Token(_TokenType.ident, source.substring(start, i), start));
      continue;
    }

    throw FormatException('Unexpected character "$c" at position $start');
  }
  tokens.add(_Token(_TokenType.end, '', source.length));
  return tokens;
}

_TokenType? _twoCharOp(String s) {
  switch (s) {
    case '==':
      return _TokenType.eq;
    case '!=':
      return _TokenType.neq;
    case '<=':
      return _TokenType.le;
    case '>=':
      return _TokenType.ge;
    case '+=':
      return _TokenType.plusAssign;
    case '-=':
      return _TokenType.minusAssign;
    case '*=':
      return _TokenType.starAssign;
    case '/=':
      return _TokenType.slashAssign;
    default:
      return null;
  }
}

_TokenType? _singleCharOp(String c) {
  switch (c) {
    case '(':
      return _TokenType.lparen;
    case ')':
      return _TokenType.rparen;
    case '+':
      return _TokenType.plus;
    case '-':
      return _TokenType.minus;
    case '*':
      return _TokenType.star;
    case '/':
      return _TokenType.slash;
    case '%':
      return _TokenType.percent;
    case '<':
      return _TokenType.lt;
    case '>':
      return _TokenType.gt;
    case '=':
      return _TokenType.assign;
    default:
      return null;
  }
}

(String, int) _readString(String source, int start) {
  final quote = source[start];
  final sb = StringBuffer();
  var i = start + 1;
  while (i < source.length && source[i] != quote) {
    if (source[i] == '\\' && i + 1 < source.length) {
      final next = source[i + 1];
      switch (next) {
        case 'n':
          sb.write('\n');
        case 't':
          sb.write('\t');
        case 'r':
          sb.write('\r');
        case '\\':
          sb.write('\\');
        case '"':
          sb.write('"');
        case "'":
          sb.write("'");
        default:
          sb.write(next);
      }
      i += 2;
    } else {
      sb.write(source[i]);
      i++;
    }
  }
  if (i >= source.length) {
    throw FormatException('Unterminated string literal at position $start');
  }
  return (sb.toString(), i + 1);
}

bool _isDigit(String c) {
  final code = c.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

bool _isIdentStart(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a) ||
      c == '_';
}

bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);

// ─── Parser ─────────────────────────────────────────────────────────────────

class _Parser {
  final List<_Token> _tokens;
  final dynamic Function(String name) _resolveVariable;
  int _i = 0;

  _Parser(this._tokens, this._resolveVariable);

  _Token _peek() => _tokens[_i];
  bool get _atEnd => _peek().type == _TokenType.end;

  bool _match(_TokenType t) {
    if (_peek().type == t) {
      _i++;
      return true;
    }
    return false;
  }

  bool _matchIdent(String name) {
    final tok = _peek();
    if (tok.type == _TokenType.ident && tok.lexeme == name) {
      _i++;
      return true;
    }
    return false;
  }

  void expectEnd() {
    if (!_atEnd) {
      throw FormatException(
          'Unexpected token "${_peek().lexeme}" at position ${_peek().position}');
    }
  }

  dynamic parseExpression() => _parseOr();

  dynamic _parseOr() {
    var left = _parseAnd();
    while (_matchIdent('or')) {
      final right = _parseAnd();
      left = _toBool(left) || _toBool(right);
    }
    return left;
  }

  dynamic _parseAnd() {
    var left = _parseNot();
    while (_matchIdent('and')) {
      final right = _parseNot();
      left = _toBool(left) && _toBool(right);
    }
    return left;
  }

  dynamic _parseNot() {
    if (_matchIdent('not')) {
      return !_toBool(_parseNot());
    }
    return _parseComparison();
  }

  dynamic _parseComparison() {
    final left = _parseAdditive();
    final tok = _peek();
    switch (tok.type) {
      case _TokenType.eq:
      case _TokenType.neq:
      case _TokenType.lt:
      case _TokenType.gt:
      case _TokenType.le:
      case _TokenType.ge:
        _i++;
        return _compare(left, _parseAdditive(), tok.type);
      default:
        return left;
    }
  }

  dynamic _parseAdditive() {
    var left = _parseMultiplicative();
    while (true) {
      if (_match(_TokenType.plus)) {
        left = _add(left, _parseMultiplicative());
      } else if (_match(_TokenType.minus)) {
        left = _asNum(left) - _asNum(_parseMultiplicative());
      } else {
        break;
      }
    }
    return left;
  }

  dynamic _parseMultiplicative() {
    var left = _parseUnary();
    while (true) {
      if (_match(_TokenType.star)) {
        left = _asNum(left) * _asNum(_parseUnary());
      } else if (_match(_TokenType.slash)) {
        left = _asNum(left) / _asNum(_parseUnary());
      } else if (_match(_TokenType.percent)) {
        left = _asNum(left) % _asNum(_parseUnary());
      } else {
        break;
      }
    }
    return left;
  }

  dynamic _parseUnary() {
    if (_match(_TokenType.minus)) return -_asNum(_parseUnary());
    if (_match(_TokenType.plus)) return _asNum(_parseUnary());
    return _parsePrimary();
  }

  dynamic _parsePrimary() {
    final tok = _peek();
    switch (tok.type) {
      case _TokenType.number:
        _i++;
        return tok.literal;
      case _TokenType.string:
        _i++;
        return tok.literal;
      case _TokenType.variable:
        _i++;
        return _resolveVariable(tok.lexeme.substring(1));
      case _TokenType.ident:
        _i++;
        if (tok.lexeme == 'true') return true;
        if (tok.lexeme == 'false') return false;
        if (tok.lexeme == 'null') return null;
        // Unknown bareword — treat as a string for backwards compatibility.
        return tok.lexeme;
      case _TokenType.lparen:
        _i++;
        final value = parseExpression();
        if (!_match(_TokenType.rparen)) {
          throw FormatException('Expected ")" at position ${_peek().position}');
        }
        return value;
      default:
        throw FormatException(
            'Unexpected token "${tok.lexeme}" at position ${tok.position}');
    }
  }
}

// ─── Coercion and operators ────────────────────────────────────────────────

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty && v.toLowerCase() != 'false';
  return v != null;
}

num _asNum(dynamic v) {
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final parsed = num.tryParse(v);
    if (parsed != null) return parsed;
  }
  throw FormatException('Cannot coerce $v (${v.runtimeType}) to a number');
}

dynamic _add(dynamic left, dynamic right) {
  if (left is String || right is String) {
    return '$left$right';
  }
  return _asNum(left) + _asNum(right);
}

bool _compare(dynamic left, dynamic right, _TokenType op) {
  if (left is num && right is num) {
    switch (op) {
      case _TokenType.eq:
        return left == right;
      case _TokenType.neq:
        return left != right;
      case _TokenType.lt:
        return left < right;
      case _TokenType.gt:
        return left > right;
      case _TokenType.le:
        return left <= right;
      case _TokenType.ge:
        return left >= right;
      default:
        throw StateError('not a comparison op');
    }
  }
  if (left is bool && right is bool) {
    switch (op) {
      case _TokenType.eq:
        return left == right;
      case _TokenType.neq:
        return left != right;
      default:
        throw FormatException('Ordering comparison is not valid for booleans');
    }
  }
  if (left == null || right == null) {
    switch (op) {
      case _TokenType.eq:
        return left == right;
      case _TokenType.neq:
        return left != right;
      default:
        return false;
    }
  }
  final l = left.toString();
  final r = right.toString();
  switch (op) {
    case _TokenType.eq:
      return l == r;
    case _TokenType.neq:
      return l != r;
    case _TokenType.lt:
      return l.compareTo(r) < 0;
    case _TokenType.gt:
      return l.compareTo(r) > 0;
    case _TokenType.le:
      return l.compareTo(r) <= 0;
    case _TokenType.ge:
      return l.compareTo(r) >= 0;
    default:
      throw StateError('not a comparison op');
  }
}
