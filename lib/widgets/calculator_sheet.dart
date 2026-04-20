import 'package:flutter/material.dart';
import '../theme.dart';

class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key});

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expr    = '';
  String _display = '0';
  final List<({String expr, String result})> _history = [];

  double? _safeEval(String s) {
    if (!RegExp(r'^[\d+\-*/.%() ]+$').hasMatch(s)) return null;
    try {
      // Simple left-to-right evaluator using Dart's num parsing on each operation.
      // We do a minimal recursive descent to handle operator precedence.
      final v = _evalExpr(s.replaceAll(' ', ''));
      if (v == null || v.isNaN || v.isInfinite) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  double? _evalExpr(String s) {
    // Handle +/- (lowest precedence)
    int depth = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      final c = s[i];
      if (c == ')') depth++;
      if (c == '(') depth--;
      if (depth == 0 && (c == '+' || (c == '-' && i > 0))) {
        final left  = _evalExpr(s.substring(0, i));
        final right = _evalTerm(s.substring(i + 1));
        if (left == null || right == null) return null;
        return c == '+' ? left + right : left - right;
      }
    }
    return _evalTerm(s);
  }

  double? _evalTerm(String s) {
    int depth = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      final c = s[i];
      if (c == ')') depth++;
      if (c == '(') depth--;
      if (depth == 0 && (c == '*' || c == '/')) {
        final left  = _evalTerm(s.substring(0, i));
        final right = _evalFactor(s.substring(i + 1));
        if (left == null || right == null) return null;
        if (c == '/' && right == 0) return null;
        return c == '*' ? left * right : left / right;
      }
    }
    return _evalFactor(s);
  }

  double? _evalFactor(String s) {
    if (s.isEmpty) return null;
    if (s.startsWith('(') && s.endsWith(')')) {
      return _evalExpr(s.substring(1, s.length - 1));
    }
    if (s.startsWith('-')) {
      final v = _evalFactor(s.substring(1));
      return v != null ? -v : null;
    }
    // Handle % suffix
    if (s.endsWith('%')) {
      final v = double.tryParse(s.substring(0, s.length - 1));
      return v != null ? v / 100 : null;
    }
    return double.tryParse(s);
  }

  String _formatResult(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return double.parse(v.toStringAsFixed(8)).toString();
  }

  void _press(String k) {
    setState(() {
      if (k == 'C') {
        _expr    = '';
        _display = '0';
        return;
      }
      if (k == '⌫') {
        _expr = _expr.isEmpty ? '' : _expr.substring(0, _expr.length - 1);
        _display = _expr.isEmpty ? '0' : _expr;
        return;
      }
      if (k == '=') {
        final v = _safeEval(_expr);
        if (v == null) {
          _display = 'Error';
        } else {
          final res = _formatResult(v);
          _history.insert(0, (expr: _expr, result: res));
          if (_history.length > 4) _history.removeLast();
          _display = res;
          _expr    = res;
        }
        return;
      }
      if (_display == 'Error') _expr = '';
      _expr = _expr + k;
      final v = _safeEval(_expr);
      _display = v != null ? _formatResult(v) : _expr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(kSheetRadius),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CALCULATOR',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                    color: context.subColor,
                  )),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text('Close',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.subColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // History
          SizedBox(
            height: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _history.take(2).map((h) => Text(
                    '${h.expr} = ${h.result}',
                    style: TextStyle(fontSize: 12, color: context.muteColor),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  )).toList(),
            ),
          ),

          // Display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _expr.isEmpty ? ' ' : _expr,
                  style: TextStyle(fontSize: 14, color: context.subColor),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _display,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: _display == 'Error'
                        ? const Color(0xFFB91C1C)
                        : context.inkColor,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Keypad
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 64 / 64,
            children: [
              _Key('C',  kind: _KeyKind.fn, onPress: _press),
              _Key('()', kind: _KeyKind.fn, onPress: (k) {
                final opens  = _expr.split('(').length - 1;
                final closes = _expr.split(')').length - 1;
                _press(opens > closes ? ')' : '(');
              }),
              _Key('%',  kind: _KeyKind.fn, onPress: _press),
              _Key('÷',  kind: _KeyKind.op, onPress: (_) => _press('/')),
              _Key('7',  onPress: _press),
              _Key('8',  onPress: _press),
              _Key('9',  onPress: _press),
              _Key('×',  kind: _KeyKind.op, onPress: (_) => _press('*')),
              _Key('4',  onPress: _press),
              _Key('5',  onPress: _press),
              _Key('6',  onPress: _press),
              _Key('−',  kind: _KeyKind.op, onPress: (_) => _press('-')),
              _Key('1',  onPress: _press),
              _Key('2',  onPress: _press),
              _Key('3',  onPress: _press),
              _Key('+',  kind: _KeyKind.op, onPress: _press),
              _Key('0',  onPress: _press),
              _Key('.',  onPress: _press),
              _Key('⌫',  kind: _KeyKind.fn, onPress: _press),
              _Key('=',  kind: _KeyKind.eq, onPress: _press),
            ],
          ),
        ],
      ),
    );
  }
}

enum _KeyKind { num, op, fn, eq }

class _Key extends StatelessWidget {
  final String label;
  final _KeyKind kind;
  final void Function(String) onPress;

  const _Key(this.label, {this.kind = _KeyKind.num, required this.onPress});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (kind) {
      case _KeyKind.op:
        bg = context.surface2Color;
        fg = context.inkColor;
      case _KeyKind.fn:
        bg = Colors.transparent;
        fg = context.subColor;
      case _KeyKind.eq:
        bg = context.inkColor;
        fg = context.bgColor;
      case _KeyKind.num:
        bg = context.surfaceColor;
        fg = context.inkColor;
    }

    return GestureDetector(
      onTap: () => onPress(label),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kInputRadius),
          border: Border.all(color: context.borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}
