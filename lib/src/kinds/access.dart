import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../texts.dart';

// =================================================================== Ses Labirenti

/// Mükemmel labirent; her hücrenin açık yönleri (1 K, 2 D, 4 G, 8 B).
class SesPuzzle extends OPuzzle {
  final int n;
  final List<int> open;
  final int exit;
  final int best;
  const SesPuzzle(this.n, this.open, this.exit, this.best);

  /// Çıkışa olan yol uzunlukları.
  List<int> distances() {
    final dist = List<int>.filled(n * n, -1);
    dist[exit] = 0;
    final q = Queue<int>()..add(exit);
    while (q.isNotEmpty) {
      final c = q.removeFirst();
      for (var d = 0; d < 4; d++) {
        if (open[c] & (1 << d) == 0) continue;
        final nb = c + kDirs4[d][0] + kDirs4[d][1] * n;
        if (dist[nb] >= 0) continue;
        dist[nb] = dist[c] + 1;
        q.add(nb);
      }
    }
    return dist;
  }
}

class SesKind extends OzgunKind {
  @override
  String get id => 'ses';
  const SesKind();

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final n = 4 + d ~/ 2;
    final open = List<int>.filled(n * n, 0);
    final seen = List<bool>.filled(n * n, false);
    final stack = [0];
    seen[0] = true;
    while (stack.isNotEmpty) {
      final c = stack.last;
      final x = c % n, y = c ~/ n;
      final opts = <int>[];
      for (var dd = 0; dd < 4; dd++) {
        final nx = x + kDirs4[dd][0], ny = y + kDirs4[dd][1];
        if (nx < 0 || ny < 0 || nx >= n || ny >= n || seen[ny * n + nx]) continue;
        opts.add(dd);
      }
      if (opts.isEmpty) {
        stack.removeLast();
        continue;
      }
      final dd = r.pick(opts);
      final nb = (y + kDirs4[dd][1]) * n + x + kDirs4[dd][0];
      open[c] |= 1 << dd;
      open[nb] |= 1 << ((dd + 2) % 4);
      seen[nb] = true;
      stack.add(nb);
    }
    final exit = n * n - 1 - (r.chance(0.5) ? 0 : n - 1);
    final p = SesPuzzle(n, open, exit, 0);
    final best = p.distances()[0];
    if (best < n) return null;
    return SesPuzzle(n, open, exit, best);
  }

  @override
  bool check(OPuzzle p) => p is SesPuzzle && p.best > 0 && p.distances()[0] == p.best;

  @override
  Widget build(OzgunPlay play) => _SesView(play: play);
}

class _SesView extends StatefulWidget {
  final OzgunPlay play;
  const _SesView({required this.play});
  @override
  State<_SesView> createState() => _SesViewState();
}

class _SesViewState extends State<_SesView> with Clock {
  late final SesPuzzle p = widget.play.puzzle as SesPuzzle;
  late final List<int> dist = p.distances();
  int at = 0, steps = 0, bumps = 0, hints = 0;
  final Set<int> seen = {0};
  bool visuals = true;
  String said = '';

  @override
  void initState() {
    super.initState();
    startClock();
    said = _ways();
  }

  String get lang => widget.play.lang;

  String _ways() {
    const keys = ['north', 'east', 'south', 'west'];
    final ways = [for (var d = 0; d < 4; d++) if (p.open[at] & (1 << d) != 0) ot(lang, keys[d])];
    return '${ot(lang, 'paths')}: ${ways.join(', ')}';
  }

  void _move(int d) {
    if (ended) return;
    if (p.open[at] & (1 << d) == 0) {
      bumps++;
      widget.play.sfx(Sfx.error);
      HapticFeedback.mediumImpact();
      setState(() => said = '${ot(lang, 'wall')} · ${_ways()}');
      return;
    }
    final before = dist[at];
    setState(() {
      at = at + kDirs4[d][0] + kDirs4[d][1] * p.n;
      steps++;
      seen.add(at);
    });
    if (at == p.exit) {
      ended = true;
      widget.play.sfx(Sfx.win);
      setState(() => said = ot(lang, 'exit'));
      later(900, () => widget.play.win(stars: starsByMoves(steps, p.best, hints: hints), seconds: seconds, hints: hints, score: 1000 - steps * 5));
      return;
    }
    final closer = dist[at] < before;
    widget.play.sfx(closer ? Sfx.coin : Sfx.tap);
    HapticFeedback.selectionClick();
    setState(() => said = '${ot(lang, closer ? 'closer' : 'farther')} · ${_ways()}');
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    for (var d = 0; d < 4; d++) {
      if (p.open[at] & (1 << d) == 0) continue;
      final nb = at + kDirs4[d][0] + kDirs4[d][1] * p.n;
      if (dist[nb] < dist[at]) {
        hints++;
        _move(d);
        return;
      }
    }
  }

  Widget _arrow(int d, IconData icon) {
    const keys = ['north', 'east', 'south', 'west'];
    return Semantics(
      button: true,
      label: ot(lang, keys[d]),
      child: SizedBox(
        width: 76,
        height: 64,
        child: FilledButton.tonal(
          onPressed: ended ? null : () => _move(d),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          child: Icon(icon, size: 36),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = p.n;
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ot(lang, 'moves')}: $steps',
        status: clock(),
        onHint: _hint,
        extra: [
          IconButton(
            tooltip: ot(lang, 'show'),
            onPressed: () => setState(() => visuals = !visuals),
            icon: Icon(visuals ? Icons.visibility : Icons.visibility_off),
          ),
          IconButton(
            tooltip: ot(lang, 'listen'),
            onPressed: () {
              widget.play.sfx(Sfx.unlock);
              setState(() => said = _ways());
            },
            icon: const Icon(Icons.hearing),
          ),
        ],
      ),
      top: Semantics(
        liveRegion: true,
        child: Text(said, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      board: GestureDetector(
        onPanEnd: (e) {
          final v = e.velocity.pixelsPerSecond;
          if (v.distance < 120) return;
          if (v.dx.abs() > v.dy.abs()) {
            _move(v.dx > 0 ? 1 : 3);
          } else {
            _move(v.dy > 0 ? 2 : 0);
          }
        },
        child: TapCanvas(
          w: n.toDouble(),
          h: n.toDouble(),
          semantics: said,
          paint: (c) {
            c.drawRect(Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), fill(const Color(0xFF111827)));
            if (!visuals) {
              c.drawCircle(Offset(at % n + 0.5, at ~/ n + 0.5), 0.3, fill(const Color(0xFFFFD166)));
              return;
            }
            final wall = stroke(const Color(0xFFF9FAFB), 0.08);
            for (final cell in seen) {
              final x = (cell % n).toDouble(), y = (cell ~/ n).toDouble();
              c.drawRect(Rect.fromLTWH(x, y, 1, 1), fill(const Color(0xFF374151)));
              final o = p.open[cell];
              if (o & 1 == 0) c.drawLine(Offset(x, y), Offset(x + 1, y), wall);
              if (o & 2 == 0) c.drawLine(Offset(x + 1, y), Offset(x + 1, y + 1), wall);
              if (o & 4 == 0) c.drawLine(Offset(x, y + 1), Offset(x + 1, y + 1), wall);
              if (o & 8 == 0) c.drawLine(Offset(x, y), Offset(x, y + 1), wall);
            }
            final e = Offset(p.exit % n + 0.5, p.exit ~/ n + 0.5);
            if (seen.contains(p.exit) || steps > p.best * 2) c.drawCircle(e, 0.3, fill(const Color(0xFF34C6B8)));
            c.drawCircle(Offset(at % n + 0.5, at ~/ n + 0.5), 0.32, fill(const Color(0xFFFFD166)));
          },
        ),
      ),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        _arrow(0, Icons.keyboard_arrow_up),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _arrow(3, Icons.keyboard_arrow_left),
          const SizedBox(width: 86),
          _arrow(1, Icons.keyboard_arrow_right),
        ]),
        const SizedBox(height: 6),
        _arrow(2, Icons.keyboard_arrow_down),
      ]),
    );
  }
}
