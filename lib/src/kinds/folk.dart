import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../data/folk_data.dart';
import 'folk_art.dart';
import 'folk_logic.dart';

/// Halk oyunlarının kısa metni.
String ft(String lang, String key) => Strings.pick(kFolkTexts[key]!, lang);

/// İçerik listelerindeki dil sırası.
int folkLang(String lang) {
  final i = kFolkLangs.indexOf(lang);
  return i < 0 ? 1 : i;
}

int _starsFor(int mistakes, int hints) {
  var s = mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);
  s -= hints;
  return s < 1 ? 1 : s;
}

/// Kâğıt rengi kart: koyu mürekkeple okunur metin.
class _Paper extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? border;
  final EdgeInsets padding;
  const _Paper({required this.child, this.color = const Color(0xFFF4EBD9), this.border, this.padding = const EdgeInsets.all(10)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? const Color(0xFFB9AE9B), width: border == null ? 1 : 2.5),
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Color(0xFF22303F)), child: child),
    );
  }
}

/// Seçilebilir metin kartı (koyu zemin, açık yazı).
class _Card extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? tint;
  final bool dim;
  final Widget? lead;
  const _Card({required this.text, this.onTap, this.tint, this.dim = false, this.lead});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final bg = tint ?? Color.lerp(look.card, Colors.white, 0.06)!;
    final fg = bg.computeLuminance() > 0.4 ? const Color(0xFF22303F) : Colors.white;
    final l = lead;
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: look.accent.withValues(alpha: 0.5))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              if (l != null) ...[l, const SizedBox(width: 8)],
              Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.25))),
            ]),
          ),
        ),
      ),
    );
  }
}

// =================================================================== Nasreddin Hoca

class HocaPuzzle extends OPuzzle {
  final HocaLevel lv;
  const HocaPuzzle(this.lv);
}

class HocaKind extends OzgunKind {
  const HocaKind();
  @override
  String get id => 'hoca';

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeHocaLevel(d, r);
    return lv == null ? null : HocaPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is HocaPuzzle && checkHocaLevel(p.lv);

  @override
  Widget build(OzgunPlay play) => _HocaView(play: play);
}

class _HocaView extends StatefulWidget {
  final OzgunPlay play;
  const _HocaView({required this.play});
  @override
  State<_HocaView> createState() => _HocaViewState();
}

class _HocaViewState extends State<_HocaView> with Clock {
  late final HocaLevel lv = (widget.play.puzzle as HocaPuzzle).lv;
  late final int li = folkLang(widget.play.lang);
  int round = 0;
  final List<int> placed = [];
  final Set<int> wrong = {};
  int? flash;
  bool roundDone = false;
  int mistakes = 0, hints = 0;

  HocaRound get rd => lv.rounds[round];

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _tap(int code) {
    if (ended || roundDone) return;
    final r = rd;
    if (r.task == kTaskAnswer) {
      if (code == r.answer.first) {
        placed.add(code);
        _finishRound();
      } else if (wrong.add(code)) {
        mistakes++;
        widget.play.sfx(Sfx.error);
        setState(() {});
      }
      return;
    }
    if (placed.contains(code)) return;
    if (code == r.answer[placed.length]) {
      setState(() => placed.add(code));
      widget.play.sfx(Sfx.place);
      if (placed.length == r.answer.length) _finishRound();
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      setState(() => flash = code);
      later(500, () => setState(() => flash = null));
    }
  }

  void _finishRound() {
    widget.play.sfx(Sfx.combo);
    setState(() => roundDone = true);
    later(1600, () {
      if (round + 1 < lv.rounds.length) {
        setState(() {
          round++;
          placed.clear();
          wrong.clear();
          roundDone = false;
        });
      } else if (!ended) {
        ended = true;
        widget.play.sfx(Sfx.win);
        widget.play.win(
          stars: _starsFor(mistakes, hints),
          seconds: seconds,
          hints: hints,
          score: 1000 - mistakes * 60 - hints * 40,
        );
      }
    });
  }

  Future<void> _hint() async {
    if (ended || roundDone || !await widget.play.ctx.requestHint()) return;
    if (!mounted || roundDone) return;
    hints++;
    final r = rd;
    if (r.task == kTaskAnswer) {
      // Yanlış bir seçeneği ele.
      for (final c in r.items) {
        if (c != r.answer.first && !wrong.contains(c)) {
          setState(() => wrong.add(c));
          return;
        }
      }
      return;
    }
    _tap(r.answer[placed.length]);
  }

  String _question() {
    switch (rd.task) {
      case kTaskAnswer:
        return ft(widget.play.lang, 'qAnswer');
      case kTaskOrder:
        return ft(widget.play.lang, 'qOrder');
      default:
        return ft(widget.play.lang, 'qFinish');
    }
  }

  Widget _story() {
    final t = kHocaTales[rd.tale];
    final rows = <Widget>[];
    if (rd.task == kTaskOrder) {
      for (var i = 0; i < 4; i++) {
        final has = i < placed.length;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _Paper(
            color: has ? const Color(0xFFF4EBD9) : const Color(0xFFE6E0D4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8B5A2B))),
              const SizedBox(width: 10),
              Expanded(child: Text(has ? hocaText(placed[i], li) : '…', style: const TextStyle(color: Color(0xFF22303F)))),
            ]),
          ),
        ));
      }
    } else {
      for (var i = 0; i < 4; i++) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w900, color: StudioLook.gold)),
            Expanded(child: Text(t.panels[i][li], style: const TextStyle(color: Colors.white, height: 1.25))),
          ]),
        ));
      }
      final parts = <String>[for (final c in placed) hocaText(c, li)];
      final shown = roundDone ? hocaText(hocaCode(rd.tale, 7), li) : (rd.task == kTaskFinish ? joinSegs(parts, li) : '');
      rows.add(const SizedBox(height: 6));
      rows.add(_Paper(
        color: roundDone ? const Color(0xFFE3F1E6) : const Color(0xFFF4EBD9),
        border: roundDone ? OColors.good : null,
        child: Row(children: [
          SizedBox(width: 34, height: 34, child: CustomPaint(painter: _EmblemPainter(rd.tale))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(shown.isEmpty ? '…' : shown,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF22303F))),
          ),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final t = kHocaTales[rd.tale];
    final cards = <Widget>[];
    for (final c in rd.items) {
      final used = placed.contains(c);
      if (rd.task != kTaskAnswer && used) continue;
      cards.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _Card(
          text: hocaText(c, li),
          dim: wrong.contains(c),
          tint: flash == c ? OColors.bad : (roundDone && c == rd.answer.first && rd.task == kTaskAnswer ? OColors.good : null),
          onTap: () => _tap(c),
        ),
      ));
    }
    return OScreen(
      bar: OBar(
        lang: lang,
        left: '${ft(lang, 'tale')} ${round + 1}/${lv.rounds.length}',
        status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}',
        onHint: _hint,
      ),
      top: Row(children: [
        SizedBox(width: 40, height: 40, child: CustomPaint(painter: _EmblemPainter(rd.tale))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title[li], maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white)),
            Text(_question(), style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      board: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _story(),
          const SizedBox(height: 12),
          ...cards,
        ]),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  final int tale;
  _EmblemPainter(this.tale);
  @override
  void paint(Canvas canvas, Size size) => paintHocaEmblem(canvas, tale, Offset.zero & size);
  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.tale != tale;
}

// =================================================================== Hacivat ile Karagöz

class KaraPuzzle extends OPuzzle {
  final KaraLevel lv;
  const KaraPuzzle(this.lv);
}

class KaraKind extends OzgunKind {
  const KaraKind();
  @override
  String get id => 'karagoz';

  @override
  OPuzzle? make(int d, SeededRandom r) {
    final lv = makeKaraLevel(d, r);
    return lv == null ? null : KaraPuzzle(lv);
  }

  @override
  bool check(OPuzzle p) => p is KaraPuzzle && checkKaraLevel(p.lv);

  @override
  Widget build(OzgunPlay play) => _KaraView(play: play);
}

class _KaraView extends StatefulWidget {
  final OzgunPlay play;
  const _KaraView({required this.play});
  @override
  State<_KaraView> createState() => _KaraViewState();
}

class _KaraViewState extends State<_KaraView> with Clock {
  late final KaraLevel lv = (widget.play.puzzle as KaraPuzzle).lv;
  late final KaraScene sc = kKaraScenes[lv.scene];
  late final int li = folkLang(widget.play.lang);
  late int placed = lv.given;

  /// Eşyası seçilen replikler (2 ve 5).
  final Set<int> propsDone = {};
  int? flashLine;
  int? flashProp;
  int mistakes = 0, hints = 0;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  /// Eşya bekleyen replik (yoksa null).
  int? get awaiting {
    for (final i in const [2, 5]) {
      if (placed > i && !propsDone.contains(i)) return i;
    }
    return null;
  }

  int _propFor(int line) => sc.props[line == 2 ? 0 : 1];

  void _tapLine(int code) {
    if (ended) return;
    if (awaiting != null) {
      widget.play.sfx(Sfx.tap);
      setState(() => flashProp = -1);
      later(600, () => setState(() => flashProp = null));
      return;
    }
    if (code == karaCode(lv.scene, placed)) {
      setState(() => placed++);
      widget.play.sfx(Sfx.place);
      _maybeWin();
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      setState(() => flashLine = code);
      later(500, () => setState(() => flashLine = null));
    }
  }

  void _tapProp(int p) {
    final a = awaiting;
    if (ended || a == null) return;
    if (p == _propFor(a)) {
      setState(() => propsDone.add(a));
      widget.play.sfx(Sfx.combo);
      _maybeWin();
    } else {
      mistakes++;
      widget.play.sfx(Sfx.error);
      setState(() => flashProp = p);
      later(500, () => setState(() => flashProp = null));
    }
  }

  void _maybeWin() {
    if (placed < 6 || propsDone.length < 2 || ended) return;
    ended = true;
    widget.play.sfx(Sfx.win);
    later(1200, () => widget.play.win(stars: _starsFor(mistakes, hints), seconds: seconds, hints: hints, score: 1000 - mistakes * 60 - hints * 40));
  }

  Future<void> _hint() async {
    if (ended || !await widget.play.ctx.requestHint()) return;
    if (!mounted || ended) return;
    hints++;
    final a = awaiting;
    if (a != null) {
      _tapProp(_propFor(a));
    } else if (placed < 6) {
      _tapLine(karaCode(lv.scene, placed));
    }
  }

  String _speaker(int line) => ft(widget.play.lang, line.isEven ? 'hacivat' : 'karagoz');

  void _paintStage(Canvas c) {
    const w = 20.0, h = 10.0;
    paintCurtain(c, w, h);
    final speaking = placed == 0 ? -1 : (placed - 1);
    final hTalk = speaking >= 0 && speaking.isEven;
    final kTalk = speaking >= 0 && speaking.isOdd;
    paintPuppet(c, const Offset(6.0, 8.4), 0.62, hacivat: true, right: true, lift: hTalk ? 0.4 : 0, arm: hTalk ? 1 : 0);
    paintPuppet(c, const Offset(14.0, 8.4), 0.62, hacivat: false, right: false, lift: kTalk ? 0.4 : 0, arm: kTalk ? 1 : 0);
    // Seçilen eşyalar perdede gölge olarak durur.
    var x = 9.0;
    for (final i in const [2, 5]) {
      if (propsDone.contains(i)) {
        paintProp(c, _propFor(i), Rect.fromLTWH(x, 5.6, 2.2, 2.2), shadow: true);
        x += 2.4;
      }
    }
  }

  Widget _propIcon(int p, {double size = 44}) => SizedBox(width: size, height: size, child: CustomPaint(painter: _PropPainter(p)));

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final a = awaiting;
    final last = placed > 0 ? placed - 1 : -1;
    final bubble = last >= 0 ? karaText(karaCode(lv.scene, last), li) : sc.title[li];
    final lineCards = <Widget>[];
    for (final c in lv.tray) {
      final mine = c ~/ 8 == lv.scene && c % 8 < placed;
      if (mine) continue;
      lineCards.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _Card(
          text: karaText(c, li),
          tint: flashLine == c ? OColors.bad : null,
          dim: a != null,
          lead: lv.showSpeaker
              ? CircleAvatar(
                  radius: 14,
                  backgroundColor: (c % 8).isEven ? const Color(0xFF2E7D6B) : const Color(0xFFB23A3A),
                  child: Text(_speaker(c % 8).characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                )
              : null,
          onTap: () => _tapLine(c),
        ),
      ));
    }
    final script = <Widget>[];
    for (var i = 0; i < placed; i++) {
      script.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_speaker(i)}: ', style: TextStyle(fontWeight: FontWeight.w900, color: i.isEven ? const Color(0xFF8FD3C0) : const Color(0xFFFFA8A0))),
          Expanded(child: Text(karaText(karaCode(lv.scene, i), li), style: const TextStyle(color: Colors.white, height: 1.25))),
          if (i == 2 || i == 5)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: propsDone.contains(i)
                  ? _propIcon(_propFor(i), size: 26)
                  : const Icon(Icons.help_outline, color: StudioLook.gold, size: 24),
            ),
        ]),
      ));
    }
    return OScreen(
      bar: OBar(
        lang: lang,
        left: sc.title[li],
        status: '${ft(lang, 'mistakes')}: $mistakes · ${clock()}',
        onHint: _hint,
      ),
      top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 150, child: TapCanvas(w: 20, h: 10, paint: _paintStage, semantics: sc.title[li])),
        const SizedBox(height: 6),
        _Paper(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(last >= 0 ? '${_speaker(last)}: $bubble' : bubble, maxLines: 4, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF22303F))),
        ),
      ]),
      board: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...script,
          const SizedBox(height: 8),
          Text(a != null ? ft(lang, 'pickProp') : ft(lang, 'nextLine'),
              style: TextStyle(fontWeight: FontWeight.w800, color: flashProp == -1 ? StudioLook.gold : kStudioSubtle)),
          const SizedBox(height: 6),
          if (placed < 6) ...lineCards,
        ]),
      ),
      bottom: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final p in lv.shelf)
            OChip(
              selected: false,
              color: flashProp == p ? OColors.bad : (a != null ? const Color(0xFF4A3A2A) : const Color(0xFF2E2A33)),
              tooltip: ft(lang, 'props'),
              onTap: () => _tapProp(p),
              child: _propIcon(p, size: 38),
            ),
        ],
      ),
    );
  }
}

class _PropPainter extends CustomPainter {
  final int id;
  _PropPainter(this.id);
  @override
  void paint(Canvas canvas, Size size) => paintProp(canvas, id, Offset.zero & size);
  @override
  bool shouldRepaint(covariant _PropPainter old) => old.id != id;
}
