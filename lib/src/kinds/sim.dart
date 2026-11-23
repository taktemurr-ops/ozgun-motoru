import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';
import 'logic.dart' show HexArea;

// =================================================================== Mahalle Kur

/// Karolar: 0 ev, 1 park, 2 dükkân, 3 atölye, 4 çeşme. -1 boş, -2 dere.
class MahallePuzzle extends OPuzzle {
  final int n;
  final Set<int> river;
  final List<int> queue;
  final int target;
  const MahallePuzzle(this.n, this.river, this.queue, this.target);

  List<int> nb(int i) {
    final x = i % n, y = i ~/ n;
    return [
      if (y > 0) i - n,
      if (x < n - 1) i + 1,
      if (y < n - 1) i + n,
      if (x > 0) i - 1,
    ];
  }

  int cellScore(List<int> g, int i) {
    final t = g[i];
    if (t < 0) return 0;
    final around = nb(i).map((j) => g[j]).toList();
    int count(int k) => around.where((v) => v == k).length;
    switch (t) {
      case 0:
        return 1 + 2 * count(1) + count(4) - 2 * count(3);
      case 1:
        return 1 + count(4) + (around.contains(-2) ? 1 : 0);
      case 2:
        return math.min(4, count(0)) - count(2);
      case 3:
        return 3 + count(2);
      default:
        return 0;
    }
  }

  int score(List<int> g) {
    var s = 0;
    for (var i = 0; i < n * n; i++) {
      s += cellScore(g, i);
    }
    return s;
  }

  List<int> empty() => [for (var i = 0; i < n * n; i++) river.contains(i) ? -2 : -1];

  /// Açgözlü yerleştirme: her karo en çok puan getiren yere.
  int greedyPos(List<int> g, int tile) {
    var best = -1, bestScore = -1 << 30;
    final base = score(g);
    for (var i = 0; i < n * n; i++) {
      if (g[i] != -1) continue;
      g[i] = tile;
      final s = score(g) - base;
      g[i] = -1;
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  int greedyTotal() {
    final g = empty();
    for (final t in queue) {
      final pos = greedyPos(g, t);
      if (pos < 0) break;
      g[pos] = t;
    }
    return score(g);
  }
}

class MahalleKind extends OzgunKind {
  @override
  String get id => 'mahalle';
  const MahalleKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 5 + d ~/ 4;
    final river = <int>{};
    if (d >= 4) {
      var x = r.nextInt(n);
      for (var y = 0; y < n; y++) {
        river.add(y * n + x);
        if (r.chance(0.35)) x = clampI(x + (r.chance(0.5) ? 1 : -1), 0, n - 1);
      }
    }
    final cells = n * n - river.length;
    final queue = [for (var i = 0; i < cells; i++) r.weighted(const [5, 3, 2, 2, 1])];
    final probe = MahallePuzzle(n, river, queue, 0);
    final g = probe.greedyTotal();
    if (g < cells) return null;
    final target = (g * (0.86 + d * 0.01)).round();
    return MahallePuzzle(n, river, queue, target);
  }

  @override
  bool check(OPuzzle p) => p is MahallePuzzle && p.greedyTotal() >= p.target && p.queue.length == p.n * p.n - p.river.length;

  @override
  Widget build(OzgunPlay play) => _MahalleView(play: play);
}

const List<IconData> _tileIcons = [Icons.house_rounded, Icons.park_rounded, Icons.storefront_rounded, Icons.handyman_rounded, Icons.water_drop_rounded];
const List<Color> _tileCols = [Color(0xFFC8553D), Color(0xFF4F9A6E), Color(0xFF3E6FB0), Color(0xFF7D6E62), Color(0xFF3A8D8C)];

class _MahalleView extends StatefulWidget {
  final OzgunPlay play;
  const _MahalleView({required this.play});
  @override
  State<_MahalleView> createState() => _MahalleViewState();
}

class _MahalleViewState extends State<_MahalleView> with Clock {
  late final MahallePuzzle p = widget.play.puzzle as MahallePuzzle;
  late List<int> g = p.empty();
  int next = 0, hints = 0;
  int? flash;
  final List<List<int>> hist = [];

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _place(int i) {
    if (ended || next >= p.queue.length || g[i] != -1) return;
    hist.add(List.of(g));
    setState(() {
      g = List.of(g);
      g[i] = p.queue[next];
      next++;
      flash = i;
    });
    widget.play.sfx(Sfx.place);
    if (next >= p.queue.length) {
      ended = true;
      final s = p.score(g);
      if (s >= p.target) {
        widget.play.sfx(Sfx.win);
        final extra = s - p.target;
        later(900, () => widget.play.win(stars: (extra >= p.target ~/ 10 ? 3 : (extra >= 0 ? 2 : 1)) - hints, seconds: seconds, hints: hints, score: s * 10));
      } else {
        widget.play.sfx(Sfx.lose);
        later(900, () => widget.play.lose(score: s * 10, seconds: seconds, headline: '$s / ${p.target}'));
      }
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final pos = p.greedyPos(List.of(g), p.queue[next]);
    if (pos < 0) return;
    hints++;
    _place(pos);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final s = p.score(g);
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ot(lang, 'score')}: $s',
        status: '${ot(lang, 'target')}: ${p.target}',
        onUndo: hist.isEmpty || ended
            ? null
            : () => setState(() {
                  g = hist.removeLast();
                  next--;
                }),
        onHint: _hint,
      ),
      top: SizedBox(
        height: 54,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < 4 && next + k < p.queue.length; k++)
            Container(
              width: k == 0 ? 50 : 36,
              height: k == 0 ? 50 : 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _tileCols[p.queue[next + k]].withValues(alpha: k == 0 ? 1 : 0.55),
                borderRadius: BorderRadius.circular(10),
                border: k == 0 ? Border.all(color: Colors.white, width: 3) : null,
              ),
              child: Icon(_tileIcons[p.queue[next + k]], color: Colors.white, size: k == 0 ? 30 : 20),
            ),
          const SizedBox(width: 8),
          Text('${p.queue.length - next}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
      board: TapCanvas(
        w: p.n.toDouble(),
        h: p.n.toDouble(),
        onTap: (o) {
          final x = o.dx.floor(), y = o.dy.floor();
          if (x >= 0 && y >= 0 && x < p.n && y < p.n) _place(y * p.n + x);
        },
        paint: (c) {
          c.drawRect(Rect.fromLTWH(0, 0, p.n.toDouble(), p.n.toDouble()), fill(const Color(0xFFDCE8C8)));
          for (var i = 0; i < p.n * p.n; i++) {
            final r = Rect.fromLTWH(i % p.n + 0.05, i ~/ p.n + 0.05, 0.9, 0.9);
            final t = g[i];
            if (t == -2) {
              c.drawRect(r.inflate(0.05), fill(const Color(0xFF7FB3D5)));
              continue;
            }
            if (t == -1) {
              c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.1)), fill(const Color(0xFFEDF3E1)));
              continue;
            }
            c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.12)), fill(_tileCols[t]));
            final ic = _tileIcons[t];
            final tp = TextPainter(
              text: TextSpan(text: String.fromCharCode(ic.codePoint), style: TextStyle(fontFamily: ic.fontFamily, package: ic.fontPackage, fontSize: 0.62, color: Colors.white)),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
            final cs = p.cellScore(g, i);
            drawLabel(c, cs >= 0 ? '+$cs' : '$cs', r.topRight + const Offset(-0.16, 0.14), 0.2, Colors.white);
            if (flash == i) c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(0.12)), stroke(Colors.white, 0.06));
          }
        },
      ),
    );
  }
}

// =================================================================== Akvaryum Dengesi

/// Bitki, küçük balık, büyük balık, yosun, salyangoz.
class Tank {
  final int p, f, b, a, s;
  const Tank(this.p, this.f, this.b, this.a, this.s);

  static const lo = [4, 3, 1, 0];
  static const hi = [30, 20, 5, 10];

  List<int> get v => [p, f, b, a];

  bool get safe {
    final x = v;
    for (var i = 0; i < 4; i++) {
      if (x[i] < lo[i] || x[i] > hi[i]) return false;
    }
    return true;
  }

  /// Sınırlara en yakın mesafe (göreli).
  double margin() {
    final x = v;
    var m = 1.0;
    for (var i = 0; i < 4; i++) {
      final span = (hi[i] - lo[i]).toDouble();
      m = math.min(m, math.min(x[i] - lo[i], hi[i] - x[i]) / span);
    }
    return m;
  }

  /// Eylem: 0 bekle, 1 bitki, 2 küçük balık, 3 salyangoz, 4 temizle.
  Tank act(int a0) => switch (a0) {
        1 => Tank(p + 3, f, b, a, s),
        2 => Tank(p, f + 2, b, a, s),
        3 => Tank(p, f, b, a, s + 1),
        4 => Tank(p, f, b, math.max(0, a - 4), s),
        _ => this,
      };

  Tank day(int g, int dayNo) {
    var np = p + math.max(1, p ~/ g) - f ~/ 2;
    var nf = f;
    if (p >= f) {
      nf += math.max(1, f ~/ 3);
    } else {
      nf -= (f - p + 1) ~/ 2;
    }
    nf -= b ~/ 2;
    var nb = b;
    if (f < b) nb -= 1;
    if (dayNo % 3 == 0 && f >= 3 * b) nb += 1;
    var na = a + 1 + (f + 2 * b) ~/ 5 - s;
    if (na < 0) na = 0;
    if (na > 10) nf -= 2;
    var ns = s;
    if (a == 0 && dayNo % 2 == 0 && s > 0) ns -= 1;
    np = clampI(np, 0, 40);
    return Tank(np, math.max(0, nf), math.max(0, nb), na, ns);
  }
}

class AkvaryumPuzzle extends OPuzzle {
  final Tank start;
  final int days;
  final int growth;
  const AkvaryumPuzzle(this.start, this.days, this.growth);

  /// İki adım ileriye bakan güvenli eylem (yoksa -1).
  int bestAction(Tank t, int dayNo) {
    var best = -1;
    var bestScore = -1e9;
    for (var a = 0; a < 5; a++) {
      final n1 = t.act(a).day(growth, dayNo);
      if (!n1.safe) continue;
      var look = -1e9;
      if (dayNo >= days) {
        look = n1.margin();
      } else {
        for (var b = 0; b < 5; b++) {
          final n2 = n1.act(b).day(growth, dayNo + 1);
          if (n2.safe) look = math.max(look, n2.margin());
        }
      }
      final sc = n1.margin() + look;
      if (sc > bestScore) {
        bestScore = sc;
        best = a;
      }
    }
    return best;
  }

  bool survivable() {
    var t = start;
    for (var dn = 1; dn <= days; dn++) {
      final a = bestAction(t, dn);
      if (a < 0) return false;
      t = t.act(a).day(growth, dn);
    }
    return true;
  }
}

class AkvaryumKind extends OzgunKind {
  @override
  String get id => 'akvaryum';
  const AkvaryumKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final start = Tank(r.range(8, 16), r.range(5, 10), r.range(1, 3), r.range(1, 4), r.range(0, 2));
    final p = AkvaryumPuzzle(start, 8 + d, r.range(3, 4));
    if (!start.safe || !p.survivable()) return null;
    // Hiçbir şey yapmadan geçilmemeli.
    var t = start;
    var idle = true;
    for (var dn = 1; dn <= p.days; dn++) {
      t = t.day(p.growth, dn);
      if (!t.safe) {
        idle = false;
        break;
      }
    }
    return idle ? null : p;
  }

  @override
  bool check(OPuzzle p) => p is AkvaryumPuzzle && p.start.safe && p.survivable();

  @override
  Widget build(OzgunPlay play) => _AkvaryumView(play: play);
}

class _AkvaryumView extends StatefulWidget {
  final OzgunPlay play;
  const _AkvaryumView({required this.play});
  @override
  State<_AkvaryumView> createState() => _AkvaryumViewState();
}

class _AkvaryumViewState extends State<_AkvaryumView> with Clock, SingleTickerProviderStateMixin {
  late final AkvaryumPuzzle p = widget.play.puzzle as AkvaryumPuzzle;
  late final AnimationController swim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late Tank t = p.start;
  int dayNo = 1, action = 0, hints = 0;
  int? suggested;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  void dispose() {
    swim.dispose();
    super.dispose();
  }

  void _next() {
    if (ended) return;
    final nt = t.act(action).day(p.growth, dayNo);
    setState(() {
      t = nt;
      dayNo++;
      action = 0;
      suggested = null;
    });
    if (!nt.safe) {
      ended = true;
      widget.play.sfx(Sfx.lose);
      later(900, () => widget.play.lose(seconds: seconds, score: dayNo * 50, headline: '${ot(widget.play.lang, 'day')} ${dayNo - 1}'));
      return;
    }
    widget.play.sfx(Sfx.tap);
    if (dayNo > p.days) {
      ended = true;
      widget.play.sfx(Sfx.win);
      final m = nt.margin();
      later(900, () => widget.play.win(stars: (m >= 0.2 ? 3 : (m >= 0.1 ? 2 : 1)) - hints, seconds: seconds, hints: hints, score: 1000 + (m * 1000).round()));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    final a = p.bestAction(t, dayNo);
    if (a < 0) return;
    hints++;
    setState(() {
      action = a;
      suggested = a;
    });
  }

  Widget _bar(String label, int v, int i, Color col) {
    final top = Tank.hi[i] + 6.0;
    return Expanded(
      child: Column(children: [
        Text('$label $v', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        SizedBox(
          height: 10,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BandPainter(v / top, Tank.lo[i] / top, Tank.hi[i] / top, col),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final shown = math.min(dayNo, p.days);
    return OScreen(
      bar: OBar(lang: lang, left: '${ot(lang, 'day')} $shown/${p.days}', status: clock(), onHint: _hint),
      top: Row(children: [
        _bar('🌿', t.p, 0, const Color(0xFF4F9A6E)),
        const SizedBox(width: 6),
        _bar('🐟', t.f, 1, const Color(0xFF3E6FB0)),
        const SizedBox(width: 6),
        _bar('🐠', t.b, 2, const Color(0xFFE07A5F)),
        const SizedBox(width: 6),
        _bar('🟢', t.a, 3, const Color(0xFF8A9A3B)),
      ]),
      board: AnimatedBuilder(
        animation: swim,
        builder: (context, _) {
          final ph = swim.value * 2 * math.pi;
          return TapCanvas(
            w: 16,
            h: 10,
            paint: (c) {
              c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 16, 10), const Radius.circular(0.5)),
                  fill(Color.lerp(const Color(0xFF7EC8E3), const Color(0xFF6E8B3D), clampD(t.a / 14, 0.0, 0.8))!));
              c.drawRect(const Rect.fromLTWH(0, 9, 16, 1), fill(const Color(0xFFD8C39A)));
              final rr = SeededRandom(widget.play.seed);
              for (var k = 0; k < math.min(t.p, 18); k++) {
                final x = 0.6 + rr.nextDouble() * 14.8;
                final hgt = 1.5 + rr.nextDouble() * 2.5;
                final sway = math.sin(ph + k) * 0.25;
                final path = Path()
                  ..moveTo(x, 9.2)
                  ..quadraticBezierTo(x + sway, 9.2 - hgt / 2, x + sway * 2, 9.2 - hgt);
                c.drawPath(path, stroke(const Color(0xFF3F8F4F), 0.22));
              }
              for (var k = 0; k < math.min(t.f, 16); k++) {
                final y = 1.5 + (k * 0.47) % 6.5;
                final x = (k * 2.3 + swim.value * 16 * (k.isEven ? 1 : -1)) % 16;
                _fish(c, Offset(x < 0 ? x + 16 : x, y), 0.35, const Color(0xFFF2B33D), k.isEven);
              }
              for (var k = 0; k < math.min(t.b, 6); k++) {
                final y = 2.5 + k * 1.1;
                final x = (k * 5.1 + swim.value * 16 * 0.6) % 16;
                _fish(c, Offset(x, y), 0.75, const Color(0xFF3E6FB0), true);
              }
              for (var k = 0; k < math.min(t.s, 6); k++) {
                final m = Offset(2 + k * 2.4, 8.8);
                c.drawCircle(m, 0.25, fill(const Color(0xFF8B5A2B)));
                c.drawCircle(m, 0.12, stroke(const Color(0xFFD8C39A), 0.05));
              }
            },
          );
        },
      ),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          for (final (a, label) in const [(0, '—'), (1, '🌿+3'), (2, '🐟+2'), (3, '🐌+1'), (4, '🧽−4')])
            OChip(
              selected: action == a,
              color: suggested == a ? const Color(0xFFFFF1C1) : null,
              onTap: ended ? null : () => setState(() => action = a),
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: ended ? null : _next, icon: const Icon(Icons.wb_sunny_outlined), label: Text(ot(lang, 'nextDay'))),
      ]),
    );
  }

  void _fish(Canvas c, Offset m, double s, Color col, bool right) {
    final d = right ? 1.0 : -1.0;
    c.drawOval(Rect.fromCenter(center: m, width: s * 2, height: s * 1.1), fill(col));
    final tail = Path()
      ..moveTo(m.dx - d * s * 0.9, m.dy)
      ..lineTo(m.dx - d * s * 1.5, m.dy - s * 0.5)
      ..lineTo(m.dx - d * s * 1.5, m.dy + s * 0.5)
      ..close();
    c.drawPath(tail, fill(col));
    c.drawCircle(m + Offset(d * s * 0.5, -s * 0.12), s * 0.12, fill(Colors.black87));
  }
}

class _BandPainter extends CustomPainter {
  final double v, lo, hi;
  final Color col;
  _BandPainter(this.v, this.lo, this.hi, this.col);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.drawRRect(r, fill(const Color(0x22000000)));
    canvas.drawRect(Rect.fromLTRB(size.width * lo, 0, size.width * hi, size.height), fill(col.withValues(alpha: 0.25)));
    final x = size.width * clampD(v, 0.0, 1.0);
    final ok = v >= lo && v <= hi;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, x, size.height), const Radius.circular(5)), fill(ok ? col : OColors.bad));
  }

  @override
  bool shouldRepaint(covariant _BandPainter old) => old.v != v;
}

// =================================================================== Boya Karışımı

/// RYB uzayındaki ana boyalar: kırmızı, sarı, mavi, beyaz, siyah.
const List<List<double>> kPaints = [
  [1, 0, 0],
  [0, 1, 0],
  [0, 0, 1],
  [0, 0, 0],
  [1, 1, 1],
];

/// RYB'den RGB'ye üç doğrusal dönüşüm (küp köşeleri).
Color rybToColor(double r, double y, double b) {
  const c = [
    [1.0, 1.0, 1.0],
    [1.0, 0.0, 0.0],
    [1.0, 1.0, 0.0],
    [1.0, 0.5, 0.0],
    [0.163, 0.373, 0.6],
    [0.5, 0.0, 0.5],
    [0.0, 0.66, 0.2],
    [0.2, 0.094, 0.0],
  ];
  double ch(int k) {
    double lerp(double a, double b2, double t) => a + (b2 - a) * t;
    final x00 = lerp(c[0][k], c[1][k], r), x01 = lerp(c[2][k], c[3][k], r);
    final x10 = lerp(c[4][k], c[5][k], r), x11 = lerp(c[6][k], c[7][k], r);
    final y0 = lerp(x00, x01, y), y1 = lerp(x10, x11, y);
    return lerp(y0, y1, b);
  }

  int to8(double v) => (clampD(v, 0.0, 1.0) * 255).round();
  return Color.fromARGB(255, to8(ch(0)), to8(ch(1)), to8(ch(2)));
}

Color mixPaints(List<int> paints, List<int> counts) {
  final total = counts.fold(0, (a, b) => a + b);
  if (total == 0) return const Color(0xFFF7F3EA);
  var r = 0.0, y = 0.0, b = 0.0;
  for (var i = 0; i < paints.length; i++) {
    final w = counts[i] / total;
    r += kPaints[paints[i]][0] * w;
    y += kPaints[paints[i]][1] * w;
    b += kPaints[paints[i]][2] * w;
  }
  return rybToColor(r, y, b);
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

class BoyaPuzzle extends OPuzzle {
  final List<int> paints;
  final List<int> target;
  const BoyaPuzzle(this.paints, this.target);

  bool matches(List<int> c) {
    final ct = c.fold(0, (a, b) => a + b), tt = target.fold(0, (a, b) => a + b);
    if (ct == 0) return false;
    for (var i = 0; i < c.length; i++) {
      if (c[i] * tt != target[i] * ct) return false;
    }
    return true;
  }
}

class BoyaKind extends OzgunKind {
  @override
  String get id => 'boya';
  const BoyaKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final k = 2 + (d >= 3 ? 1 : 0) + (d >= 6 ? 1 : 0);
    final pool = [0, 1, 2, if (d >= 2) 3, if (d >= 5) 4];
    r.shuffle(pool);
    final paints = pool.take(k).toList()..sort();
    final maxEach = 2 + d ~/ 3;
    final target = [for (var i = 0; i < k; i++) r.range(0, maxEach)];
    if (target.where((v) => v > 0).length < 2) return null;
    var g = 0;
    for (final v in target) {
      g = _gcd(g, v);
    }
    if (g != 1) return null;
    return BoyaPuzzle(paints, target);
  }

  @override
  bool check(OPuzzle p) => p is BoyaPuzzle && p.matches(p.target) && p.target.where((v) => v > 0).length >= 2;

  @override
  Widget build(OzgunPlay play) => _BoyaView(play: play);
}

class _BoyaView extends StatefulWidget {
  final OzgunPlay play;
  const _BoyaView({required this.play});
  @override
  State<_BoyaView> createState() => _BoyaViewState();
}

class _BoyaViewState extends State<_BoyaView> with Clock {
  late final BoyaPuzzle p = widget.play.puzzle as BoyaPuzzle;
  late List<int> counts = List<int>.filled(p.paints.length, 0);
  final List<int> drops = [];
  int used = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _add(int i) {
    if (ended) return;
    setState(() {
      counts = List.of(counts);
      counts[i]++;
      drops.add(i);
      used++;
    });
    widget.play.sfx(Sfx.tap);
    _check();
  }

  void _check() {
    if (ended || !p.matches(counts)) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    final tt = p.target.fold(0, (a, b) => a + b);
    later(800, () => widget.play.win(stars: starsByMoves(used, tt, hints: hints), seconds: seconds, hints: hints, score: 1000 - used * 15));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    hints++;
    // Bir boyanın doğru oranını göster: o boyayı hedefe göre düzelt.
    final ct = counts.fold(0, (a, b) => a + b);
    final tt = p.target.fold(0, (a, b) => a + b);
    final k = math.max(1, (ct / tt).ceil());
    setState(() {
      counts = [for (final v in p.target) v * k];
      drops
        ..clear()
        ..addAll([for (var i = 0; i < counts.length; i++) for (var j = 0; j < counts[i]; j++) i]);
    });
    _check();
  }

  double _similarity() {
    final a = mixPaints(p.paints, counts), b = mixPaints(p.paints, p.target);
    final d = math.sqrt(math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2)) / math.sqrt(3);
    return clampD(1 - d, 0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final cur = mixPaints(p.paints, counts);
    final tgt = mixPaints(p.paints, p.target);
    final sim = (_similarity() * 100).round();
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '💧 $used',
        status: '%$sim',
        onUndo: drops.isEmpty || ended
            ? null
            : () => setState(() {
                  counts = List.of(counts);
                  counts[drops.removeLast()]--;
                }),
        onReset: ended
            ? null
            : () => setState(() {
                  counts = List<int>.filled(p.paints.length, 0);
                  drops.clear();
                }),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: 10,
        h: 6,
        paint: (c) {
          c.drawCircle(const Offset(2.8, 3), 2.3, fill(tgt));
          c.drawCircle(const Offset(2.8, 3), 2.3, stroke(const Color(0x33000000), 0.06));
          c.drawCircle(const Offset(7.2, 3), 2.3, fill(cur));
          c.drawCircle(const Offset(7.2, 3), 2.3, stroke(const Color(0x33000000), 0.06));
          drawLabel(c, ot(lang, 'target'), const Offset(2.8, 5.7), 0.4, OColors.ink);
          drawLabel(c, '%$sim', const Offset(7.2, 5.7), 0.4, OColors.ink);
        },
      ),
      bottom: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
        for (var i = 0; i < p.paints.length; i++)
          OChip(
            onTap: ended ? null : () => _add(i),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rybToColor(kPaints[p.paints[i]][0], kPaints[p.paints[i]][1], kPaints[p.paints[i]][2]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(height: 2),
              Text('${counts[i]}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

// =================================================================== Kervan Yolu

class KervanPuzzle extends OPuzzle {
  final int radius;
  final List<int> path; // çözüm: ilk A, son B
  final Set<int> markets;
  final Set<int> oases;
  final Set<int> rocks;
  final int water; // 0: su kuralı yok
  const KervanPuzzle(this.radius, this.path, this.markets, this.oases, this.rocks, this.water);

  int get a => path.first;
  int get b => path.last;

  /// Yolun geçerli uzunluğu (geçersiz adımdan önce) ve kalan su.
  (int, int) walk(HexArea area, List<int> route) {
    var w = water;
    final seen = <int>{};
    for (var i = 0; i < route.length; i++) {
      final c = route[i];
      if (rocks.contains(c) || !seen.add(c)) return (i, w);
      if (i > 0 && !area.adjacent(route[i - 1], c)) return (i, w);
      if (i > 0 && water > 0) {
        w--;
        if (w < 0) return (i, w);
        if (oases.contains(c) || c == b) w = water;
      }
    }
    return (route.length, w);
  }

  bool solved(HexArea area, List<int> route) =>
      route.isNotEmpty && route.first == a && route.last == b && walk(area, route).$1 == route.length && route.toSet().containsAll(markets);
}

class KervanKind extends OzgunKind {
  @override
  String get id => 'kervan';
  const KervanKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final radius = 3 + (d >= 6 ? 1 : 0);
    final area = HexArea(radius);
    final n = area.cells.length;
    final want = math.min((n * 0.55).round(), 10 + d * 2);
    final path = [r.nextInt(n)];
    final seen = {path.first};
    while (path.length < want) {
      final opts = area.neighbors(path.last).where((j) => !seen.contains(j)).toList();
      if (opts.isEmpty) break;
      final nx = r.pick(opts);
      seen.add(nx);
      path.add(nx);
    }
    if (path.length < 8) return null;
    final inner = path.sublist(2, path.length - 2);
    r.shuffle(inner);
    final markets = inner.take(math.min(inner.length, 2 + d ~/ 3)).toSet();
    var water = 0;
    final oases = <int>{};
    if (d >= 4) {
      final no = 1 + d ~/ 4;
      for (var k = 1; k <= no; k++) {
        final at = path[clampI((path.length * k / (no + 1)).round(), 1, path.length - 2)];
        if (!markets.contains(at)) oases.add(at);
      }
      var gap = 0, maxGap = 0;
      for (var i = 1; i < path.length; i++) {
        gap++;
        if (oases.contains(path[i]) || i == path.length - 1) {
          maxGap = math.max(maxGap, gap);
          gap = 0;
        }
      }
      water = maxGap + (d >= 8 ? 0 : 1);
    }
    final rocks = <int>{};
    for (var i = 0; i < n; i++) {
      if (!seen.contains(i) && r.chance(0.3 + d * 0.01)) rocks.add(i);
    }
    final p = KervanPuzzle(radius, path, markets, oases, rocks, water);
    return p.solved(area, path) ? p : null;
  }

  @override
  bool check(OPuzzle p) => p is KervanPuzzle && p.solved(HexArea(p.radius), p.path) && p.markets.isNotEmpty;

  @override
  Widget build(OzgunPlay play) => _KervanView(play: play);
}

class _KervanView extends StatefulWidget {
  final OzgunPlay play;
  const _KervanView({required this.play});
  @override
  State<_KervanView> createState() => _KervanViewState();
}

class _KervanViewState extends State<_KervanView> with Clock {
  late final KervanPuzzle p = widget.play.puzzle as KervanPuzzle;
  late final HexArea area = HexArea(p.radius);
  late List<int> route = [p.a];
  int hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  Offset get origin => Offset(math.sqrt(3) * (p.radius + 0.5) + 0.2, 1.5 * p.radius + 1.2);

  void _touch(Offset o, {bool drag = false}) {
    if (ended) return;
    final c = area.hit(o - origin);
    if (c == null) return;
    final at = route.indexOf(c);
    if (at >= 0) {
      if (!drag && at < route.length - 1) {
        setState(() => route = route.sublist(0, at + 1));
        widget.play.sfx(Sfx.tap);
      }
      return;
    }
    if (p.rocks.contains(c) || !area.adjacent(route.last, c)) return;
    final next = [...route, c];
    final (ok, _) = p.walk(area, next);
    if (ok < next.length) {
      widget.play.sfx(Sfx.error);
      return;
    }
    setState(() => route = next);
    widget.play.sfx(Sfx.place);
    if (p.solved(area, route)) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(800, () => widget.play.win(stars: starsByMoves(route.length, p.path.length, hints: hints), seconds: seconds, hints: hints, score: 1000 - seconds));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    var k = 0;
    while (k < route.length && k < p.path.length && route[k] == p.path[k]) {
      k++;
    }
    hints++;
    setState(() => route = p.path.sublist(0, math.min(p.path.length, k + 1)));
    if (p.solved(area, route)) {
      ended = true;
      later(800, () => widget.play.win(stars: 1, seconds: seconds, hints: hints));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final (_, left) = p.walk(area, route);
    final visited = route.toSet();
    final mk = p.markets.where(visited.contains).length;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '🏺 $mk/${p.markets.length}',
        status: p.water > 0 ? '💧 $left/${p.water} · ${clock()}' : clock(),
        onUndo: route.length <= 1 || ended ? null : () => setState(() => route = route.sublist(0, route.length - 1)),
        onReset: ended ? null : () => setState(() => route = [p.a]),
        onHint: _hint,
      ),
      board: TapCanvas(
        w: math.sqrt(3) * (2 * p.radius + 1) + 0.4,
        h: 3.0 * p.radius + 2.4,
        onTap: (o) => _touch(o),
        onPanUpdate: (o) => _touch(o, drag: true),
        paint: (c) {
          final o = origin;
          for (var i = 0; i < area.cells.length; i++) {
            final m = o + area.center(i);
            final hex = area.hexPath(m, 0.97);
            c.drawPath(hex, fill(p.rocks.contains(i) ? const Color(0xFF9C8466) : const Color(0xFFEBD3A4)));
            c.drawPath(hex, stroke(const Color(0xFFC9A66B), 0.05));
            if (p.rocks.contains(i)) {
              final tri = Path()
                ..moveTo(m.dx - 0.45, m.dy + 0.3)
                ..lineTo(m.dx, m.dy - 0.4)
                ..lineTo(m.dx + 0.45, m.dy + 0.3)
                ..close();
              c.drawPath(tri, fill(const Color(0xFF6E5A44)));
            }
            if (p.oases.contains(i)) {
              c.drawOval(Rect.fromCenter(center: m + const Offset(0, 0.2), width: 0.9, height: 0.4), fill(const Color(0xFF5DADE2)));
              c.drawLine(m + const Offset(0.2, 0.15), m + const Offset(0.25, -0.45), stroke(const Color(0xFF6B4A2B), 0.08));
              c.drawCircle(m + const Offset(0.25, -0.5), 0.22, fill(const Color(0xFF4F7F52)));
            }
            if (p.markets.contains(i)) {
              c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 0.9, height: 0.7), const Radius.circular(0.1)),
                  fill(visited.contains(i) ? const Color(0xFF4F9A6E) : const Color(0xFFB23A48)));
              c.drawRect(Rect.fromCenter(center: m + const Offset(0, -0.4), width: 1.0, height: 0.16), fill(const Color(0xFFD9A441)));
            }
          }
          if (route.length > 1) {
            final path = Path();
            for (var k = 0; k < route.length; k++) {
              final m = o + area.center(route[k]);
              if (k == 0) {
                path.moveTo(m.dx, m.dy);
              } else {
                path.lineTo(m.dx, m.dy);
              }
            }
            c.drawPath(path, stroke(const Color(0x995B3A0A), 0.32));
            c.drawPath(path, stroke(const Color(0xFFF4E3C1), 0.08));
          }
          for (final (cell, col) in [(p.a, const Color(0xFF3E6FB0)), (p.b, const Color(0xFF7A4E7E))]) {
            final m = o + area.center(cell);
            c.drawCircle(m, 0.55, fill(col));
            c.drawRect(Rect.fromCenter(center: m, width: 0.5, height: 0.36), fill(Colors.white));
            c.drawRect(Rect.fromCenter(center: m + const Offset(0, -0.26), width: 0.62, height: 0.12), fill(Colors.white));
          }
          final m = o + area.center(route.last);
          c.drawCircle(m + const Offset(0, -0.05), 0.24, fill(const Color(0xFF8B5A2B)));
          c.drawCircle(m + const Offset(0.22, -0.28), 0.1, fill(const Color(0xFF8B5A2B)));
        },
      ),
    );
  }
}
