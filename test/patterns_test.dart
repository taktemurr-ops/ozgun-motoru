import 'package:flutter_test/flutter_test.dart';
import 'package:ozgun_motoru/src/data/pattern_texts.dart';
import 'package:ozgun_motoru/src/kinds/pattern_logic.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  test('desen metinleri 33 dilde', () {
    for (final e in kPatternTexts.entries) {
      expect(e.value.length, 33, reason: e.key);
      expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
    }
  });

  test('kolam: çözüm tek kapalı çizgi, başlangıç birden çok', () {
    for (var s = 0; s < 200; s++) {
      final lv = makeKolamLevel(1 + s % 10, SeededRandom(s));
      if (lv == null) continue;
      expect(kolamLoops(lv.w, lv.h, lv.sol), 1);
      expect(kolamLoops(lv.w, lv.h, lv.start), greaterThan(1));
    }
  });

  test('girih: her boşluğa yalnız kendi karosu oturur', () {
    for (var s = 0; s < 60; s++) {
      final lv = makeGirihLevel(1 + s % 10, SeededRandom(s));
      if (lv == null) continue;
      expect(checkGirihLevel(lv), isTrue);
      for (final h in lv.holes) {
        expect(girihMatches(lv.tiles[h], lv.tiles[h].type, lv.tiles[h].rot), isTrue);
      }
    }
  });

  test('batik: çözüm sırası hedef kumaşı verir', () {
    for (var s = 0; s < 200; s++) {
      final lv = makeBatikLevel(1 + s % 10, SeededRandom(s));
      if (lv == null) continue;
      expect(batikResult(lv.w, lv.h, lv.motifs, lv.order, lv.waxAt, lv.order.length), lv.target);
    }
  });

  test('kağıt oyma: çözüm açılınca hedef çıkar', () {
    for (var s = 0; s < 200; s++) {
      final lv = makePaperLevel(1 + s % 10, SeededRandom(s));
      if (lv == null) continue;
      expect(paperUnfold(lv.s, lv.fold, lv.cut), lv.target);
    }
  });

  test('minyatür ve kına bölümleri doğrulanır', () {
    for (var s = 0; s < 200; s++) {
      final m = makeMiniLevel(1 + s % 10, SeededRandom(s));
      if (m != null) expect(checkMiniLevel(m), isTrue);
      final k = makeHennaLevel(1 + s % 10, SeededRandom(s));
      if (k != null) expect(checkHennaLevel(k), isTrue);
    }
  });
}
