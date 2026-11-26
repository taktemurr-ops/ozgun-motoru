import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../texts.dart';
import 'folk.dart' show ft;
import 'mosaic_logic.dart';

// =================================================================== Mozaik Restorasyonu

class MozPuzzle extends OPuzzle {
  final MozLevel lv;
  const MozPuzzle(this.lv);
}

class MozaikKind extends OzgunKind {
  const MozaikKind();
  @override
  String get id => 'mozrest';

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeMozLevel(d, r);
    return lv == null ? null : MozPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is MozPuzzle && checkMozLevel(p.lv);

  @override
  Widget build(OzgunPlay play) => _MozView(play: play);
}

/// Hücreye özgü küçük oynama (taşlar el yapımı görünsün).
int _hash(int i) {
  var h = (i * 2654435761) & 0xFFFFFFFF;
  h ^= h >> 13;
  h = (h * 1274126177) & 0xFFFFFFFF;
  return h ^ (h >> 16);
}

Color _shade(Color c, int i) {
  final t = ((_hash(i) % 13) - 6) / 100.0;
  return t >= 0 ? Color.lerp(c, Colors.white, t)! : Color.lerp(c, Colors.black, -t)!;
}

void _tessera(Canvas c, double x, double y, Color col, int seed, {double size = 1}) {
  final h = _hash(seed);
  final j = size * 0.05;
  final dx = ((h & 7) - 3.5) / 3.5 * j, dy = (((h >> 3) & 7) - 3.5) / 3.5 * j;
  final r = Rect.fromLTWH(x + size * 0.07 + dx, y + size * 0.07 + dy, size * 0.86, size * 0.86);
  c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(size * 0.14)), fill(_shade(col, seed)));
  c.drawLine(r.topLeft + Offset(size * 0.12, size * 0.14), r.topCenter + Offset(0, size * 0.12),
      stroke(Colors.white.withValues(alpha: 0.18), size * 0.06));
}

class _MozView extends StatefulWidget {
  final OzgunPlay play;
  const _MozView({required this.play});
  @override
  State<_MozView> createState() => _MozViewState();
}

class _MozViewState extends State<_MozView> with Clock {
  late final MozLevel lv = (widget.play.puzzle as MozPuzzle).lv;
  late List<bool> filled = List<bool>.filled(lv.w * lv.h, false);
  late List<int> supply = _initSupply();
  late List<int> rot = [for (final f in lv.frags) f.rot];
  final Set<int> fragGone = {};
  int? selColor, selFrag, flashCell;
  bool flashFit = false;
  int mistakes = 0, hints = 0;

  List<int> _initSupply() {
    final s = List<int>.filled(lv.palette.length, 0);
    for (final i in lv.looseCells) {
      s[lv.grid[i]]++;
    }
    return s;
  }

  int get gaps {
    var n = 0;
    for (var i = 0; i < filled.length; i++) {
      if (lv.hole[i] && !filled[i]) n++;
    }
    return n;
  }

  @override
  void initState() {
    super.initState();
    startClock();
    final firstColor = supply.indexWhere((v) => v > 0);
    if (firstColor >= 0) selColor = firstColor;
  }

  /// Hiçbir yere oturamayan kırık parça taşlarına ayrılır (oyun kilitlenmez).
  void _settle() {
    for (var f = 0; f < lv.frags.length; f++) {
      if (fragGone.contains(f)) continue;
      var can = false;
      for (var r = 0; r < 4 && !can; r++) {
        final shape = fragShape(lv, lv.frags[f], r);
        for (var y = 0; y < lv.h && !can; y++) {
          for (var x = 0; x < lv.w && !can; x++) {
            if (fragFits(lv, filled, shape, x, y)) can = true;
          }
        }
      }
      if (!can) {
        fragGone.add(f);
        for (final c in lv.frags[f].cells) {
          supply[lv.at(c[0], c[1])]++;
        }
        if (selFrag == f) selFrag = null;
      }
    }
  }

  void _afterFill() {
    _settle();
    if (gaps == 0 && !ended) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(900, () => widget.play.win(
            stars: starsByMoves(mistakes, 0, hints: hints),
            seconds: seconds,
            hints: hints,
            score: 1000 - mistakes * 40 - hints * 40,
          ));
    }
  }

  void _miss(int? cell, {bool fit = false}) {
    mistakes++;
    widget.play.sfx(Sfx.error);
    setState(() {
      flashCell = cell;
      flashFit = fit;
    });
    later(600, () => setState(() {
          flashCell = null;
          flashFit = false;
        }));
  }

  void _tap(Offset o) {
    if (ended) return;
    final x = o.dx.floor(), y = o.dy.floor();
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return;
    final i = y * lv.w + x;
    if (!lv.hole[i] || filled[i]) return;
    final f = selFrag;
    if (f != null) {
      final shape = fragShape(lv, lv.frags[f], rot[f]);
      final at = fragPlacement(lv, filled, shape, x, y);
      if (at == null) return _miss(i, fit: true);
      setState(() {
        for (final p in shape) {
          filled[(at[1] + p[1]) * lv.w + at[0] + p[0]] = true;
        }
        fragGone.add(f);
        selFrag = null;
      });
      widget.play.sfx(Sfx.combo);
      _afterFill();
      return;
    }
    final c = selColor;
    if (c == null) return;
    if (lv.grid[i] != c || supply[c] <= 0) return _miss(i);
    setState(() {
      filled[i] = true;
      supply[c]--;
      if (supply[c] == 0) {
        final nx = supply.indexWhere((v) => v > 0);
        selColor = nx >= 0 ? nx : null;
      }
    });
    widget.play.sfx(Sfx.place);
    _afterFill();
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    hints++;
    for (var i = 0; i < filled.length; i++) {
      if (lv.hole[i] && !filled[i] && supply[lv.grid[i]] > 0) {
        setState(() {
          filled[i] = true;
          supply[lv.grid[i]]--;
        });
        widget.play.sfx(Sfx.place);
        _afterFill();
        return;
      }
    }
    // Yalnız kırıklar kaldıysa birini yerine koy.
    for (var f = 0; f < lv.frags.length; f++) {
      if (fragGone.contains(f)) continue;
      for (var r = 0; r < 4; r++) {
        final shape = fragShape(lv, lv.frags[f], r);
        for (var y = 0; y < lv.h; y++) {
          for (var x = 0; x < lv.w; x++) {
            if (fragFits(lv, filled, shape, x, y)) {
              setState(() {
                for (final p in shape) {
                  filled[(y + p[1]) * lv.w + x + p[0]] = true;
                }
                fragGone.add(f);
                if (selFrag == f) selFrag = null;
              });
              _afterFill();
              return;
            }
          }
        }
      }
    }
  }

  void _paint(Canvas c) {
    final w = lv.w.toDouble(), h = lv.h.toDouble();
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-0.3, -0.3, w + 0.6, h + 0.6), const Radius.circular(0.4)), fill(const Color(0xFF6B5E4E)));
    c.drawRect(Rect.fromLTWH(0, 0, w, h), fill(const Color(0xFF3B3530)));
    for (var y = 0; y < lv.h; y++) {
      for (var x = 0; x < lv.w; x++) {
        final i = y * lv.w + x;
        if (!lv.hole[i] || filled[i]) {
          _tessera(c, x.toDouble(), y.toDouble(), Color(lv.palette[lv.grid[i]]), i);
        } else {
          // Sıva ve çatlak.
          final hh = _hash(i + 7);
          c.drawRect(Rect.fromLTWH(x + 0.02, y + 0.02, 0.96, 0.96), fill(const Color(0xFFCFC6B8)));
          final a = Offset(x + 0.15 + (hh & 3) * 0.15, y + 0.1);
          final b = Offset(x + 0.5, y + 0.45 + ((hh >> 2) & 3) * 0.08);
          final e = Offset(x + 0.35 + ((hh >> 4) & 3) * 0.15, y + 0.92);
          c.drawLine(a, b, stroke(const Color(0x66574B3E), 0.05));
          c.drawLine(b, e, stroke(const Color(0x66574B3E), 0.05));
        }
        if (flashCell == i) {
          c.drawRect(Rect.fromLTWH(x + 0.04, y + 0.04, 0.92, 0.92), stroke(OColors.bad, 0.12));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final look = StudioLook.of(context);
    final sf = selFrag;
    final colorChips = <Widget>[
      for (var k = 0; k < lv.palette.length; k++)
        if (supply[k] > 0)
          OChip(
            selected: selColor == k && sf == null,
            onTap: () => setState(() {
              selColor = k;
              selFrag = null;
            }),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 22, height: 22, child: CustomPaint(painter: _TileSwatch(Color(lv.palette[k])))),
              const SizedBox(width: 6),
              Text('${supply[k]}'),
            ]),
          ),
    ];
    final fragChips = <Widget>[
      for (var f = 0; f < lv.frags.length; f++)
        if (!fragGone.contains(f))
          OChip(
            selected: sf == f,
            tooltip: ft(lang, 'fragments'),
            onTap: () => setState(() => selFrag = sf == f ? null : f),
            child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _FragPainter(fragShape(lv, lv.frags[f], rot[f]), lv.palette))),
          ),
    ];
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ft(lang, 'gaps')}: $gaps',
        status: flashFit ? ft(lang, 'fits') : '${ft(lang, 'mistakes')}: $mistakes · ${clock()}',
        onHint: _hint,
        extra: [
          if (sf != null)
            IconButton(
              tooltip: ft(lang, 'rotate'),
              onPressed: () => setState(() => rot[sf] = (rot[sf] + 1) % 4),
              icon: Icon(Icons.rotate_right, color: look.accent),
            ),
        ],
      ),
      board: TapCanvas(w: lv.w + 0.0, h: lv.h + 0.0, paint: _paint, onTap: _tap, semantics: ot(lang, 'target')),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (fragChips.isNotEmpty) ...[
          Text(ft(lang, 'fragments'), style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: fragChips),
          const SizedBox(height: 8),
        ],
        Text(ft(lang, 'tiles'), style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: colorChips),
      ]),
    );
  }
}

class _TileSwatch extends CustomPainter {
  final Color color;
  _TileSwatch(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    _tessera(canvas, 0, 0, color, 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TileSwatch old) => old.color != color;
}

class _FragPainter extends CustomPainter {
  final List<List<int>> shape;
  final List<int> palette;
  _FragPainter(this.shape, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    var mw = 1, mh = 1;
    for (final p in shape) {
      if (p[0] + 1 > mw) mw = p[0] + 1;
      if (p[1] + 1 > mh) mh = p[1] + 1;
    }
    final n = mw > mh ? mw : mh;
    final k = size.width / n;
    canvas.save();
    canvas.translate((size.width - mw * k) / 2, (size.height - mh * k) / 2);
    canvas.scale(k);
    for (final p in shape) {
      canvas.drawRect(Rect.fromLTWH(p[0].toDouble(), p[1].toDouble(), 1, 1), fill(const Color(0xFF3B3530)));
      _tessera(canvas, p[0].toDouble(), p[1].toDouble(), Color(palette[p[2]]), p[0] * 7 + p[1]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FragPainter old) => true;
}
