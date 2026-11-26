// Desen atölyesi ekranları: Kolam Çizgisi, Girih Desenleri, Batik Atölyesi, Minyatür Boyama, Kağıt Oyma, Kına Deseni.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/pattern_texts.dart';
import '../studio_chrome.dart';
import '../texts.dart';
import 'folk.dart' show ft;
import 'pattern_logic.dart';

Text _label(String s) => Text(s, style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700));

// =================================================================== Kolam Çizgisi

class KolamPuzzle extends OPuzzle {
  final KolamLevel lv;
  const KolamPuzzle(this.lv);
}

class KolamKind extends OzgunKind {
  const KolamKind();
  @override
  String get id => 'kolam';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeKolamLevel(d, r);
    return lv == null ? null : KolamPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is KolamPuzzle && checkKolamLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _KolamView(play: play);
}

class _KolamView extends StatefulWidget {
  final OzgunPlay play;
  const _KolamView({required this.play});
  @override
  State<_KolamView> createState() => _KolamViewState();
}

class _KolamViewState extends State<_KolamView> with Clock {
  late final KolamLevel lv = (widget.play.puzzle as KolamPuzzle).lv;
  late List<bool> m = List<bool>.of(lv.start);
  late List<int> comp = kolamComponents(lv.w, lv.h, m);
  final List<int> undo = [];
  int taps = 0, hints = 0;

  int get loops => comp.fold<int>(0, (a, b) => b + 1 > a ? b + 1 : a);

  @override
  void initState() {
    super.initState();
    startClock();
  }

  Offset _mid(int s) {
    final c = kolamSideCells(lv.w, lv.h, s);
    return Offset((c[0] + c[2]) / 2 + 0.5, (c[1] + c[3]) / 2 + 0.5);
  }

  void _toggle(int s, {bool hint = false}) {
    setState(() {
      m[s] = !m[s];
      comp = kolamComponents(lv.w, lv.h, m);
      if (!hint) {
        taps++;
        undo.add(s);
      }
    });
    widget.play.sfx(Sfx.place);
    if (loops == 1 && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1100, () => widget.play.win(
            stars: starsByMoves(taps, lv.par, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - taps * 10 - hints * 60,
          ));
    }
  }

  void _tap(Offset o) {
    if (ended) return;
    final p = o - const Offset(0.5, 0.5);
    var best = -1;
    var bd = 0.38;
    for (var s = 0; s < lv.sides; s++) {
      if (!lv.editable[s]) continue;
      final dd = (_mid(s) - p).distance;
      if (dd < bd) {
        bd = dd;
        best = s;
      }
    }
    if (best >= 0) _toggle(best);
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    for (var s = 0; s < lv.sides; s++) {
      if (lv.editable[s] && m[s] != lv.sol[s]) {
        hints++;
        _toggle(s, hint: true);
        return;
      }
    }
  }

  /// Kenar ortasında ayna (geri dönüş) var mı? Dış kenarlar hep geri döndürür.
  bool _reflect(int x, int y, int side) {
    final w = lv.w, h = lv.h, nV = lv.nV;
    switch (side) {
      case 0: // K
        return y == 0 || m[nV + (y - 1) * w + x];
      case 1: // D
        return x == w - 1 || m[y * (w - 1) + x];
      case 2: // G
        return y == h - 1 || m[nV + y * w + x];
      default: // B
        return x == 0 || m[y * (w - 1) + x - 1];
    }
  }

  static const _loopColors = [
    Color(0xFFF2C14E), Color(0xFF7FC8F8), Color(0xFFF28482), Color(0xFF9BE58B),
    Color(0xFFD7A4F0), Color(0xFFFFB067), Color(0xFF6EE0D0), Color(0xFFF7A1C4),
  ];

  void _paint(Canvas c) {
    final bw = lv.w + 1.0, bh = lv.h + 1.0;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, bw, bh), const Radius.circular(0.3)), fill(const Color(0xFF3B2F2A)));
    c.save();
    c.translate(0.5, 0.5);
    final one = loops == 1;
    // Her hücrede dört parça: 0 K-D, 1 D-G, 2 G-B, 3 B-K.
    for (var y = 0; y < lv.h; y++) {
      for (var x = 0; x < lv.w; x++) {
        final mids = [
          Offset(x + 0.5, y + 0.0),
          Offset(x + 1.0, y + 0.5),
          Offset(x + 0.5, y + 1.0),
          Offset(x + 0.0, y + 0.5),
        ];
        for (var k = 0; k < 4; k++) {
          final a = k, b = (k + 1) % 4;
          final p = mids[a], q = mids[b];
          Offset tan(int side, Offset from, Offset to) {
            if (_reflect(x, y, side)) {
              return side.isEven ? Offset((to.dx - from.dx).sign, 0) : Offset(0, (to.dy - from.dy).sign);
            }
            final v = to - from;
            return v / v.distance;
          }

          final path = Path()
            ..moveTo(p.dx, p.dy)
            ..cubicTo(
              p.dx + tan(a, p, q).dx * 0.3,
              p.dy + tan(a, p, q).dy * 0.3,
              q.dx + tan(b, q, p).dx * 0.3,
              q.dy + tan(b, q, p).dy * 0.3,
              q.dx,
              q.dy,
            );
          final col = one ? const Color(0xFFF6F1E3) : _loopColors[comp[(y * lv.w + x) * 4 + k] % _loopColors.length];
          c.drawPath(path, stroke(col, 0.09));
        }
        c.drawCircle(Offset(x + 0.5, y + 0.5), 0.07, fill(const Color(0xFFF6F1E3)));
      }
    }
    if (!one) {
      for (var s = 0; s < lv.sides; s++) {
        if (lv.editable[s]) c.drawCircle(_mid(s), 0.13, stroke(const Color(0x99FFFFFF), 0.025));
      }
    }
    c.restore();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${pt(lang, 'lines')}: $loops',
        status: '${ot(lang, 'moves')}: $taps · ${clock()}',
        onHint: _hint,
        onUndo: undo.isEmpty || ended
            ? null
            : () {
                final s = undo.removeLast();
                setState(() {
                  m[s] = !m[s];
                  comp = kolamComponents(lv.w, lv.h, m);
                });
              },
      ),
      board: TapCanvas(w: lv.w + 1.0, h: lv.h + 1.0, paint: _paint, onTap: _tap, semantics: pt(lang, 'lines')),
    );
  }
}

// =================================================================== Girih Desenleri

class GirihPuzzle extends OPuzzle {
  final GirihLevel lv;
  const GirihPuzzle(this.lv);
}

class GirihKind extends OzgunKind {
  const GirihKind();
  @override
  String get id => 'girih';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeGirihLevel(d, r);
    return lv == null ? null : GirihPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is GirihPuzzle && checkGirihLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _GirihView(play: play);
}

const List<Color> _girihColors = [
  Color(0xFF1F4E79), // ongen
  Color(0xFFD9A441), // beşgen
  Color(0xFF2E7D5B), // eşkenar dörtgen
  Color(0xFF3A8D8C), // altıgen
  Color(0xFFB23A48), // papyon
];

void _drawGirihTile(Canvas c, GTile t, Offset Function(GPt) map, {bool straps = true}) {
  final path = Path();
  for (var i = 0; i < t.v.length; i++) {
    final o = map(t.v[i]);
    if (i == 0) {
      path.moveTo(o.dx, o.dy);
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }
  path.close();
  c.drawPath(path, fill(_girihColors[t.type]));
  c.drawPath(path, stroke(const Color(0x33FFFFFF), 0.03));
  if (!straps) return;
  for (final s in girihStraps(t)) {
    final p = Path()
      ..moveTo(map(s[0]).dx, map(s[0]).dy)
      ..lineTo(map(s[1]).dx, map(s[1]).dy)
      ..lineTo(map(s[2]).dx, map(s[2]).dy);
    c.drawPath(p, stroke(const Color(0xFF2A1E14), 0.13));
    c.drawPath(p, stroke(const Color(0xFFF4E9D0), 0.07));
  }
}

class _GirihView extends StatefulWidget {
  final OzgunPlay play;
  const _GirihView({required this.play});
  @override
  State<_GirihView> createState() => _GirihViewState();
}

class _GirihViewState extends State<_GirihView> with Clock {
  late final GirihLevel lv = (widget.play.puzzle as GirihPuzzle).lv;
  final Set<int> placed = {};
  int? selType;
  int rot = 0;
  int mistakes = 0, hints = 0;
  int? flash;
  late double minX, minY, maxX, maxY;

  @override
  void initState() {
    super.initState();
    minX = minY = 1e9;
    maxX = maxY = -1e9;
    for (final t in lv.tiles) {
      for (final p in t.v) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    startClock();
  }

  static const double _m = 0.4;
  Offset _map(GPt p) => Offset(p.x - minX + _m, maxY - p.y + _m);
  GPt _unmap(Offset o) => GPt(o.dx - _m + minX, maxY - (o.dy - _m));

  int get left => lv.holes.length - placed.length;

  void _place(int h) {
    setState(() => placed.add(h));
    widget.play.sfx(Sfx.place);
    if (left == 0 && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1000, () => widget.play.win(
            stars: starsByMoves(mistakes, 0, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - mistakes * 50 - hints * 60,
          ));
    }
  }

  void _tap(Offset o) {
    if (ended) return;
    final p = _unmap(o);
    for (final h in lv.holes) {
      if (placed.contains(h) || !girihContains(lv.tiles[h], p)) continue;
      final st = selType;
      if (st == null) return;
      if (girihMatches(lv.tiles[h], st, rot)) {
        _place(h);
      } else {
        mistakes++;
        widget.play.sfx(Sfx.error);
        setState(() => flash = h);
        later(600, () => setState(() => flash = null));
      }
      return;
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    for (final h in lv.holes) {
      if (!placed.contains(h)) {
        hints++;
        setState(() {
          selType = lv.tiles[h].type;
          rot = lv.tiles[h].rot;
        });
        _place(h);
        return;
      }
    }
  }

  void _paint(Canvas c) {
    final w = maxX - minX + 2 * _m, h = maxY - minY + 2 * _m;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(0.3)), fill(const Color(0xFF241C17)));
    for (var i = 0; i < lv.tiles.length; i++) {
      final t = lv.tiles[i];
      final isHole = lv.holes.contains(i) && !placed.contains(i);
      if (!isHole) {
        _drawGirihTile(c, t, _map);
        continue;
      }
      final path = Path();
      for (var k = 0; k < t.v.length; k++) {
        final o = _map(t.v[k]);
        if (k == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      c.drawPath(path, fill(const Color(0xFF12100E)));
      c.drawPath(path, stroke(flash == i ? OColors.bad : const Color(0xFFE6D3A3), flash == i ? 0.09 : 0.045));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final look = StudioLook.of(context);
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ft(lang, 'gaps')}: $left',
        status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}',
        onHint: _hint,
        extra: [
          IconButton(
            tooltip: ft(lang, 'rotate'),
            onPressed: ended ? null : () => setState(() => rot = (rot + 1) % 10),
            icon: Icon(Icons.rotate_left, color: look.accent),
          ),
        ],
      ),
      board: TapCanvas(w: maxX - minX + 2 * _m, h: maxY - minY + 2 * _m, paint: _paint, onTap: _tap, semantics: pt(lang, 'karo')),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        _label(pt(lang, 'karo')),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          for (var t = 0; t < 5; t++)
            OChip(
              selected: selType == t,
              onTap: () => setState(() => selType = t),
              child: SizedBox(width: 44, height: 44, child: CustomPaint(painter: _GirihChipPainter(t, rot))),
            ),
        ]),
      ]),
    );
  }
}

class _GirihChipPainter extends CustomPainter {
  final int type, rot;
  _GirihChipPainter(this.type, this.rot);
  @override
  void paint(Canvas canvas, Size size) {
    final t = girihBuild(type, const GPt(0, 0), rot, 0);
    final c = t.center;
    var r = 0.0;
    for (final p in t.v) {
      r = math.max(r, (p - c).len);
    }
    final k = size.width / (2 * r + 0.2);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    _drawGirihTile(canvas, t, (p) => Offset(p.x - c.x, c.y - p.y));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GirihChipPainter old) => old.type != type || old.rot != rot;
}

// =================================================================== Batik Atölyesi

class BatikPuzzle extends OPuzzle {
  final BatikLevel lv;
  const BatikPuzzle(this.lv);
}

class BatikKind extends OzgunKind {
  const BatikKind();
  @override
  String get id => 'batik';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeBatikLevel(d, r);
    return lv == null ? null : BatikPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is BatikPuzzle && checkBatikLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _BatikView(play: play);
}

const List<Color> _dyeColors = [Color(0xFFF2C94C), Color(0xFFD1495B), Color(0xFF3D5A98), Color(0xFF8B5A2B)];

Color batikColor(int mask) {
  var r = 250.0, g = 246.0, b = 236.0;
  for (var k = 0; k < 4; k++) {
    if (mask & (1 << k) == 0) continue;
    final d = _dyeColors[k];
    r = r * (d.r * 255) / 255;
    g = g * (d.g * 255) / 255;
    b = b * (d.b * 255) / 255;
  }
  return Color.fromARGB(255, r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255));
}

void _paintFabric(Canvas c, int w, int h, List<int> masks, List<bool>? waxed) {
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02), fill(batikColor(masks[i])));
      if (waxed != null && waxed[i]) {
        c.drawRect(Rect.fromLTWH(x + 0.08, y + 0.08, 0.84, 0.84), fill(const Color(0x66FFF6D8)));
        c.drawLine(Offset(x + 0.2, y + 0.3), Offset(x + 0.6, y + 0.75), stroke(const Color(0x55FFFFFF), 0.05));
      }
    }
  }
}

class _BatikView extends StatefulWidget {
  final OzgunPlay play;
  const _BatikView({required this.play});
  @override
  State<_BatikView> createState() => _BatikViewState();
}

class _BatikViewState extends State<_BatikView> with Clock {
  late final BatikLevel lv = (widget.play.puzzle as BatikPuzzle).lv;
  final List<int> baths = [];
  late List<int?> waxAt = List<int?>.filled(lv.motifs.length, null);
  final List<int> ops = []; // >=0 banyo (boya), <0 mum (-(motif+1))
  int moves = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  List<int> get current => batikResult(lv.w, lv.h, lv.motifs, baths, waxAt, baths.length);

  List<bool> get waxed {
    final out = List<bool>.filled(lv.w * lv.h, false);
    for (var k = 0; k < lv.motifs.length; k++) {
      if (waxAt[k] == null) continue;
      for (var i = 0; i < out.length; i++) {
        if (lv.motifs[k][i]) out[i] = true;
      }
    }
    return out;
  }

  void _after() {
    final cur = current;
    var done = true;
    for (var i = 0; i < cur.length && done; i++) {
      if (cur[i] != lv.target[i]) done = false;
    }
    if (done && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      final par = lv.order.length + lv.motifs.length;
      later(1000, () => widget.play.win(
            stars: starsByMoves(moves, par, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - (moves - par) * 30 - hints * 60,
          ));
    }
  }

  void _bath(int dye) {
    if (ended || baths.contains(dye)) return;
    setState(() {
      baths.add(dye);
      ops.add(dye);
      moves++;
    });
    widget.play.sfx(Sfx.combo);
    _after();
  }

  void _wax(int k) {
    if (ended || waxAt[k] != null) return;
    setState(() {
      waxAt[k] = baths.length;
      ops.add(-(k + 1));
      moves++;
    });
    widget.play.sfx(Sfx.place);
    _after();
  }

  void _undo() {
    if (ops.isEmpty || ended) return;
    final o = ops.removeLast();
    setState(() {
      if (o >= 0) {
        baths.removeLast();
      } else {
        waxAt[-o - 1] = null;
      }
    });
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    hints++;
    // Çözümle tutarlı değilse baştan al.
    var ok = baths.length <= lv.order.length;
    for (var b = 0; b < baths.length && ok; b++) {
      if (baths[b] != lv.order[b]) ok = false;
    }
    for (var k = 0; k < lv.motifs.length && ok; k++) {
      final a = waxAt[k];
      if (a != null && a != lv.waxAt[k]) ok = false;
      if (a == null && lv.waxAt[k] < baths.length) ok = false;
    }
    if (!ok) {
      setState(() {
        baths.clear();
        ops.clear();
        waxAt = List<int?>.filled(lv.motifs.length, null);
      });
    }
    for (var k = 0; k < lv.motifs.length; k++) {
      if (waxAt[k] == null && lv.waxAt[k] == baths.length) {
        moves--;
        _wax(k);
        return;
      }
    }
    if (baths.length < lv.order.length) {
      moves--;
      _bath(lv.order[baths.length]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final cur = current;
    final wx = waxed;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ot(lang, 'moves')}: $moves',
        status: clock(),
        onHint: _hint,
        onUndo: ops.isEmpty || ended ? null : _undo,
        onReset: ended
            ? null
            : () => setState(() {
                  baths.clear();
                  ops.clear();
                  waxAt = List<int?>.filled(lv.motifs.length, null);
                }),
      ),
      top: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _label(ot(lang, 'target')),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          height: 64 * lv.h / lv.w,
          child: TapCanvas(w: lv.w + 0.0, h: lv.h + 0.0, paint: (c) => _paintFabric(c, lv.w, lv.h, lv.target, null)),
        ),
      ]),
      board: TapCanvas(
        w: lv.w + 0.0,
        h: lv.h + 0.0,
        paint: (c) => _paintFabric(c, lv.w, lv.h, cur, wx),
        semantics: ot(lang, 'target'),
      ),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        _label(pt(lang, 'wax')),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          for (var k = 0; k < lv.motifs.length; k++)
            OChip(
              selected: waxAt[k] != null,
              tooltip: pt(lang, 'motifs'),
              onTap: () => _wax(k),
              child: SizedBox(width: 36, height: 36 * lv.h / lv.w, child: CustomPaint(painter: _MaskPainter(lv.w, lv.h, lv.motifs[k]))),
            ),
        ]),
        const SizedBox(height: 8),
        _label(pt(lang, 'dyes')),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: [
          for (final dy in lv.dyes)
            OChip(
              selected: baths.contains(dy),
              onTap: baths.contains(dy) ? null : () => _bath(dy),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: _dyeColors[dy], shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                ),
                if (baths.contains(dy)) ...[const SizedBox(width: 6), Text('${baths.indexOf(dy) + 1}')],
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final int w, h;
  final List<bool> mask;
  _MaskPainter(this.w, this.h, this.mask);
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / w;
    canvas.drawRect(Offset.zero & size, fill(const Color(0xFF3A3028)));
    for (var i = 0; i < mask.length; i++) {
      if (mask[i]) canvas.drawRect(Rect.fromLTWH((i % w) * k, (i ~/ w) * k, k, k), fill(const Color(0xFFFFF1C9)));
    }
  }

  @override
  bool shouldRepaint(covariant _MaskPainter old) => false;
}

// =================================================================== Minyatür Boyama

class MiniPuzzle extends OPuzzle {
  final MiniLevel lv;
  const MiniPuzzle(this.lv);
}

class MinyaturKind extends OzgunKind {
  const MinyaturKind();
  @override
  String get id => 'minyatur';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeMiniLevel(d, r);
    return lv == null ? null : MiniPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is MiniPuzzle && checkMiniLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _MiniView(play: play);
}

class _MiniView extends StatefulWidget {
  final OzgunPlay play;
  const _MiniView({required this.play});
  @override
  State<_MiniView> createState() => _MiniViewState();
}

class _MiniViewState extends State<_MiniView> with Clock {
  late final MiniLevel lv = (widget.play.puzzle as MiniPuzzle).lv;
  late final List<bool> filled = List<bool>.filled(lv.regions, false);
  int sel = 0;
  int mistakes = 0, hints = 0;
  int? flash;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  int get left => filled.where((f) => !f).length;
  int leftOf(int c) {
    var n = 0;
    for (var k = 0; k < lv.regions; k++) {
      if (!filled[k] && lv.regionColor[k] == c) n++;
    }
    return n;
  }

  void _fill(int k) {
    setState(() {
      filled[k] = true;
      if (leftOf(sel) == 0) {
        for (var c = 0; c < lv.palette.length; c++) {
          if (leftOf(c) > 0) {
            sel = c;
            break;
          }
        }
      }
    });
    widget.play.sfx(Sfx.place);
    if (left == 0 && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1000, () => widget.play.win(
            stars: starsByMoves(mistakes, lv.regions ~/ 15, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - mistakes * 20 - hints * 40,
          ));
    }
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= lv.n || y >= lv.n) return;
    final k = lv.region[y * lv.n + x];
    if (filled[k]) return;
    if (lv.regionColor[k] == sel) {
      _fill(k);
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      setState(() => flash = k);
      later(500, () => setState(() => flash = null));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    var best = -1;
    for (var k = 0; k < lv.regions; k++) {
      if (filled[k]) continue;
      if (best < 0 || (lv.regionColor[k] == sel && lv.regionColor[best] != sel)) best = k;
    }
    if (best >= 0) {
      hints++;
      _fill(best);
    }
  }

  void _paint(Canvas c) {
    final n = lv.n;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final k = lv.region[y * n + x];
        Color col;
        if (filled[k]) {
          col = Color(lv.palette[lv.regionColor[k]]);
        } else if (flash == k) {
          col = const Color(0xFFF2B8A8);
        } else if (lv.regionColor[k] == sel) {
          col = const Color(0xFFE0D6C2);
        } else {
          col = const Color(0xFFF7F1E3);
        }
        c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02), fill(col));
      }
    }
    final line = stroke(const Color(0xFF5B4636), 0.06);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final k = lv.region[y * n + x];
        if (x + 1 < n && lv.region[y * n + x + 1] != k) c.drawLine(Offset(x + 1.0, y.toDouble()), Offset(x + 1.0, y + 1.0), line);
        if (y + 1 < n && lv.region[(y + 1) * n + x] != k) c.drawLine(Offset(x.toDouble(), y + 1.0), Offset(x + 1.0, y + 1.0), line);
      }
    }
    c.drawRect(Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), stroke(const Color(0xFF5B4636), 0.12));
    for (var k = 0; k < lv.regions; k++) {
      if (filled[k]) continue;
      final l = lv.labelCell[k];
      drawLabel(c, '${lv.regionColor[k] + 1}', Offset(l % n + 0.5, l ~/ n + 0.5), 0.8, const Color(0xFF5B4636));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(lang: lang, left: '${ft(lang, 'gaps')}: $left', status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}', onHint: _hint),
      board: InteractiveViewer(
        maxScale: 4,
        child: TapCanvas(w: lv.n + 0.0, h: lv.n + 0.0, paint: _paint, onTap: _tap, semantics: ot(lang, 'target')),
      ),
      bottom: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (var cI = 0; cI < lv.palette.length; cI++)
          OChip(
            selected: sel == cI,
            onTap: () => setState(() => sel = cI),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: Color(lv.palette[cI]), shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
              ),
              const SizedBox(width: 5),
              leftOf(cI) == 0 ? const Icon(Icons.check, size: 18) : Text('${cI + 1}'),
            ]),
          ),
      ]),
    );
  }
}

// =================================================================== Kağıt Oyma

class PaperPuzzle extends OPuzzle {
  final PaperLevel lv;
  const PaperPuzzle(this.lv);
}

class KagitOymaKind extends OzgunKind {
  const KagitOymaKind();
  @override
  String get id => 'kagit-oyma';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makePaperLevel(d, r);
    return lv == null ? null : PaperPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is PaperPuzzle && checkPaperLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _PaperView(play: play);
}

const List<Color> _paperColors = [Color(0xFFE84A8A), Color(0xFFF28C28), Color(0xFF1FA38A), Color(0xFF7E4BC4), Color(0xFFF2C14E), Color(0xFF2F80ED)];

void _paintSheet(Canvas c, int s, List<bool> holes, Color paper, {List<bool>? wrong}) {
  c.drawRect(Rect.fromLTWH(0, -0.6, s.toDouble(), 0.25), fill(const Color(0xFF8A6A4A)));
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02);
      if (!holes[i]) c.drawRect(r, fill(paper));
      if (wrong != null && wrong[i]) c.drawRect(r.deflate(0.1), stroke(OColors.bad, 0.12));
    }
  }
}

class _PaperView extends StatefulWidget {
  final OzgunPlay play;
  const _PaperView({required this.play});
  @override
  State<_PaperView> createState() => _PaperViewState();
}

class _PaperViewState extends State<_PaperView> with Clock {
  late final PaperLevel lv = (widget.play.puzzle as PaperPuzzle).lv;
  late final Color paper = _paperColors[widget.play.seed.abs() % _paperColors.length];
  final Set<int> cuts = {};
  int tries = 0, mistakes = 0, hints = 0;
  List<bool>? shown, wrong;
  late final int hs = lv.s ~/ 2;
  late final int pw = hs, ph = lv.fold >= 2 ? hs : lv.s;
  late final Map<int, int> disp = {}; // ekran hücresi -> tabaka hücresi

  int get dw => lv.rot.isOdd ? ph : pw;
  int get dh => lv.rot.isOdd ? pw : ph;

  Offset _tf(double x, double y) {
    switch (lv.rot) {
      case 1:
        return Offset(ph - y, x);
      case 2:
        return Offset(pw - x, ph - y);
      case 3:
        return Offset(y, pw - x);
      default:
        return Offset(x, y);
    }
  }

  @override
  void initState() {
    super.initState();
    for (var y = 0; y < lv.s; y++) {
      for (var x = 0; x < lv.s; x++) {
        if (!paperInPiece(lv.s, lv.fold, x, y)) continue;
        final a = _tf(x.toDouble(), y.toDouble()), b = _tf(x + 1.0, y + 1.0);
        final dx = math.min(a.dx, b.dx).round(), dy = math.min(a.dy, b.dy).round();
        disp[dy * dw + dx] = y * lv.s + x;
      }
    }
    startClock();
  }

  void _tap(Offset o) {
    if (ended || shown != null) return;
    final x = (o.dx - 0.5).floor(), y = (o.dy - 1.0).floor();
    if (x < 0 || y < 0 || x >= dw || y >= dh) return;
    final c = disp[y * dw + x];
    if (c == null || paperBorder(lv.s, c % lv.s, c ~/ lv.s)) return;
    setState(() => cuts.contains(c) ? cuts.remove(c) : cuts.add(c));
    widget.play.sfx(Sfx.tap);
  }

  void _unfold() {
    if (ended || shown != null) return;
    tries++;
    final t = paperUnfold(lv.s, lv.fold, cuts);
    final wr = [for (var i = 0; i < t.length; i++) t[i] != lv.target[i]];
    final ok = !wr.contains(true);
    setState(() {
      shown = t;
      wrong = ok ? null : wr;
    });
    if (ok) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1400, () => widget.play.win(
            stars: starsByMoves(mistakes, 0, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - mistakes * 120 - hints * 80,
          ));
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      later(1800, () => setState(() {
            shown = null;
            wrong = null;
          }));
    }
  }

  Future<void> _hint() async {
    if (ended || shown != null || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    final sol = lv.cut.toSet();
    for (final c in disp.values) {
      if (paperBorder(lv.s, c % lv.s, c ~/ lv.s)) continue;
      if (sol.contains(c) != cuts.contains(c)) {
        hints++;
        setState(() => sol.contains(c) ? cuts.add(c) : cuts.remove(c));
        widget.play.sfx(Sfx.place);
        return;
      }
    }
  }

  void _paintPiece(Canvas c) {
    c.save();
    c.translate(0.5, 1.0);
    for (final e in disp.entries) {
      final dx = e.key % dw, dy = e.key ~/ dw;
      final r = Rect.fromLTWH(dx.toDouble(), dy.toDouble(), 1.02, 1.02);
      c.drawRect(r, fill(cuts.contains(e.value) ? const Color(0xFF1C1A24) : paper));
      if (!cuts.contains(e.value) && paperBorder(lv.s, e.value % lv.s, e.value ~/ lv.s)) {
        c.drawRect(r, fill(const Color(0x22000000)));
      }
    }
    // İp (tabakanın üst kenarı) ve kesikli katlama çizgileri.
    void seg(double x1, double y1, double x2, double y2, Paint p, {bool dash = false}) {
      final a = _tf(x1, y1), b = _tf(x2, y2);
      if (!dash) {
        c.drawLine(a, b, p);
        return;
      }
      final len = (b - a).distance;
      final n = (len / 0.4).floor();
      for (var i = 0; i < n; i += 2) {
        c.drawLine(Offset.lerp(a, b, i / n)!, Offset.lerp(a, b, (i + 1) / n)!, p);
      }
    }

    final str = stroke(const Color(0xFFE6D3A3), 0.14);
    final fold = stroke(Colors.white, 0.07);
    seg(0, 0, pw.toDouble(), 0, str);
    seg(pw.toDouble(), 0, pw.toDouble(), lv.fold >= 3 ? hs.toDouble() : ph.toDouble(), fold, dash: true);
    if (lv.fold == 2) seg(0, ph.toDouble(), pw.toDouble(), ph.toDouble(), fold, dash: true);
    if (lv.fold >= 3) seg(0, 0, hs.toDouble(), hs.toDouble(), fold, dash: true);
    c.restore();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final sh = shown;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${pt(lang, 'tries')}: $tries',
        status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}',
        onHint: _hint,
        onReset: ended ? null : () => setState(cuts.clear),
      ),
      top: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _label(ot(lang, 'target')),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          height: 90,
          child: TapCanvas(
            w: lv.s + 0.0,
            h: lv.s + 0.8,
            paint: (c) {
              c.translate(0, 0.8);
              _paintSheet(c, lv.s, lv.target, paper);
            },
          ),
        ),
      ]),
      board: sh != null
          ? TapCanvas(
              w: lv.s + 0.0,
              h: lv.s + 0.8,
              paint: (c) {
                c.translate(0, 0.8);
                _paintSheet(c, lv.s, sh, paper, wrong: wrong);
              },
            )
          : TapCanvas(w: dw + 1.0, h: dh + 1.5, paint: _paintPiece, onTap: _tap, semantics: pt(lang, 'folded')),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        _label(pt(lang, 'folded')),
        const SizedBox(height: 6),
        OChip(
          onTap: ended || sh != null ? null : _unfold,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.open_in_full, size: 20),
            const SizedBox(width: 6),
            Text(pt(lang, 'unfold')),
          ]),
        ),
      ]),
    );
  }
}

// =================================================================== Kına Deseni

class HennaPuzzle extends OPuzzle {
  final HennaLevel lv;
  const HennaPuzzle(this.lv);
}

class KinaKind extends OzgunKind {
  const KinaKind();
  @override
  String get id => 'kina';
  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeHennaLevel(d, r);
    return lv == null ? null : HennaPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is HennaPuzzle && checkHennaLevel(p.lv);
  @override
  Widget build(OzgunPlay play) => _HennaView(play: play);
}

/// Ten rengi seçenekleri (açıktan koyuya).
const List<Color> kSkinTones = [
  Color(0xFFF3D6C1), Color(0xFFE8B896), Color(0xFFC98E62), Color(0xFFA4683F), Color(0xFF7B4A2A), Color(0xFF4E2E1C),
];

class _HennaView extends StatefulWidget {
  final OzgunPlay play;
  const _HennaView({required this.play});
  @override
  State<_HennaView> createState() => _HennaViewState();
}

class _HennaViewState extends State<_HennaView> with Clock {
  late final HennaLevel lv = (widget.play.puzzle as HennaPuzzle).lv;
  late final Set<int> drawn = {
    for (var e = 0; e < lv.edges.length; e++)
      if (lv.inPattern[e] && lv.edgeSector[e] == 0) e,
  };
  late int tone = widget.play.seed.abs() % kSkinTones.length;
  int mistakes = 0, hints = 0;
  int? flash;

  late final double rad = lv.rings + 1.3;
  double get cw => rad * 2;
  double get chh => rad * 2 + rad * 0.95;
  Offset get center => Offset(rad, chh - rad);

  @override
  void initState() {
    super.initState();
    startClock();
  }

  int get left {
    var n = 0;
    for (var e = 0; e < lv.edges.length; e++) {
      if (lv.inPattern[e] && !drawn.contains(e)) n++;
    }
    return n;
  }

  void _add(int e) {
    setState(() => drawn.add(e));
    widget.play.sfx(Sfx.place);
    if (left == 0 && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(1100, () => widget.play.win(
            stars: starsByMoves(mistakes, 1, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - mistakes * 30 - hints * 50,
          ));
    }
  }

  void _tap(Offset o) {
    if (ended) return;
    final p = o - center;
    final e = hennaNearest(lv, p.dx, p.dy);
    if (e < 0 || drawn.contains(e)) return;
    if (lv.inPattern[e]) {
      _add(e);
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      setState(() => flash = e);
      later(500, () => setState(() => flash = null));
    }
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    for (var e = 0; e < lv.edges.length; e++) {
      if (lv.inPattern[e] && !drawn.contains(e)) {
        hints++;
        _add(e);
        return;
      }
    }
  }

  void _edge(Canvas c, int e, Paint p) {
    final a = lv.edges[e][0], b = lv.edges[e][1];
    if (lv.edges[e][2] == 1) {
      final r = math.sqrt(lv.px[a] * lv.px[a] + lv.py[a] * lv.py[a]);
      final aa = math.atan2(lv.py[a], lv.px[a]);
      var sw = math.atan2(lv.py[b], lv.px[b]) - aa;
      while (sw < 0) {
        sw += 2 * math.pi;
      }
      if (sw > math.pi) sw -= 2 * math.pi;
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), aa, sw, false, p);
    } else {
      c.drawLine(Offset(lv.px[a], lv.py[a]), Offset(lv.px[b], lv.py[b]), p);
    }
  }

  void _paint(Canvas c) {
    final skin = kSkinTones[tone];
    final skinDark = Color.lerp(skin, Colors.black, 0.18)!;
    // Avuç ve parmaklar (sade silüet).
    final ctr = center;
    final fingerW = rad * 0.34;
    for (var i = 0; i < 4; i++) {
      final fx = ctr.dx - rad * 0.78 + i * rad * 0.52;
      final len = rad * (i == 1 || i == 2 ? 1.05 : 0.9);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(fx - fingerW / 2, ctr.dy - rad * 0.5 - len, fingerW, len + rad * 0.3), Radius.circular(fingerW / 2)),
        fill(skinDark),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(fx - fingerW / 2 + 0.05, ctr.dy - rad * 0.5 - len + 0.05, fingerW - 0.1, len + rad * 0.3), Radius.circular(fingerW / 2)),
        fill(skin),
      );
    }
    c.drawCircle(ctr, rad * 0.98, fill(skinDark));
    c.drawCircle(ctr, rad * 0.95, fill(skin));
    c.save();
    c.translate(ctr.dx, ctr.dy);
    final dark = tone >= 3;
    const henna = Color(0xFF6B2A12);
    // Nokta ağı (soluk).
    for (var i = 0; i < lv.px.length; i++) {
      c.drawCircle(Offset(lv.px[i], lv.py[i]), 0.05, fill(dark ? const Color(0x55FFFFFF) : const Color(0x40000000)));
    }
    if (lv.guides) {
      for (var e = 0; e < lv.edges.length; e++) {
        if (lv.inPattern[e] && !drawn.contains(e)) _edge(c, e, stroke(henna.withValues(alpha: 0.22), 0.07));
      }
    }
    final under = stroke(const Color(0x66FFF1DD), 0.2);
    final line = stroke(henna, 0.11);
    for (final e in drawn) {
      if (dark) _edge(c, e, under);
      _edge(c, e, line);
    }
    final fl = flash;
    if (fl != null) _edge(c, fl, stroke(OColors.bad, 0.1));
    // Noktalar ve dış halkada yaprakçıklar.
    final touched = <int>{};
    for (final e in drawn) {
      touched
        ..add(lv.edges[e][0])
        ..add(lv.edges[e][1]);
    }
    for (final p in touched) {
      final o = Offset(lv.px[p], lv.py[p]);
      c.drawCircle(o, 0.1, fill(henna));
      final r = o.distance;
      if ((r - lv.rings).abs() < 1e-6) {
        final u = o / r;
        final tip = o + u * 0.45;
        final nrm = Offset(-u.dy, u.dx) * 0.16;
        final leaf = Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx + u.dx * 0.22 + nrm.dx, o.dy + u.dy * 0.22 + nrm.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(o.dx + u.dx * 0.22 - nrm.dx, o.dy + u.dy * 0.22 - nrm.dy, o.dx, o.dy);
        c.drawPath(leaf, fill(henna));
      }
    }
    c.restore();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return OScreen(
      bar: OBar(lang: lang, left: '${ft(lang, 'gaps')}: $left', status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}', onHint: _hint),
      board: TapCanvas(w: cw, h: chh, paint: _paint, onTap: _tap, semantics: pt(lang, 'tone')),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        _label(pt(lang, 'tone')),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
          for (var t = 0; t < kSkinTones.length; t++)
            OChip(
              selected: tone == t,
              tooltip: pt(lang, 'tone'),
              onTap: () => setState(() => tone = t),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: kSkinTones[t], shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
              ),
            ),
        ]),
      ]),
    );
  }
}
