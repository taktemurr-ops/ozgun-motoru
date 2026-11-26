import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// Atölye: Kündekâri, Tezhip, Cam Boncuk Fırını ve Çömlek Çarkı.

const List<List<int>> _d4 = [
  [0, -1],
  [1, 0],
  [0, 1],
  [-1, 0],
];

// =================================================================== Kündekâri

/// Geçmeli tahta parçası: hücre konumları (çapaya göre) ve her hücrenin dört
/// kenarındaki geçme profili (+k erkek, −k dişi, 0 düz).
class KPiece {
  final List<int> dx;
  final List<int> dy;
  final List<List<int>> ed;
  const KPiece(this.dx, this.dy, this.ed);
  int get size => dx.length;

  String get key {
    final b = StringBuffer();
    for (var i = 0; i < size; i++) {
      b.write('${dx[i]},${dy[i]}:${ed[i].join(',')};');
    }
    return b.toString();
  }
}

class KundePuzzle extends OPuzzle {
  final int n;
  final List<KPiece> pieces;

  /// Çözümde her parçanın çapa hücresi (y * n + x).
  final List<int> sol;
  const KundePuzzle(this.n, this.pieces, this.sol);

  /// Yerleşimi hücre → (parça, parça içi hücre) olarak çıkarır; çakışma ya da
  /// taşma varsa null.
  List<List<int>?>? layout(List<int> pos) {
    final occ = List<List<int>?>.filled(n * n, null);
    for (var i = 0; i < pieces.length; i++) {
      final a = pos[i];
      if (a < 0) continue;
      final p = pieces[i];
      for (var c = 0; c < p.size; c++) {
        final x = a % n + p.dx[c], y = a ~/ n + p.dy[c];
        if (x < 0 || y < 0 || x >= n || y >= n || occ[y * n + x] != null) return null;
        occ[y * n + x] = [i, c];
      }
    }
    return occ;
  }

  /// Uyuşmayan kenarlar: (hücre, yön) listesi.
  List<List<int>> mismatches(List<int> pos) {
    final occ = layout(pos);
    final out = <List<int>>[];
    if (occ == null) return out;
    for (var cell = 0; cell < n * n; cell++) {
      final o = occ[cell];
      if (o == null) continue;
      final e = pieces[o[0]].ed[o[1]];
      final x = cell % n, y = cell ~/ n;
      for (var k = 0; k < 4; k++) {
        final nx = x + _d4[k][0], ny = y + _d4[k][1];
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) {
          if (e[k] != 0) out.add([cell, k]);
          continue;
        }
        final m = occ[ny * n + nx];
        if (m == null) {
          if (e[k] == 0) out.add([cell, k]);
          continue;
        }
        if (m[0] == o[0]) continue;
        if (pieces[m[0]].ed[m[1]][(k + 2) % 4] != -e[k]) out.add([cell, k]);
      }
    }
    return out;
  }

  bool solved(List<int> pos) {
    if (pos.any((a) => a < 0)) return false;
    final occ = layout(pos);
    if (occ == null || occ.any((o) => o == null)) return false;
    return mismatches(pos).isEmpty;
  }

  /// Parça, [anchor] çapasıyla serbest hücrelere sığıyor mu?
  bool fitsFree(int i, int anchor, List<int> pos) {
    final occ = layout([for (var j = 0; j < pos.length; j++) j == i ? -1 : pos[j]]);
    if (occ == null) return false;
    final p = pieces[i];
    for (var c = 0; c < p.size; c++) {
      final x = anchor % n + p.dx[c], y = anchor ~/ n + p.dy[c];
      if (x < 0 || y < 0 || x >= n || y >= n || occ[y * n + x] != null) return false;
    }
    return true;
  }
}

/// Çözüm sayısını (en çok [limit]) sayar: her adımda okuma sırasındaki ilk boş
/// hücreye bir parçanın çapası gelmek zorundadır.
int countKunde(int n, List<KPiece> pieces, {int limit = 2}) {
  final occ = List<List<int>?>.filled(n * n, null);
  final used = List<bool>.filled(pieces.length, false);
  var count = 0;
  var steps = 0;

  bool fits(KPiece p, int ax, int ay) {
    for (var c = 0; c < p.size; c++) {
      final x = ax + p.dx[c], y = ay + p.dy[c];
      if (x < 0 || y < 0 || x >= n || y >= n || occ[y * n + x] != null) return false;
    }
    for (var c = 0; c < p.size; c++) {
      final x = ax + p.dx[c], y = ay + p.dy[c];
      final e = p.ed[c];
      for (var k = 0; k < 4; k++) {
        final nx = x + _d4[k][0], ny = y + _d4[k][1];
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) {
          if (e[k] != 0) return false;
        } else {
          if (e[k] == 0) return false;
          final o = occ[ny * n + nx];
          if (o != null && o[(k + 2) % 4] != -e[k]) return false;
        }
      }
    }
    return true;
  }

  void rec() {
    if (count >= limit || steps > 200000) return;
    steps++;
    final f = occ.indexOf(null);
    if (f < 0) {
      count++;
      return;
    }
    final ax = f % n, ay = f ~/ n;
    final seen = <String>{};
    for (var i = 0; i < pieces.length; i++) {
      if (used[i]) continue;
      final p = pieces[i];
      if (!seen.add(p.key)) continue;
      if (!fits(p, ax, ay)) continue;
      used[i] = true;
      for (var c = 0; c < p.size; c++) {
        occ[(ay + p.dy[c]) * n + ax + p.dx[c]] = p.ed[c];
      }
      rec();
      for (var c = 0; c < p.size; c++) {
        occ[(ay + p.dy[c]) * n + ax + p.dx[c]] = null;
      }
      used[i] = false;
    }
  }

  rec();
  return steps > 200000 ? limit : count;
}

class KundekariKind extends OzgunKind {
  @override
  String get id => 'kundekari';
  const KundekariKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = d <= 2 ? 3 : (d <= 4 ? 4 : (d <= 7 ? 5 : 6));
    final kinds = 2 + d ~/ 4;
    final e = List.generate(n * n, (_) => List<int>.filled(4, 0));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        if (x + 1 < n) {
          final v = r.range(1, kinds) * (r.chance(0.5) ? 1 : -1);
          e[i][1] = v;
          e[i + 1][3] = -v;
        }
        if (y + 1 < n) {
          final v = r.range(1, kinds) * (r.chance(0.5) ? 1 : -1);
          e[i][2] = v;
          e[i + n][0] = -v;
        }
      }
    }
    final own = List<int>.filled(n * n, -1);
    final order = [for (var i = 0; i < n * n; i++) i];
    r.shuffle(order);
    final groups = <List<int>>[];
    final mx = d <= 3 ? 2 : (d <= 7 ? 3 : 4);
    for (final s in order) {
      if (own[s] >= 0) continue;
      final want = r.range(1, mx);
      final cells = [s];
      own[s] = groups.length;
      while (cells.length < want) {
        final fr = <int>[];
        for (final c in cells) {
          for (final dd in _d4) {
            final x = c % n + dd[0], y = c ~/ n + dd[1];
            if (x >= 0 && y >= 0 && x < n && y < n && own[y * n + x] < 0) fr.add(y * n + x);
          }
        }
        if (fr.isEmpty) break;
        final c = r.pick(fr);
        own[c] = groups.length;
        cells.add(c);
      }
      cells.sort();
      groups.add(cells);
    }
    if (groups.length < 3) return null;
    r.shuffle(groups);
    final pieces = <KPiece>[];
    final sol = <int>[];
    for (final g in groups) {
      final a = g.first;
      pieces.add(KPiece(
        [for (final c in g) c % n - a % n],
        [for (final c in g) c ~/ n - a ~/ n],
        [for (final c in g) List<int>.of(e[c])],
      ));
      sol.add(a);
    }
    if (countKunde(n, pieces) != 1) return null;
    return KundePuzzle(n, pieces, sol);
  }

  @override
  bool check(OPuzzle p) => p is KundePuzzle && p.pieces.length == p.sol.length && p.solved(p.sol);

  @override
  Widget build(OzgunPlay play) => _KundeView(play: play);
}

const _wood = [Color(0xFF9C6B3F), Color(0xFFB7834F), Color(0xFF8A5A33), Color(0xFFC49563), Color(0xFF7B4E2C)];
const _joint = [Color(0xFFD9A441), Color(0xFF3E6FB0), Color(0xFFB23A48), Color(0xFF4F7F52)];

void _paintJoint(Canvas c, Offset at, int v, double s) {
  if (v == 0) return;
  final k = (v.abs() - 1) % 4;
  final col = _joint[k];
  final paint = v > 0 ? fill(col) : stroke(col, s * 0.35);
  final r = s;
  switch (k) {
    case 0:
      c.drawCircle(at, r, paint);
    case 1:
      c.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - r)
            ..lineTo(at.dx + r, at.dy + r * 0.8)
            ..lineTo(at.dx - r, at.dy + r * 0.8)
            ..close(),
          paint);
    case 2:
      c.drawRect(Rect.fromCenter(center: at, width: r * 1.7, height: r * 1.7), paint);
    default:
      c.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - r * 1.1)
            ..lineTo(at.dx + r * 1.1, at.dy)
            ..lineTo(at.dx, at.dy + r * 1.1)
            ..lineTo(at.dx - r * 1.1, at.dy)
            ..close(),
          paint);
  }
}

/// Hücre ortasına sekiz köşeli yıldız (girih esinli).
void _paintStar(Canvas c, Offset ctr, double r, Color col) {
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8 - math.pi / 2;
    final rr = i.isEven ? r : r * 0.55;
    final p = ctr + Offset(math.cos(a) * rr, math.sin(a) * rr);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  c.drawPath(path, stroke(col, r * 0.12));
}

void _paintCell(Canvas c, Rect rc, List<int> e, Color wood) {
  c.drawRRect(RRect.fromRectAndRadius(rc.deflate(rc.width * 0.02), Radius.circular(rc.width * 0.06)), fill(wood));
  _paintStar(c, rc.center, rc.width * 0.26, const Color(0x66F4E3C1));
  final s = rc.width * 0.09;
  final mids = [
    Offset(rc.center.dx, rc.top + s * 1.6),
    Offset(rc.right - s * 1.6, rc.center.dy),
    Offset(rc.center.dx, rc.bottom - s * 1.6),
    Offset(rc.left + s * 1.6, rc.center.dy),
  ];
  for (var k = 0; k < 4; k++) {
    _paintJoint(c, mids[k], e[k], s);
  }
}

class _KundeView extends StatefulWidget {
  final OzgunPlay play;
  const _KundeView({required this.play});
  @override
  State<_KundeView> createState() => _KundeViewState();
}

class _KundeViewState extends State<_KundeView> with Clock {
  late final KundePuzzle p = widget.play.puzzle as KundePuzzle;
  late List<int> pos = List<int>.filled(p.pieces.length, -1);
  final List<List<int>> hist = [];
  int? sel;
  int hints = 0, moves = 0;
  static const double ts = 0.42; // tepsi ölçeği
  late final double trayW = math.max(p.n.toDouble(), 6.0);
  late final List<Offset> slots = _slots();
  late final double trayH = slots.isEmpty ? 0 : slots.map((o) => o.dy).reduce(math.max) + 4 * ts + 0.3 - (p.n + 0.5);

  List<Offset> _slots() {
    final out = <Offset>[];
    const sw = 4 * ts + 0.35;
    final cols = math.max(1, (trayW / sw).floor());
    for (var i = 0; i < p.pieces.length; i++) {
      out.add(Offset((i % cols) * sw + 0.2, p.n + 0.5 + (i ~/ cols) * (4 * ts + 0.2)));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _push() => hist.add(List.of(pos));

  bool _tryPlace(int i, int cell) {
    final pc = p.pieces[i];
    for (var c = 0; c < pc.size; c++) {
      final ax = cell % p.n - pc.dx[c], ay = cell ~/ p.n - pc.dy[c];
      if (ax < 0 || ay < 0 || ax >= p.n || ay >= p.n) continue;
      final a = ay * p.n + ax;
      if (p.fitsFree(i, a, pos)) {
        _push();
        setState(() {
          pos[i] = a;
          sel = null;
          moves++;
        });
        widget.play.sfx(Sfx.place);
        _check();
        return true;
      }
    }
    return false;
  }

  void _tap(Offset o) {
    if (ended) return;
    if (o.dy < p.n && o.dx >= 0 && o.dx < p.n && o.dy >= 0) {
      final cell = o.dy.floor() * p.n + o.dx.floor();
      final s = sel;
      if (s != null) {
        if (!_tryPlace(s, cell)) widget.play.sfx(Sfx.error);
        return;
      }
      final occ = p.layout(pos);
      final at = occ?[cell];
      if (at != null) {
        _push();
        setState(() {
          pos[at[0]] = -1;
          sel = at[0];
        });
        widget.play.sfx(Sfx.tap);
      }
      return;
    }
    for (var i = 0; i < slots.length; i++) {
      final r = Rect.fromLTWH(slots[i].dx, slots[i].dy, 4 * ts + 0.2, 4 * ts);
      if (r.contains(o) && pos[i] < 0) {
        setState(() => sel = sel == i ? null : i);
        widget.play.sfx(Sfx.tap);
        return;
      }
    }
  }

  void _check() {
    if (ended || !p.solved(pos)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    final par = p.pieces.length;
    later(700, () => widget.play.win(stars: starsByMoves(moves, par, hints: hints), seconds: seconds, hints: hints, score: 1500 - seconds - moves * 5));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < pos.length; i++) {
      if (pos[i] == p.sol[i]) continue;
      _push();
      final pc = p.pieces[i];
      final want = <int>{for (var c = 0; c < pc.size; c++) (p.sol[i] ~/ p.n + pc.dy[c]) * p.n + p.sol[i] % p.n + pc.dx[c]};
      final occ = p.layout(pos);
      setState(() {
        if (occ != null) {
          for (final w in want) {
            final o = occ[w];
            if (o != null) pos[o[0]] = -1;
          }
        }
        pos[i] = p.sol[i];
        sel = null;
        hints++;
      });
      _check();
      return;
    }
  }

  void _paint(Canvas c) {
    final n = p.n;
    final fr = Rect.fromLTWH(-0.12, -0.12, n + 0.24, n + 0.24);
    c.drawRRect(RRect.fromRectAndRadius(fr, const Radius.circular(0.18)), fill(const Color(0xFF4A2F1B)));
    c.drawRect(Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), fill(const Color(0xFF2E1D12)));
    final occ = p.layout(pos);
    final bad = <int>{for (final m in p.mismatches(pos)) m[0] * 4 + m[1]};
    if (occ != null) {
      for (var cell = 0; cell < n * n; cell++) {
        final o = occ[cell];
        if (o == null) continue;
        final rc = Rect.fromLTWH((cell % n).toDouble(), (cell ~/ n).toDouble(), 1, 1);
        _paintCell(c, rc, p.pieces[o[0]].ed[o[1]], _wood[o[0] % _wood.length]);
        for (var k = 0; k < 4; k++) {
          if (!bad.contains(cell * 4 + k)) continue;
          final a = [rc.topLeft, rc.topRight, rc.bottomRight, rc.bottomLeft];
          c.drawLine(a[k], a[(k + 1) % 4], stroke(OColors.bad, 0.07));
        }
      }
      // Parça sınırları
      for (var cell = 0; cell < n * n; cell++) {
        final o = occ[cell];
        if (o == null) continue;
        final x = cell % n, y = cell ~/ n;
        for (var k = 0; k < 4; k++) {
          final nx = x + _d4[k][0], ny = y + _d4[k][1];
          final same = nx >= 0 && ny >= 0 && nx < n && ny < n && occ[ny * n + nx]?[0] == o[0];
          if (same) continue;
          final rc = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);
          final a = [rc.topLeft, rc.topRight, rc.bottomRight, rc.bottomLeft];
          c.drawLine(a[k], a[(k + 1) % 4], stroke(const Color(0xFF2B1A0E), 0.035));
        }
      }
    }
    // Tepsi
    for (var i = 0; i < p.pieces.length; i++) {
      if (pos[i] >= 0) continue;
      final o = slots[i];
      if (sel == i) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 0.08, o.dy - 0.08, 4 * ts + 0.16, 4 * ts + 0.16), const Radius.circular(0.12)),
            fill(OColors.gold.withValues(alpha: 0.35)));
      }
      final pc = p.pieces[i];
      final minX = pc.dx.reduce(math.min);
      for (var cc = 0; cc < pc.size; cc++) {
        final rc = Rect.fromLTWH(o.dx + (pc.dx[cc] - minX) * ts, o.dy + pc.dy[cc] * ts, ts, ts);
        _paintCell(c, rc, pc.ed[cc], _wood[i % _wood.length]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final left = pos.where((a) => a < 0).length;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: clock(),
        status: '${ot(lang, 'moves')}: $moves · $left',
        onUndo: hist.isEmpty
            ? null
            : () => setState(() {
                  pos = hist.removeLast();
                  sel = null;
                }),
        onReset: () => setState(() {
          _push();
          pos = List<int>.filled(p.pieces.length, -1);
          sel = null;
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: trayW,
        h: p.n + 0.5 + trayH,
        paint: _paint,
        onTap: _tap,
        semantics: 'Kündekâri ${p.n}×${p.n}',
      ),
    );
  }
}

// =================================================================== Tezhip

/// Tezhip: düzlemin bir dilimi boyanır, simetri deseni dışa doğru açar.
/// mode 0: iki eksenli ayna, 1: dörtlü dönme, 2: sekizli (ayna + köşegen).
class TezhipPuzzle extends OPuzzle {
  final int n;
  final int mode;
  final int quad;
  final int colors;
  final List<int> target;
  final List<int> rep; // her hücrenin boyanabilir temsilcisi
  final int par;
  const TezhipPuzzle(this.n, this.mode, this.quad, this.colors, this.target, this.rep, this.par);

  bool editable(int i) => rep[i] == i;
}

List<int> tezhipOrbit(int n, int mode, int i) {
  final x = i % n, y = i ~/ n, m = n - 1;
  final pts = <List<int>>[];
  if (mode == 1) {
    pts.addAll([
      [x, y],
      [m - y, x],
      [m - x, m - y],
      [y, m - x],
    ]);
  } else {
    pts.addAll([
      [x, y],
      [m - x, y],
      [x, m - y],
      [m - x, m - y],
    ]);
    if (mode == 2) {
      pts.addAll([
        [y, x],
        [m - y, x],
        [y, m - x],
        [m - y, m - x],
      ]);
    }
  }
  final s = <int>{for (final p in pts) p[1] * n + p[0]};
  return s.toList()..sort();
}

int _quadOf(int n, int i) => (i % n < n ~/ 2 ? 0 : 1) + (i ~/ n < n ~/ 2 ? 0 : 2);

List<int> tezhipReps(int n, int mode, int quad) {
  final rep = List<int>.filled(n * n, -1);
  for (var i = 0; i < n * n; i++) {
    if (rep[i] >= 0) continue;
    final orb = tezhipOrbit(n, mode, i);
    final inQ = orb.where((j) => _quadOf(n, j) == quad).toList();
    final r = inQ.isEmpty ? orb.first : inQ.first;
    for (final j in orb) {
      rep[j] = r;
    }
  }
  return rep;
}

/// Boyanabilir dilimdeki renk bileşenleri: her biri tek fırça darbesiyle boyanabilir.
int tezhipPar(int n, List<int> target, List<int> rep) {
  final seen = List<bool>.filled(n * n, false);
  var comps = 0;
  for (var i = 0; i < n * n; i++) {
    if (rep[i] != i || seen[i] || target[i] == 0) continue;
    comps++;
    final q = <int>[i];
    seen[i] = true;
    while (q.isNotEmpty) {
      final c = q.removeLast();
      for (final dd in _d4) {
        final x = c % n + dd[0], y = c ~/ n + dd[1];
        if (x < 0 || y < 0 || x >= n || y >= n) continue;
        final j = y * n + x;
        if (seen[j] || rep[j] != j || target[j] != target[i]) continue;
        seen[j] = true;
        q.add(j);
      }
    }
  }
  return comps;
}

class TezhipKind extends OzgunKind {
  @override
  String get id => 'tezhip';
  const TezhipKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = d <= 2 ? 6 : (d <= 5 ? 8 : (d <= 8 ? 10 : 12));
    final mode = d <= 3 ? 0 : (d <= 6 ? r.range(0, 1) : r.range(1, 2));
    final quad = mode == 2 ? 0 : r.nextInt(4);
    final colors = d <= 2 ? 2 : (d <= 6 ? 3 : 4);
    final rep = tezhipReps(n, mode, quad);
    final reps = [for (var i = 0; i < n * n; i++) if (rep[i] == i) i];
    // Tohumlardan büyüyen motif lekeleri.
    final val = List<int>.filled(n * n, 0);
    final seeds = 2 + d ~/ 2;
    for (var s = 0; s < seeds; s++) {
      final col = 1 + r.nextInt(colors);
      var c = r.pick(reps);
      final len = 2 + r.nextInt(3 + d ~/ 2);
      for (var k = 0; k < len; k++) {
        val[c] = col;
        final dd = _d4[r.nextInt(4)];
        final x = c % n + dd[0], y = c ~/ n + dd[1];
        if (x < 0 || y < 0 || x >= n || y >= n) continue;
        final j = y * n + x;
        if (rep[j] == j) c = j;
      }
    }
    final target = [for (var i = 0; i < n * n; i++) val[rep[i]]];
    final filled = reps.where((i) => target[i] != 0).length;
    if (filled < reps.length * 0.25 || filled > reps.length * 0.75) return null;
    final used = <int>{for (final i in reps) target[i]}..remove(0);
    if (used.length < math.min<int>(colors, 2)) return null;
    final par = tezhipPar(n, target, rep);
    if (par < 2) return null;
    return TezhipPuzzle(n, mode, quad, colors, target, rep, par);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! TezhipPuzzle) return false;
    for (var i = 0; i < p.n * p.n; i++) {
      for (final j in tezhipOrbit(p.n, p.mode, i)) {
        if (p.target[j] != p.target[i] || p.rep[j] != p.rep[i]) return false;
      }
      if (p.target[i] < 0 || p.target[i] > p.colors) return false;
    }
    return p.par >= 1;
  }

  @override
  Widget build(OzgunPlay play) => _TezhipView(play: play);
}

const _tezhipPal = [Color(0xFFF4EBD9), Color(0xFF1F4E8C), Color(0xFFD4A017), Color(0xFF2E8B8B), Color(0xFFA2322E)];

class _TezhipView extends StatefulWidget {
  final OzgunPlay play;
  const _TezhipView({required this.play});
  @override
  State<_TezhipView> createState() => _TezhipViewState();
}

class _TezhipViewState extends State<_TezhipView> with Clock {
  late final TezhipPuzzle p = widget.play.puzzle as TezhipPuzzle;
  late List<int> cur = List<int>.filled(p.n * p.n, 0);
  final List<List<int>> hist = [];
  int color = 1, strokes = 0, hints = 0;
  bool painted = false;
  late final double thumb = p.n * 0.36;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  int? _cell(Offset o) {
    final y0 = thumb + 0.4;
    final x = o.dx.floor(), y = (o.dy - y0).floor();
    if (x < 0 || y < 0 || x >= p.n || y >= p.n) return null;
    return y * p.n + x;
  }

  void _paintAt(Offset o) {
    final i = _cell(o);
    if (i == null || ended || !p.editable(i) || cur[i] == color) return;
    if (!painted) {
      hist.add(List.of(cur));
      strokes++;
      painted = true;
    }
    setState(() {
      for (final j in tezhipOrbit(p.n, p.mode, i)) {
        cur[j] = color;
      }
    });
  }

  void _start(Offset o) {
    painted = false;
    _paintAt(o);
    if (painted) widget.play.sfx(Sfx.tap);
  }

  void _end() {
    painted = false;
    _check();
  }

  void _check() {
    if (ended) return;
    for (var i = 0; i < cur.length; i++) {
      if (cur[i] != p.target[i]) return;
    }
    ended = true;
    widget.play.sfx(Sfx.win);
    later(800, () => widget.play.win(stars: starsByMoves(strokes, p.par, hints: hints), seconds: seconds, hints: hints, score: 1200 - seconds - strokes * 10));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var i = 0; i < cur.length; i++) {
      if (!p.editable(i) || cur[i] == p.target[i]) continue;
      hist.add(List.of(cur));
      setState(() {
        for (final j in tezhipOrbit(p.n, p.mode, i)) {
          cur[j] = p.target[i];
        }
        hints++;
      });
      _check();
      return;
    }
  }

  void _paint(Canvas c) {
    final n = p.n;
    final t = thumb / n;
    final tx = (n - thumb) / 2;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tx - 0.12, -0.05, thumb + 0.24, thumb + 0.24), const Radius.circular(0.15)),
        fill(const Color(0xFF15365F)));
    for (var i = 0; i < n * n; i++) {
      c.drawRect(Rect.fromLTWH(tx + (i % n) * t, 0.07 + (i ~/ n) * t, t * 1.02, t * 1.02), fill(_tezhipPal[p.target[i]]));
    }
    final y0 = thumb + 0.4;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-0.1, y0 - 0.1, n + 0.2, n + 0.2), const Radius.circular(0.2)), fill(const Color(0xFFD4A017)));
    for (var i = 0; i < n * n; i++) {
      final rc = Rect.fromLTWH((i % n).toDouble(), y0 + (i ~/ n), 1, 1);
      c.drawRect(rc, fill(_tezhipPal[cur[i]]));
      if (!p.editable(i)) c.drawRect(rc, fill(const Color(0x22000000)));
      c.drawRect(rc, stroke(const Color(0x33000000), 0.02));
    }
    // simetri eksenleri
    final g = stroke(const Color(0x88D4A017), 0.05);
    c.drawLine(Offset(n / 2, y0), Offset(n / 2, y0 + n), g);
    c.drawLine(Offset(0, y0 + n / 2), Offset(n.toDouble(), y0 + n / 2), g);
    if (p.mode == 2) {
      c.drawLine(Offset(0, y0), Offset(n.toDouble(), y0 + n), g);
      c.drawLine(Offset(n.toDouble(), y0), Offset(0, y0 + n), g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: clock(),
        status: '${ot(lang, 'strokes')}: $strokes / ${p.par}',
        onUndo: hist.isEmpty ? null : () => setState(() => cur = hist.removeLast()),
        onReset: () => setState(() {
          hist.add(List.of(cur));
          cur = List<int>.filled(p.n * p.n, 0);
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: p.n.toDouble(),
        h: thumb + 0.4 + p.n,
        paint: _paint,
        onTap: (o) {
          _start(o);
          _end();
        },
        onPanStart: _start,
        onPanUpdate: _paintAt,
        onPanEnd: _end,
        semantics: 'Tezhip',
      ),
      bottom: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: [
        for (var k = 0; k <= p.colors; k++)
          OChip(
            selected: color == k,
            onTap: ended ? null : () => setState(() => color = k),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _tezhipPal[k], shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
              child: k == 0 ? const Icon(Icons.cleaning_services_outlined, size: 18, color: Color(0xFF22303F)) : null,
            ),
          ),
      ]),
    );
  }
}

// =================================================================== Cam Boncuk Fırını

/// Pota yığınlarından boncuğa halka halka cam dökülür; ilk dökülen en içtedir.
class BoncukPuzzle extends OPuzzle {
  final List<int> target;
  final List<List<int>> pots;
  final int cap;
  final int colors;
  final int opt;
  final int limit;

  /// En kısa çözüm: (kaynak, hedef) çiftleri; hedef −1 boncuktur.
  final List<List<int>> sol;
  const BoncukPuzzle(this.target, this.pots, this.cap, this.colors, this.opt, this.limit, this.sol);
}

String _bKey(List<List<int>> s, int k) => '${s.map((e) => e.join()).join('|')}#$k';

/// En kısa döküm dizisi (bulunamazsa null).
List<List<int>>? solveBoncuk(List<int> target, List<List<int>> pots, int cap, {int limit = 40000}) {
  final start = [for (final p in pots) List<int>.of(p)];
  final prev = <String, List<Object>>{_bKey(start, 0): const []};
  final q = Queue<List<Object>>()..add([start, 0]);
  while (q.isNotEmpty) {
    final cur = q.removeFirst();
    final s = cur[0] as List<List<int>>;
    final k = cur[1] as int;
    final key = _bKey(s, k);
    if (k == target.length) {
      final out = <List<int>>[];
      var kk = key;
      while (true) {
        final pr = prev[kk]!;
        if (pr.isEmpty) break;
        out.add(pr[1] as List<int>);
        kk = pr[0] as String;
      }
      return out.reversed.toList();
    }
    for (var i = 0; i < s.length; i++) {
      if (s[i].isEmpty) continue;
      final top = s[i].last;
      void push(List<List<int>> ns, int nk, List<int> mv) {
        final nkey = _bKey(ns, nk);
        if (prev.containsKey(nkey)) return;
        prev[nkey] = [key, mv];
        q.add([ns, nk]);
      }

      if (top == target[k]) {
        final ns = [for (final p in s) List<int>.of(p)];
        ns[i].removeLast();
        push(ns, k + 1, [i, -1]);
      }
      for (var j = 0; j < s.length; j++) {
        if (j == i || s[j].length >= cap) continue;
        final ns = [for (final p in s) List<int>.of(p)];
        ns[i].removeLast();
        ns[j].add(top);
        push(ns, k, [i, j]);
      }
    }
    if (prev.length > limit) return null;
  }
  return null;
}

class BoncukKind extends OzgunKind {
  @override
  String get id => 'boncuk';
  const BoncukKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final len = math.min<int>(7, 4 + d ~/ 2);
    final colors = 3 + d ~/ 4;
    final k = 3 + (d >= 5 ? 1 : 0);
    final cap = d < 8 ? 4 : 3;
    final target = [for (var i = 0; i < len; i++) r.nextInt(colors)];
    final lay = List<int>.of(target);
    r.shuffle(lay);
    final pots = List.generate(k, (_) => <int>[]);
    for (final c in lay) {
      final opts = [for (var i = 0; i < k - 1; i++) if (pots[i].length < cap) i];
      if (opts.isEmpty) return null;
      pots[r.pick(opts)].add(c);
    }
    r.shuffle(pots);
    final sol = solveBoncuk(target, pots, cap);
    if (sol == null) return null;
    final opt = sol.length;
    if (d >= 3 && opt < len + 1) return null;
    if (opt > len + 10) return null;
    final slack = d <= 3 ? 3 : (d <= 6 ? 2 : 1);
    return BoncukPuzzle(target, pots, cap, colors, opt, opt + slack, sol);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! BoncukPuzzle || p.sol.length != p.opt || p.opt > p.limit) return false;
    final s = [for (final x in p.pots) List<int>.of(x)];
    var k = 0;
    for (final mv in p.sol) {
      final i = mv[0], j = mv[1];
      if (i < 0 || i >= s.length || s[i].isEmpty) return false;
      final top = s[i].last;
      if (j < 0) {
        if (k >= p.target.length || top != p.target[k]) return false;
        s[i].removeLast();
        k++;
      } else {
        if (j >= s.length || j == i || s[j].length >= p.cap) return false;
        s[i].removeLast();
        s[j].add(top);
      }
    }
    return k == p.target.length;
  }

  @override
  Widget build(OzgunPlay play) => _BoncukView(play: play);
}

const _glass = [Color(0xFF1F5FAF), Color(0xFFE0A030), Color(0xFFB0303F), Color(0xFF2FA6A0), Color(0xFFF2EFE6)];

class _BoncukView extends StatefulWidget {
  final OzgunPlay play;
  const _BoncukView({required this.play});
  @override
  State<_BoncukView> createState() => _BoncukViewState();
}

class _BoncukViewState extends State<_BoncukView> with Clock {
  late final BoncukPuzzle p = widget.play.puzzle as BoncukPuzzle;
  late List<List<int>> pots = [for (final x in p.pots) List<int>.of(x)];
  List<int> bead = [];
  final List<(List<List<int>>, List<int>)> hist = [];
  int? sel;
  int pours = 0, hints = 0;
  int flash = -1;
  static const double w = 10;
  late final double potW = w / pots.length;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _push() => hist.add(([for (final x in pots) List<int>.of(x)], List<int>.of(bead)));

  void _pour(int i, int j) {
    if (pots[i].isEmpty) return;
    if (pours >= p.limit) {
      widget.play.sfx(Sfx.error);
      return;
    }
    final top = pots[i].last;
    if (j < 0) {
      if (bead.length >= p.target.length || top != p.target[bead.length]) {
        widget.play.sfx(Sfx.error);
        setState(() => flash = i);
        later(400, () => setState(() => flash = -1));
        return;
      }
      _push();
      setState(() {
        pots[i].removeLast();
        bead.add(top);
        pours++;
        sel = null;
      });
      widget.play.sfx(Sfx.place);
      _check();
      return;
    }
    if (pots[j].length >= p.cap) {
      widget.play.sfx(Sfx.error);
      return;
    }
    _push();
    setState(() {
      pots[i].removeLast();
      pots[j].add(top);
      pours++;
      sel = null;
    });
    widget.play.sfx(Sfx.tap);
  }

  void _check() {
    if (ended || bead.length != p.target.length) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    final stars = pours <= p.opt ? 3 : (pours <= p.opt + 1 ? 2 : 1);
    later(800, () => widget.play.win(stars: math.max(1, stars - hints), seconds: seconds, hints: hints, score: 1000 - seconds - (pours - p.opt) * 40));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final sol = solveBoncuk(p.target.sublist(bead.length), pots, p.cap);
    if (sol == null || sol.isEmpty) {
      widget.play.sfx(Sfx.error);
      return;
    }
    hints++;
    final mv = sol.first;
    setState(() => sel = null);
    _pour(mv[0], mv[1]);
  }

  void _tap(Offset o) {
    if (ended) return;
    if (o.dy > 6.2) {
      final i = clampI((o.dx / potW).floor(), 0, pots.length - 1);
      final s = sel;
      if (s == null) {
        if (pots[i].isNotEmpty) setState(() => sel = i);
        widget.play.sfx(Sfx.tap);
      } else if (s == i) {
        setState(() => sel = null);
      } else {
        _pour(s, i);
      }
      return;
    }
    final s = sel;
    if (s != null && (o - const Offset(3.6, 3.0)).distance < 2.8) _pour(s, -1);
  }

  void _rings(Canvas c, Offset ctr, double rOut, List<int> rings, int total) {
    c.drawCircle(ctr, rOut + 0.08, fill(const Color(0x33000000)));
    final step = rOut / (total + 1);
    for (var k = rings.length - 1; k >= 0; k--) {
      c.drawCircle(ctr, step * (k + 2), fill(_glass[rings[k] % _glass.length]));
    }
    c.drawCircle(ctr, step, fill(const Color(0xFF3B3B3B)));
    c.drawCircle(ctr.translate(-rOut * 0.35, -rOut * 0.35), rOut * 0.12, fill(const Color(0x55FFFFFF)));
  }

  void _paint(Canvas c) {
    // fırın ağzı
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.2, 0.2, 6.8, 5.6), const Radius.circular(0.5)), fill(const Color(0xFF3A2A22)));
    c.drawCircle(const Offset(3.6, 3.0), 2.6, fill(const Color(0xFFE07A2F).withValues(alpha: 0.35)));
    _rings(c, const Offset(3.6, 3.0), 2.2, bead, p.target.length);
    if (sel != null) c.drawCircle(const Offset(3.6, 3.0), 2.45, stroke(OColors.gold, 0.08));
    // hedef
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7.3, 0.6, 2.5, 3.0), const Radius.circular(0.3)), fill(OColors.soft));
    _rings(c, const Offset(8.55, 2.0), 1.05, p.target, p.target.length);
    drawLabel(c, ot(widget.play.lang, 'target'), const Offset(8.55, 3.3), 0.34, OColors.ink);
    // potalar
    for (var i = 0; i < pots.length; i++) {
      final x0 = i * potW + 0.25, pw = potW - 0.5;
      final rc = Rect.fromLTWH(x0, 6.5, pw, 3.6);
      c.drawRRect(RRect.fromRectAndRadius(rc, const Radius.circular(0.35)), fill(flash == i ? OColors.bad : const Color(0xFF6E6259)));
      final lh = 3.2 / p.cap;
      for (var k = 0; k < pots[i].length; k++) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 + 0.15, 10.0 - (k + 1) * lh, pw - 0.3, lh - 0.06), const Radius.circular(0.12)),
            fill(_glass[pots[i][k] % _glass.length]));
      }
      if (sel == i) c.drawRRect(RRect.fromRectAndRadius(rc.inflate(0.08), const Radius.circular(0.4)), stroke(OColors.gold, 0.1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: clock(),
        status: '${ot(lang, 'pours')}: $pours / ${p.limit}',
        onUndo: hist.isEmpty
            ? null
            : () => setState(() {
                  final h = hist.removeLast();
                  pots = h.$1;
                  bead = h.$2;
                  pours = math.max(0, pours - 1);
                  sel = null;
                }),
        onReset: () => setState(() {
          _push();
          pots = [for (final x in p.pots) List<int>.of(x)];
          bead = [];
          pours = 0;
          sel = null;
        }),
        onHint: _hint,
      ),
      board: TapCanvas(w: w, h: 10.3, paint: _paint, onTap: _tap, semantics: 'Cam boncuk'),
    );
  }
}

// =================================================================== Çömlek Çarkı

/// Çarkta dönen çamuru parmakla sıkıştırıp genişleterek hedef profile uydur.
class ComlekPuzzle extends OPuzzle {
  final List<double> target; // yükseklik başına 0..1 yarıçap (alttan üste)
  final double tol;
  const ComlekPuzzle(this.target, this.tol);
}

const int kComlekH = 16;

double comlekError(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - b[i]).abs();
  }
  return s / a.length;
}

/// Bir dokunuşun çamura etkisi: [h] yüksekliğinde yarıçap [want]e yaklaşır,
/// komşular yumuşakça izler.
void comlekTouch(List<double> cur, double h, double want, double k) {
  for (var i = 0; i < cur.length; i++) {
    final dd = (i - h) / 1.4;
    final wgt = math.exp(-dd * dd);
    cur[i] = clampD(cur[i] + (want - cur[i]) * k * wgt, 0.12, 1.0);
  }
}

class ComlekKind extends OzgunKind {
  @override
  String get id => 'comlek';
  const ComlekKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final pts = 2 + d ~/ 3;
    final ctrl = [for (var i = 0; i < pts; i++) 0.25 + r.nextDouble() * 0.7];
    if (ctrl.first < 0.35) ctrl[0] = 0.35 + r.nextDouble() * 0.3;
    final t = <double>[];
    for (var h = 0; h < kComlekH; h++) {
      final u = h / (kComlekH - 1) * (pts - 1);
      final i0 = math.min<int>(u.floor(), pts - 2);
      final f = u - i0;
      final m = (1 - math.cos(f * math.pi)) / 2;
      t.add(ctrl[i0] * (1 - m) + ctrl[i0 + 1] * m);
    }
    final hi = t.reduce(math.max), lo = t.reduce(math.min);
    if (hi - lo < 0.2 + 0.02 * d) return null;
    final tol = math.max(0.05, 0.075 - 0.003 * d);
    return ComlekPuzzle(t, tol);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! ComlekPuzzle || p.target.length != kComlekH || p.tol <= 0) return false;
    if (p.target.any((v) => v < 0.12 || v > 1.0)) return false;
    // Basit bir çömlekçi hedefe ulaşabilmeli.
    final cur = List<double>.filled(kComlekH, 0.62);
    for (var pass = 0; pass < 10; pass++) {
      for (var h = 0; h < kComlekH; h++) {
        comlekTouch(cur, h.toDouble(), p.target[h], 0.5);
      }
    }
    return comlekError(cur, p.target) <= p.tol;
  }

  @override
  Widget build(OzgunPlay play) => _ComlekView(play: play);
}

class _ComlekView extends StatefulWidget {
  final OzgunPlay play;
  const _ComlekView({required this.play});
  @override
  State<_ComlekView> createState() => _ComlekViewState();
}

class _ComlekViewState extends State<_ComlekView> with Clock {
  late final ComlekPuzzle p = widget.play.puzzle as ComlekPuzzle;
  List<double> cur = List<double>.filled(kComlekH, 0.62);
  final List<List<double>> hist = [];
  int hints = 0, touches = 0;
  double phase = 0;
  Timer? spin;
  static const double bw = 10, bh = 12, cx = 5, maxR = 4.2, y0 = 10.6, rowH = 0.6;

  @override
  void initState() {
    super.initState();
    startClock();
    spin = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted && !ended) setState(() => phase = (phase + 0.18) % 1.0);
    });
  }

  @override
  void dispose() {
    spin?.cancel();
    super.dispose();
  }

  double get err => comlekError(cur, p.target);

  void _start(Offset o) {
    if (ended) return;
    hist.add(List.of(cur));
    touches++;
    _move(o);
  }

  void _move(Offset o) {
    if (ended) return;
    final h = (y0 - o.dy) / rowH;
    if (h < -1 || h > kComlekH) return;
    final want = clampD((o.dx - cx).abs() / maxR, 0.12, 1.0);
    setState(() => comlekTouch(cur, h, want, 0.35));
  }

  void _fire() {
    if (ended) return;
    final e = err;
    if (e > p.tol * 3) {
      widget.play.sfx(Sfx.error);
      return;
    }
    ended = true;
    widget.play.sfx(Sfx.win);
    var stars = e <= p.tol ? 3 : (e <= p.tol * 1.8 ? 2 : 1);
    stars = math.max(1, stars - hints);
    later(800, () => widget.play.win(stars: stars, seconds: seconds, hints: hints, score: (1000 * (1 - e * 4)).round()));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    var worst = 0;
    for (var h = 1; h < kComlekH; h++) {
      if ((cur[h] - p.target[h]).abs() > (cur[worst] - p.target[worst]).abs()) worst = h;
    }
    hist.add(List.of(cur));
    setState(() {
      comlekTouch(cur, worst.toDouble(), p.target[worst], 0.9);
      hints++;
    });
  }

  Path _profile(List<double> r) {
    final path = Path()..moveTo(cx - r[0] * maxR, y0);
    for (var h = 0; h < kComlekH; h++) {
      path.lineTo(cx - r[h] * maxR, y0 - h * rowH);
    }
    for (var h = kComlekH - 1; h >= 0; h--) {
      path.lineTo(cx + r[h] * maxR, y0 - h * rowH);
    }
    return path..close();
  }

  void _paint(Canvas c) {
    // çark
    c.drawOval(Rect.fromCenter(center: const Offset(cx, y0 + 0.45), width: 9.4, height: 1.3), fill(const Color(0xFF5B4636)));
    c.drawOval(Rect.fromCenter(center: const Offset(cx, y0 + 0.3), width: 9.0, height: 1.0), fill(const Color(0xFF8C7A68)));
    // çamur
    final body = _profile(cur);
    c.drawPath(body, fill(const Color(0xFFB8704A)));
    c.save();
    c.clipPath(body);
    for (var k = 0; k < 7; k++) {
      final x = cx - maxR + ((k + phase) / 7) * maxR * 2;
      c.drawLine(Offset(x, 0), Offset(x, y0), stroke(const Color(0x22FFFFFF), 0.12));
    }
    c.restore();
    // hedef profil
    final tp = Path();
    for (final side in [-1.0, 1.0]) {
      tp.moveTo(cx + side * p.target[0] * maxR, y0);
      for (var h = 1; h < kComlekH; h++) {
        tp.lineTo(cx + side * p.target[h] * maxR, y0 - h * rowH);
      }
    }
    c.drawPath(tp, stroke(OColors.gold, 0.09));
    final pct = (clampD(1 - err / 0.4, 0, 1) * 100).round();
    drawLabel(c, '${ot(widget.play.lang, 'match')} %$pct', const Offset(cx, 0.4), 0.5, OColors.ink);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: clock(),
        status: '${ot(lang, 'moves')}: $touches',
        onUndo: hist.isEmpty ? null : () => setState(() => cur = hist.removeLast()),
        onReset: () => setState(() {
          hist.add(List.of(cur));
          cur = List<double>.filled(kComlekH, 0.62);
        }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: bw,
        h: bh,
        paint: _paint,
        onTap: (o) {
          _start(o);
        },
        onPanStart: _start,
        onPanUpdate: _move,
        semantics: 'Çömlek çarkı',
      ),
      bottom: FilledButton.icon(onPressed: ended ? null : _fire, icon: const Icon(Icons.local_fire_department_outlined), label: Text(ot(lang, 'fire'))),
    );
  }
}
