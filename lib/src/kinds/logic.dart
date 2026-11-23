import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// =================================================================== Lale Bahçesi

class LalePuzzle extends OPuzzle {
  final int n;
  final List<int> region;
  final int regions;
  final List<bool> sol;
  final List<int> regionCount;
  final List<int> rowCount;
  final List<int> colCount;
  const LalePuzzle(this.n, this.region, this.regions, this.sol, this.regionCount, this.rowCount, this.colCount);

  /// Komşu (çapraz dahil) lale çiftleri.
  Set<int> clashes(List<bool> g) {
    final out = <int>{};
    for (var i = 0; i < n * n; i++) {
      if (!g[i]) continue;
      final x = i % n, y = i ~/ n;
      for (final d in kDirs8) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        if (g[ny * n + nx]) out.add(i);
      }
    }
    return out;
  }

  bool solved(List<bool> g) {
    if (clashes(g).isNotEmpty) return false;
    final rc = List<int>.filled(regions, 0), rw = List<int>.filled(n, 0), cl = List<int>.filled(n, 0);
    for (var i = 0; i < n * n; i++) {
      if (!g[i]) continue;
      rc[region[i]]++;
      rw[i ~/ n]++;
      cl[i % n]++;
    }
    for (var i = 0; i < regions; i++) {
      if (rc[i] != regionCount[i]) return false;
    }
    for (var i = 0; i < n; i++) {
      if (rw[i] != rowCount[i] || cl[i] != colCount[i]) return false;
    }
    return true;
  }
}

class LaleKind extends OzgunKind {
  @override
  String get id => 'lale';
  const LaleKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 5 + (d - 1) * 4 ~/ 9;
    final g = List<bool>.filled(n * n, false);
    final order = [for (var i = 0; i < n * n; i++) i];
    r.shuffle(order);
    final want = n * n ~/ 5 + r.nextInt(2);
    var placed = 0;
    for (final i in order) {
      if (placed >= want) break;
      final x = i % n, y = i ~/ n;
      var ok = true;
      for (final dd in kDirs8) {
        final nx = x + dd[0], ny = y + dd[1];
        if (nx >= 0 && ny >= 0 && nx < n && ny < n && g[ny * n + nx]) ok = false;
      }
      if (ok) {
        g[i] = true;
        placed++;
      }
    }
    if (placed < n * n ~/ 6) return null;
    final k = n + d ~/ 3;
    final region = List<int>.filled(n * n, -1);
    final frontier = <int>[];
    final seeds = [for (var i = 0; i < n * n; i++) i];
    r.shuffle(seeds);
    for (var i = 0; i < k; i++) {
      region[seeds[i]] = i;
      frontier.add(seeds[i]);
    }
    var guard = 0;
    while (frontier.isNotEmpty && guard++ < 10000) {
      final fi = r.nextInt(frontier.length);
      final c = frontier[fi];
      final x = c % n, y = c ~/ n;
      final free = <int>[];
      for (final dd in kDirs4) {
        final nx = x + dd[0], ny = y + dd[1];
        if (nx >= 0 && ny >= 0 && nx < n && ny < n && region[ny * n + nx] < 0) free.add(ny * n + nx);
      }
      if (free.isEmpty) {
        frontier.removeAt(fi);
        continue;
      }
      final nb = r.pick(free);
      region[nb] = region[c];
      frontier.add(nb);
    }
    if (region.contains(-1)) return null;
    final rc = List<int>.filled(k, 0), rw = List<int>.filled(n, 0), cl = List<int>.filled(n, 0);
    for (var i = 0; i < n * n; i++) {
      if (!g[i]) continue;
      rc[region[i]]++;
      rw[i ~/ n]++;
      cl[i % n]++;
    }
    return LalePuzzle(n, region, k, g, rc, rw, cl);
  }

  @override
  bool check(OPuzzle p) => p is LalePuzzle && p.solved(p.sol);

  @override
  Widget build(OzgunPlay play) => _LaleView(play: play);
}

const List<Color> _beds = [
  Color(0xFFE9DCC4),
  Color(0xFFD8E6C8),
  Color(0xFFF1D6C9),
  Color(0xFFD3DEEA),
  Color(0xFFEADBEA),
  Color(0xFFF3E7B8),
  Color(0xFFCFE3DE),
  Color(0xFFE6D2B5),
];

class _LaleView extends StatefulWidget {
  final OzgunPlay play;
  const _LaleView({required this.play});
  @override
  State<_LaleView> createState() => _LaleViewState();
}

class _LaleViewState extends State<_LaleView> with Clock {
  late final LalePuzzle p = widget.play.puzzle as LalePuzzle;
  late List<int> s = List<int>.filled(p.n * p.n, 0); // 0 boş, 1 lale, 2 nokta
  final List<List<int>> hist = [];
  int hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  List<bool> get grid => [for (final v in s) v == 1];

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.n || y >= p.n) return;
    hist.add(List.of(s));
    setState(() => s[y * p.n + x] = (s[y * p.n + x] + 1) % 3);
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    if (ended || !p.solved(grid)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: 3 - hints, seconds: seconds, hints: hints, score: 1000 - seconds));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < s.length; i++) {
      if ((s[i] == 1) != p.sol[i] || (s[i] == 0 && !p.sol[i])) {
        hints++;
        hist.add(List.of(s));
        setState(() => s[i] = p.sol[i] ? 1 : 2);
        _check();
        return;
      }
    }
  }

  void _tulip(Canvas c, Offset m, Color col) {
    c.drawLine(m + const Offset(0, 0.05), m + const Offset(0, 0.36), stroke(const Color(0xFF4F7F52), 0.06));
    final leaf = Path()
      ..moveTo(m.dx, m.dy + 0.3)
      ..quadraticBezierTo(m.dx + 0.22, m.dy + 0.12, m.dx + 0.2, m.dy + 0.02)
      ..quadraticBezierTo(m.dx + 0.08, m.dy + 0.2, m.dx, m.dy + 0.3);
    c.drawPath(leaf, fill(const Color(0xFF4F7F52)));
    final cup = Path()
      ..moveTo(m.dx - 0.2, m.dy - 0.28)
      ..lineTo(m.dx - 0.08, m.dy - 0.14)
      ..lineTo(m.dx, m.dy - 0.32)
      ..lineTo(m.dx + 0.08, m.dy - 0.14)
      ..lineTo(m.dx + 0.2, m.dy - 0.28)
      ..quadraticBezierTo(m.dx + 0.22, m.dy + 0.08, m.dx, m.dy + 0.08)
      ..quadraticBezierTo(m.dx - 0.22, m.dy + 0.08, m.dx - 0.2, m.dy - 0.28)
      ..close();
    c.drawPath(cup, fill(col));
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    final g = grid;
    final bad = p.clashes(g);
    final rw = List<int>.filled(n, 0), cl = List<int>.filled(n, 0), rc = List<int>.filled(p.regions, 0);
    for (var i = 0; i < n * n; i++) {
      if (!g[i]) continue;
      rw[i ~/ n]++;
      cl[i % n]++;
      rc[p.region[i]]++;
    }
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: clock(),
        onUndo: hist.isEmpty || ended ? null : () => setState(() => s = hist.removeLast()),
        onReset: ended
            ? null
            : () => setState(() {
                  hist.add(List.of(s));
                  s = List<int>.filled(n * n, 0);
                }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: n + 0.8,
        h: n + 0.8,
        onTap: _tap,
        paint: (c) {
          final labelled = <int>{};
          for (var i = 0; i < n * n; i++) {
            final x = i % n, y = i ~/ n;
            final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
            c.drawRect(r, fill(_beds[p.region[i] % _beds.length]));
            if (x < n - 1 && p.region[i + 1] != p.region[i]) c.drawLine(Offset(x + 1.0, y.toDouble()), Offset(x + 1.0, y + 1.0), stroke(const Color(0xFF5B4636), 0.07));
            if (y < n - 1 && p.region[i + n] != p.region[i]) c.drawLine(Offset(x.toDouble(), y + 1.0), Offset(x + 1.0, y + 1.0), stroke(const Color(0xFF5B4636), 0.07));
            if (labelled.add(p.region[i])) {
              final reg = p.region[i];
              drawLabel(c, '${p.regionCount[reg]}', Offset(x + 0.2, y + 0.2), 0.26, rc[reg] == p.regionCount[reg] ? OColors.good : OColors.ink);
            }
            final m = r.center;
            if (s[i] == 1) {
              _tulip(c, m, bad.contains(i) ? OColors.bad : const Color(0xFFC8453B));
            } else if (s[i] == 2) {
              c.drawCircle(m, 0.07, fill(const Color(0x885B4636)));
            }
          }
          c.drawRect(Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), stroke(const Color(0xFF5B4636), 0.1));
          for (var i = 0; i < n; i++) {
            drawLabel(c, '${p.rowCount[i]}', Offset(n + 0.4, i + 0.5), 0.4, rw[i] == p.rowCount[i] ? OColors.good : OColors.ink);
            drawLabel(c, '${p.colCount[i]}', Offset(i + 0.5, n + 0.4), 0.4, cl[i] == p.colCount[i] ? OColors.good : OColors.ink);
          }
        },
      ),
    );
  }
}

// =================================================================== Bal Peteği

/// Altıgen bölge (eksenel koordinat) ve komşuluk.
class HexArea {
  final int radius;
  late final List<List<int>> cells = [
    for (var q = -radius; q <= radius; q++)
      for (var r = math.max(-radius, -q - radius); r <= math.min(radius, -q + radius); r++) [q, r],
  ];
  late final Map<int, int> index = {for (var i = 0; i < cells.length; i++) key(cells[i][0], cells[i][1]): i};
  HexArea(this.radius);

  static int key(int q, int r) => (q + 32) * 64 + (r + 32);

  static const List<List<int>> dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
    [1, -1],
    [-1, 1],
  ];

  List<int> neighbors(int i) {
    final c = cells[i];
    final out = <int>[];
    for (final d in dirs) {
      final j = index[key(c[0] + d[0], c[1] + d[1])];
      if (j != null) out.add(j);
    }
    return out;
  }

  bool adjacent(int a, int b) => neighbors(a).contains(b);

  /// Sivri tepeli altıgenin merkezi (yarıçap 1).
  Offset center(int i) {
    final c = cells[i];
    return Offset(math.sqrt(3) * (c[0] + c[1] / 2), 1.5 * c[1]);
  }

  int? hit(Offset p) {
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < cells.length; i++) {
      final d = (center(i) - p).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return bd <= 0.95 ? best : null;
  }

  Path hexPath(Offset m, double s) {
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final a = math.pi / 180 * (60 * k - 30);
      final p = m + Offset(math.cos(a) * s, math.sin(a) * s);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }
}

class BalPuzzle extends OPuzzle {
  final int radius;
  final List<int> path; // path[k] = k+1 sayısının hücresi
  final List<bool> given; // sayıya göre
  const BalPuzzle(this.radius, this.path, this.given);
}

class BalKind extends OzgunKind {
  @override
  String get id => 'bal';
  const BalKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final radius = 2 + (d >= 4 ? 1 : 0) + (d >= 8 ? 1 : 0);
    final area = HexArea(radius);
    final n = area.cells.length;
    for (var attempt = 0; attempt < 12; attempt++) {
      final seen = List<bool>.filled(n, false);
      var cur = r.nextInt(n);
      final path = [cur];
      seen[cur] = true;
      while (path.length < n) {
        final opts = area.neighbors(cur).where((j) => !seen[j]).toList();
        if (opts.isEmpty) break;
        int onward(int j) => area.neighbors(j).where((k) => !seen[k]).length;
        r.shuffle(opts);
        opts.sort((a, b) => onward(a) - onward(b));
        cur = opts.first;
        seen[cur] = true;
        path.add(cur);
      }
      if (path.length < n) continue;
      final frac = 0.45 - d * 0.025;
      final given = [for (var k = 0; k < n; k++) k == 0 || k == n - 1 || r.chance(frac)];
      return BalPuzzle(radius, path, given);
    }
    return null;
  }

  @override
  bool check(OPuzzle p) {
    if (p is! BalPuzzle) return false;
    final area = HexArea(p.radius);
    if (p.path.length != area.cells.length || p.path.toSet().length != p.path.length) return false;
    for (var k = 1; k < p.path.length; k++) {
      if (!area.adjacent(p.path[k - 1], p.path[k])) return false;
    }
    return true;
  }

  @override
  Widget build(OzgunPlay play) => _BalView(play: play);
}

class _BalView extends StatefulWidget {
  final OzgunPlay play;
  const _BalView({required this.play});
  @override
  State<_BalView> createState() => _BalViewState();
}

class _BalViewState extends State<_BalView> with Clock {
  late final BalPuzzle p = widget.play.puzzle as BalPuzzle;
  late final HexArea area = HexArea(p.radius);
  late final int n = area.cells.length;
  late List<int> val = _fresh(); // hücre → sayı (0 boş)
  int hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  List<int> _fresh() {
    final v = List<int>.filled(area.cells.length, 0);
    for (var k = 0; k < p.path.length; k++) {
      if (p.given[k]) v[p.path[k]] = k + 1;
    }
    return v;
  }

  bool isGiven(int cell) {
    final v = val[cell];
    return v > 0 && p.given[v - 1] && p.path[v - 1] == cell;
  }

  /// 1'den başlayıp kesintisiz yerleşmiş son sayı.
  int chainEnd() {
    final where = List<int>.filled(n + 2, -1);
    for (var i = 0; i < n; i++) {
      if (val[i] > 0) where[val[i]] = i;
    }
    var m = 0;
    while (m < n && where[m + 1] >= 0 && (m == 0 || area.adjacent(where[m], where[m + 1]))) {
      m++;
    }
    return m;
  }

  int cellOf(int v) => val.indexOf(v);

  void _tap(Offset o) {
    if (ended) return;
    final cell = area.hit(o - _origin);
    if (cell == null) return;
    if (val[cell] > 0) {
      if (isGiven(cell)) return;
      final cut = val[cell];
      setState(() {
        for (var i = 0; i < n; i++) {
          if (val[i] >= cut && !isGiven(i)) val[i] = 0;
        }
      });
      widget.play.sfx(Sfx.tap);
      return;
    }
    final m = chainEnd();
    if (m >= n) return;
    final last = cellOf(m);
    if (last < 0 || !area.adjacent(last, cell)) {
      widget.play.sfx(Sfx.error);
      return;
    }
    if (val.contains(m + 1)) return; // sıradaki sayı verilmiş ama komşu değil
    setState(() => val[cell] = m + 1);
    widget.play.sfx(Sfx.place);
    _check();
  }

  void _check() {
    if (ended || chainEnd() < n) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: 3 - hints, seconds: seconds, hints: hints, score: 1000 - seconds));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    var k = 1;
    while (k <= n && val[p.path[k - 1]] == k) {
      k++;
    }
    if (k > n) return;
    hints++;
    setState(() {
      for (var i = 0; i < n; i++) {
        if (val[i] >= k && !isGiven(i)) val[i] = 0;
      }
      val[p.path[k - 1]] = k;
    });
    _check();
  }

  Offset get _origin => Offset(math.sqrt(3) * (p.radius + 0.5) + 0.2, 1.5 * p.radius + 1.2);

  @override
  Widget build(BuildContext context) {
    final w = math.sqrt(3) * (2 * p.radius + 1) + 0.4;
    final h = 3.0 * p.radius + 2.4;
    final m = chainEnd();
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '$m/$n',
        status: clock(),
        onReset: ended ? null : () => setState(() => val = _fresh()),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: w,
        h: h,
        onTap: _tap,
        paint: (c) {
          final o = _origin;
          final tip = m < n ? cellOf(m) : -1;
          for (var i = 0; i < n; i++) {
            final ctr = o + area.center(i);
            final path = area.hexPath(ctr, 0.96);
            final v = val[i];
            final given = isGiven(i);
            final inChain = v > 0 && v <= m;
            c.drawPath(path, fill(given ? const Color(0xFFE9B949) : (inChain ? const Color(0xFFF6D98C) : (v > 0 ? const Color(0xFFF1C6A8) : const Color(0xFFFFF4D6)))));
            c.drawPath(path, stroke(const Color(0xFFB7862B), 0.07));
            if (i == tip) c.drawPath(area.hexPath(ctr, 0.8), stroke(OColors.accent, 0.08));
            if (v > 0) drawLabel(c, '$v', ctr, v > 99 ? 0.55 : 0.7, given ? const Color(0xFF5B3A0A) : OColors.ink, weight: given ? FontWeight.w900 : FontWeight.w600);
          }
        },
      ),
    );
  }
}

// =================================================================== Mantar Avı

class MantarPuzzle extends OPuzzle {
  final int w, h;
  final List<bool> mush;
  final List<bool> tree;
  final int start;
  const MantarPuzzle(this.w, this.h, this.mush, this.tree, this.start);

  List<int> around(int i) {
    final x = i % w, y = i ~/ w;
    final out = <int>[];
    for (final d in kDirs8) {
      final nx = x + d[0], ny = y + d[1];
      if (nx >= 0 && ny >= 0 && nx < w && ny < h) out.add(ny * w + nx);
    }
    return out;
  }

  int number(int i) => around(i).where((j) => mush[j]).length;

  /// Açılan hücre 0 ise çevresi de açılır.
  void flood(List<bool> open, int i) {
    final stack = [i];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      if (open[c] || tree[c] || mush[c]) continue;
      open[c] = true;
      if (number(c) == 0) stack.addAll(around(c));
    }
  }

  /// Tahminsiz çözülebilir mi (yerel ve alt küme kuralları).
  bool deducible() {
    final open = List<bool>.filled(w * h, false), flag = List<bool>.filled(w * h, false);
    flood(open, start);
    var progress = true;
    while (progress) {
      progress = false;
      final cons = <List<int>>[];
      final need = <int>[];
      for (var i = 0; i < w * h; i++) {
        if (!open[i]) continue;
        final u = <int>[];
        var f = 0;
        for (final j in around(i)) {
          if (tree[j] || open[j]) continue;
          if (flag[j]) {
            f++;
          } else {
            u.add(j);
          }
        }
        if (u.isEmpty) continue;
        final left = number(i) - f;
        if (left == 0) {
          for (final j in u) {
            flood(open, j);
          }
          progress = true;
        } else if (left == u.length) {
          for (final j in u) {
            flag[j] = true;
          }
          progress = true;
        } else {
          cons.add(u);
          need.add(left);
        }
      }
      if (progress) continue;
      for (var a = 0; a < cons.length && !progress; a++) {
        for (var b = 0; b < cons.length && !progress; b++) {
          if (a == b || cons[a].length >= cons[b].length) continue;
          if (!cons[a].every(cons[b].contains)) continue;
          final rest = cons[b].where((j) => !cons[a].contains(j)).toList();
          final diff = need[b] - need[a];
          if (diff == 0) {
            for (final j in rest) {
              flood(open, j);
            }
            progress = true;
          } else if (diff == rest.length) {
            for (final j in rest) {
              flag[j] = true;
            }
            progress = true;
          }
        }
      }
    }
    for (var i = 0; i < w * h; i++) {
      if (!mush[i] && !tree[i] && !open[i]) return false;
    }
    return true;
  }
}

class MantarKind extends OzgunKind {
  @override
  String get id => 'mantar';
  const MantarKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final w = 6 + d ~/ 3, h = w + 2;
    final density = 0.12 + d * 0.008;
    for (var attempt = 0; attempt < 15; attempt++) {
      final start = (h ~/ 2 + r.range(-1, 1)) * w + w ~/ 2 + r.range(-1, 1);
      final keep = {start, ...MantarPuzzle(w, h, const [], const [], start).around(start)};
      final tree = List<bool>.filled(w * h, false);
      final mush = List<bool>.filled(w * h, false);
      final cells = [for (var i = 0; i < w * h; i++) if (!keep.contains(i)) i];
      r.shuffle(cells);
      final nt = d >= 3 ? (w * h * 0.05).round() : 0;
      final nm = (w * h * density).round();
      for (var i = 0; i < nt; i++) {
        tree[cells[i]] = true;
      }
      for (var i = nt; i < nt + nm; i++) {
        mush[cells[i]] = true;
      }
      final p = MantarPuzzle(w, h, mush, tree, start);
      if (p.number(start) == 0 && p.deducible()) return p;
    }
    return null;
  }

  @override
  bool check(OPuzzle p) => p is MantarPuzzle && p.mush.contains(true) && p.deducible();

  @override
  Widget build(OzgunPlay play) => _MantarView(play: play);
}

class _MantarView extends StatefulWidget {
  final OzgunPlay play;
  const _MantarView({required this.play});
  @override
  State<_MantarView> createState() => _MantarViewState();
}

class _MantarViewState extends State<_MantarView> with Clock {
  late final MantarPuzzle p = widget.play.puzzle as MantarPuzzle;
  late final List<bool> open = List<bool>.filled(p.w * p.h, false);
  late final List<bool> mark = List<bool>.filled(p.w * p.h, false);
  late int lives = widget.play.d <= 4 ? 3 : (widget.play.d <= 7 ? 2 : 1);
  bool markMode = false;
  int hints = 0, mistakes = 0;

  @override
  void initState() {
    super.initState();
    p.flood(open, p.start);
    startClock();
  }

  int? cellAt(Offset o) {
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.w || y >= p.h) return null;
    return y * p.w + x;
  }

  void _act(int i, bool asMark) {
    if (ended || open[i] || p.tree[i]) return;
    if (asMark) {
      setState(() => mark[i] = !mark[i]);
      widget.play.sfx(Sfx.tap);
      return;
    }
    if (mark[i]) return;
    if (p.mush[i]) {
      setState(() {
        mark[i] = true;
        lives--;
        mistakes++;
      });
      widget.play.sfx(Sfx.error);
      if (lives <= 0) {
        ended = true;
        later(900, () => widget.play.lose(seconds: seconds));
      }
      return;
    }
    setState(() => p.flood(open, i));
    widget.play.sfx(Sfx.place);
    _check();
  }

  void _check() {
    for (var i = 0; i < p.w * p.h; i++) {
      if (!p.mush[i] && !p.tree[i] && !open[i]) return;
    }
    if (ended) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(700, () => widget.play.win(stars: 3 - mistakes - hints, seconds: seconds, hints: hints, score: 1000 - seconds - mistakes * 100));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < p.w * p.h; i++) {
      if (open[i] || p.mush[i] || p.tree[i]) continue;
      if (p.around(i).any((j) => open[j])) {
        hints++;
        setState(() => p.flood(open, i));
        _check();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final marked = mark.where((v) => v).length;
    final total = p.mush.where((v) => v).length;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '🍄 $marked/$total',
        status: '${ot(lang, 'lives')}: $lives · ${clock()}',
        onHint: _hint,
      ),
      board: TapCanvas(
        w: p.w.toDouble(),
        h: p.h.toDouble(),
        onTap: (o) {
          final i = cellAt(o);
          if (i != null) _act(i, markMode);
        },
        onLongPress: (o) {
          final i = cellAt(o);
          if (i != null) _act(i, true);
        },
        paint: (c) {
          for (var i = 0; i < p.w * p.h; i++) {
            final x = i % p.w, y = i ~/ p.w;
            final r = Rect.fromLTWH(x + 0.03, y + 0.03, 0.94, 0.94);
            final m = r.center;
            if (p.tree[i]) {
              c.drawRect(r, fill(const Color(0xFF6B8F4E)));
              c.drawRect(Rect.fromCenter(center: m + const Offset(0, 0.25), width: 0.12, height: 0.3), fill(const Color(0xFF6B4A2B)));
              c.drawCircle(m - const Offset(0, 0.06), 0.3, fill(const Color(0xFF2F5D34)));
              continue;
            }
            if (open[i]) {
              c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.12)), fill(const Color(0xFFEADBC0)));
              final k = p.number(i);
              if (k > 0) drawLabel(c, '$k', m, 0.58, const [OColors.ink, Color(0xFF2E5E8C), Color(0xFF4F7F52), Color(0xFFB23A48), Color(0xFF7A4E7E)][math.min(k, 4)]);
            } else {
              c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.12)), fill(const Color(0xFF8DB86B)));
              c.drawLine(m + const Offset(-0.2, 0.2), m + const Offset(-0.12, 0.02), stroke(const Color(0xFF5E8C45), 0.04));
              c.drawLine(m + const Offset(0.1, 0.25), m + const Offset(0.16, 0.06), stroke(const Color(0xFF5E8C45), 0.04));
              if (mark[i]) {
                c.drawRect(Rect.fromCenter(center: m + const Offset(0, 0.12), width: 0.14, height: 0.24), fill(const Color(0xFFF4EBDC)));
                c.drawArc(Rect.fromCenter(center: m, width: 0.56, height: 0.46), math.pi, math.pi, true, fill(const Color(0xFFC8453B)));
                c.drawCircle(m + const Offset(-0.1, -0.1), 0.04, fill(Colors.white));
                c.drawCircle(m + const Offset(0.09, -0.06), 0.035, fill(Colors.white));
              }
            }
          }
        },
      ),
      bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OChip(selected: !markMode, tooltip: ot(lang, 'open'), onTap: () => setState(() => markMode = false), child: const Icon(Icons.grass, size: 26)),
        const SizedBox(width: 12),
        OChip(selected: markMode, tooltip: ot(lang, 'mark'), onTap: () => setState(() => markMode = true), child: const Text('🍄', style: TextStyle(fontSize: 22))),
      ]),
    );
  }
}

// =================================================================== Pazar Tezgâhı

class PazarPuzzle extends OPuzzle {
  final int k, m;
  final List<int> color; // öğe → renk
  final List<int> price; // öğe → fiyat
  final List<int> start; // konum → öğe
  const PazarPuzzle(this.k, this.m, this.color, this.price, this.start);

  bool solved(List<int> at) {
    for (var row = 0; row < k; row++) {
      final c0 = color[at[row * m]];
      for (var j = 0; j < m; j++) {
        final it = at[row * m + j];
        if (color[it] != c0) return false;
        if (j > 0 && price[at[row * m + j - 1]] >= price[it]) return false;
      }
    }
    return true;
  }

  /// En az değiş tokuş ve bunu sağlayan hedef yerleşim.
  (int, List<int>) best(List<int> at) {
    var bestSwaps = 1 << 30;
    var bestTarget = <int>[];
    for (final perm in _perms(k)) {
      final target = List<int>.filled(k * m, 0); // konum → öğe
      for (var c = 0; c < k; c++) {
        final items = [for (var i = 0; i < k * m; i++) if (color[i] == c) i]..sort((a, b) => price[a] - price[b]);
        for (var j = 0; j < m; j++) {
          target[perm[c] * m + j] = items[j];
        }
      }
      final where = List<int>.filled(k * m, 0);
      for (var pos = 0; pos < k * m; pos++) {
        where[at[pos]] = pos;
      }
      final seen = List<bool>.filled(k * m, false);
      var cycles = 0;
      for (var pos = 0; pos < k * m; pos++) {
        if (seen[pos]) continue;
        cycles++;
        var q = pos;
        while (!seen[q]) {
          seen[q] = true;
          q = where[target[q]];
        }
      }
      final swaps = k * m - cycles;
      if (swaps < bestSwaps) {
        bestSwaps = swaps;
        bestTarget = target;
      }
    }
    return (bestSwaps, bestTarget);
  }

  static List<List<int>> _perms(int n) {
    if (n == 1) {
      return [
        [0],
      ];
    }
    final out = <List<int>>[];
    for (final p in _perms(n - 1)) {
      for (var i = 0; i <= p.length; i++) {
        out.add([...p.sublist(0, i), n - 1, ...p.sublist(i)]);
      }
    }
    return out;
  }
}

class PazarKind extends OzgunKind {
  @override
  String get id => 'pazar';
  const PazarKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final k = 3 + d ~/ 4, m = 3 + d ~/ 3;
    final color = <int>[], price = <int>[];
    for (var c = 0; c < k; c++) {
      final ps = [for (var v = 1; v <= 9; v++) v];
      r.shuffle(ps);
      for (var j = 0; j < m; j++) {
        color.add(c);
        price.add(ps[j]);
      }
    }
    final start = [for (var i = 0; i < k * m; i++) i];
    r.shuffle(start);
    final p = PazarPuzzle(k, m, color, price, start);
    if (p.solved(start) || p.best(start).$1 < k * m ~/ 2) return null;
    return p;
  }

  @override
  bool check(OPuzzle p) => p is PazarPuzzle && p.solved(p.best(p.start).$2) && !p.solved(p.start);

  @override
  Widget build(OzgunPlay play) => _PazarView(play: play);
}

const List<Color> _produce = [Color(0xFFD7263D), Color(0xFFF4C430), Color(0xFF5C3C92), Color(0xFF4CAF50), Color(0xFFF28C28), Color(0xFF8D6E63)];

void _paintProduce(Canvas c, int kind, Offset m, double s) {
  final col = _produce[kind % _produce.length];
  switch (kind) {
    case 0: // domates
      c.drawCircle(m, s * 0.3, fill(col));
      c.drawCircle(m + Offset(-s * 0.1, -s * 0.1), s * 0.08, fill(Colors.white.withValues(alpha: 0.4)));
      c.drawLine(m + Offset(0, -s * 0.3), m + Offset(0, -s * 0.38), stroke(const Color(0xFF2F7D32), s * 0.06));
    case 1: // limon
      c.drawOval(Rect.fromCenter(center: m, width: s * 0.66, height: s * 0.46), fill(col));
    case 2: // patlıcan
      c.save();
      c.translate(m.dx, m.dy);
      c.rotate(-0.6);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.36, height: s * 0.7), fill(col));
      c.drawRect(Rect.fromCenter(center: Offset(0, -s * 0.34), width: s * 0.14, height: s * 0.1), fill(const Color(0xFF2F7D32)));
      c.restore();
    case 3: // salatalık
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: s * 0.72, height: s * 0.26), Radius.circular(s * 0.13)), fill(col));
    case 4: // portakal
      c.drawCircle(m, s * 0.3, fill(col));
      c.drawCircle(m + Offset(0, -s * 0.22), s * 0.05, fill(const Color(0xFF2F7D32)));
    default: // patates
      c.drawOval(Rect.fromCenter(center: m, width: s * 0.6, height: s * 0.42), fill(col));
  }
}

class _PazarView extends StatefulWidget {
  final OzgunPlay play;
  const _PazarView({required this.play});
  @override
  State<_PazarView> createState() => _PazarViewState();
}

class _PazarViewState extends State<_PazarView> with Clock {
  late final PazarPuzzle p = widget.play.puzzle as PazarPuzzle;
  late List<int> at = List.of(p.start);
  late final int par = p.best(p.start).$1;
  int? sel;
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _swap(int a, int b) {
    setState(() {
      final t = at[a];
      at[a] = at[b];
      at[b] = t;
      sel = null;
      moves++;
    });
    widget.play.sfx(Sfx.place);
    if (p.solved(at)) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(700, () => widget.play.win(stars: starsByMoves(moves, par, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 10));
    }
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.m || y >= p.k) return;
    final pos = y * p.m + x;
    final s = sel;
    if (s == null) {
      setState(() => sel = pos);
      widget.play.sfx(Sfx.tap);
    } else if (s == pos) {
      setState(() => sel = null);
    } else {
      _swap(s, pos);
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final target = p.best(at).$2;
    for (var pos = 0; pos < at.length; pos++) {
      if (at[pos] != target[pos]) {
        hints++;
        _swap(pos, at.indexOf(target[pos]));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OScreen(
      bar: OBar(lang: widget.play.lang, left: '${ot(widget.play.lang, 'moves')}: $moves', status: clock(), onHint: _hint),
      board: TapCanvas(
        w: p.m.toDouble(),
        h: p.k + 0.3,
        onTap: _tap,
        paint: (c) {
          for (var row = 0; row < p.k; row++) {
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, row + 0.05, p.m.toDouble(), 0.95), const Radius.circular(0.1)), fill(const Color(0xFFC89F6C)));
            c.drawRect(Rect.fromLTWH(0, row + 0.88, p.m.toDouble(), 0.12), fill(const Color(0xFF8B5A2B)));
            for (var j = 0; j < p.m; j++) {
              final pos = row * p.m + j;
              final it = at[pos];
              final m = Offset(j + 0.5, row + 0.42);
              if (sel == pos) c.drawCircle(m, 0.44, fill(const Color(0x553E6FB0)));
              _paintProduce(c, p.color[it], m, 1);
              final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(j + 0.5, row + 0.8), width: 0.36, height: 0.22), const Radius.circular(0.05));
              c.drawRRect(tag, fill(Colors.white));
              drawLabel(c, '${p.price[it]}', tag.center, 0.17, OColors.ink);
            }
          }
          c.drawRect(Rect.fromLTWH(0, p.k.toDouble(), p.m.toDouble(), 0.3), fill(const Color(0xFF6B4A2B)));
        },
      ),
    );
  }
}
