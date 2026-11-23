import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/stars.dart';
import 'craft.dart';
import 'logic.dart';

// =================================================================== Takımyıldız

/// Gök küresinden düzleme dik izdüşüm; sonuç 8×8 kutuya sığdırılır (merkez 5,5).
List<Offset> projectStars(List<List<double>> stars) {
  List<double> vec(List<double> s) {
    final ra = s[0] * math.pi / 180, de = s[1] * math.pi / 180;
    return [math.cos(de) * math.cos(ra), math.cos(de) * math.sin(ra), math.sin(de)];
  }

  List<double> norm(List<double> v) {
    final l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [v[0] / l, v[1] / l, v[2] / l];
  }

  List<double> cross(List<double> a, List<double> b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  double dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  final vs = stars.map(vec).toList();
  final c = norm([for (var k = 0; k < 3; k++) vs.map((v) => v[k]).reduce((a, b) => a + b)]);
  final east = norm(cross(const [0.0, 0.0, 1.0], c));
  final north = cross(c, east);
  final pts = [for (final v in vs) Offset(-dot(v, east), -dot(v, north))];
  final minX = pts.map((p) => p.dx).reduce(math.min), maxX = pts.map((p) => p.dx).reduce(math.max);
  final minY = pts.map((p) => p.dy).reduce(math.min), maxY = pts.map((p) => p.dy).reduce(math.max);
  final span = math.max(maxX - minX, maxY - minY);
  final k = span <= 0 ? 1.0 : 8 / span;
  final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  return [for (final p in pts) const Offset(5, 5) + (p - mid) * k];
}

class SkyPuzzle extends OPuzzle {
  final int constellation;
  final List<Offset> points;
  final List<int> real; // takımyıldız yıldızı → nokta
  final double angle;
  const SkyPuzzle(this.constellation, this.points, this.real, this.angle);

  Constellation get con => kConstellations[constellation];

  Set<int> get lines => {for (final l in con.lines) HatPuzzle.ek(real[l[0]], real[l[1]])};
}

class SkyKind extends OzgunKind {
  @override
  String get id => 'yildiz';
  const SkyKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final maxIdx = math.min(kConstellations.length, 4 + d * 2);
    final ci = r.nextInt(maxIdx);
    final con = kConstellations[ci];
    final base = projectStars(con.stars);
    final angle = d <= 2 ? 0.0 : r.nextDouble() * 2 * math.pi;
    Offset rot(Offset p) {
      final q = p - const Offset(5, 5);
      return const Offset(5, 5) + Offset(q.dx * math.cos(angle) - q.dy * math.sin(angle), q.dx * math.sin(angle) + q.dy * math.cos(angle));
    }

    final realPts = base.map(rot).toList();
    final all = <Offset>[...realPts];
    final extra = 3 + d * 2;
    var guard = 0;
    while (all.length < realPts.length + extra && guard++ < 500) {
      final p = Offset(0.6 + r.nextDouble() * 8.8, 0.6 + r.nextDouble() * 8.8);
      if (all.every((q) => (q - p).distance > 0.8)) all.add(p);
    }
    // Sırayı karıştır, gerçek yıldızların yeni yerlerini tut.
    final order = [for (var i = 0; i < all.length; i++) i];
    r.shuffle(order);
    final points = [for (final i in order) all[i]];
    final real = [for (var s = 0; s < realPts.length; s++) order.indexOf(s)];
    return SkyPuzzle(ci, points, real, angle);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! SkyPuzzle) return false;
    for (var i = 0; i < p.points.length; i++) {
      final q = p.points[i];
      if (q.dx < -1 || q.dy < -1 || q.dx > 11 || q.dy > 11) return false;
      for (var j = i + 1; j < p.points.length; j++) {
        if ((q - p.points[j]).distance < 0.3) return false;
      }
    }
    return p.lines.length == p.con.lines.length && p.real.toSet().length == p.real.length;
  }

  @override
  Widget build(OzgunPlay play) => _SkyView(play: play);
}

class _SkyView extends StatefulWidget {
  final OzgunPlay play;
  const _SkyView({required this.play});
  @override
  State<_SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<_SkyView> with Clock {
  late final SkyPuzzle p = widget.play.puzzle as SkyPuzzle;
  late final Set<int> want = p.lines;
  late final List<double> mags = () {
    final r = SeededRandom(widget.play.seed ^ 0x5a5a);
    return [for (var i = 0; i < p.points.length; i++) 0.09 + r.nextDouble() * 0.1];
  }();
  late final List<Offset> thumb = projectStars(p.con.stars);
  Set<int> lines = {};
  int? sel;
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  int? starAt(Offset o) {
    var best = -1;
    var bd = 1e9;
    for (var i = 0; i < p.points.length; i++) {
      final d = (p.points[i] - o).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return bd < 0.6 ? best : null;
  }

  void _tap(Offset o) {
    if (ended) return;
    final s = starAt(o);
    if (s == null) {
      setState(() => sel = null);
      return;
    }
    final a = sel;
    if (a == null || a == s) {
      setState(() => sel = a == s ? null : s);
      widget.play.sfx(Sfx.tap);
      return;
    }
    final e = HatPuzzle.ek(a, s);
    setState(() {
      lines = {...lines};
      if (!lines.remove(e)) lines.add(e);
      sel = s;
      moves++;
    });
    widget.play.sfx(Sfx.place);
    _check();
  }

  void _check() {
    if (ended || lines.length != want.length || !lines.containsAll(want)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(900, () => widget.play.win(stars: starsByMoves(moves, want.length, hints: hints), seconds: seconds, hints: hints, score: 1000 - moves * 10));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    hints++;
    final extra = lines.where((e) => !want.contains(e)).toList();
    setState(() {
      lines = {...lines};
      if (extra.isNotEmpty) {
        lines.remove(extra.first);
      } else {
        lines.add(want.firstWhere((e) => !lines.contains(e)));
      }
    });
    _check();
  }

  @override
  Widget build(BuildContext context) {
    final con = p.con;
    return OScreen(
      bar: OBar(
        lang: widget.play.lang,
        left: '${lines.intersection(want).length}/${want.length}',
        status: clock(),
        onReset: ended ? null : () => setState(() => lines = {}),
        onHint: _hint,
      ),
      top: SizedBox(
        height: 84,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(con.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            height: 84,
            child: TapCanvas(
              w: 10,
              h: 10,
              paint: (c) {
                c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 10, 10), const Radius.circular(1)), fill(const Color(0xFF1B2240)));
                for (final l in con.lines) {
                  c.drawLine(thumb[l[0]], thumb[l[1]], stroke(const Color(0xFF9FB4FF), 0.25));
                }
                for (final t in thumb) {
                  c.drawCircle(t, 0.35, fill(Colors.white));
                }
              },
            ),
          ),
        ]),
      ),
      board: TapCanvas(
        w: 10,
        h: 10,
        onTap: _tap,
        paint: (c) {
          c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 10, 10), const Radius.circular(0.4)), fill(const Color(0xFF0E1430)));
          final dust = SeededRandom(widget.play.seed);
          for (var k = 0; k < 60; k++) {
            c.drawCircle(Offset(dust.nextDouble() * 10, dust.nextDouble() * 10), 0.02 + dust.nextDouble() * 0.03, fill(const Color(0x66FFFFFF)));
          }
          final done = ended;
          for (final e in lines) {
            final ok = want.contains(e);
            c.drawLine(p.points[e ~/ 1000], p.points[e % 1000], stroke(done || ok ? const Color(0xFF9FB4FF) : const Color(0xFF9FB4FF).withValues(alpha: 0.75), 0.07));
          }
          for (var i = 0; i < p.points.length; i++) {
            final m = p.points[i];
            c.drawCircle(m, mags[i] * 2.2, fill(const Color(0x22FFFFFF)));
            c.drawCircle(m, mags[i], fill(const Color(0xFFFFF7E0)));
            if (sel == i) c.drawCircle(m, 0.38, stroke(OColors.gold, 0.06));
          }
        },
      ),
    );
  }
}

// =================================================================== Günlük Üçlü

/// Günlük Üçlü'de kullanılan kısa bulmacalar.
const Map<String, OzgunKind> kDailyPool = {
  'kilim': KilimKind(),
  'cini': CiniKind(),
  'lale': LaleKind(),
  'bal': BalKind(),
  'pazar': PazarKind(),
  'hat': HatKind(),
  'ebru': EbruKind(),
  'mantar': MantarKind(),
};

class DailyPuzzle extends OPuzzle {
  final List<String> kinds;
  final List<OPuzzle> parts;
  final int d;
  const DailyPuzzle(this.kinds, this.parts, this.d);
}

class DailyKind extends OzgunKind {
  @override
  String get id => 'gunluk-uclu';
  const DailyKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final keys = kDailyPool.keys.toList();
    r.shuffle(keys);
    final pick = keys.take(3).toList();
    final sd = math.max(1, d - 3);
    final parts = <OPuzzle>[];
    for (final k in pick) {
      final p = kDailyPool[k]!.make(sd, r);
      if (p == null || !kDailyPool[k]!.check(p)) return null;
      parts.add(p);
    }
    return DailyPuzzle(pick, parts, sd);
  }

  @override
  bool check(OPuzzle p) {
    if (p is! DailyPuzzle || p.parts.length != 3) return false;
    for (var i = 0; i < 3; i++) {
      if (!kDailyPool[p.kinds[i]]!.check(p.parts[i])) return false;
    }
    return true;
  }

  @override
  Widget build(OzgunPlay play) => _DailyView(play: play);
}

class _DailyView extends StatefulWidget {
  final OzgunPlay play;
  const _DailyView({required this.play});
  @override
  State<_DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<_DailyView> {
  late final DailyPuzzle p = widget.play.puzzle as DailyPuzzle;
  int part = 0, stars = 0, wins = 0;

  void _done(bool won, int s) {
    if (won) {
      wins++;
      stars += s;
    }
    if (part + 1 >= p.parts.length) {
      if (wins >= 2) {
        widget.play.win(stars: (stars / 3).round(), score: wins * 400);
      } else {
        widget.play.lose(headline: '$wins/3');
      }
      return;
    }
    setState(() => part++);
  }

  @override
  Widget build(BuildContext context) {
    final sub = OzgunPlay(ctx: widget.play.ctx, puzzle: p.parts[part], d: p.d, seed: widget.play.seed + part, relay: _done);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 46,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: i <= part ? OColors.accent : OColors.soft, borderRadius: BorderRadius.circular(4)),
            ),
        ]),
      ),
      Expanded(child: KeyedSubtree(key: ValueKey(part), child: kDailyPool[p.kinds[part]]!.build(sub))),
    ]);
  }
}
