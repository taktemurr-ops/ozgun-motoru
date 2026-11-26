import 'package:studio_core/core/rng.dart';

import '../data/folk_data.dart';

/// Flutter'sız bölüm mantığı: Nasreddin Hoca ve Hacivat ile Karagöz.
/// Kurma ve doğrulama burada; ekranlar folk.dart'ta.

const List<String> kFolkLangs = [
  'tr', 'en', 'de', 'es', 'fr', 'ar', 'fa', 'he', 'ur', 'ru', 'uk', 'pl', 'cs', 'ro', 'hu', 'el', 'it', //
  'pt', 'nl', 'sv', 'da', 'nb', 'fi', 'ja', 'ko', 'zh', 'hi', 'bn', 'id', 'ms', 'th', 'vi', 'fil',
];

/// Boşluksuz yazılan dillerde parçalar bitişik birleştirilir.
String joinSegs(List<String> segs, int li) {
  final l = kFolkLangs[li];
  return segs.join(l == 'ja' || l == 'zh' ? '' : ' ');
}

// =================================================================== Nasreddin Hoca

/// Görev türleri.
const int kTaskAnswer = 0, kTaskOrder = 1, kTaskFinish = 2;

/// Kart kodu: fıkra * 16 + parça. 0..3 sahne, 4..6 nükte parçası, 7 bütün nükte, 8..9 düz yanıt.
int hocaCode(int tale, int part) => tale * 16 + part;
int hocaTaleOf(int code) => code ~/ 16;
int hocaPartOf(int code) => code % 16;

/// Kartın [li] dilindeki metni.
String hocaText(int code, int li) {
  final t = kHocaTales[hocaTaleOf(code)];
  final p = hocaPartOf(code);
  if (p < 4) return t.panels[p][li];
  if (p < 7) return t.seg[p - 4][li];
  if (p == 7) return joinSegs([for (final s in t.seg) s[li]], li);
  return t.flats[p - 8][li];
}

class HocaRound {
  final int tale;
  final int task;

  /// Ekrandaki kartlar (karışık).
  final List<int> items;

  /// Doğru sıra (cevap görevinde tek kart).
  final List<int> answer;
  const HocaRound(this.tale, this.task, this.items, this.answer);
}

class HocaLevel {
  final List<HocaRound> rounds;
  const HocaLevel(this.rounds);
}

List<int> _others(int tale, SeededRandom r) {
  final o = [for (var i = 0; i < kHocaTales.length; i++) if (i != tale) i];
  r.shuffle(o);
  return o;
}

bool _sameOrder(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

HocaRound? makeHocaRound(int tale, int task, int d, SeededRandom r) {
  final others = _others(tale, r);
  switch (task) {
    case kTaskAnswer:
      final n = d <= 3 ? 3 : (d <= 7 ? 4 : 5);
      final own = d <= 3 ? 1 : 2;
      final items = <int>[hocaCode(tale, 7)];
      final flats = [8, 9];
      r.shuffle(flats);
      for (var i = 0; i < own; i++) {
        items.add(hocaCode(tale, flats[i]));
      }
      var k = 0;
      while (items.length < n) {
        items.add(hocaCode(others[k++], 7));
      }
      r.shuffle(items);
      return HocaRound(tale, task, items, [hocaCode(tale, 7)]);
    case kTaskOrder:
      final answer = [for (var p = 0; p < 4; p++) hocaCode(tale, p)];
      final items = List.of(answer);
      if (d >= 6) items.add(hocaCode(others[0], r.nextInt(4)));
      if (d >= 9) items.add(hocaCode(others[1], r.nextInt(4)));
      for (var a = 0; a < 8 && _sameOrder(items, answer); a++) {
        r.shuffle(items);
      }
      if (_sameOrder(items, answer)) return null;
      return HocaRound(tale, task, items, answer);
    case kTaskFinish:
      final answer = [for (var s = 0; s < 3; s++) hocaCode(tale, 4 + s)];
      final items = List.of(answer);
      final decoys = d <= 3 ? 1 : (d <= 7 ? 2 : 3);
      for (var i = 0; i < decoys; i++) {
        items.add(hocaCode(others[i], 4 + r.nextInt(3)));
      }
      for (var a = 0; a < 8 && _sameOrder(items, answer); a++) {
        r.shuffle(items);
      }
      if (_sameOrder(items, answer)) return null;
      return HocaRound(tale, task, items, answer);
  }
  return null;
}

HocaLevel? makeHocaLevel(int d, SeededRandom r) {
  final n = d <= 3 ? 2 : (d <= 7 ? 3 : 4);
  final tales = [for (var i = 0; i < kHocaTales.length; i++) i];
  r.shuffle(tales);
  final tasks = [kTaskAnswer, kTaskOrder, kTaskFinish, r.nextInt(3)];
  r.shuffle(tasks);
  final rounds = <HocaRound>[];
  for (var i = 0; i < n; i++) {
    final rd = makeHocaRound(tales[i], tasks[i], d, r);
    if (rd == null) return null;
    rounds.add(rd);
  }
  return HocaLevel(rounds);
}

bool checkHocaRound(HocaRound rd) {
  final nt = kHocaTales.length;
  if (rd.tale < 0 || rd.tale >= nt) return false;
  if (rd.items.toSet().length != rd.items.length) return false;
  for (final c in rd.items) {
    if (hocaTaleOf(c) < 0 || hocaTaleOf(c) >= nt || hocaPartOf(c) > 9) return false;
  }
  for (final a in rd.answer) {
    if (hocaTaleOf(a) != rd.tale || rd.items.where((x) => x == a).length != 1) return false;
  }
  switch (rd.task) {
    case kTaskAnswer:
      if (rd.answer.length != 1 || rd.answer.first != hocaCode(rd.tale, 7)) return false;
      if (rd.items.length < 3) return false;
      // Başka bir kart bu fıkranın nüktesi ya da parçası olamaz.
      for (final c in rd.items) {
        if (c == rd.answer.first) continue;
        final p = hocaPartOf(c);
        if (p != 7 && p != 8 && p != 9) return false;
        if (hocaTaleOf(c) == rd.tale && p == 7) return false;
      }
    case kTaskOrder:
      if (rd.answer.length != 4) return false;
      for (var p = 0; p < 4; p++) {
        if (rd.answer[p] != hocaCode(rd.tale, p)) return false;
      }
      for (final c in rd.items) {
        if (hocaPartOf(c) > 3) return false;
      }
      if (_sameOrder(rd.items, rd.answer)) return false;
    case kTaskFinish:
      if (rd.answer.length != 3) return false;
      for (var s = 0; s < 3; s++) {
        if (rd.answer[s] != hocaCode(rd.tale, 4 + s)) return false;
      }
      for (final c in rd.items) {
        final p = hocaPartOf(c);
        if (p < 4 || p > 6) return false;
      }
      if (_sameOrder(rd.items, rd.answer)) return false;
    default:
      return false;
  }
  // Her dilde kartlar boş değil ve birbirinden ayırt edilebilir.
  for (var li = 0; li < kFolkLangs.length; li++) {
    final seen = <String>{};
    for (final c in rd.items) {
      final s = hocaText(c, li).trim();
      if (s.isEmpty || !seen.add(s)) return false;
    }
  }
  return true;
}

bool checkHocaLevel(HocaLevel lv) {
  if (lv.rounds.isEmpty || lv.rounds.length > 4) return false;
  if (lv.rounds.map((e) => e.tale).toSet().length != lv.rounds.length) return false;
  if (lv.rounds.length >= 3 && lv.rounds.map((e) => e.task).toSet().length < 2) return false;
  return lv.rounds.every(checkHocaRound);
}

// =================================================================== Hacivat ile Karagöz

const int kKaraProps = 12;

/// Replik kodu: sahne * 8 + replik.
int karaCode(int scene, int line) => scene * 8 + line;

class KaraLevel {
  final int scene;

  /// Başta yerinde verilen replik sayısı.
  final int given;

  /// Tepsideki replik kartları (verilenler hariç; başka sahneden şaşırtmacalar olabilir).
  final List<int> tray;

  /// Raftaki eşyalar (gerekli iki eşya + şaşırtmacalar).
  final List<int> shelf;

  /// Kartlarda konuşanın yüzü görünür mü?
  final bool showSpeaker;
  const KaraLevel(this.scene, this.given, this.tray, this.shelf, this.showSpeaker);

  List<int> get answer => [for (var i = 0; i < 6; i++) karaCode(scene, i)];
}

KaraLevel? makeKaraLevel(int d, SeededRandom r) {
  final ns = kKaraScenes.length;
  final scene = r.nextInt(ns);
  final given = d <= 2 ? 2 : (d <= 5 ? 1 : 0);
  final tray = [for (var i = given; i < 6; i++) karaCode(scene, i)];
  final strays = d <= 5 ? 0 : (d <= 8 ? 1 : 2);
  final others = [for (var i = 0; i < ns; i++) if (i != scene) i];
  r.shuffle(others);
  for (var i = 0; i < strays; i++) {
    tray.add(karaCode(others[i], r.nextInt(6)));
  }
  final want = [for (var i = given; i < 6; i++) karaCode(scene, i)];
  for (var a = 0; a < 8 && _sameOrder(tray, want); a++) {
    r.shuffle(tray);
  }
  if (_sameOrder(tray, want)) return null;
  final need = kKaraScenes[scene].props;
  final shelf = [...need];
  final pool = [for (var p = 0; p < kKaraProps; p++) if (!need.contains(p)) p];
  r.shuffle(pool);
  final extra = d <= 2 ? 1 : (d <= 5 ? 2 : (d <= 8 ? 3 : 4));
  shelf.addAll(pool.take(extra));
  r.shuffle(shelf);
  return KaraLevel(scene, given, tray, shelf, d <= 4);
}

String karaText(int code, int li) => kKaraScenes[code ~/ 8].lines[code % 8][li];

bool checkKaraLevel(KaraLevel lv) {
  final ns = kKaraScenes.length;
  if (lv.scene < 0 || lv.scene >= ns || lv.given < 0 || lv.given > 2) return false;
  final sc = kKaraScenes[lv.scene];
  if (sc.lines.length != 6 || sc.props.length != 2 || sc.props[0] == sc.props[1]) return false;
  if (lv.tray.toSet().length != lv.tray.length) return false;
  for (var i = 0; i < 6; i++) {
    final c = karaCode(lv.scene, i);
    final n = lv.tray.where((x) => x == c).length;
    if (n != (i < lv.given ? 0 : 1)) return false;
  }
  for (final c in lv.tray) {
    final s = c ~/ 8, l = c % 8;
    if (s < 0 || s >= ns || l > 5) return false;
  }
  final want = [for (var i = lv.given; i < 6; i++) karaCode(lv.scene, i)];
  if (_sameOrder(lv.tray, want)) return false;
  if (lv.shelf.toSet().length != lv.shelf.length) return false;
  for (final p in lv.shelf) {
    if (p < 0 || p >= kKaraProps) return false;
  }
  for (final p in sc.props) {
    if (!lv.shelf.contains(p)) return false;
  }
  if (lv.shelf.length < 3) return false;
  for (var li = 0; li < kFolkLangs.length; li++) {
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      if (!seen.add(karaText(karaCode(lv.scene, i), li).trim())) return false;
    }
    for (final c in lv.tray) {
      final s = karaText(c, li).trim();
      if (s.isEmpty) return false;
      if (c ~/ 8 != lv.scene && seen.contains(s)) return false;
    }
  }
  return true;
}
