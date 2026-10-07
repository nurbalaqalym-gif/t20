import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Менің қосымшам',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F8A80),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3CC4B6),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Менің қосымшам'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Тапсырмалар'),
              Tab(text: 'Калькулятор'),
              Tab(text: 'Жазба'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [TodoTab(), CalcTab(), NoteTab()]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Тапсырмалар

class Task {
  Task(this.text, this.done);
  String text;
  bool done;
}

class TodoTab extends StatefulWidget {
  const TodoTab({super.key});

  @override
  State<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends State<TodoTab> with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  List<Task> _tasks = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('tasks') ?? [];
    setState(() {
      _tasks = raw.map((s) => Task(s.substring(2), s.startsWith('1'))).toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'tasks',
      _tasks.map((t) => '${t.done ? 1 : 0}|${t.text}').toList(),
    );
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _tasks.add(Task(text, false)));
    _controller.clear();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final left = _tasks.where((t) => !t.done).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 120,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Жаңа тапсырма жазыңыз',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _add, child: const Text('Қосу')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(
                    child: Text('Тапсырма жоқ. Бірінші тапсырманы қосыңыз.'),
                  )
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, i) {
                      final t = _tasks[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: t.done,
                          onChanged: (v) {
                            setState(() => t.done = v ?? false);
                            _save();
                          },
                        ),
                        title: Text(
                          t.text,
                          style: TextStyle(
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Өшіру',
                          onPressed: () {
                            setState(() => _tasks.removeAt(i));
                            _save();
                          },
                        ),
                      );
                    },
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Қалғаны: $left / ${_tasks.length}'),
              TextButton(
                onPressed: () {
                  setState(() => _tasks.removeWhere((t) => t.done));
                  _save();
                },
                child: const Text('Орындалғандарды өшіру'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Калькулятор

class CalcTab extends StatefulWidget {
  const CalcTab({super.key});

  @override
  State<CalcTab> createState() => _CalcTabState();
}

class _CalcTabState extends State<CalcTab> with AutomaticKeepAliveClientMixin {
  String _cur = '0';
  String? _prev;
  String? _op;
  bool _fresh = false;

  static const _rows = [
    ['C', '⌫', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['0', ',', '='],
  ];
  static const _ops = ['÷', '×', '−', '+'];

  @override
  bool get wantKeepAlive => true;

  String _fmt(double r) {
    if (!r.isFinite) return 'Қате';
    if (r == r.roundToDouble() && r.abs() < 1e15) return r.toInt().toString();
    return double.parse(r.toStringAsPrecision(12)).toString();
  }

  String _calc(String a, String b, String op) {
    final x = double.parse(a);
    final y = double.parse(b);
    switch (op) {
      case '+':
        return _fmt(x + y);
      case '−':
        return _fmt(x - y);
      case '×':
        return _fmt(x * y);
      default:
        return y == 0 ? 'Қате' : _fmt(x / y);
    }
  }

  void _press(String k) {
    if (_cur == 'Қате' && k != 'C') return;
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(k)) {
        _cur = (_cur == '0' || _fresh) ? k : _cur + k;
        _fresh = false;
      } else if (k == ',') {
        if (_fresh) {
          _cur = '0';
          _fresh = false;
        }
        if (!_cur.contains('.')) _cur += '.';
      } else if (k == 'C') {
        _cur = '0';
        _prev = null;
        _op = null;
        _fresh = false;
      } else if (k == '⌫') {
        _cur = _cur.length > 1 ? _cur.substring(0, _cur.length - 1) : '0';
      } else if (k == '%') {
        _cur = _fmt(double.parse(_cur) / 100);
      } else if (k == '=') {
        if (_op != null && _prev != null) {
          _cur = _calc(_prev!, _cur, _op!);
          _prev = null;
          _op = null;
          _fresh = true;
        }
      } else {
        if (_op != null && _prev != null && !_fresh) {
          _cur = _calc(_prev!, _cur, _op!);
        }
        _prev = _cur;
        _op = k;
        _fresh = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final history = (_prev != null && _op != null)
        ? '${_prev!.replaceAll('.', ',')} $_op'
        : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(history, style: TextStyle(color: cs.outline)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _cur.replaceAll('.', ','),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  for (final k in row)
                    Expanded(
                      flex: k == '0' ? 2 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _CalcKey(
                          label: k,
                          isOp: _ops.contains(k),
                          isEq: k == '=',
                          onTap: () => _press(k),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.isOp,
    required this.isEq,
    required this.onTap,
  });

  final String label;
  final bool isOp;
  final bool isEq;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isEq
        ? cs.primary
        : isOp
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;
    final fg = isEq
        ? cs.onPrimary
        : isOp
        ? cs.onPrimaryContainer
        : cs.onSurface;

    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- Жазба

class NoteTab extends StatefulWidget {
  const NoteTab({super.key});

  @override
  State<NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<NoteTab> with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _controller.text = prefs.getString('note') ?? '');
  }

  Future<void> _save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note', value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _save,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Мұнда жазба жазыңыз. Ол автоматты түрде сақталады.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_controller.text.length} таңба'),
              TextButton(
                onPressed: () {
                  _controller.clear();
                  _save('');
                },
                child: const Text('Тазалау'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
