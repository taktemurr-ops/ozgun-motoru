import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// =================================================================== Kilim Dokuma

List<int> lineRuns(Iterable<bool> line) {
  final out = <int>[];
  var c = 0;
  for (final v in line) {
    if (v) {
      c++;
    } else if (c > 0) {
      out.add(c);
      c = 0;
    }
  }
  if (c > 0) out.add(c);
  return out;
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class KilimPuzzle extends OPuzzle {
  final int n;
  final List<bool> sol;
  final List<List<int>> rows;
  final List<List<int>> cols;
  const KilimPuzzle(this.n, this.sol, this.rows, this.cols);

  List<int> rowRuns(List<bool> g, int y) => lineRuns([for (var x = 0; x < n; x++) g[y * n + x]]);
  List<int> colRuns(List<bool> g, int x) => lineRuns([for (var y = 0; y < n; y++) g[y * n + x]]);

  bool solved(List<bool> g) {
    for (var i = 0; i < n; i++) {
      if (!_sameList(rowRuns(g, i), rows[i]) || !_sameList(colRuns(g, i), cols[i])) return false;
    }
    return true;
  }

  /// Kilim motifi: merkezden uzaklığa göre renk bandı.
  int tint(int x, int y) {
    final c = (n - 1) / 2;
    return (((x - c).abs() + (y - c).abs()) / 1.5).floor() % 4;
  }
}

class KilimKind extends OzgunKind {
  @override
  String get id => 'kilim';
  const KilimKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 5 + (d - 1) * 5 ~/ 9;
    final both = d >= 6;
    final g = List<bool>.filled(n * n, false);
    final half = (n + 1) ~/ 2;
    final hy = both ? half : n;
    final p = 0.5 + r.nextDouble() * 0.15;
    for (var y = 0; y < hy; y++) {
      for (var x = 0; x < half; x++) {
        final v = r.chance(p);
        for (final yy in both ? [y, n - 1 - y] : [y]) {
          g[yy * n + x] = v;
          g[yy * n + n - 1 - x] = v;
        }
      }
    }
    final filled = g.where((v) => v).length;
    if (filled < n * n * 0.35 || filled > n * n * 0.78) return null;
    final pz = KilimPuzzle(n, g, const [], const []);
    final rows = [for (var y = 0; y < n; y++) pz.rowRuns(g, y)];
    final cols = [for (var x = 0; x < n; x++) pz.colRuns(g, x)];
    if (rows.any((e) => e.isEmpty) || cols.any((e) => e.isEmpty)) return null;
    return KilimPuzzle(n, g, rows, cols);
  }

  @override
  bool check(OPuzzle p) => p is KilimPuzzle && p.rows.length == p.n && p.solved(p.sol);

  @override
  Widget build(OzgunPlay play) => _KilimView(play: play);
}

class _KilimView extends StatefulWidget {
  final OzgunPlay play;
  const _KilimView({required this.play});
  @override
  State<_KilimView> createState() => _KilimViewState();
}

class _KilimViewState extends State<_KilimView> with Clock {
  late final KilimPuzzle p = widget.play.puzzle as KilimPuzzle;
  late List<int> s = List<int>.filled(p.n * p.n, 0); // 0 boş, 1 dolu, 2 çarpı
  final List<List<int>> hist = [];
  bool crossMode = false;
  int hints = 0;
  int? dragValue;
  late final int lw = p.rows.map((e) => e.length).reduce(math.max);
  late final int th = p.cols.map((e) => e.length).reduce(math.max);

  @override
  void initState() {
    super.initState();
    startClock();
  }

  List<bool> get grid => [for (final v in s) v == 1];

  int? cellAt(Offset o) {
    final x = (o.dx - lw * 0.7).floor(), y = (o.dy - th * 0.7).floor();
    if (x < 0 || y < 0 || x >= p.n || y >= p.n) return null;
    return y * p.n + x;
  }

  void setCell(int i, int v) {
    if (ended || s[i] == v) return;
    setState(() => s[i] = v);
  }

  void _check() {
    if (ended || !p.solved(grid)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: 3 - hints, seconds: seconds, hints: hints, score: 1000 - seconds));
  }

  void _down(Offset o) {
    final i = cellAt(o);
    if (i == null || ended) return;
    hist.add(List.of(s));
    final want = crossMode ? 2 : 1;
    dragValue = s[i] == want ? 0 : want;
    setCell(i, dragValue!);
    widget.play.sfx(Sfx.tap);
  }

  void _move(Offset o) {
    final i = cellAt(o), v = dragValue;
    if (i == null || v == null) return;
    setCell(i, v);
  }

  void _end() {
    dragValue = null;
    _check();
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < s.length; i++) {
      final want = p.sol[i] ? 1 : 2;
      final wrong = (s[i] == 1) != p.sol[i];
      if (wrong || s[i] == 0) {
        hints++;
        hist.add(List.of(s));
        setState(() => s[i] = want);
        _check();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final ox = lw * 0.7, oy = th * 0.7;
    final g = grid;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: clock(),
        onUndo: hist.isEmpty ? null : () => setState(() => s = hist.removeLast()),
        onReset: () => setState(() {
          hist.add(List.of(s));
          s = List<int>.filled(p.n * p.n, 0);
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: ox + p.n + 0.2,
        h: oy + p.n + 0.2,
        onPanStart: _down,
        onPanUpdate: _move,
        onPanEnd: _end,
        onTap: (o) {
          _down(o);
          _end();
        },
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox - 0.1, oy - 0.1, p.n + 0.2, p.n + 0.2), const Radius.circular(0.2)),
              fill(const Color(0xFFF3E7D3)));
          for (var y = 0; y < p.n; y++) {
            final ok = _sameList(p.rowRuns(g, y), p.rows[y]);
            final cl = p.rows[y];
            for (var k = 0; k < cl.length; k++) {
              drawLabel(c, '${cl[k]}', Offset(ox - (cl.length - k) * 0.7 + 0.3, oy + y + 0.5), 0.5, ok ? OColors.line : OColors.ink);
            }
          }
          for (var x = 0; x < p.n; x++) {
            final ok = _sameList(p.colRuns(g, x), p.cols[x]);
            final cl = p.cols[x];
            for (var k = 0; k < cl.length; k++) {
              drawLabel(c, '${cl[k]}', Offset(ox + x + 0.5, oy - (cl.length - k) * 0.7 + 0.32), 0.5, ok ? OColors.line : OColors.ink);
            }
          }
          for (var y = 0; y < p.n; y++) {
            for (var x = 0; x < p.n; x++) {
              final r = Rect.fromLTWH(ox + x + 0.04, oy + y + 0.04, 0.92, 0.92);
              final v = s[y * p.n + x];
              if (v == 1) {
                final col = OColors.warm[p.tint(x, y)];
                c.drawRect(r, fill(col));
                final m = r.center;
                final dia = Path()
                  ..moveTo(m.dx, m.dy - 0.3)
                  ..lineTo(m.dx + 0.3, m.dy)
                  ..lineTo(m.dx, m.dy + 0.3)
                  ..lineTo(m.dx - 0.3, m.dy)
                  ..close();
                c.drawPath(dia, fill(Color.lerp(col, Colors.white, 0.45)!));
              } else {
                c.drawRect(r, fill(Colors.white));
                if (v == 2) {
                  c.drawLine(r.topLeft + const Offset(0.3, 0.3), r.bottomRight - const Offset(0.3, 0.3), stroke(OColors.line, 0.07));
                  c.drawLine(r.topRight + const Offset(-0.3, 0.3), r.bottomLeft + const Offset(0.3, -0.3), stroke(OColors.line, 0.07));
                }
              }
            }
          }
          final half = p.n / 2;
          c.drawLine(Offset(ox + half, oy), Offset(ox + half, oy + p.n), stroke(OColors.gold.withValues(alpha: 0.5), 0.04));
        },
      ),
      bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OChip(
          selected: !crossMode,
          onTap: () => setState(() => crossMode = false),
          child: Container(width: 26, height: 26, color: OColors.warm[0]),
        ),
        const SizedBox(width: 12),
        OChip(
          selected: crossMode,
          tooltip: ot(lang, 'mark'),
          onTap: () => setState(() => crossMode = true),
          child: const Icon(Icons.close, size: 26),
        ),
      ]),
    );
  }
}

// =================================================================== Çini Ustası

/// Kenarları renkli kareler; [rot] saat yönünde çeyrek dönüş sayısı.
class CiniPuzzle extends OPuzzle {
  final int n;
  final List<List<int>> edges; // [K, D, G, B] çözülmüş hali
  final List<int> rot;
  const CiniPuzzle(this.n, this.edges, this.rot);

  static List<int> turned(List<int> e, int r) => [for (var d = 0; d < 4; d++) e[(d - r) % 4]];

  bool solvedWith(List<int> rots) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final e = turned(edges[y * n + x], rots[y * n + x]);
        if (y == 0 && e[0] != 0) return false;
        if (x == 0 && e[3] != 0) return false;
        if (y == n - 1 && e[2] != 0) return false;
        if (x == n - 1 && e[1] != 0) return false;
        if (x < n - 1 && e[1] != turned(edges[y * n + x + 1], rots[y * n + x + 1])[3]) return false;
        if (y < n - 1 && e[2] != turned(edges[(y + 1) * n + x], rots[(y + 1) * n + x])[0]) return false;
      }
    }
    return true;
  }

  /// Taşın çözüm görünümüne en az kaç dönüşle geldiği.
  int stepsToSolved(int i, int from) {
    for (var k = 0; k < 4; k++) {
      if (_sameList(turned(edges[i], (from + k) % 4), edges[i])) return k;
    }
    return 0;
  }
}

class CiniKind extends OzgunKind {
  @override
  String get id => 'cini';
  const CiniKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 3 + (d - 1) ~/ 3;
    final k = 2 + (d >= 4 ? 1 : 0) + (d >= 8 ? 1 : 0);
    final h = List.generate(n, (_) => List<int>.filled(n, 0));
    final v = List.generate(n, (_) => List<int>.filled(n, 0));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n - 1; x++) {
        if (x <= n - 2 - x) {
          h[y][x] = 1 + r.nextInt(k);
          h[y][n - 2 - x] = h[y][x];
        }
      }
    }
    for (var y = 0; y < n - 1; y++) {
      for (var x = 0; x < n; x++) {
        if (x <= n - 1 - x) {
          v[y][x] = 1 + r.nextInt(k);
          v[y][n - 1 - x] = v[y][x];
        }
      }
    }
    final edges = <List<int>>[];
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        edges.add([
          y == 0 ? 0 : v[y - 1][x],
          x == n - 1 ? 0 : h[y][x],
          y == n - 1 ? 0 : v[y][x],
          x == 0 ? 0 : h[y][x - 1],
        ]);
      }
    }
    final rot = [for (var i = 0; i < n * n; i++) r.nextInt(4)];
    final p = CiniPuzzle(n, edges, rot);
    var off = 0;
    for (var i = 0; i < n * n; i++) {
      if (p.stepsToSolved(i, rot[i]) > 0) off++;
    }
    if (off < n * n ~/ 2 || p.solvedWith(rot)) return null;
    return p;
  }

  @override
  bool check(OPuzzle p) => p is CiniPuzzle && p.solvedWith(List<int>.filled(p.n * p.n, 0)) && !p.solvedWith(p.rot);

  @override
  Widget build(OzgunPlay play) => _CiniView(play: play);
}

const List<Color> _iznik = [Color(0xFFF7F3EA), Color(0xFF1F4E9A), Color(0xFF2A9D9A), Color(0xFFC8453B), Color(0xFF4F8A4B)];

class _CiniView extends StatefulWidget {
  final OzgunPlay play;
  const _CiniView({required this.play});
  @override
  State<_CiniView> createState() => _CiniViewState();
}

class _CiniViewState extends State<_CiniView> with Clock {
  late final CiniPuzzle p = widget.play.puzzle as CiniPuzzle;
  late List<int> rot = List.of(p.rot);
  late final int par = [for (var i = 0; i < p.n * p.n; i++) p.stepsToSolved(i, p.rot[i])].fold(0, (a, b) => a + b);
  final List<List<int>> hist = [];
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _turn(int i) {
    if (ended) return;
    hist.add(List.of(rot));
    setState(() {
      rot[i] = (rot[i] + 1) % 4;
      moves++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    if (ended || !p.solvedWith(rot)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: starsByMoves(moves, par, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 5));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < rot.length; i++) {
      final k = p.stepsToSolved(i, rot[i]);
      if (k > 0) {
        hints++;
        hist.add(List.of(rot));
        setState(() => rot[i] = (rot[i] + k) % 4);
        _check();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${ot(widget.play.lang, 'moves')}: $moves',
        status: clock(),
        onUndo: hist.isEmpty ? null : () => setState(() => rot = hist.removeLast()),
        onReset: () => setState(() {
          hist.add(List.of(rot));
          rot = List.of(p.rot);
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: n + 0.4,
        h: n + 0.4,
        onTap: (o) {
          final x = (o.dx - 0.2).floor(), y = (o.dy - 0.2).floor();
          if (x >= 0 && y >= 0 && x < n && y < n) _turn(y * n + x);
        },
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, n + 0.4, n + 0.4), const Radius.circular(0.25)), fill(const Color(0xFF16365F)));
          for (var y = 0; y < n; y++) {
            for (var x = 0; x < n; x++) {
              final e = CiniPuzzle.turned(p.edges[y * n + x], rot[y * n + x]);
              final o = Offset(0.2 + x, 0.2 + y);
              final m = o + const Offset(0.5, 0.5);
              final corners = [o, o + const Offset(1, 0), o + const Offset(1, 1), o + const Offset(0, 1)];
              for (var dd = 0; dd < 4; dd++) {
                final tri = Path()
                  ..moveTo(corners[dd].dx, corners[dd].dy)
                  ..lineTo(corners[(dd + 1) % 4].dx, corners[(dd + 1) % 4].dy)
                  ..lineTo(m.dx, m.dy)
                  ..close();
                c.drawPath(tri, fill(_iznik[e[dd]]));
              }
              c.drawCircle(m, 0.16, fill(const Color(0xFFF7F3EA)));
              c.drawCircle(m, 0.16, stroke(const Color(0xFF1F4E9A), 0.04));
              c.drawRect(Rect.fromLTWH(o.dx, o.dy, 1, 1), stroke(const Color(0x33000000), 0.02));
            }
          }
        },
      ),
    );
  }
}

// =================================================================== Ebru Atölyesi

class EbruPuzzle extends OPuzzle {
  final int n;
  final int k;
  final List<int> start;
  final List<int> target;
  final List<List<int>> ops; // [0 satır / 1 sütun, sıra, yön +1/-1]
  const EbruPuzzle(this.n, this.k, this.start, this.target, this.ops);

  static List<int> apply(int n, List<int> g, List<int> op) {
    final out = List.of(g);
    final i = op[1], dir = op[2];
    for (var j = 0; j < n; j++) {
      final from = (j - dir) % n;
      if (op[0] == 0) {
        out[i * n + j] = g[i * n + from];
      } else {
        out[j * n + i] = g[from * n + i];
      }
    }
    return out;
  }
}

class EbruKind extends OzgunKind {
  @override
  String get id => 'ebru';
  const EbruKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 4 + d ~/ 4;
    final k = 3 + d ~/ 4;
    final start = [for (var y = 0; y < n; y++) for (var x = 0; x < n; x++) (x + 2 * y) % k];
    final m = 2 + d ~/ 2;
    var g = start;
    final ops = <List<int>>[];
    for (var i = 0; i < m; i++) {
      List<int> op;
      var guard = 0;
      do {
        op = [r.nextInt(2), r.nextInt(n), r.chance(0.5) ? 1 : -1];
      } while (guard++ < 20 && ops.isNotEmpty && ops.last[0] == op[0] && ops.last[1] == op[1] && ops.last[2] == -op[2]);
      ops.add(op);
      g = EbruPuzzle.apply(n, g, op);
    }
    var diff = 0;
    for (var i = 0; i < g.length; i++) {
      if (g[i] != start[i]) diff++;
    }
    if (diff < n) return null;
    return EbruPuzzle(n, k, start, g, ops);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! EbruPuzzle) return false;
    var g = p.start;
    for (final op in p.ops) {
      g = EbruPuzzle.apply(p.n, g, op);
    }
    return _sameList(g, p.target) && !_sameList(p.start, p.target);
  }

  @override
  Widget build(OzgunPlay play) => _EbruView(play: play);
}

const List<Color> _ebruCols = [Color(0xFF2E5E8C), Color(0xFFD9A441), Color(0xFFB23A48), Color(0xFF3A8D8C), Color(0xFFF2E8D5), Color(0xFF7A4E7E)];

void _paintEbru(Canvas c, int n, List<int> g, Offset o, double s) {
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, n * s, n * s), Radius.circular(s * 0.3)), fill(const Color(0xFFEDE3CF)));
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final col = _ebruCols[g[y * n + x] % _ebruCols.length];
      final m = o + Offset((x + 0.5) * s, (y + 0.5) * s);
      c.drawCircle(m, s * 0.46, fill(col));
      c.drawCircle(m + Offset(-s * 0.1, -s * 0.1), s * 0.2, fill(Color.lerp(col, Colors.white, 0.35)!));
      final wave = Path()..moveTo(m.dx - s * 0.32, m.dy + s * 0.12);
      wave.quadraticBezierTo(m.dx - s * 0.1, m.dy - s * 0.12, m.dx + s * 0.05, m.dy + s * 0.1);
      wave.quadraticBezierTo(m.dx + s * 0.2, m.dy + s * 0.28, m.dx + s * 0.32, m.dy + s * 0.05);
      c.drawPath(wave, stroke(Color.lerp(col, Colors.black, 0.25)!, s * 0.05));
    }
  }
}

class _EbruView extends StatefulWidget {
  final OzgunPlay play;
  const _EbruView({required this.play});
  @override
  State<_EbruView> createState() => _EbruViewState();
}

class _EbruViewState extends State<_EbruView> with Clock {
  late final EbruPuzzle p = widget.play.puzzle as EbruPuzzle;
  late List<int> g = List.of(p.start);
  final List<List<int>> hist = [];
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _op(List<int> op) {
    if (ended) return;
    hist.add(g);
    setState(() {
      g = EbruPuzzle.apply(p.n, g, op);
      moves++;
    });
    widget.play.sfx(Sfx.place);
    _check();
  }

  void _check() {
    if (ended || !_sameList(g, p.target)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: starsByMoves(moves, p.ops.length, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 8));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    hints++;
    final steps = math.min(p.ops.length, hints);
    var x = p.start;
    for (var i = 0; i < steps; i++) {
      x = EbruPuzzle.apply(p.n, x, p.ops[i]);
    }
    hist.add(g);
    setState(() => g = x);
    _check();
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${ot(widget.play.lang, 'moves')}: $moves',
        status: clock(),
        onUndo: hist.isEmpty ? null : () => setState(() => g = hist.removeLast()),
        onReset: () => setState(() {
          hist.add(g);
          g = List.of(p.start);
        }),
        onHint: _hint,
      ),
      top: SizedBox(
        height: 96,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ot(widget.play.lang, 'target'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          SizedBox(width: 96, height: 96, child: TapCanvas(w: n.toDouble(), h: n.toDouble(), paint: (c) => _paintEbru(c, n, p.target, Offset.zero, 1))),
        ]),
      ),
      board: TapCanvas(
        w: n + 2.0,
        h: n + 2.0,
        onTap: (o) {
          final x = (o.dx - 1).floor(), y = (o.dy - 1).floor();
          if (o.dx < 1 && y >= 0 && y < n) _op([0, y, -1]);
          if (o.dx > n + 1 && y >= 0 && y < n) _op([0, y, 1]);
          if (o.dy < 1 && x >= 0 && x < n) _op([1, x, -1]);
          if (o.dy > n + 1 && x >= 0 && x < n) _op([1, x, 1]);
        },
        paint: (c) {
          _paintEbru(c, n, g, const Offset(1, 1), 1);
          final arrow = fill(OColors.ink.withValues(alpha: 0.55));
          void tri(Offset m, int dir) {
            final a = dir * math.pi / 2;
            Offset pt(double dx, double dy) => m + Offset(dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a));
            final path = Path()
              ..moveTo(pt(0.25, 0).dx, pt(0.25, 0).dy)
              ..lineTo(pt(-0.18, -0.22).dx, pt(-0.18, -0.22).dy)
              ..lineTo(pt(-0.18, 0.22).dx, pt(-0.18, 0.22).dy)
              ..close();
            c.drawPath(path, arrow);
          }

          for (var i = 0; i < n; i++) {
            tri(Offset(0.5, 1.5 + i), 2);
            tri(Offset(n + 1.5, 1.5 + i), 0);
            tri(Offset(1.5 + i, 0.5), 3);
            tri(Offset(1.5 + i, n + 1.5), 1);
          }
        },
      ),
    );
  }
}

// =================================================================== Gölge Perdesi

const List<List<List<int>>> kPentominoes = [
  [[1, 0], [2, 0], [0, 1], [1, 1], [1, 2]], // F
  [[0, 0], [0, 1], [0, 2], [0, 3], [1, 3]], // L
  [[1, 0], [1, 1], [0, 2], [1, 2], [0, 3]], // N
  [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2]], // P
  [[0, 0], [1, 0], [2, 0], [1, 1], [1, 2]], // T
  [[0, 0], [2, 0], [0, 1], [1, 1], [2, 1]], // U
  [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]], // V
  [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]], // W
  [[1, 0], [0, 1], [1, 1], [1, 2], [1, 3]], // Y
  [[0, 0], [1, 0], [1, 1], [1, 2], [2, 2]], // Z
];

/// Şekli [o] yönüne çevirir: o % 4 saat yönünde çeyrek dönüş, o >= 4 aynalama.
List<List<int>> orientCells(List<List<int>> cells, int o) {
  var pts = [for (final c in cells) [o >= 4 ? -c[0] : c[0], c[1]]];
  for (var k = 0; k < o % 4; k++) {
    pts = [for (final c in pts) [-c[1], c[0]]];
  }
  final mx = pts.map((e) => e[0]).reduce(math.min), my = pts.map((e) => e[1]).reduce(math.min);
  final out = [for (final c in pts) [c[0] - mx, c[1] - my]];
  out.sort((a, b) => a[0] != b[0] ? a[0] - b[0] : a[1] - b[1]);
  return out;
}

String cellKey(List<List<int>> cells) => cells.map((e) => '${e[0]},${e[1]}').join(';');

class GolgePuzzle extends OPuzzle {
  final List<int> shapes; // her yuvanın şekli
  final List<int> target; // yuvadaki gölgenin yönü
  final List<int> startOri; // tepsideki parçanın başlangıç yönü (yuva sırasına göre)
  final List<int> tray; // tepsideki sıra → yuva
  final bool flips;
  const GolgePuzzle(this.shapes, this.target, this.startOri, this.tray, this.flips);

  bool fits(int slot, int ori) => cellKey(orientCells(kPentominoes[shapes[slot]], ori)) == cellKey(orientCells(kPentominoes[shapes[slot]], target[slot]));
}

class GolgeKind extends OzgunKind {
  @override
  String get id => 'golge';
  const GolgeKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final m = 2 + d ~/ 3;
    final flips = d >= 5;
    final ids = [for (var i = 0; i < kPentominoes.length; i++) i];
    r.shuffle(ids);
    final shapes = ids.take(m).toList();
    final target = [for (var i = 0; i < m; i++) r.nextInt(flips ? 8 : 4)];
    final start = <int>[];
    for (var i = 0; i < m; i++) {
      final want = cellKey(orientCells(kPentominoes[shapes[i]], target[i]));
      var o = 0;
      var guard = 0;
      do {
        o = r.nextInt(flips ? 8 : 4);
      } while (guard++ < 30 && cellKey(orientCells(kPentominoes[shapes[i]], o)) == want);
      if (cellKey(orientCells(kPentominoes[shapes[i]], o)) == want) return null;
      start.add(o);
    }
    final tray = [for (var i = 0; i < m; i++) i];
    r.shuffle(tray);
    return GolgePuzzle(shapes, target, start, tray, flips);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! GolgePuzzle) return false;
    for (var i = 0; i < p.shapes.length; i++) {
      if (!p.fits(i, p.target[i]) || p.fits(i, p.startOri[i])) return false;
    }
    return p.shapes.toSet().length == p.shapes.length;
  }

  @override
  Widget build(OzgunPlay play) => _GolgeView(play: play);
}

class _GolgeView extends StatefulWidget {
  final OzgunPlay play;
  const _GolgeView({required this.play});
  @override
  State<_GolgeView> createState() => _GolgeViewState();
}

class _GolgeViewState extends State<_GolgeView> with Clock {
  late final GolgePuzzle p = widget.play.puzzle as GolgePuzzle;
  late final int m = p.shapes.length;
  late List<int> ori = List.of(p.startOri); // parça (yuva kimliği) → yön
  late List<int> placed = List<int>.filled(m, -1); // yuva → parça
  int? sel;
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  int slotOf(int piece) => placed.indexOf(piece);

  void _tap(Offset o) {
    if (ended) return;
    final col = (o.dx / 6).floor();
    if (col < 0 || col >= m) return;
    if (o.dy < 6.5) {
      // Perde: seçili parçayı bu yuvaya koy ya da yuvadaki parçayı seç.
      final s = sel;
      if (s != null) {
        final old = slotOf(s);
        if (old >= 0) placed[old] = -1;
        final prev = placed[col];
        placed[col] = s;
        if (prev >= 0 && old >= 0) placed[old] = prev;
        setState(() {
          sel = null;
          moves++;
        });
        widget.play.sfx(Sfx.place);
        _check();
      } else if (placed[col] >= 0) {
        setState(() => sel = placed[col]);
      }
    } else {
      final piece = p.tray[col];
      setState(() {
        if (sel == piece) {
          ori[piece] = p.flips ? ((ori[piece] ~/ 4) * 4 + (ori[piece] + 1) % 4) : (ori[piece] + 1) % 4;
          moves++;
          widget.play.sfx(Sfx.tap);
        } else {
          sel = piece;
        }
      });
      _check();
    }
  }

  void _rotateSel() {
    final s = sel;
    if (s == null || ended) return;
    setState(() {
      ori[s] = (ori[s] ~/ 4) * 4 + (ori[s] + 1) % 4;
      moves++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _flipSel() {
    final s = sel;
    if (s == null || ended) return;
    setState(() {
      ori[s] = (ori[s] + 4) % 8;
      moves++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    for (var i = 0; i < m; i++) {
      final pc = placed[i];
      if (pc != i || !p.fits(i, ori[pc])) return;
    }
    if (ended) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(800, () => widget.play.win(stars: starsByMoves(moves, m * 3, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 6));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < m; i++) {
      if (placed[i] != i || !p.fits(i, ori[i])) {
        hints++;
        final old = slotOf(i);
        if (old >= 0) placed[old] = -1;
        setState(() {
          placed[i] = i;
          ori[i] = p.target[i];
          sel = null;
        });
        _check();
        return;
      }
    }
  }

  void _shape(Canvas c, int piece, int o, Offset at, double s, Paint paint, {bool outline = false}) {
    final cells = orientCells(kPentominoes[p.shapes[piece]], o);
    final w = cells.map((e) => e[0]).reduce(math.max) + 1, h = cells.map((e) => e[1]).reduce(math.max) + 1;
    final base = at - Offset(w * s / 2, h * s / 2);
    for (final cc in cells) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(base.dx + cc[0] * s, base.dy + cc[1] * s, s, s), Radius.circular(s * 0.18));
      c.drawRRect(r, paint);
      if (outline) c.drawRRect(r, stroke(const Color(0x55000000), s * 0.05));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ot(lang, 'moves')}: $moves',
        status: clock(),
        onReset: () => setState(() {
          ori = List.of(p.startOri);
          placed = List<int>.filled(m, -1);
          sel = null;
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: m * 6.0,
        h: 13,
        onTap: _tap,
        paint: (c) {
          final curtain = Rect.fromLTWH(0.2, 0.2, m * 6 - 0.4, 6.1);
          c.drawRRect(RRect.fromRectAndRadius(curtain, const Radius.circular(0.4)), fill(const Color(0xFFF4DFB0)));
          c.drawRRect(RRect.fromRectAndRadius(curtain, const Radius.circular(0.4)), stroke(const Color(0xFF8B5A2B), 0.2));
          for (var i = 0; i < m; i++) {
            final mid = Offset(i * 6 + 3, 3.25);
            final pc = placed[i];
            if (pc >= 0) {
              _shape(c, i, p.target[i], mid, 0.9, fill(const Color(0x33000000)));
              _shape(c, pc, ori[pc], mid, 0.9, fill(OColors.warm[pc % OColors.warm.length].withValues(alpha: 0.85)), outline: true);
              if (sel == pc) c.drawCircle(mid, 2.9, stroke(OColors.accent, 0.1));
            } else {
              _shape(c, i, p.target[i], mid, 0.9, fill(const Color(0xDD2B1D14)));
            }
          }
          for (var j = 0; j < m; j++) {
            final piece = p.tray[j];
            final mid = Offset(j * 6 + 3, 10);
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: mid, width: 5.6, height: 5.6), const Radius.circular(0.5)),
                fill(sel == piece ? const Color(0x333E6FB0) : const Color(0x14000000)));
            if (slotOf(piece) < 0) {
              _shape(c, piece, ori[piece], mid, 0.9, fill(OColors.warm[piece % OColors.warm.length]), outline: true);
            }
          }
        },
      ),
      bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OChip(onTap: sel == null ? null : _rotateSel, child: const Icon(Icons.rotate_right, size: 28)),
        if (p.flips) ...[
          const SizedBox(width: 12),
          OChip(tooltip: ot(lang, 'flip'), onTap: sel == null ? null : _flipSel, child: const Icon(Icons.flip, size: 28)),
        ],
      ]),
    );
  }
}

// =================================================================== Kâğıt Katlama

/// Kâğıt katmanı: ön yüz rengi ve hangi yüzün yukarıda olduğu.
class Ply {
  final int color;
  final bool up;
  const Ply(this.color, this.up);
}

typedef Paper = Map<int, List<Ply>>;

int pk(int x, int y) => (x + 64) * 256 + (y + 64);
int px(int k) => k ~/ 256 - 64;
int py(int k) => k % 256 - 64;

/// [vertical] doğrusu x = line (ya da y = line); [low] true ise küçük taraf katlanır.
Paper foldPaper(Paper p, bool vertical, int line, bool low) {
  final out = <int, List<Ply>>{};
  final moving = <int, List<Ply>>{};
  p.forEach((k, v) {
    final c = vertical ? px(k) : py(k);
    final isLow = c < line;
    if (isLow == low) {
      moving[k] = v;
    } else {
      out[k] = List.of(v);
    }
  });
  moving.forEach((k, v) {
    final x = px(k), y = py(k);
    final nk = vertical ? pk(2 * line - 1 - x, y) : pk(x, 2 * line - 1 - y);
    final stack = out.putIfAbsent(nk, () => <Ply>[]);
    for (final ply in v.reversed) {
      stack.add(Ply(ply.color, !ply.up));
    }
  });
  return out;
}

/// Görünür biçim: konumlar 0'dan başlar, değer üst katmanın görünen rengi (-1 arka yüz).
Map<int, int> paperLook(Paper p) {
  if (p.isEmpty) return const {};
  final mx = p.keys.map(px).reduce(math.min), my = p.keys.map(py).reduce(math.min);
  return {for (final e in p.entries) pk(px(e.key) - mx, py(e.key) - my): e.value.last.up ? e.value.last.color : -1};
}

bool sameLook(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

List<int> bbox(Iterable<int> keys) {
  final xs = keys.map(px), ys = keys.map(py);
  return [xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max)];
}

class KagitPuzzle extends OPuzzle {
  final int w, h;
  final List<int> pattern;
  final List<List<int>> folds; // [dikey 1/0, çizgi, küçük taraf 1/0]
  const KagitPuzzle(this.w, this.h, this.pattern, this.folds);

  Paper start() => {for (var y = 0; y < h; y++) for (var x = 0; x < w; x++) pk(x, y): [Ply(pattern[y * w + x], true)]};

  Paper run(Paper p, Iterable<List<int>> fs) {
    var q = p;
    for (final f in fs) {
      q = foldPaper(q, f[0] == 1, f[1], f[2] == 1);
    }
    return q;
  }

  Map<int, int> get target => paperLook(run(start(), folds));
}

class KagitKind extends OzgunKind {
  @override
  String get id => 'kagit';
  const KagitKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final w = 4 + (d >= 4 ? 1 : 0) + (d >= 8 ? 1 : 0);
    final h = 4 + (d >= 6 ? 1 : 0);
    final pat = <int>[];
    final style = r.nextInt(3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        pat.add(switch (style) { 0 => (x + y) % 2, 1 => (x ~/ 2 + y) % 3, _ => (x * y + x) % 3 });
      }
    }
    final pz = KagitPuzzle(w, h, pat, const []);
    var paper = pz.start();
    final folds = <List<int>>[];
    final m = 1 + (d - 1) ~/ 3;
    for (var i = 0; i < m; i++) {
      final b = bbox(paper.keys);
      final vertical = b[2] > b[0] && (b[3] == b[1] || r.chance(0.5));
      final lo = vertical ? b[0] : b[1], hi = vertical ? b[2] : b[3];
      if (hi <= lo) return null;
      final line = r.range(lo + 1, hi);
      final f = [vertical ? 1 : 0, line, r.chance(0.5) ? 1 : 0];
      folds.add(f);
      paper = foldPaper(paper, vertical, line, f[2] == 1);
    }
    final p = KagitPuzzle(w, h, pat, folds);
    if (p.target.length >= w * h) return null;
    return p;
  }

  @override
  bool check(OPuzzle p) => p is KagitPuzzle && p.folds.isNotEmpty && p.target.length < p.w * p.h;

  @override
  Widget build(OzgunPlay play) => _KagitView(play: play);
}

const List<Color> _paperCols = [Color(0xFFE07A5F), Color(0xFF3D85C6), Color(0xFF81B29A)];
const Color _paperBack = Color(0xFFF2E8D5);

void _paintLook(Canvas c, Map<int, int> look, Offset o, double s) {
  for (final e in look.entries) {
    final r = Rect.fromLTWH(o.dx + px(e.key) * s, o.dy + py(e.key) * s, s, s);
    c.drawRect(r, fill(e.value < 0 ? _paperBack : _paperCols[e.value % 3]));
    c.drawRect(r, stroke(const Color(0x33000000), s * 0.03));
  }
}

class _KagitView extends StatefulWidget {
  final OzgunPlay play;
  const _KagitView({required this.play});
  @override
  State<_KagitView> createState() => _KagitViewState();
}

class _KagitViewState extends State<_KagitView> with Clock {
  late final KagitPuzzle p = widget.play.puzzle as KagitPuzzle;
  late final Map<int, int> target = p.target;
  late Paper paper = p.start();
  final List<Paper> hist = [];
  int moves = 0, hints = 0;
  bool? selVertical;
  int selLine = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _fold(bool vertical, int line, bool low) {
    hist.add(paper);
    setState(() {
      paper = foldPaper(paper, vertical, line, low);
      moves++;
      selVertical = null;
    });
    widget.play.sfx(Sfx.place);
    if (sameLook(paperLook(paper), target)) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(800, () => widget.play.win(stars: starsByMoves(moves, p.folds.length, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 20));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    hints++;
    final k = math.min(hints, p.folds.length);
    hist.add(paper);
    setState(() {
      paper = p.run(p.start(), p.folds.take(k));
      moves = k;
      selVertical = null;
    });
    if (sameLook(paperLook(paper), target)) {
      ended = true;
      later(800, () => widget.play.win(stars: 1, seconds: seconds, hints: hints));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = bbox(paper.keys);
    final ox = 1 - b[0].toDouble(), oy = 1 - b[1].toDouble();
    final cw = b[2] - b[0] + 3.0, ch = b[3] - b[1] + 3.0;
    final tb = bbox(target.keys);
    final look = <int, int>{for (final e in paper.entries) e.key: e.value.last.up ? e.value.last.color : -1};
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${ot(widget.play.lang, 'moves')}: $moves',
        status: clock(),
        onUndo: hist.isEmpty || ended ? null : () => setState(() => paper = hist.removeLast()),
        onReset: ended
            ? null
            : () => setState(() {
                  hist.add(paper);
                  paper = p.start();
                }),
        onHint: _hint,
      ),
      top: SizedBox(
        height: 90,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ot(widget.play.lang, 'target'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            height: 90,
            child: TapCanvas(w: tb[2] + 1.0, h: tb[3] + 1.0, paint: (c) => _paintLook(c, target, Offset.zero, 1)),
          ),
        ]),
      ),
      board: TapCanvas(
        w: cw,
        h: ch,
        onTap: (o) {
          if (ended) return;
          final sv = selVertical;
          if (sv != null) {
            final c = sv ? o.dx - ox : o.dy - oy;
            if ((c - selLine).abs() > 0.25) {
              _fold(sv, selLine, c < selLine);
              return;
            }
          }
          for (var x = b[0] + 1; x <= b[2]; x++) {
            if ((o.dx - (x + ox)).abs() < 0.3 && o.dy > oy + b[1] - 0.6 && o.dy < oy + b[3] + 1.6) {
              setState(() {
                selVertical = true;
                selLine = x;
              });
              return;
            }
          }
          for (var y = b[1] + 1; y <= b[3]; y++) {
            if ((o.dy - (y + oy)).abs() < 0.3 && o.dx > ox + b[0] - 0.6 && o.dx < ox + b[2] + 1.6) {
              setState(() {
                selVertical = false;
                selLine = y;
              });
              return;
            }
          }
        },
        paint: (c) {
          for (final e in look.entries) {
            final r = Rect.fromLTWH(ox + px(e.key), oy + py(e.key), 1, 1);
            final layers = paper[e.key]!.length;
            if (layers > 1) c.drawRect(r.shift(const Offset(0.06, 0.08)), fill(const Color(0x33000000)));
            c.drawRect(r, fill(e.value < 0 ? _paperBack : _paperCols[e.value % 3]));
            c.drawRect(r, stroke(const Color(0x22000000), 0.03));
          }
          final dash = stroke(OColors.ink.withValues(alpha: 0.35), 0.05);
          for (var x = b[0] + 1; x <= b[2]; x++) {
            final sel = selVertical == true && selLine == x;
            c.drawLine(Offset(x + ox, oy + b[1] - 0.5), Offset(x + ox, oy + b[3] + 1.5), sel ? stroke(OColors.accent, 0.12) : dash);
          }
          for (var y = b[1] + 1; y <= b[3]; y++) {
            final sel = selVertical == false && selLine == y;
            c.drawLine(Offset(ox + b[0] - 0.5, y + oy), Offset(ox + b[2] + 1.5, y + oy), sel ? stroke(OColors.accent, 0.12) : dash);
          }
        },
      ),
    );
  }
}

// =================================================================== Hat İzi

class HatPuzzle extends OPuzzle {
  final int g;
  final List<int> path; // düğüm sırası (çözüm)
  const HatPuzzle(this.g, this.path);

  static int ek(int a, int b) => a < b ? a * 1000 + b : b * 1000 + a;

  Set<int> get edges => {for (var i = 1; i < path.length; i++) ek(path[i - 1], path[i])};
}

class HatKind extends OzgunKind {
  @override
  String get id => 'hat';
  const HatKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final g = 3 + d ~/ 3;
    final want = (g * g * 1.1).round() + d;
    final used = <int>{};
    final diag = <int>{}; // kesişen köşegenleri önlemek için kare kimlikleri
    var cur = r.nextInt(g * g);
    final path = [cur];
    for (var step = 0; step < want; step++) {
      final cands = <int>[];
      final cx = cur % g, cy = cur ~/ g;
      for (final dd in kDirs8) {
        final nx = cx + dd[0], ny = cy + dd[1];
        if (nx < 0 || ny < 0 || nx >= g || ny >= g) continue;
        final nb = ny * g + nx;
        if (used.contains(HatPuzzle.ek(cur, nb))) continue;
        if (dd[0] != 0 && dd[1] != 0) {
          final sq = math.min(cy, ny) * g + math.min(cx, nx);
          if (diag.contains(sq)) continue;
        }
        cands.add(nb);
      }
      if (cands.isEmpty) break;
      final nb = r.pick(cands);
      used.add(HatPuzzle.ek(cur, nb));
      final nx = nb % g, ny = nb ~/ g;
      if (nx != cx && ny != cy) diag.add(math.min(cy, ny) * g + math.min(cx, nx));
      path.add(nb);
      cur = nb;
    }
    if (path.length - 1 < g * g * 0.8) return null;
    return HatPuzzle(g, path);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! HatPuzzle) return false;
    final seen = <int>{};
    for (var i = 1; i < p.path.length; i++) {
      final a = p.path[i - 1], b = p.path[i];
      if ((a % p.g - b % p.g).abs() > 1 || (a ~/ p.g - b ~/ p.g).abs() > 1 || a == b) return false;
      if (!seen.add(HatPuzzle.ek(a, b))) return false;
    }
    return seen.length >= 6;
  }

  @override
  Widget build(OzgunPlay play) => _HatView(play: play);
}

class _HatView extends StatefulWidget {
  final OzgunPlay play;
  const _HatView({required this.play});
  @override
  State<_HatView> createState() => _HatViewState();
}

class _HatViewState extends State<_HatView> with Clock {
  late final HatPuzzle p = widget.play.puzzle as HatPuzzle;
  late final Set<int> all = p.edges;
  List<int> path = [];
  int hints = 0;
  int? flash;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  Set<int> get used => {for (var i = 1; i < path.length; i++) HatPuzzle.ek(path[i - 1], path[i])};

  Offset pos(int n) => Offset(n % p.g + 0.5, n ~/ p.g + 0.5);

  int? nodeAt(Offset o, [double rad = 0.38]) {
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.g || y >= p.g) return null;
    final n = y * p.g + x;
    return (o - pos(n)).distance <= rad ? n : null;
  }

  void _visit(int n) {
    if (ended) return;
    if (path.isEmpty) {
      setState(() => path = [n]);
      widget.play.sfx(Sfx.tap);
      return;
    }
    if (n == path.last) return;
    final e = HatPuzzle.ek(path.last, n);
    if (!all.contains(e) || used.contains(e)) return;
    setState(() => path = [...path, n]);
    widget.play.sfx(Sfx.place);
    if (used.length == all.length) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(700, () => widget.play.win(stars: 3 - hints, seconds: seconds, hints: hints, score: 1000 - seconds));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    var k = 0;
    while (k < path.length && k < p.path.length && path[k] == p.path[k]) {
      k++;
    }
    hints++;
    setState(() {
      path = p.path.sublist(0, math.min(p.path.length, math.max(1, k + 1)));
      flash = path.last;
    });
    later(900, () => setState(() => flash = null));
  }

  @override
  Widget build(BuildContext context) {
    final g = p.g.toDouble();
    final u = used;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${u.length}/${all.length}',
        status: clock(),
        onUndo: path.isEmpty || ended ? null : () => setState(() => path = path.sublist(0, path.length - 1)),
        onReset: ended ? null : () => setState(() => path = []),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: g,
        h: g,
        onTap: (o) {
          final n = nodeAt(o, 0.5);
          if (n != null) _visit(n);
        },
        onPanStart: (o) {
          final n = nodeAt(o, 0.5);
          if (n != null) _visit(n);
        },
        onPanUpdate: (o) {
          final n = nodeAt(o);
          if (n != null) _visit(n);
        },
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, g, g), const Radius.circular(0.3)), fill(const Color(0xFFF6EEDC)));
          for (final e in all) {
            final a = pos(e ~/ 1000), b = pos(e % 1000);
            if (u.contains(e)) {
              c.drawLine(a, b, stroke(const Color(0xFF1E2A44), 0.14));
              c.drawLine(a, b, stroke(OColors.gold, 0.05));
            } else {
              c.drawLine(a, b, stroke(const Color(0x55806A4A), 0.06));
            }
          }
          for (var n = 0; n < p.g * p.g; n++) {
            final deg = all.where((e) => e ~/ 1000 == n || e % 1000 == n).length;
            if (deg == 0) continue;
            final isLast = path.isNotEmpty && path.last == n;
            c.drawCircle(pos(n), isLast ? 0.17 : 0.11, fill(isLast ? OColors.bad : const Color(0xFF1E2A44)));
            if (flash == n) c.drawCircle(pos(n), 0.3, stroke(OColors.accent, 0.06));
          }
        },
      ),
    );
  }
}
