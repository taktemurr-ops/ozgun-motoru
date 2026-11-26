// Halk oyunları ve Mozaik Restorasyonu: içerik bütünlüğü ve geniş bölüm taraması.
import 'package:flutter_test/flutter_test.dart';
import 'package:ozgun_motoru/ozgun_motoru.dart';
import 'package:ozgun_motoru/src/data/folk_data.dart';
import 'package:ozgun_motoru/src/kinds/folk_logic.dart';
import 'package:ozgun_motoru/src/kinds/mosaic_logic.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  test('fıkralar ve sahneler 33 dilde eksiksiz', () {
    expect(kFolkLangs.length, 33);
    expect(kHocaTales.length, greaterThanOrEqualTo(12));
    for (final t in kHocaTales) {
      expect(t.title.length, 33, reason: t.id);
      expect(t.panels.length, 4, reason: t.id);
      expect(t.seg.length, 3, reason: t.id);
      expect(t.flats.length, 2, reason: t.id);
      for (final l in [...t.panels, ...t.seg, ...t.flats]) {
        expect(l.length, 33, reason: t.id);
        expect(l.every((s) => s.trim().isNotEmpty), isTrue, reason: t.id);
      }
    }
    expect(kKaraScenes.length, greaterThanOrEqualTo(8));
    for (final s in kKaraScenes) {
      expect(s.lines.length, 6, reason: s.id);
      for (final l in s.lines) {
        expect(l.length, 33, reason: s.id);
      }
      expect(s.props.toSet().length, 2, reason: s.id);
    }
    for (final e in kFolkTexts.entries) {
      expect(e.value.length, 33, reason: e.key);
    }
  });

  test('her zorlukta binlerce bölüm kurulur ve doğrulanır', () {
    for (var d = 1; d <= 10; d++) {
      for (var s = 0; s < 300; s++) {
        final h = makeHocaLevel(d, SeededRandom(s * 31 + d));
        if (h != null) expect(checkHocaLevel(h), isTrue, reason: 'hoca $d $s');
        final k = makeKaraLevel(d, SeededRandom(s * 37 + d));
        if (k != null) expect(checkKaraLevel(k), isTrue, reason: 'karagöz $d $s');
        final m = makeMozLevel(d, SeededRandom(s * 41 + d));
        if (m != null) expect(checkMozLevel(m), isTrue, reason: 'mozaik $d $s');
      }
    }
  });

  test('mozaik: her boşluğun simetrik eşi sağlam, kırıklar yerine oturur', () {
    for (var s = 0; s < 200; s++) {
      final lv = makeMozLevel(1 + s % 10, SeededRandom(s));
      if (lv == null) continue;
      for (var i = 0; i < lv.w * lv.h; i++) {
        if (!lv.hole[i]) continue;
        final o = lv.orbit(i % lv.w, i ~/ lv.w);
        expect(o.any((j) => !lv.hole[j] && lv.grid[j] == lv.grid[i]), isTrue);
      }
    }
  });

  test('üç yeni oyunun 100.000 bölümünden örnekler', () {
    for (final kind in const ['karagoz', 'hoca', 'mozrest']) {
      final rules = ozgunRulesFor('oyun-test-$kind', kind);
      expect(rules.levelCount, 100000);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      for (var n = 1; n <= 100000; n += 997) {
        expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: '$kind $n');
      }
    }
  });
}
