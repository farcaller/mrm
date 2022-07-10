class Notifier {
  _Context? _context;

  _enter(String context) {
    if (_context == null) {
      _context = _Context(null, context);
    } else {
      final parent = _context!;
      final leaf = _Context(parent, context);
      parent.contexts.add(leaf);
      _context = leaf;
    }
  }

  _exit() {
    assert(_context != null);
    final parent = _context!.parent;
    if (parent == null) {
      _context!._print();
    }
    _context = parent;
  }

  context(String context, Function block) async {
    _enter(context);
    final r = block();
    if (r is Future) await r;
    _exit();
  }

  out(String msg) {
    _context!.issues.add(msg);
  }

  bool diff(String what, String oldValue, String newValue) {
    context(what, () {
      if (oldValue != newValue) {
        oldValue.split('\n').map((e) => '\x1B[31m- $e\x1B[0m').forEach(out);
        newValue.split('\n').map((e) => '\x1B[32m- $e\x1B[0m').forEach(out);
      }
    });
    return oldValue != newValue;
  }

  cross(String msg) {
    out('❌ $msg');
  }

  plus(String msg) {
    out('➕ $msg');
  }
}

class _Context {
  final _Context? parent;
  final String name;
  final List<String> issues = [];
  final List<_Context> contexts = [];

  _Context(this.parent, this.name);

  int get _depth {
    int depth = 0;
    var p = parent;
    while (p != null) {
      depth++;
      p = p.parent;
    }
    return depth;
  }

  String get _offset => ('  ' * _depth);

  _print() {
    if (issues.isEmpty && contexts.isEmpty) {
      _printOffseted('$name: ✔️');
    } else {
      _printOffseted('$name:');
      for (final m in issues) {
        m.split('\n').map((line) => '  $line').forEach(_printOffseted);
      }
      for (final c in contexts) {
        c._print();
      }
    }
  }

  _printOffseted(String msg) {
    print('$_offset$msg');
  }
}
