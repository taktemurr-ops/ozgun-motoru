import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';

import 'texts.dart';
import 'studio_chrome.dart';

/// Özgün oyunlardan birinin kurulmuş bölümü.
abstract class OPuzzle {
  const OPuzzle();
}

class OLevel {
  final String kind;
  final int d;
  final OPuzzle puzzle;
  const OLevel(this.kind, this.d, this.puzzle);
}

/// Özgün oyun türü: bölüm üretir, çözümü denetler, ekranı kurar.
abstract class OzgunKind {
  const OzgunKind();
  String get id;

  /// Zorluk 1..10 için deterministik bölüm (kurulamazsa null).
  OPuzzle? make(int d, SeededRandom r);

  /// Bölümün içindeki çözümün kurallara uyduğunu denetler.
  bool check(OPuzzle p);

  Widget build(OzgunPlay play);

  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Çözülen bölüm', 'Levels solved', scale: 10),
        GameStat('perfect', 'Kusursuz bölüm', 'Perfect levels', scale: 10),
      ];

  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('perfect', 'perfect', [1, 5, 15]),
      ];
}

OPuzzle realizeOzgun(OzgunKind k, int d, int seed) {
  for (var dd = d; dd >= 1; dd--) {
    for (var a = 0; a < 25; a++) {
      OPuzzle? p;
      try {
        p = k.make(dd, SeededRandom(mixSeed([seed, a, dd, 7717])));
      } catch (_) {
        p = null;
      }
      if (p != null && k.check(p)) return p;
    }
  }
  throw StateError('özgün bölüm kurulamadı: ${k.id} $d');
}

class OzgunRules extends GameRules<OLevel> {
  @override
  final String gameId;
  final OzgunKind kind;
  final int levels;
  OzgunRules({required this.gameId, required this.kind, this.levels = 100000});

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => kind.stats;

  @override
  List<MissionTemplate> get missionTemplates => kind.missions;

  /// Kampanyanın başında hissedilir ilerleme. Stüdyo planı ilk 20 bölümü
  /// zorluk 1'de tutar; bulmaca türünün en iyi örneklerinde ilk 10 bölümde
  /// tahta büyür. 1–2. bölüm tanıtım (1), 3. bölümden bir, 6. bölümden bir
  /// basamak daha eklenir; uyarlanabilir zorluk payı ve dünya testeresi korunur.
  static int rampOf(LevelSpec spec) =>
      spec.mode == GameModeId.campaign ? (spec.levelId >= 3 ? 1 : 0) + (spec.levelId >= 6 ? 1 : 0) : 0;

  @override
  OLevel generate(LevelSpec spec) {
    final d = clampI(spec.difficulty + rampOf(spec), 1, 10);
    return OLevel(kind.id, d, realizeOzgun(kind, d, spec.seed));
  }

  @override
  Validation validate(OLevel puzzle, LevelSpec spec) =>
      puzzle.kind == kind.id && kind.check(puzzle.puzzle) ? const Validation.ok() : const Validation.fail('invalid');
}

class OzgunPlay {
  final PlayContext ctx;
  final OPuzzle puzzle;
  final int d;
  final int seed;

  /// Günlük Üçlü'de alt bulmacanın sonucu ana oyuna aktarılır.
  final void Function(bool won, int stars)? relay;
  const OzgunPlay({required this.ctx, required this.puzzle, required this.d, required this.seed, this.relay});

  String get lang => ctx.lang;

  void sfx(Sfx s) => ctx.sfx(s);

  void win({int score = 0, int stars = 3, int seconds = 0, int hints = 0}) {
    final s = clampI(stars, 1, 3);
    final r = relay;
    if (r != null) return r(true, s);
    ctx.finish(RoundResult(
      won: true,
      score: score < 0 ? 0 : score,
      stars: s,
      seconds: seconds,
      hintsUsed: hints,
      gameStats: {'rounds_won': 1, if (s == 3 && hints == 0) 'perfect': 1},
    ));
  }

  void lose({int score = 0, int seconds = 0, String? headline}) {
    final r = relay;
    if (r != null) return r(false, 0);
    ctx.finish(RoundResult(won: false, score: score < 0 ? 0 : score, seconds: seconds, headline: headline));
  }
}

/// Özgün oyunların ortak sahnesi.
class OzgunStage extends StatelessWidget {
  final PlayContext ctx;
  final OzgunRules rules;
  const OzgunStage({super.key, required this.ctx, required this.rules});

  /// Motorun bütün arayüzü (paneller, pencereler, düğmeler) onaylı koyu
  /// tasarımda; tahta çizimleri kendi renklerini korur.
  @override
  Widget build(BuildContext context) => StudioChrome(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final lv = ctx.generated.puzzle as OLevel;
    final early = ctx.spec.mode == GameModeId.campaign && ctx.spec.levelId <= 3;
    return OzgunEarly(early: early, child: rules.kind.build(OzgunPlay(ctx: ctx, puzzle: lv.puzzle, d: lv.d, seed: ctx.spec.seed)));
  }
}

/// Kampanyanın ilk bölümleri: takılan oyuncuya ipucu düğmesi nazikçe
/// gösterilir (iyi bulmaca oyunlarının ilk dakika rehberliği gibi).
class OzgunEarly extends InheritedWidget {
  final bool early;
  const OzgunEarly({super.key, required this.early, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OzgunEarly>()?.early ?? false;

  @override
  bool updateShouldNotify(OzgunEarly old) => old.early != early;
}

OzgunRules ozgunRules(String gameId, OzgunKind kind) => OzgunRules(gameId: gameId, kind: kind);

// ---------------------------------------------------------------- ortak yardımcılar

class OColors {
  static const paper = Color(0xFFF4F1EA);
  static const ink = Color(0xFF22303F);
  static const good = Color(0xFF4F9A6E);
  static const bad = Color(0xFFC8553D);
  static const accent = Color(0xFF3E6FB0);
  static const gold = Color(0xFFD9A441);
  static const soft = Color(0xFFE6E0D4);
  static const line = Color(0xFFB9AE9B);

  /// Kilim, çini ve ebru için sıcak, doğal tonlar.
  static const List<Color> warm = [
    Color(0xFFB23A48),
    Color(0xFF2E5E8C),
    Color(0xFFD9A441),
    Color(0xFF4F7F52),
    Color(0xFF7A4E7E),
    Color(0xFFE07A5F),
    Color(0xFF3A8D8C),
    Color(0xFF5B4636),
  ];
}

/// Saat ve iptal edilebilen gecikmeler.
mixin Clock<T extends StatefulWidget> on State<T> {
  int seconds = 0;
  bool ended = false;
  Timer? _t;
  final List<Timer> _later = [];

  void startClock() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ended && mounted) setState(() => seconds++);
    });
  }

  void later(int ms, VoidCallback f) {
    _later.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }));
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final t in _later) {
      t.cancel();
    }
    super.dispose();
  }

  String clock([int? s]) {
    final v = s ?? seconds;
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }
}

int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Hamle sayısına göre yıldız: en iyi sayıda 3, biraz fazlasında 2.
int starsByMoves(int moves, int par, {int hints = 0}) {
  var s = moves <= par ? 3 : (moves <= par + math.max(2, par ~/ 2) ? 2 : 1);
  s -= hints;
  return s < 1 ? 1 : s;
}

/// Üst çubuk: solda bilgi, ortada durum; ipucu, geri al ve baştan düğmeleri.
class OBar extends StatelessWidget {
  final String lang;
  final String left;
  final String status;
  final VoidCallback? onHint;
  final VoidCallback? onUndo;
  final VoidCallback? onReset;
  final List<Widget> extra;
  const OBar({super.key, required this.lang, this.left = '', this.status = '', this.onHint, this.onUndo, this.onReset, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: look.accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(children: [
        if (left.isNotEmpty) Text(left, style: TextStyle(fontWeight: FontWeight.w900, color: look.number)),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(status, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700, color: kStudioSubtle)),
          ),
        ),
        ...extra,
        if (onUndo != null) IconButton(tooltip: ot(lang, 'undo'), onPressed: onUndo, icon: const Icon(Icons.undo)),
        if (onReset != null) IconButton(tooltip: ot(lang, 'reset'), onPressed: onReset, icon: const Icon(Icons.restart_alt)),
        if (onHint != null) _HintButton(tooltip: ot(lang, 'hint'), onHint: onHint!, early: OzgunEarly.of(context)),
      ]),
    );
  }
}

/// İpucu düğmesi. İlk bölümlerde 20 sn sonra altın hâleyle öne çıkar
/// (harcama yapmaz; yalnız gösterir). Sonsuz animasyon yok.
class _HintButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback onHint;
  final bool early;
  const _HintButton({required this.tooltip, required this.onHint, required this.early});

  @override
  State<_HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<_HintButton> {
  Timer? _t;
  bool nudge = false;

  @override
  void initState() {
    super.initState();
    if (widget.early) {
      _t = Timer(const Duration(seconds: 20), () {
        if (mounted) setState(() => nudge = true);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = IconButton(
      tooltip: widget.tooltip,
      onPressed: () {
        _t?.cancel();
        if (nudge) setState(() => nudge = false);
        widget.onHint();
      },
      icon: const Icon(Icons.lightbulb_rounded, color: StudioLook.gold),
    );
    if (!nudge) return b;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      child: b,
      builder: (context, v, ch) => Transform.scale(
        scale: 1 + 0.18 * v,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: StudioLook.gold.withValues(alpha: 0.18),
            boxShadow: [BoxShadow(color: StudioLook.gold.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 1)],
          ),
          child: ch,
        ),
      ),
    );
  }
}

/// Mantıksal birimlerle çizilen, dokunuşları aynı birimlere çeviren tuval.
/// [w] × [h] birimlik alan kullanılabilir yere oranı korunarak sığdırılır.
class TapCanvas extends StatelessWidget {
  final double w;
  final double h;
  final void Function(Canvas c) paint;
  final void Function(Offset p)? onTap;
  final void Function(Offset p)? onLongPress;
  final void Function(Offset p)? onPanStart;
  final void Function(Offset p)? onPanUpdate;
  final VoidCallback? onPanEnd;
  final String? semantics;
  const TapCanvas({
    super.key,
    required this.w,
    required this.h,
    required this.paint,
    this.onTap,
    this.onLongPress,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final mw = box.maxWidth.isFinite ? box.maxWidth : 360.0;
      final mh = box.maxHeight.isFinite ? box.maxHeight : 360.0;
      final k = math.min(mw / w, mh / h);
      final size = Size(w * k, h * k);
      Offset lp(Offset o) => o / k;
      final ps = onPanStart, pu = onPanUpdate, pe = onPanEnd, t = onTap, lpr = onLongPress;
      return Center(
        child: Semantics(
          label: semantics,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: t == null ? null : (e) => t(lp(e.localPosition)),
            onLongPressStart: lpr == null ? null : (e) => lpr(lp(e.localPosition)),
            onPanStart: ps == null ? null : (e) => ps(lp(e.localPosition)),
            onPanUpdate: pu == null ? null : (e) => pu(lp(e.localPosition)),
            onPanEnd: pe == null ? null : (_) => pe(),
            child: CustomPaint(size: size, painter: _FnPainter(paint, k)),
          ),
        ),
      );
    });
  }
}

class _FnPainter extends CustomPainter {
  final void Function(Canvas c) fn;
  final double k;
  _FnPainter(this.fn, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    fn(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FnPainter old) => true;
}

Paint fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Ortalanmış kısa yazı (mantıksal birimlerle).
void drawLabel(Canvas c, String s, Offset center, double size, Color color, {FontWeight weight = FontWeight.w700}) {
  if (s.isEmpty) return;
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.0)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Hızlı ızgara yardımcıları.
const List<List<int>> kDirs4 = [
  [0, -1],
  [1, 0],
  [0, 1],
  [-1, 0],
];

const List<List<int>> kDirs8 = [
  [-1, -1],
  [0, -1],
  [1, -1],
  [1, 0],
  [1, 1],
  [0, 1],
  [-1, 1],
  [-1, 0],
];

/// Tek sütun düzeni: çubuk, tahta, isteğe bağlı alt düğmeler.
class OScreen extends StatelessWidget {
  final Widget bar;
  final Widget board;
  final Widget? top;
  final Widget? bottom;
  const OScreen({super.key, required this.bar, required this.board, this.top, this.bottom});

  @override
  Widget build(BuildContext context) {
    final t = top, b = bottom;
    return Column(children: [
      bar,
      if (t != null) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: t),
      Expanded(child: Padding(padding: const EdgeInsets.all(10), child: board)),
      if (b != null) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: b),
    ]);
  }
}

/// Altta kullanılan yuvarlak köşeli seçim düğmesi.
class OChip extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;
  const OChip({super.key, required this.child, this.selected = false, this.onTap, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final c = color ?? Color.lerp(look.card, Colors.white, 0.08)!;
    final bg = selected ? Color.lerp(c, look.accent, 0.35)! : c;
    final fg = bg.computeLuminance() > 0.4 ? const Color(0xFF22303F) : Colors.white;
    final w = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? look.accent : Colors.white24, width: selected ? 2.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: IconTheme.merge(
            data: IconThemeData(color: fg),
            child: DefaultTextStyle.merge(style: TextStyle(color: fg, fontWeight: FontWeight.w700), child: child),
          ),
        ),
      ),
    );
    final tt = tooltip;
    return tt == null ? w : Tooltip(message: tt, child: w);
  }
}
