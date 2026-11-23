import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

/// Izgarada rastgele ama hedefe yönelen yol (kayalardan kaçınır).
List<int>? _walk(int w, int h, int from, int to, Set<int> blocked, SeededRandom r, {int limit = 200}) {
  final path = [from];
  final seen = {from};
  var cur = from;
  var guard = 0;
  while (cur != to && guard++ < limit) {
    final cx = cur % w, cy = cur ~/ w, tx = to % w, ty = to ~/ w;
    final opts = <int>[];
    for (final d in kDirs4) {
      final nx = cx + d[0], ny = cy + d[1];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final nb = ny * w + nx;
      if (seen.contains(nb) || (blocked.contains(nb) && nb != to)) continue;
      final closer = (tx - nx).abs() + (ty - ny).abs() < (tx - cx).abs() + (ty - cy).abs();
      opts.add(nb);
      if (closer) opts.add(nb);
      if (closer) opts.add(nb);
    }
    if (opts.isEmpty) return null;
    cur = r.pick(opts);
    seen.add(cur);
    path.add(cur);
  }
  return cur == to ? path : null;
}

// =================================================================== Dişli Atölyesi

class DisliPuzzle extends OPuzzle {
  final int w, h;
  final int motor;
  final List<int> targets;
  final Set<int> rocks;
  final Set<int> solution;
  const DisliPuzzle(this.w, this.h, this.motor, this.targets, this.rocks, this.solution);

  Set<int> powered(Set<int> gears) {
    final all = {...gears, motor, ...targets};
    final out = {motor};
    final stack = [motor];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      final x = c % w, y = c ~/ w;
      for (final d in kDirs4) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final nb = ny * w + nx;
        if (all.contains(nb) && out.add(nb)) stack.add(nb);
      }
    }
    return out;
  }

  bool solved(Set<int> gears) => gears.length <= solution.length && powered(gears).containsAll(targets);
}

class DisliKind extends OzgunKind {
  @override
  String get id => 'disli';
  const DisliKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final w = 5 + d ~/ 4, h = w + 1;
    final cells = [for (var i = 0; i < w * h; i++) i];
    r.shuffle(cells);
    final motor = cells[0];
    final nt = 1 + d ~/ 4;
    final targets = <int>[];
    for (final c in cells.skip(1)) {
      if (targets.length >= nt) break;
      final far = (c % w - motor % w).abs() + (c ~/ w - motor ~/ w).abs() >= 3;
      if (far && targets.every((t) => (c % w - t % w).abs() + (c ~/ w - t ~/ w).abs() >= 2)) targets.add(c);
    }
    if (targets.length < nt) return null;
    final rocks = <int>{};
    final nr = (w * h * (0.12 + d * 0.012)).round();
    for (final c in cells.skip(1)) {
      if (rocks.length >= nr) break;
      if (!targets.contains(c)) rocks.add(c);
    }
    final sol = <int>{};
    for (final t in targets) {
      final path = _walk(w, h, motor, t, {...rocks, ...targets}, r);
      if (path == null) return null;
      for (final c in path) {
        if (c != motor && !targets.contains(c)) sol.add(c);
      }
    }
    // Gereksiz dişlileri ayıkla (bağlantı korunuyorsa).
    for (final c in sol.toList()) {
      final rest = {...sol}..remove(c);
      if (DisliPuzzle(w, h, motor, targets, rocks, rest).powered(rest).containsAll(targets)) sol.remove(c);
    }
    if (sol.length < 2) return null;
    return DisliPuzzle(w, h, motor, targets, rocks, sol);
  }

  @override
  bool check(OPuzzle p) => p is DisliPuzzle && p.solved(p.solution) && p.rocks.intersection(p.solution).isEmpty;

  @override
  Widget build(OzgunPlay play) => _DisliView(play: play);
}

class _DisliView extends StatefulWidget {
  final OzgunPlay play;
  const _DisliView({required this.play});
  @override
  State<_DisliView> createState() => _DisliViewState();
}

class _DisliViewState extends State<_DisliView> with Clock, SingleTickerProviderStateMixin {
  late final DisliPuzzle p = widget.play.puzzle as DisliPuzzle;
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  Set<int> gears = {};
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.w || y >= p.h) return;
    final c = y * p.w + x;
    if (c == p.motor || p.targets.contains(c) || p.rocks.contains(c)) return;
    if (gears.contains(c)) {
      setState(() => gears = {...gears}..remove(c));
    } else {
      if (gears.length >= p.solution.length) {
        widget.play.sfx(Sfx.error);
        return;
      }
      setState(() => gears = {...gears, c});
    }
    moves++;
    widget.play.sfx(Sfx.place);
    if (p.solved(gears)) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1200, () => widget.play.win(stars: starsByMoves(moves, p.solution.length, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 8));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final wrong = gears.where((g) => !p.solution.contains(g)).toList();
    final missing = p.solution.where((g) => !gears.contains(g)).toList();
    if (missing.isEmpty) return;
    hints++;
    setState(() {
      gears = {...gears};
      if (gears.length >= p.solution.length && wrong.isNotEmpty) gears.remove(wrong.first);
      gears.add(missing.first);
    });
    if (p.solved(gears)) {
      ended = true;
      later(1200, () => widget.play.win(stars: 1, seconds: seconds, hints: hints));
    }
  }

  void _gear(Canvas c, Offset m, double rad, double angle, Color col) {
    c.save();
    c.translate(m.dx, m.dy);
    c.rotate(angle);
    const teeth = 8;
    for (var k = 0; k < teeth; k++) {
      c.save();
      c.rotate(k * 2 * math.pi / teeth);
      c.drawRect(Rect.fromCenter(center: Offset(0, -rad), width: rad * 0.35, height: rad * 0.35), fill(col));
      c.restore();
    }
    c.drawCircle(Offset.zero, rad * 0.86, fill(col));
    c.drawCircle(Offset.zero, rad * 0.28, fill(const Color(0xFF3B2F25)));
    c.restore();
  }

  @override
  Widget build(BuildContext context) {
    final left = p.solution.length - gears.length;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '⚙ $left',
        status: clock(),
        onReset: ended ? null : () => setState(() => gears = {}),
        onHint: _hint,
      ),
      board: AnimatedBuilder(
        animation: spin,
        builder: (context, _) {
          final on = p.powered(gears);
          final a = spin.value * 2 * math.pi;
          return TapCanvas(
            w: p.w.toDouble(),
            h: p.h.toDouble(),
            onTap: _tap,
            paint: (c) {
              c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, p.w.toDouble(), p.h.toDouble()), const Radius.circular(0.3)), fill(const Color(0xFFE8DCC6)));
              for (var i = 0; i < p.w * p.h; i++) {
                final m = Offset(i % p.w + 0.5, i ~/ p.w + 0.5);
                final par = ((i % p.w) + (i ~/ p.w) - (p.motor % p.w) - (p.motor ~/ p.w)).isEven ? 1 : -1;
                final ang = on.contains(i) ? a * par + (par < 0 ? math.pi / 8 : 0) : 0.0;
                if (p.rocks.contains(i)) {
                  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 0.86, height: 0.86), const Radius.circular(0.18)), fill(const Color(0xFF8A7F72)));
                } else if (i == p.motor) {
                  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 0.9, height: 0.9), const Radius.circular(0.15)), fill(const Color(0xFF3E6FB0)));
                  _gear(c, m, 0.36, ang, const Color(0xFFD9A441));
                } else if (p.targets.contains(i)) {
                  c.drawCircle(m, 0.46, fill(on.contains(i) ? const Color(0xFFF6E7B0) : Colors.white));
                  c.drawCircle(m, 0.46, stroke(const Color(0xFF5B4636), 0.06));
                  final hand = on.contains(i) ? a * 3 * par : 0.0;
                  c.drawLine(m, m + Offset(math.sin(hand) * 0.3, -math.cos(hand) * 0.3), stroke(OColors.ink, 0.05));
                  c.drawLine(m, m + const Offset(0, -0.2), stroke(OColors.ink, 0.07));
                } else if (gears.contains(i)) {
                  _gear(c, m, 0.38, ang, on.contains(i) ? const Color(0xFFB8860B) : const Color(0xFF9C8F7A));
                } else {
                  c.drawCircle(m, 0.06, fill(const Color(0x665B4636)));
                }
              }
            },
          );
        },
      ),
    );
  }
}

// =================================================================== Işık Yolu

class IsikPuzzle extends OPuzzle {
  final int n;
  final int source; // ilk hücre
  final int dir; // kDirs4 indeksi
  final Map<int, int> mirrors; // hücre → çözüm yönü (0 '/', 1 '\')
  final Map<int, int> start; // hücre → başlangıç yönü
  final Set<int> targets;
  final Set<int> walls;
  const IsikPuzzle(this.n, this.source, this.dir, this.mirrors, this.start, this.targets, this.walls);

  /// Işının geçtiği hücreler (sırasıyla).
  List<int> beam(Map<int, int> ori) {
    final out = <int>[];
    final seen = <int>{};
    var x = source % n, y = source ~/ n, dx = kDirs4[dir][0], dy = kDirs4[dir][1];
    for (var step = 0; step < n * n * 4; step++) {
      if (x < 0 || y < 0 || x >= n || y >= n) break;
      final c = y * n + x;
      if (walls.contains(c)) break;
      if (!seen.add(c * 8 + (dx + 1) * 3 + (dy + 1))) break;
      out.add(c);
      final m = ori[c];
      if (m != null) {
        final t = dx;
        if (m == 0) {
          dx = -dy;
          dy = -t;
        } else {
          dx = dy;
          dy = t;
        }
      }
      x += dx;
      y += dy;
    }
    return out;
  }

  bool solved(Map<int, int> ori) => beam(ori).toSet().containsAll(targets);
}

class IsikKind extends OzgunKind {
  @override
  String get id => 'isik';
  const IsikKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 5 + d ~/ 3;
    final dir = r.nextInt(4);
    final dx0 = kDirs4[dir][0], dy0 = kDirs4[dir][1];
    // Kaynak, ışının girdiği kenarda.
    final along = r.nextInt(n);
    var x = dx0 == 1 ? 0 : (dx0 == -1 ? n - 1 : along);
    var y = dy0 == 1 ? 0 : (dy0 == -1 ? n - 1 : along);
    final source = y * n + x;
    final used = <int>{source};
    final mirrors = <int, int>{};
    final pathCells = <int>[source];
    var dx = dx0, dy = dy0;
    final want = 2 + d ~/ 2;
    while (mirrors.length < want) {
      final len = 1 + r.nextInt(3);
      var ok = true;
      for (var k = 0; k < len; k++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n || used.contains(ny * n + nx)) {
          ok = false;
          break;
        }
        x = nx;
        y = ny;
        used.add(y * n + x);
        pathCells.add(y * n + x);
      }
      if (!ok && mirrors.isEmpty && pathCells.length < 2) return null;
      // Dönüş: sol ya da sağ, içeride kalan.
      var turned = false;
      for (final m in r.chance(0.5) ? const [0, 1] : const [1, 0]) {
        final ndx = m == 0 ? -dy : dy, ndy = m == 0 ? -dx : dx;
        final nx = x + ndx, ny = y + ndy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n || used.contains(ny * n + nx)) continue;
        if (mirrors.containsKey(y * n + x) || y * n + x == source) continue;
        mirrors[y * n + x] = m;
        dx = ndx;
        dy = ndy;
        turned = true;
        break;
      }
      if (!turned) break;
    }
    if (mirrors.length < 2) return null;
    // Son düz parça ve hedef.
    final len = 1 + r.nextInt(3);
    for (var k = 0; k < len; k++) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n || used.contains(ny * n + nx)) break;
      x = nx;
      y = ny;
      used.add(y * n + x);
      pathCells.add(y * n + x);
    }
    final end = y * n + x;
    if (mirrors.containsKey(end) || end == source) return null;
    final targets = {end};
    final plain = pathCells.where((c) => !mirrors.containsKey(c) && c != source && c != end).toList();
    r.shuffle(plain);
    for (final c in plain.take(d >= 4 ? 1 + d ~/ 5 : 0)) {
      targets.add(c);
    }
    final free = [for (var i = 0; i < n * n; i++) if (!used.contains(i)) i];
    r.shuffle(free);
    final decoys = d ~/ 2;
    final walls = <int>{};
    var fi = 0;
    final all = {...mirrors};
    for (var k = 0; k < decoys && fi < free.length; k++) {
      all[free[fi++]] = r.nextInt(2);
    }
    for (var k = 0; k < (d >= 3 ? 2 + d ~/ 3 : 0) && fi < free.length; k++) {
      walls.add(free[fi++]);
    }
    final start = {for (final e in all.entries) e.key: r.nextInt(2)};
    final p = IsikPuzzle(n, source, dir, all, start, targets, walls);
    if (!p.solved(all)) return null;
    if (p.solved(start)) {
      final k = mirrors.keys.first;
      start[k] = 1 - all[k]!;
      if (p.solved(start)) return null;
    }
    return p;
  }

  @override
  bool check(OPuzzle p) => p is IsikPuzzle && p.solved(p.mirrors) && !p.solved(p.start);

  @override
  Widget build(OzgunPlay play) => _IsikView(play: play);
}

class _IsikView extends StatefulWidget {
  final OzgunPlay play;
  const _IsikView({required this.play});
  @override
  State<_IsikView> createState() => _IsikViewState();
}

class _IsikViewState extends State<_IsikView> with Clock {
  late final IsikPuzzle p = widget.play.puzzle as IsikPuzzle;
  late Map<int, int> ori = {...p.start};
  late final int par = p.mirrors.keys.where((k) => p.start[k] != p.mirrors[k]).length;
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.n || y >= p.n) return;
    final c = y * p.n + x;
    final m = ori[c];
    if (m == null) return;
    setState(() {
      ori = {...ori, c: 1 - m};
      moves++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    if (ended || !p.solved(ori)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(800, () => widget.play.win(stars: starsByMoves(moves, par, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 10));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final beam = p.beam(p.mirrors);
    for (final c in beam) {
      final want = p.mirrors[c];
      if (want != null && ori[c] != want) {
        hints++;
        setState(() => ori = {...ori, c: want});
        _check();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    final beam = p.beam(ori);
    final lit = beam.toSet();
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${ot(widget.play.lang, 'moves')}: $moves',
        status: clock(),
        onReset: ended ? null : () => setState(() => ori = {...p.start}),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: n + 1.0,
        h: n + 1.0,
        onTap: (o) => _tap(o - const Offset(0.5, 0.5)),
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, n + 1.0, n + 1.0), const Radius.circular(0.3)), fill(const Color(0xFF1B2333)));
          c.translate(0.5, 0.5);
          for (var i = 0; i < n * n; i++) {
            final r = Rect.fromLTWH(i % n + 0.04, i ~/ n + 0.04, 0.92, 0.92);
            c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.08)), fill(const Color(0xFF26314A)));
          }
          // Kaynak.
          final sx = p.source % n - kDirs4[p.dir][0] * 0.55 + 0.5, sy = p.source ~/ n - kDirs4[p.dir][1] * 0.55 + 0.5;
          c.drawCircle(Offset(sx, sy), 0.22, fill(const Color(0xFFFFD166)));
          // Işın.
          if (beam.isNotEmpty) {
            final path = Path()..moveTo(sx, sy);
            for (final cell in beam) {
              path.lineTo(cell % n + 0.5, cell ~/ n + 0.5);
            }
            final last = beam.last;
            final lx = last % n + 0.5, ly = last ~/ n + 0.5;
            final tail = beam.length >= 2 ? Offset(lx, ly) - Offset(beam[beam.length - 2] % n + 0.5, beam[beam.length - 2] ~/ n + 0.5) : Offset(kDirs4[p.dir][0].toDouble(), kDirs4[p.dir][1].toDouble());
            if (!p.mirrors.containsKey(last)) path.lineTo(lx + tail.dx * 0.5, ly + tail.dy * 0.5);
            c.drawPath(path, stroke(const Color(0x66FFD166), 0.24));
            c.drawPath(path, stroke(const Color(0xFFFFF3C4), 0.07));
          }
          for (final w in p.walls) {
            c.drawRect(Rect.fromLTWH(w % n + 0.08, w ~/ n + 0.08, 0.84, 0.84), fill(const Color(0xFF6B5B4B)));
          }
          for (final t in p.targets) {
            final m = Offset(t % n + 0.5, t ~/ n + 0.5);
            final on = lit.contains(t);
            final gem = Path()
              ..moveTo(m.dx, m.dy - 0.3)
              ..lineTo(m.dx + 0.26, m.dy)
              ..lineTo(m.dx, m.dy + 0.3)
              ..lineTo(m.dx - 0.26, m.dy)
              ..close();
            if (on) c.drawCircle(m, 0.42, fill(const Color(0x5534C6B8)));
            c.drawPath(gem, fill(on ? const Color(0xFF34C6B8) : const Color(0xFF3B6E6A)));
          }
          for (final e in ori.entries) {
            final m = Offset(e.key % n + 0.5, e.key ~/ n + 0.5);
            final a = e.value == 0 ? Offset(0.32, -0.32) : Offset(0.32, 0.32);
            c.drawLine(m - a, m + a, stroke(const Color(0xFFB8C4D9), 0.13));
            c.drawLine(m - a, m + a, stroke(Colors.white, 0.04));
          }
        },
      ),
    );
  }
}

// =================================================================== Döner Dünya

class DonerPuzzle extends OPuzzle {
  final int n;
  final Set<int> walls;
  final int ball;
  final int goal;
  final int best;
  const DonerPuzzle(this.n, this.walls, this.ball, this.goal, this.best);

  /// Dünya [q] çeyrek saat yönünde döndüğünde tahtadaki yerçekimi.
  static List<int> gravity(int q) => const [
        [0, 1],
        [1, 0],
        [0, -1],
        [-1, 0],
      ][q % 4];

  /// Topu düşürür; hedeften geçerse hedefte durur. (son hücre, hedefe vardı mı)
  (int, bool) slide(int at, int q) {
    final g = gravity(q);
    var x = at % n, y = at ~/ n;
    while (true) {
      if (y * n + x == goal) return (goal, true);
      final nx = x + g[0], ny = y + g[1];
      if (nx < 0 || ny < 0 || nx >= n || ny >= n || walls.contains(ny * n + nx)) return (y * n + x, false);
      x = nx;
      y = ny;
    }
  }

  /// En az hamle (dönüş) ve ilk hamle (-1 sol, +1 sağ).
  (int, int) solve(int at, int q) {
    final startKey = at * 4 + q % 4;
    final dist = <int, int>{startKey: 0};
    final first = <int, int>{startKey: 0};
    final queue = [startKey];
    for (var qi = 0; qi < queue.length; qi++) {
      final k = queue[qi];
      final c = k ~/ 4, qq = k % 4;
      for (final turn in const [-1, 1]) {
        final nq = (qq + turn) % 4;
        final (cell, won) = slide(c, nq);
        final f = first[k] == 0 ? turn : first[k]!;
        if (won) return (dist[k]! + 1, f);
        final nk = cell * 4 + nq;
        if (dist.containsKey(nk)) continue;
        dist[nk] = dist[k]! + 1;
        first[nk] = f;
        queue.add(nk);
      }
    }
    return (-1, 0);
  }
}

class DonerKind extends OzgunKind {
  @override
  String get id => 'doner';
  const DonerKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 5 + d ~/ 4;
    final need = math.min(6, 2 + d ~/ 2);
    for (var attempt = 0; attempt < 20; attempt++) {
      final walls = <int>{};
      for (var i = 0; i < n * n; i++) {
        if (r.chance(0.2)) walls.add(i);
      }
      final free = [for (var i = 0; i < n * n; i++) if (!walls.contains(i)) i];
      if (free.length < 6) continue;
      final goal = r.pick(free);
      var ball = r.pick(free);
      if (ball == goal) continue;
      final probe = DonerPuzzle(n, walls, ball, goal, 0);
      final (settled, won) = probe.slide(ball, 0);
      if (won) continue;
      ball = settled;
      final (best, _) = DonerPuzzle(n, walls, ball, goal, 0).solve(ball, 0);
      if (best < need) continue;
      return DonerPuzzle(n, walls, ball, goal, best);
    }
    return null;
  }

  @override
  bool check(OPuzzle p) => p is DonerPuzzle && p.best > 0 && p.solve(p.ball, 0).$1 == p.best && !p.slide(p.ball, 0).$2;

  @override
  Widget build(OzgunPlay play) => _DonerView(play: play);
}

class _DonerView extends StatefulWidget {
  final OzgunPlay play;
  const _DonerView({required this.play});
  @override
  State<_DonerView> createState() => _DonerViewState();
}

class _DonerViewState extends State<_DonerView> with Clock {
  late final DonerPuzzle p = widget.play.puzzle as DonerPuzzle;
  late int ball = p.ball;
  int q = 0; // toplam çeyrek dönüş (animasyon için işaretli)
  int moves = 0, hints = 0;
  bool busy = false;
  final List<(int, int)> hist = [];

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _turn(int t) {
    if (ended || busy) return;
    hist.add((ball, q));
    setState(() {
      q += t;
      moves++;
      busy = true;
    });
    widget.play.sfx(Sfx.tap);
    later(320, () {
      final (cell, won) = p.slide(ball, q % 4);
      setState(() {
        ball = cell;
        busy = false;
      });
      if (won) {
        ended = true;
        widget.play.sfx(Sfx.win);
        later(700, () => widget.play.win(stars: starsByMoves(moves, p.best, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 20));
      } else {
        widget.play.sfx(Sfx.place);
      }
    });
  }

  Future<void> _hint() async {
    if (ended || busy || !await widget.play.ctx.requestHint()) return;
    final (_, first) = p.solve(ball, q % 4);
    if (first == 0) return;
    hints++;
    _turn(first);
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${ot(widget.play.lang, 'moves')}: $moves',
        status: clock(),
        onUndo: hist.isEmpty || ended || busy
            ? null
            : () => setState(() {
                  final (b, qq) = hist.removeLast();
                  ball = b;
                  q = qq;
                }),
        onReset: ended || busy
            ? null
            : () => setState(() {
                  ball = p.ball;
                  q = 0;
                  hist.clear();
                }),
        onHint: _hint,
      ),
      board: AnimatedRotation(
        turns: q / 4,
        duration: const Duration(milliseconds: 300),
        child: TapCanvas(
          w: n + 0.4,
          h: n + 0.4,
          paint: (c) {
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, n + 0.4, n + 0.4), const Radius.circular(0.3)), fill(const Color(0xFF5B4636)));
            c.translate(0.2, 0.2);
            c.drawRect(Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), fill(const Color(0xFFF1E6D2)));
            for (final w in p.walls) {
              c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w % n + 0.04, w ~/ n + 0.04, 0.92, 0.92), const Radius.circular(0.1)), fill(const Color(0xFF8B6B4A)));
            }
            final g = Offset(p.goal % n + 0.5, p.goal ~/ n + 0.5);
            c.drawCircle(g, 0.36, fill(const Color(0xFF2B2B2B)));
            c.drawCircle(g, 0.36, stroke(OColors.gold, 0.06));
            final b = Offset(ball % n + 0.5, ball ~/ n + 0.5);
            c.drawCircle(b, 0.34, fill(const Color(0xFFC8453B)));
            c.drawCircle(b + const Offset(-0.1, -0.1), 0.1, fill(Colors.white.withValues(alpha: 0.5)));
          },
        ),
      ),
      bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OChip(onTap: busy ? null : () => _turn(-1), child: const Icon(Icons.rotate_left, size: 32)),
        const SizedBox(width: 24),
        OChip(onTap: busy ? null : () => _turn(1), child: const Icon(Icons.rotate_right, size: 32)),
      ]),
    );
  }
}

// =================================================================== Domino Zinciri

/// Parça: 1 düz, 2 sola dönüş, 3 sağa dönüş.
class DominoPuzzle extends OPuzzle {
  final int w, h;
  final int start;
  final int dir;
  final int bell;
  final Set<int> rocks;
  final Map<int, int> solution;
  final Map<int, int> fixed;
  const DominoPuzzle(this.w, this.h, this.start, this.dir, this.bell, this.rocks, this.solution, this.fixed);

  int get needPlain => solution.entries.where((e) => e.value == 1 && !fixed.containsKey(e.key)).length;
  int get needTurn => solution.entries.where((e) => e.value != 1 && !fixed.containsKey(e.key)).length;

  /// Devrilen hücreler ve zilin çalıp çalmadığı.
  (List<int>, bool) run(Map<int, int> pieces) {
    var dx = kDirs4[dir][0], dy = kDirs4[dir][1];
    var x = start % w + dx, y = start ~/ w + dy;
    final fallen = <int>[start];
    final seen = <int>{};
    while (true) {
      if (x < 0 || y < 0 || x >= w || y >= h) return (fallen, false);
      final c = y * w + x;
      if (c == bell) return (fallen, true);
      final pc = pieces[c];
      if (pc == null || !seen.add(c)) return (fallen, false);
      fallen.add(c);
      final t = dx;
      if (pc == 2) {
        dx = dy;
        dy = -t;
      } else if (pc == 3) {
        dx = -dy;
        dy = t;
      }
      x += dx;
      y += dy;
    }
  }
}

class DominoKind extends OzgunKind {
  @override
  String get id => 'domino';
  const DominoKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final w = 6 + d ~/ 4, h = w + 1;
    final dir = r.nextInt(4);
    var dx = kDirs4[dir][0], dy = kDirs4[dir][1];
    var x = r.range(1, w - 2), y = r.range(1, h - 2);
    final start = y * w + x;
    final used = {start};
    final sol = <int, int>{};
    final turnsWant = 1 + d ~/ 2;
    var turns = 0;
    var steps = 0;
    var straight = 0;
    while (steps < w * h) {
      steps++;
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || used.contains(ny * w + nx)) break;
      x = nx;
      y = ny;
      final c = y * w + x;
      used.add(c);
      straight++;
      if (turns >= turnsWant && straight >= 2 && r.chance(0.4)) break;
      var piece = 1;
      if (straight >= 1 && r.chance(0.45)) {
        for (final t in r.chance(0.5) ? const [2, 3] : const [3, 2]) {
          final ndx = t == 2 ? dy : -dy, ndy = t == 2 ? -dx : dx;
          final ax = x + ndx, ay = y + ndy;
          if (ax < 0 || ay < 0 || ax >= w || ay >= h || used.contains(ay * w + ax)) continue;
          piece = t;
          dx = ndx;
          dy = ndy;
          turns++;
          straight = 0;
          break;
        }
      }
      sol[c] = piece;
    }
    // Son eklenen hücre zil olur.
    if (sol.length < 4 || turns < 1) return null;
    final bell = sol.keys.last;
    sol.remove(bell);
    final cells = [for (var i = 0; i < w * h; i++) if (!used.contains(i)) i];
    r.shuffle(cells);
    final rocks = cells.take((w * h * 0.12).round()).toSet();
    final keys = sol.keys.toList();
    r.shuffle(keys);
    final fixedN = (keys.length * math.max(0.15, 0.5 - d * 0.04)).round();
    final fixed = {for (final k in keys.take(fixedN)) k: sol[k]!};
    final p = DominoPuzzle(w, h, start, dir, bell, rocks, sol, fixed);
    if (!p.run(sol).$2 || p.needPlain + p.needTurn < 2) return null;
    return p;
  }

  @override
  bool check(OPuzzle p) => p is DominoPuzzle && p.run(p.solution).$2 && !p.run(p.fixed).$2;

  @override
  Widget build(OzgunPlay play) => _DominoView(play: play);
}

class _DominoView extends StatefulWidget {
  final OzgunPlay play;
  const _DominoView({required this.play});
  @override
  State<_DominoView> createState() => _DominoViewState();
}

class _DominoViewState extends State<_DominoView> with Clock {
  late final DominoPuzzle p = widget.play.puzzle as DominoPuzzle;
  late Map<int, int> pieces = {...p.fixed};
  List<int> fallen = [];
  bool running = false;
  int tries = 0, hints = 0;
  Timer? anim;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  void dispose() {
    anim?.cancel();
    super.dispose();
  }

  int get usedPlain => pieces.entries.where((e) => e.value == 1 && !p.fixed.containsKey(e.key)).length;
  int get usedTurn => pieces.entries.where((e) => e.value != 1 && !p.fixed.containsKey(e.key)).length;

  void _tap(Offset o) {
    if (ended || running) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= p.w || y >= p.h) return;
    final c = y * p.w + x;
    if (c == p.start || c == p.bell || p.rocks.contains(c) || p.fixed.containsKey(c)) return;
    final cur = pieces[c] ?? 0;
    // Sıradaki geçerli parça: boş → düz → sola → sağa → boş.
    var next = (cur + 1) % 4;
    while (next != 0) {
      final plainOk = next == 1 && (usedPlain - (cur == 1 ? 1 : 0)) < p.needPlain;
      final turnOk = next != 1 && (usedTurn - (cur >= 2 ? 1 : 0)) < p.needTurn;
      if (plainOk || turnOk) break;
      next = (next + 1) % 4;
    }
    setState(() {
      fallen = [];
      final m = {...pieces};
      if (next == 0) {
        m.remove(c);
      } else {
        m[c] = next;
      }
      pieces = m;
    });
    widget.play.sfx(Sfx.tap);
  }

  void _go() {
    if (ended || running) return;
    final (cells, ok) = p.run(pieces);
    tries++;
    setState(() {
      running = true;
      fallen = [];
    });
    var k = 0;
    anim = Timer.periodic(const Duration(milliseconds: 140), (t) {
      if (!mounted) return;
      if (k < cells.length) {
        setState(() => fallen = cells.sublist(0, ++k));
        widget.play.sfx(Sfx.tap);
        return;
      }
      t.cancel();
      setState(() => running = false);
      if (ok) {
        ended = true;
        widget.play.sfx(Sfx.win);
        later(600, () => widget.play.win(stars: clampI(4 - tries - hints, 1, 3), seconds: seconds, hints: hints, score: 1000 - tries * 100));
      } else {
        widget.play.sfx(Sfx.error);
      }
    });
  }

  Future<void> _hint() async {
    if (ended || running || !await widget.play.ctx.requestHint()) return;
    for (final e in p.solution.entries) {
      if (pieces[e.key] != e.value) {
        hints++;
        setState(() {
          final m = {...pieces};
          // Yer açmak için yanlış bir parçayı kaldır.
          final kind = e.value == 1 ? 1 : 2;
          final full = kind == 1 ? usedPlain >= p.needPlain : usedTurn >= p.needTurn;
          if (full) {
            final wrong = m.entries.where((x) => !p.fixed.containsKey(x.key) && p.solution[x.key] != x.value && ((x.value == 1) == (kind == 1))).toList();
            if (wrong.isNotEmpty) m.remove(wrong.first.key);
          }
          m[e.key] = e.value;
          pieces = m;
          fallen = [];
        });
        return;
      }
    }
  }

  void _arrow(Canvas c, Offset m, int dx, int dy, Color col, double s) {
    final a = math.atan2(dy.toDouble(), dx.toDouble());
    c.save();
    c.translate(m.dx, m.dy);
    c.rotate(a);
    final path = Path()
      ..moveTo(s, 0)
      ..lineTo(-s * 0.6, -s * 0.6)
      ..lineTo(-s * 0.6, s * 0.6)
      ..close();
    c.drawPath(path, fill(col));
    c.restore();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final fs = fallen.toSet();
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '▮ ${p.needPlain - usedPlain}  ↱ ${p.needTurn - usedTurn}',
        status: clock(),
        onReset: ended || running
            ? null
            : () => setState(() {
                  pieces = {...p.fixed};
                  fallen = [];
                }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: p.w.toDouble(),
        h: p.h.toDouble(),
        onTap: _tap,
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, p.w.toDouble(), p.h.toDouble()), const Radius.circular(0.25)), fill(const Color(0xFF3F6E5A)));
          for (var i = 0; i < p.w * p.h; i++) {
            final m = Offset(i % p.w + 0.5, i ~/ p.w + 0.5);
            c.drawCircle(m, 0.04, fill(const Color(0x33FFFFFF)));
            if (p.rocks.contains(i)) {
              c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 0.8, height: 0.8), const Radius.circular(0.2)), fill(const Color(0xFF6E6358)));
            }
          }
          final s = Offset(p.start % p.w + 0.5, p.start ~/ p.w + 0.5);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: s, width: 0.34, height: 0.8), const Radius.circular(0.06)), fill(const Color(0xFFD9A441)));
          _arrow(c, s + Offset(kDirs4[p.dir][0] * 0.34, kDirs4[p.dir][1] * 0.34), kDirs4[p.dir][0], kDirs4[p.dir][1], Colors.white, 0.14);
          final b = Offset(p.bell % p.w + 0.5, p.bell ~/ p.w + 0.5);
          final bell = Path()
            ..moveTo(b.dx - 0.3, b.dy + 0.22)
            ..quadraticBezierTo(b.dx - 0.26, b.dy - 0.34, b.dx, b.dy - 0.34)
            ..quadraticBezierTo(b.dx + 0.26, b.dy - 0.34, b.dx + 0.3, b.dy + 0.22)
            ..close();
          c.drawPath(bell, fill(const Color(0xFFE9C46A)));
          c.drawCircle(b + const Offset(0, 0.28), 0.07, fill(const Color(0xFFE9C46A)));
          for (final e in pieces.entries) {
            final m = Offset(e.key % p.w + 0.5, e.key ~/ p.w + 0.5);
            final down = fs.contains(e.key);
            final fixed = p.fixed.containsKey(e.key);
            final col = fixed ? const Color(0xFFF4EBDC) : const Color(0xFFFFFFFF);
            if (e.value == 1) {
              c.drawRRect(
                  RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: down ? 0.8 : 0.3, height: down ? 0.3 : 0.8), const Radius.circular(0.06)), fill(down ? const Color(0xFFB8C4A0) : col));
              if (fixed) c.drawCircle(m, 0.05, fill(OColors.ink));
            } else {
              final arc = Path()
                ..moveTo(m.dx - 0.3, m.dy + 0.3)
                ..quadraticBezierTo(m.dx - 0.3, m.dy - 0.3, m.dx + 0.3, m.dy - 0.3);
              c.drawPath(arc, stroke(down ? const Color(0xFFB8C4A0) : col, 0.22));
              drawLabel(c, e.value == 2 ? '↺' : '↻', m + const Offset(0.12, 0.12), 0.36, fixed ? OColors.ink : const Color(0xFF2E5E8C));
            }
          }
          if (fallen.isNotEmpty && !running && !ended) {
            final last = fallen.last;
            c.drawCircle(Offset(last % p.w + 0.5, last ~/ p.w + 0.5), 0.45, stroke(OColors.bad, 0.06));
          }
        },
      ),
      bottom: FilledButton.icon(
        onPressed: running || ended ? null : _go,
        icon: const Icon(Icons.play_arrow),
        label: Text(ot(lang, 'go')),
      ),
    );
  }
}

// =================================================================== Tren Makası

class TrenNode {
  final int depth;
  final List<int> kids;
  double y = 0;
  TrenNode(this.depth, this.kids);
}

class TrenPuzzle extends OPuzzle {
  final List<TrenNode> nodes; // 0 kök
  final List<int> leaves; // düğüm kimlikleri, istasyon sırası = renk
  final List<int> trains; // istasyon (renk) indeksi
  final int depth;
  final bool timed;
  const TrenPuzzle(this.nodes, this.leaves, this.trains, this.depth, this.timed);

  int colorOf(int node) => leaves.indexOf(node);
}

class TrenKind extends OzgunKind {
  @override
  String get id => 'tren';
  const TrenKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final depth = 2 + d ~/ 4;
    final nodes = <TrenNode>[TrenNode(0, [])];
    void grow(int id) {
      final nd = nodes[id];
      if (nd.depth >= depth) return;
      final two = nd.depth == 0 || r.chance(0.78);
      for (var k = 0; k < (two ? 2 : 1); k++) {
        nodes.add(TrenNode(nd.depth + 1, []));
        nd.kids.add(nodes.length - 1);
        grow(nodes.length - 1);
      }
    }

    grow(0);
    final leaves = <int>[];
    void order(int id) {
      if (nodes[id].kids.isEmpty) {
        leaves.add(id);
      } else {
        for (final k in nodes[id].kids) {
          order(k);
        }
      }
    }

    order(0);
    if (leaves.length < 3 || leaves.length > 8) return null;
    for (var i = 0; i < leaves.length; i++) {
      nodes[leaves[i]].y = i + 0.5;
    }
    double place(int id) {
      final nd = nodes[id];
      if (nd.kids.isEmpty) return nd.y;
      final ys = nd.kids.map(place).toList();
      nd.y = ys.reduce((a, b) => a + b) / ys.length;
      return nd.y;
    }

    place(0);
    final trains = [for (var i = 0; i < 4 + d; i++) r.nextInt(leaves.length)];
    return TrenPuzzle(nodes, leaves, trains, depth, d >= 4);
  }

  @override
  bool check(OPuzzle p) => p is TrenPuzzle && p.leaves.length >= 3 && p.trains.every((t) => t >= 0 && t < p.leaves.length);

  @override
  Widget build(OzgunPlay play) => _TrenView(play: play);
}

const List<Color> _stationCols = [
  Color(0xFFC8453B),
  Color(0xFF2E5E8C),
  Color(0xFFD9A441),
  Color(0xFF4F7F52),
  Color(0xFF7A4E7E),
  Color(0xFFE07A5F),
  Color(0xFF3A8D8C),
  Color(0xFF5B4636),
];

class _Train {
  final int color;
  int from; // -1 depo
  int to;
  double t = 0;
  _Train(this.color, this.from, this.to);
}

class _TrenView extends StatefulWidget {
  final OzgunPlay play;
  const _TrenView({required this.play});
  @override
  State<_TrenView> createState() => _TrenViewState();
}

class _TrenViewState extends State<_TrenView> with Clock {
  late final TrenPuzzle p = widget.play.puzzle as TrenPuzzle;
  late final List<int> sw = List<int>.filled(p.nodes.length, 0);
  final List<_Train> moving = [];
  int sent = 0, delivered = 0, hearts = 3, hints = 0;
  double sinceSpawn = 99;
  bool started = false;
  Timer? frame;
  final List<(int, bool)> flashes = [];

  late final double spawnEvery = math.max(2.6, 6.2 - widget.play.d * 0.35);
  late final double speed = 0.9 + widget.play.d * 0.06; // kenar / saniye

  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  void dispose() {
    frame?.cancel();
    super.dispose();
  }

  void _start() {
    if (started) return;
    setState(() => started = true);
    frame = Timer.periodic(const Duration(milliseconds: 50), (_) => _step(0.05));
  }

  void _step(double dt) {
    if (!mounted || ended) return;
    sinceSpawn += dt;
    final canSpawn = sent < p.trains.length && (p.timed ? sinceSpawn >= spawnEvery : moving.isEmpty && sinceSpawn >= 0.8);
    if (canSpawn) {
      moving.add(_Train(p.trains[sent], -1, 0));
      sent++;
      sinceSpawn = 0;
    }
    final done = <_Train>[];
    for (final tr in moving) {
      tr.t += dt * speed;
      if (tr.t < 1) continue;
      final at = p.nodes[tr.to];
      if (at.kids.isEmpty) {
        done.add(tr);
        final ok = p.colorOf(tr.to) == tr.color;
        if (ok) {
          delivered++;
          widget.play.sfx(Sfx.coin);
        } else {
          hearts--;
          widget.play.sfx(Sfx.error);
        }
        flashes.add((tr.to, ok));
        later(700, () => setState(() => flashes.removeAt(0)));
        continue;
      }
      final next = at.kids.length == 1 ? at.kids[0] : at.kids[sw[tr.to]];
      tr.from = tr.to;
      tr.to = next;
      tr.t -= 1;
    }
    moving.removeWhere(done.contains);
    if (hearts <= 0) {
      ended = true;
      frame?.cancel();
      later(700, () => widget.play.lose(seconds: seconds, score: delivered * 50));
    } else if (sent >= p.trains.length && moving.isEmpty) {
      ended = true;
      frame?.cancel();
      widget.play.sfx(Sfx.win);
      later(700, () => widget.play.win(stars: hearts - hints, seconds: seconds, hints: hints, score: delivered * 100));
    }
    setState(() {});
  }

  Offset pos(int id) => id < 0 ? Offset(0.3, p.nodes[0].y) : Offset(1.2 + p.nodes[id].depth * 1.8, p.nodes[id].y);

  void _tap(Offset o) {
    if (ended) return;
    if (!started) _start();
    for (var i = 0; i < p.nodes.length; i++) {
      if (p.nodes[i].kids.length == 2 && (pos(i) - o).distance < 0.55) {
        setState(() => sw[i] = 1 - sw[i]);
        widget.play.sfx(Sfx.tap);
        return;
      }
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    // Önde giden trenin yolundaki makasları doğru konuma getir.
    final tr = moving.isNotEmpty ? moving.first : null;
    final color = tr?.color ?? (sent < p.trains.length ? p.trains[sent] : null);
    if (color == null) return;
    hints++;
    final goal = p.leaves[color];
    bool route(int id) {
      if (id == goal) return true;
      final kids = p.nodes[id].kids;
      for (var k = 0; k < kids.length; k++) {
        if (route(kids[k])) {
          if (kids.length == 2) sw[id] = k;
          return true;
        }
      }
      return false;
    }

    setState(() => route(0));
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final w = 1.2 + p.depth * 1.8 + 1.2;
    final h = p.leaves.length.toDouble();
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${'♥' * clampI(hearts, 0, 3)}${'♡' * (3 - clampI(hearts, 0, 3))}',
        status: '$delivered/${p.trains.length} · ${clock()}',
        onHint: _hint,
      ),
      top: SizedBox(
        height: 30,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = sent; i < p.trains.length; i++)
            Container(
              width: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(color: _stationCols[p.trains[i]], borderRadius: BorderRadius.circular(6)),
            ),
        ]),
      ),
      board: TapCanvas(
        w: w,
        h: h,
        onTap: _tap,
        paint: (c) {
          final rail = stroke(const Color(0xFF6B5B4B), 0.12);
          final sleeper = stroke(const Color(0xFFB9AE9B), 0.06);
          void track(Offset a, Offset b) {
            final mid = Offset((a.dx + b.dx) / 2, a.dy);
            final path = Path()
              ..moveTo(a.dx, a.dy)
              ..lineTo(mid.dx - 0.3, a.dy)
              ..quadraticBezierTo(mid.dx, a.dy, mid.dx, (a.dy + b.dy) / 2)
              ..quadraticBezierTo(mid.dx, b.dy, mid.dx + 0.3, b.dy)
              ..lineTo(b.dx, b.dy);
            c.drawPath(path, sleeper..strokeWidth = 0.3);
            c.drawPath(path, rail);
          }

          track(pos(-1), pos(0));
          for (var i = 0; i < p.nodes.length; i++) {
            for (final k in p.nodes[i].kids) {
              track(pos(i), pos(k));
            }
          }
          for (var i = 0; i < p.nodes.length; i++) {
            final nd = p.nodes[i];
            if (nd.kids.length == 2) {
              final m = pos(i);
              c.drawCircle(m, 0.34, fill(Colors.white));
              c.drawCircle(m, 0.34, stroke(OColors.ink, 0.05));
              final tgt = pos(nd.kids[sw[i]]);
              final dir = Offset(1, (tgt.dy - m.dy).sign * 0.8);
              final u = dir / dir.distance;
              c.drawLine(m - u * 0.2, m + u * 0.24, stroke(OColors.accent, 0.1));
            }
          }
          for (var li = 0; li < p.leaves.length; li++) {
            final m = pos(p.leaves[li]) + const Offset(0.6, 0);
            final house = Path()
              ..moveTo(m.dx - 0.3, m.dy + 0.3)
              ..lineTo(m.dx - 0.3, m.dy - 0.05)
              ..lineTo(m.dx, m.dy - 0.35)
              ..lineTo(m.dx + 0.3, m.dy - 0.05)
              ..lineTo(m.dx + 0.3, m.dy + 0.3)
              ..close();
            c.drawPath(house, fill(_stationCols[li]));
            for (final f in flashes) {
              if (f.$1 == p.leaves[li]) c.drawCircle(m, 0.45, stroke(f.$2 ? OColors.good : OColors.bad, 0.08));
            }
          }
          for (final tr in moving) {
            final a = pos(tr.from), b = pos(tr.to);
            final mid = (a.dx + b.dx) / 2;
            final t = clampD(tr.t, 0.0, 1.0);
            // Önce yatay, sonra dikey, sonra yatay giden yaklaşık konum.
            Offset at;
            if (t < 0.4) {
              at = Offset(a.dx + (mid - a.dx) * (t / 0.4), a.dy);
            } else if (t < 0.6) {
              at = Offset(mid, a.dy + (b.dy - a.dy) * ((t - 0.4) / 0.2));
            } else {
              at = Offset(mid + (b.dx - mid) * ((t - 0.6) / 0.4), b.dy);
            }
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 0.6, height: 0.34), const Radius.circular(0.08)), fill(_stationCols[tr.color]));
            c.drawRect(Rect.fromCenter(center: at + const Offset(0.12, -0.02), width: 0.16, height: 0.12), fill(Colors.white.withValues(alpha: 0.8)));
          }
          if (!started) drawLabel(c, '▶', pos(-1) + const Offset(0.1, -0.45), 0.4, OColors.good);
        },
      ),
      bottom: started
          ? null
          : FilledButton.icon(onPressed: _start, icon: const Icon(Icons.train), label: Text(ot(lang, 'go'))),
    );
  }
}

// =================================================================== Kum Saati

/// Açıklık maskesi: 1 K, 2 D, 4 G, 8 B.
int rotMask(int m, int r) {
  var x = m;
  for (var i = 0; i < r % 4; i++) {
    x = ((x << 1) | (x >> 3)) & 15;
  }
  return x;
}

class KumPuzzle extends OPuzzle {
  final int w, h;
  final int source; // sütun
  final List<int> cups; // sütunlar
  final List<int> mask; // çözülmüş maske (0 boş, -1 kaya)
  final List<int> rot; // başlangıç dönüşü
  const KumPuzzle(this.w, this.h, this.source, this.cups, this.mask, this.rot);

  int cur(int i, List<int> rots) => mask[i] <= 0 ? 0 : rotMask(mask[i], rots[i]);

  /// Kumun ulaştığı hücreler, dolan bardaklar ve taşma.
  (Set<int>, Set<int>, bool) flow(List<int> rots) {
    final reached = <int>{};
    final filled = <int>{};
    var spill = false;
    final first = source;
    if (cur(first, rots) & 1 == 0) return (reached, filled, false);
    final stack = [first];
    reached.add(first);
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      final m = cur(c, rots);
      final x = c % w, y = c ~/ w;
      for (var d = 0; d < 4; d++) {
        if (m & (1 << d) == 0) continue;
        if (d == 0) {
          if (y == 0 && x == source) continue; // kaynağın girişi
          final up = (y - 1) * w + x;
          if (y == 0 || cur(up, rots) & 4 == 0) spill = true;
          continue; // kum yukarı çıkmaz
        }
        final nx = x + kDirs4[d][0], ny = y + kDirs4[d][1];
        if (ny >= h) {
          if (cups.contains(x)) {
            filled.add(x);
          } else {
            spill = true;
          }
          continue;
        }
        if (nx < 0 || nx >= w) {
          spill = true;
          continue;
        }
        final nb = ny * w + nx;
        final back = (d + 2) % 4;
        if (cur(nb, rots) & (1 << back) == 0) {
          spill = true;
          continue;
        }
        if (reached.add(nb)) stack.add(nb);
      }
    }
    return (reached, filled, spill);
  }

  bool solved(List<int> rots) {
    final (_, filled, spill) = flow(rots);
    return !spill && filled.length == cups.length;
  }
}

class KumKind extends OzgunKind {
  @override
  String get id => 'kum';
  const KumKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final w = 4 + d ~/ 4, h = 5 + d ~/ 3;
    final nc = math.min(w - 1, 1 + d ~/ 4);
    final source = r.nextInt(w);
    final cols = [for (var x = 0; x < w; x++) x]..remove(source);
    r.shuffle(cols);
    final cups = cols.take(nc).toList();
    if (nc > 1 && r.chance(0.5)) cups[0] = source;
    final mask = List<int>.filled(w * h, 0);
    mask[source] |= 1;
    for (final cx in cups) {
      var x = source, y = 0;
      while (y < h) {
        final c = y * w + x;
        if (y == h - 1 && x == cx) {
          mask[c] |= 4;
          break;
        }
        final side = x != cx && (y == h - 1 || r.chance(0.45));
        if (side) {
          final dx = cx > x ? 1 : -1;
          mask[c] |= dx > 0 ? 2 : 8;
          x += dx;
          mask[y * w + x] |= dx > 0 ? 8 : 2;
        } else {
          mask[c] |= 4;
          y++;
          mask[y * w + x] |= 1;
        }
      }
    }
    // Boş hücreler: süs parçaları ve kayalar.
    final rot = List<int>.filled(w * h, 0);
    for (var i = 0; i < w * h; i++) {
      if (mask[i] == 0) {
        mask[i] = r.chance(0.18) ? -1 : const [5, 3, 7, 6][r.nextInt(4)];
      }
      rot[i] = r.nextInt(4);
    }
    final p = KumPuzzle(w, h, source, cups, mask, rot);
    if (!p.solved(List<int>.filled(w * h, 0))) return null;
    if (p.solved(rot)) return null;
    return p;
  }

  @override
  bool check(OPuzzle p) => p is KumPuzzle && p.solved(List<int>.filled(p.w * p.h, 0)) && !p.solved(p.rot);

  @override
  Widget build(OzgunPlay play) => _KumView(play: play);
}

class _KumView extends StatefulWidget {
  final OzgunPlay play;
  const _KumView({required this.play});
  @override
  State<_KumView> createState() => _KumViewState();
}

class _KumViewState extends State<_KumView> with Clock {
  late final KumPuzzle p = widget.play.puzzle as KumPuzzle;
  late List<int> rot = List.of(p.rot);
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = (o.dy - 1).floor();
    if (x < 0 || y < 0 || x >= p.w || y >= p.h) return;
    final i = y * p.w + x;
    if (p.mask[i] <= 0) return;
    setState(() {
      rot = List.of(rot);
      rot[i] = (rot[i] + 1) % 4;
      moves++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    if (ended || !p.solved(rot)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(900, () => widget.play.win(stars: starsByMoves(moves, p.w * p.h ~/ 2, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 5));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    // Çözüm yolundaki ilk yanlış parçayı düzelt.
    final (reachedSol, _, _) = p.flow(List<int>.filled(p.w * p.h, 0));
    final order = reachedSol.toList()..sort();
    for (final i in order) {
      if (p.cur(i, rot) != p.mask[i]) {
        hints++;
        setState(() {
          rot = List.of(rot);
          rot[i] = 0;
        });
        _check();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (reached, filled, spill) = p.flow(rot);
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${filled.length}/${p.cups.length}',
        status: '${ot(widget.play.lang, 'moves')}: $moves · ${clock()}',
        onReset: ended ? null : () => setState(() => rot = List.of(p.rot)),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: p.w.toDouble(),
        h: p.h + 2.0,
        onTap: _tap,
        paint: (c) {
          const sand = Color(0xFFE2B866);
          // Kaynak huni.
          final sx = p.source + 0.5;
          final funnel = Path()
            ..moveTo(sx - 0.45, 0.1)
            ..lineTo(sx + 0.45, 0.1)
            ..lineTo(sx + 0.12, 0.95)
            ..lineTo(sx - 0.12, 0.95)
            ..close();
          c.drawPath(funnel, fill(sand));
          c.drawPath(funnel, stroke(const Color(0xFF8B6B4A), 0.05));
          c.drawRect(Rect.fromLTWH(0, 1, p.w.toDouble(), p.h.toDouble()), fill(const Color(0xFF4B3B2F)));
          for (var i = 0; i < p.w * p.h; i++) {
            final x = i % p.w, y = i ~/ p.w;
            final m = Offset(x + 0.5, y + 1.5);
            if (p.mask[i] < 0) {
              c.drawCircle(m, 0.36, fill(const Color(0xFF7D6E62)));
              continue;
            }
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 0.94, height: 0.94), const Radius.circular(0.1)), fill(const Color(0xFF6A5444)));
            final msk = p.cur(i, rot);
            final full = reached.contains(i);
            final col = full ? sand : const Color(0xFFCDBBA7);
            for (var dd = 0; dd < 4; dd++) {
              if (msk & (1 << dd) == 0) continue;
              c.drawLine(m, m + Offset(kDirs4[dd][0] * 0.5, kDirs4[dd][1] * 0.5), stroke(col, 0.3));
            }
            if (msk != 0) c.drawCircle(m, 0.15, fill(col));
          }
          for (var x = 0; x < p.w; x++) {
            final m = Offset(x + 0.5, p.h + 1.5);
            if (!p.cups.contains(x)) continue;
            final glass = Path()
              ..moveTo(m.dx - 0.35, m.dy - 0.4)
              ..lineTo(m.dx + 0.35, m.dy - 0.4)
              ..lineTo(m.dx + 0.08, m.dy)
              ..lineTo(m.dx + 0.35, m.dy + 0.4)
              ..lineTo(m.dx - 0.35, m.dy + 0.4)
              ..lineTo(m.dx - 0.08, m.dy)
              ..close();
            c.drawPath(glass, fill(const Color(0x33FFFFFF)));
            if (filled.contains(x)) c.drawRect(Rect.fromLTRB(m.dx - 0.3, m.dy + 0.1, m.dx + 0.3, m.dy + 0.38), fill(sand));
            c.drawPath(glass, stroke(const Color(0xFF8B6B4A), 0.05));
          }
          if (spill) drawLabel(c, '!', Offset(p.w - 0.3, 0.5), 0.6, OColors.bad);
        },
      ),
    );
  }
}
