import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';

/// Flutter'sız bölüm mantığı: Mozaik Restorasyonu.
///
/// Antik üslupta (Anadolu/Roma/Bizans döşeme mozaiklerini andıran) özgün
/// desenler yordamsal üretilir: dişli bordür, dalga şeridi ve ortada baklava,
/// rozet, kafes ya da halka göbek. Desen simetriktir (kare tablolarda dört
/// eksenli, dikdörtgenlerde iki eksenli); hasarlı her taşın simetrideki eşi
/// sağlam kalır, böylece her boşluğun rengi mantıkla bulunur.

/// Taş renkleri: krem, kiremit, aşı boyası, is siyahı, arduvaz mavisi,
/// zeytin yeşili, bordo, deniz yeşili, gül kurusu, kül grisi.
const List<int> kMozColors = [
  0xFFEDE3CC, 0xFFB5523B, 0xFFD39B3A, 0xFF2B2622, 0xFF3F5E7A, //
  0xFF6E7A3A, 0xFF8A2D2B, 0xFF3E8A7A, 0xFFC98276, 0xFF8C8A84,
];

class MozFrag {
  /// Parçanın asıl yerindeki hücreleri [x, y].
  final List<List<int>> cells;

  /// Tepside kaç çeyrek tur dönük durduğu (1..3).
  final int rot;
  const MozFrag(this.cells, this.rot);
}

class MozLevel {
  final int w, h;

  /// 0: dört eksenli (kare), 1: iki eksenli.
  final int sym;

  /// Renkler (ARGB).
  final List<int> palette;

  /// Hücre rengi (palet sırası), satır satır.
  final List<int> grid;
  final List<bool> hole;
  final List<MozFrag> frags;
  const MozLevel(this.w, this.h, this.sym, this.palette, this.grid, this.hole, this.frags);

  int at(int x, int y) => grid[y * w + x];
  bool holeAt(int x, int y) => hole[y * w + x];

  /// Simetri yörüngesi.
  List<int> orbit(int x, int y) {
    final xs = {x, w - 1 - x}, ys = {y, h - 1 - y};
    final out = <int>{};
    for (final a in xs) {
      for (final b in ys) {
        out.add(b * w + a);
        if (sym == 0) out.add(a * w + b);
      }
    }
    return out.toList();
  }

  /// Parçalara ait olmayan, tek tek taşla doldurulacak hücreler.
  List<int> get looseCells {
    final inFrag = <int>{for (final f in frags) for (final c in f.cells) c[1] * w + c[0]};
    return [for (var i = 0; i < w * h; i++) if (hole[i] && !inFrag.contains(i)) i];
  }
}

/// Parçanın [rot] çeyrek tur döndürülmüş biçimi: göreli [dx, dy, renk] üçlüleri.
List<List<int>> fragShape(MozLevel lv, MozFrag f, int rot) {
  var pts = [for (final c in f.cells) [c[0], c[1], lv.at(c[0], c[1])]];
  for (var k = 0; k < rot % 4; k++) {
    pts = [for (final p in pts) [-p[1], p[0], p[2]]];
  }
  final mx = pts.map((p) => p[0]).reduce(math.min), my = pts.map((p) => p[1]).reduce(math.min);
  final out = [for (final p in pts) [p[0] - mx, p[1] - my, p[2]]];
  out.sort((a, b) => a[1] != b[1] ? a[1] - b[1] : a[0] - b[0]);
  return out;
}

/// Biçim (ox, oy) kaydırmasıyla boş ve rengi tutan hücrelere oturuyor mu?
bool fragFits(MozLevel lv, List<bool> filled, List<List<int>> shape, int ox, int oy) {
  for (final p in shape) {
    final x = ox + p[0], y = oy + p[1];
    if (x < 0 || y < 0 || x >= lv.w || y >= lv.h) return false;
    final i = y * lv.w + x;
    if (!lv.hole[i] || filled[i] || lv.grid[i] != p[2]) return false;
  }
  return true;
}

/// Dokunulan hücreyi kapsayan ve oturan ilk yerleşim (yoksa null).
List<int>? fragPlacement(MozLevel lv, List<bool> filled, List<List<int>> shape, int tx, int ty) {
  for (final p in shape) {
    final ox = tx - p[0], oy = ty - p[1];
    if (fragFits(lv, filled, shape, ox, oy)) return [ox, oy];
  }
  return null;
}

int _colorAt(int x, int y, int w, int h, _Motif m) {
  final ux = (2 * x - (w - 1)).abs(), vy = (2 * y - (h - 1)).abs();
  final ring = math.min((w - 1 - ux) ~/ 2, (h - 1 - vy) ~/ 2);
  final along = (h - 1 - vy) <= (w - 1 - ux) ? ux : vy;
  final a = along ~/ 2;
  if (ring == 0) return m.dentil > 0 ? (a % 2 == 0 ? 0 : 1) : (a % 3 == 1 ? 1 : 0);
  if (ring == 1 && m.band) return a % 3 == 0 ? 0 : 2;
  final p = ux ~/ 2, q = vy ~/ 2;
  final s = m.scale;
  if (p + q <= m.core) return m.inner[m.inner.length - 1];
  int idx;
  switch (m.kind) {
    case 0: // iç içe baklavalar
      idx = (p + q) ~/ s;
    case 1: // iç içe kareler
      idx = math.max(p, q) ~/ s;
    case 2: // rozet: halkalar ve köşegen yapraklar
      idx = (math.sqrt((p * p + q * q).toDouble()) / s).floor() + ((p - q).abs() <= 1 ? 1 : 0);
    case 3: // kafes
      idx = (p % s == 0 || q % s == 0) ? 0 : 1 + ((p ~/ s + q ~/ s) % 2);
    case 4: // dama baklava
      idx = (p + q) % 2 == 0 ? 0 : (((p * q) % 3 == 0) ? 1 : 2);
    default: // yalnız iki eksenli: şeritli kuşak
      idx = (p ~/ s + (q % 2)) % 3;
  }
  return m.inner[idx % (m.inner.length - 1)];
}

class _Motif {
  final int kind, scale, core, dentil;
  final bool band;
  final List<int> inner;
  const _Motif(this.kind, this.scale, this.core, this.dentil, this.band, this.inner);
}

/// Son kurma denemesinin sorunu (tanılama için).
String? lastMozProblem;
MozLevel? lastMozTry;

MozLevel? makeMozLevel(int d, SeededRandom r) {
  final n = 7 + (d * 4) ~/ 5; // 7..15
  final sym = d >= 5 && r.nextInt(2) == 0 ? 1 : 0;
  final w = n, h = sym == 0 ? n : n - 2;
  final k = 3 + (d ~/ 3 > 3 ? 3 : d ~/ 3);
  final cols = [for (var i = 0; i < kMozColors.length; i++) i];
  r.shuffle(cols);
  final palette = [for (final c in cols.take(k)) kMozColors[c]];
  // İç renkler: paletin 2. sırasından sonrası ve kremle başlayan bir döngü.
  final inner = <int>[for (var i = 2; i < k; i++) i, 0];
  r.shuffle(inner);
  inner.add(1); // göbek rengi
  final band = n >= 11 && r.nextInt(3) > 0;
  final kind = sym == 1 && r.nextInt(3) == 0 ? 5 : r.nextInt(5);
  final m = _Motif(kind, 1 + r.nextInt(2), r.nextInt(2), r.nextInt(2), band, inner);
  final grid = <int>[
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) _colorAt(x, y, w, h, m),
  ];
  // Hasar: rastgele lekeler.
  final hole = List<bool>.filled(w * h, false);
  final target = ((w * h) * (0.12 + 0.02 * d)).round();
  var count = 0;
  for (var guard = 0; guard < 60 && count < target; guard++) {
    final cx = r.nextInt(w), cy = r.nextInt(h);
    final rad = 0.8 + r.nextDouble() * (0.8 + d / 6);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= rad * rad && !hole[y * w + x] && count < target) {
          hole[y * w + x] = true;
          count++;
        }
      }
    }
  }
  final lv0 = MozLevel(w, h, sym, palette, grid, hole, const []);
  // Her yörüngede en az bir sağlam taş kalsın.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = lv0.orbit(x, y);
      if (o.every((i) => hole[i])) hole[o[r.nextInt(o.length)]] = false;
    }
  }
  // Parçalar: bitişik boşluklardan koparılmış kırıklar.
  final nf = d <= 2 ? 0 : (d <= 5 ? 1 : (d <= 8 ? 2 : 3));
  final used = <int>{};
  final frags = <MozFrag>[];
  final holes = [for (var i = 0; i < w * h; i++) if (hole[i]) i];
  r.shuffle(holes);
  for (final start in holes) {
    if (frags.length >= nf) break;
    if (used.contains(start)) continue;
    final size = 3 + r.nextInt(d >= 7 ? 3 : 2);
    final got = <int>[start];
    final seen = <int>{start};
    for (var g = 0; g < 40 && got.length < size; g++) {
      final from = got[r.nextInt(got.length)];
      final fx = from % w, fy = from ~/ w;
      final dir = r.nextInt(4);
      final nx = fx + const [0, 1, 0, -1][dir], ny = fy + const [-1, 0, 1, 0][dir];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final ni = ny * w + nx;
      if (!hole[ni] || used.contains(ni) || seen.contains(ni)) continue;
      seen.add(ni);
      got.add(ni);
    }
    if (got.length < 3) continue;
    used.addAll(got);
    frags.add(MozFrag([for (final i in got) [i % w, i ~/ w]], 1 + r.nextInt(3)));
  }
  final lv = MozLevel(w, h, sym, palette, grid, hole, frags);
  lastMozProblem = mozProblem(lv);
  lastMozTry = lv;
  return lastMozProblem == null ? lv : null;
}

bool checkMozLevel(MozLevel lv) => mozProblem(lv) == null;

/// Bölümün kurallara aykırı yanı (yoksa null).
String? mozProblem(MozLevel lv) {
  final w = lv.w, h = lv.h;
  if (w < 6 || h < 5 || w > 16 || h > 16) return 'boyut';
  if (lv.grid.length != w * h || lv.hole.length != w * h) return 'uzunluk';
  final k = lv.palette.length;
  if (k < 3 || lv.palette.toSet().length != k) return 'palet';
  if (lv.grid.any((c) => c < 0 || c >= k)) return 'renk';
  if (lv.grid.toSet().length < 3) return 'renk-az';
  if (lv.sym == 0 && w != h) return 'kare';
  // Desen ilan edilen simetriye uyar; her boşluğun yörüngesinde sağlam taş vardır.
  var holes = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final o = lv.orbit(x, y);
      if (o.any((j) => lv.grid[j] != lv.grid[i])) return 'simetri';
      if (lv.hole[i]) {
        holes++;
        if (o.every((j) => lv.hole[j])) return 'yörünge';
      }
    }
  }
  if (holes < 4 || holes > (w * h * 0.45)) return 'hasar';
  final seen = <int>{};
  for (final f in lv.frags) {
    if (f.cells.length < 3 || f.cells.length > 6 || f.rot < 1 || f.rot > 3) return 'parça';
    final set = <int>{};
    for (final c in f.cells) {
      if (c[0] < 0 || c[1] < 0 || c[0] >= w || c[1] >= h) return 'parça-dışı';
      final i = c[1] * w + c[0];
      if (!lv.hole[i] || !seen.add(i)) return 'parça-çakışma';
      set.add(i);
    }
    // Bitişiklik.
    final q = [set.first];
    final reach = <int>{set.first};
    while (q.isNotEmpty) {
      final i = q.removeLast();
      for (final j in [i - w, i + w, if (i % w > 0) i - 1, if (i % w < w - 1) i + 1]) {
        if (set.contains(j) && reach.add(j)) q.add(j);
      }
    }
    if (reach.length != set.length) return 'parça-bitişik';
    // Tepsideki biçim döndürülerek asıl yerine oturabilir.
    final filled = List<bool>.filled(w * h, false);
    final back = fragShape(lv, f, 0);
    final mx = f.cells.map((c) => c[0]).reduce(math.min), my = f.cells.map((c) => c[1]).reduce(math.min);
    if (!fragFits(lv, filled, back, mx, my)) return 'parça-oturmuyor';
  }
  return lv.looseCells.length >= 2 ? null : 'gevşek';
}
