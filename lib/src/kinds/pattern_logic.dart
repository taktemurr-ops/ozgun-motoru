// Desen atölyesi: Kolam Çizgisi, Girih Desenleri, Batik Atölyesi, Minyatür Boyama, Kağıt Oyma ve Kına Deseni.
// Saf Dart mantığı (Flutter'sız): bölüm üretimi ve doğrulama. Bütün desenler prosedüreldir; müze görseli, marka
// ya da dini simge kullanılmaz.
import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';

int _cl(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

// =================================================================== Kolam Çizgisi
//
// Ayna eğrisi modeli: w×h noktanın her biri bir hücrenin ortasında. Çizgi her hücrede dört çapraz parçadan
// (KD, GD, GB, KB) geçer; iki hücre arasındaki kenarın ortasında ya düz kesişir ya da (ayna varsa) geri döner.
// Dış kenarlarda hep geri döner. Kolam, bütün parçaların tek kapalı çizgi olmasıdır.
// Kenar numarası: önce dikey kenarlar ((x,y)-(x+1,y)): y*(w-1)+x, sonra yatay kenarlar ((x,y)-(x,y+1)): nV + y*w+x.

class KolamLevel {
  final int w, h;
  final List<bool> sol;
  final List<bool> start;
  final List<bool> editable;
  final int par;
  const KolamLevel(this.w, this.h, this.sol, this.start, this.editable, this.par);
  int get nV => h * (w - 1);
  int get sides => nV + (h - 1) * w;
}

int kolamSideCount(int w, int h) => h * (w - 1) + (h - 1) * w;

/// Her parçanın (hücre*4 + k; k: 0 KD, 1 GD, 2 GB, 3 KB) bağlı olduğu çizginin numarası.
List<int> kolamComponents(int w, int h, List<bool> m) {
  final n = w * h * 4;
  final p = List<int>.generate(n, (i) => i);
  int f(int a) {
    while (p[a] != a) {
      p[a] = p[p[a]];
      a = p[a];
    }
    return a;
  }

  void u(int a, int b) {
    final ra = f(a), rb = f(b);
    if (ra != rb) p[ra] = rb;
  }

  int s(int x, int y, int k) => (y * w + x) * 4 + k;
  final nV = h * (w - 1);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x == 0) u(s(x, y, 3), s(x, y, 2));
      if (x == w - 1) u(s(x, y, 0), s(x, y, 1));
      if (y == 0) u(s(x, y, 3), s(x, y, 0));
      if (y == h - 1) u(s(x, y, 2), s(x, y, 1));
      if (x < w - 1) {
        if (m[y * (w - 1) + x]) {
          u(s(x, y, 0), s(x, y, 1));
          u(s(x + 1, y, 3), s(x + 1, y, 2));
        } else {
          u(s(x, y, 0), s(x + 1, y, 2));
          u(s(x, y, 1), s(x + 1, y, 3));
        }
      }
      if (y < h - 1) {
        if (m[nV + y * w + x]) {
          u(s(x, y, 1), s(x, y, 2));
          u(s(x, y + 1, 0), s(x, y + 1, 3));
        } else {
          u(s(x, y, 2), s(x, y + 1, 0));
          u(s(x, y, 1), s(x, y + 1, 3));
        }
      }
    }
  }
  final lab = <int, int>{};
  return [for (var i = 0; i < n; i++) lab.putIfAbsent(f(i), () => lab.length)];
}

int kolamLoops(int w, int h, List<bool> m) {
  final c = kolamComponents(w, h, m);
  var mx = -1;
  for (final v in c) {
    if (v > mx) mx = v;
  }
  return mx + 1;
}

/// Kenarın (x, y) uçlarındaki iki hücre.
List<int> kolamSideCells(int w, int h, int s) {
  final nV = h * (w - 1);
  if (s < nV) {
    final y = s ~/ (w - 1), x = s % (w - 1);
    return [x, y, x + 1, y];
  }
  final t = s - nV;
  final y = t ~/ w, x = t % w;
  return [x, y, x, y + 1];
}

/// Simetrik yörünge: kenarın yatay ve dikey aynadaki karşılıkları.
List<int> _kolamOrbit(int w, int h, int s) {
  final c = kolamSideCells(w, h, s);
  final out = <int>{};
  for (final fx in const [false, true]) {
    for (final fy in const [false, true]) {
      int mx(int x) => fx ? w - 1 - x : x;
      int my(int y) => fy ? h - 1 - y : y;
      final ax = mx(c[0]), ay = my(c[1]), bx = mx(c[2]), by = my(c[3]);
      final x0 = math.min(ax, bx), y0 = math.min(ay, by);
      if (ay == by) {
        out.add(y0 * (w - 1) + x0);
      } else {
        out.add(h * (w - 1) + y0 * w + x0);
      }
    }
  }
  return out.toList();
}

KolamLevel? makeKolamLevel(int d, SeededRandom r) {
  const sizes = [
    [3, 3], [3, 4], [4, 4], [4, 5], [5, 5], [5, 6], [5, 6], [6, 6], [6, 7], [7, 7],
  ];
  final w = sizes[d - 1][0], h = sizes[d - 1][1];
  final n = kolamSideCount(w, h);
  final m = List<bool>.filled(n, false);
  final pr = 0.3 + r.nextDouble() * 0.25;
  final seen = <int>{};
  final orbits = <List<int>>[];
  for (var s = 0; s < n; s++) {
    if (seen.contains(s)) continue;
    final o = _kolamOrbit(w, h, s);
    seen.addAll(o);
    orbits.add(o);
    if (r.chance(pr)) {
      for (final e in o) {
        m[e] = true;
      }
    }
  }
  var loops = kolamLoops(w, h, m);
  // Simetriyi koruyarak birleştir.
  for (var pass = 0; pass < 6 && loops > 1; pass++) {
    r.shuffle(orbits);
    for (final o in orbits) {
      for (final e in o) {
        m[e] = !m[e];
      }
      final l2 = kolamLoops(w, h, m);
      if (l2 < loops) {
        loops = l2;
      } else {
        for (final e in o) {
          m[e] = !m[e];
        }
      }
      if (loops == 1) break;
    }
  }
  // Gerekirse tek kenarlarla birleştir (iki farklı çizginin buluştuğu kenar hep birleştirir).
  if (loops > 1) {
    final ids = List<int>.generate(n, (i) => i);
    r.shuffle(ids);
    for (final e in ids) {
      if (loops == 1) break;
      m[e] = !m[e];
      final l2 = kolamLoops(w, h, m);
      if (l2 < loops) {
        loops = l2;
      } else {
        m[e] = !m[e];
      }
    }
  }
  if (loops != 1) return null;
  // Düzenlenebilir kenarlar ve karıştırma.
  final k = _cl(2 + d + (d > 5 ? d - 5 : 0), 3, n ~/ 2);
  final idx = List<int>.generate(n, (i) => i);
  r.shuffle(idx);
  final editable = List<bool>.filled(n, false);
  for (var i = 0; i < k; i++) {
    editable[idx[i]] = true;
  }
  final start = List<bool>.of(m);
  final ed = [for (var i = 0; i < k; i++) idx[i]];
  r.shuffle(ed);
  final t = _cl((k * (0.5 + r.nextDouble() * 0.3)).round(), 1, k);
  for (var i = 0; i < t; i++) {
    start[ed[i]] = !start[ed[i]];
  }
  if (kolamLoops(w, h, start) < 2) return null;
  return KolamLevel(w, h, m, start, editable, t);
}

bool checkKolamLevel(KolamLevel lv) {
  final n = kolamSideCount(lv.w, lv.h);
  if (lv.sol.length != n || lv.start.length != n || lv.editable.length != n) return false;
  if (kolamLoops(lv.w, lv.h, lv.sol) != 1) return false;
  if (kolamLoops(lv.w, lv.h, lv.start) < 2) return false;
  var diff = 0;
  for (var i = 0; i < n; i++) {
    if (lv.sol[i] != lv.start[i]) {
      if (!lv.editable[i]) return false;
      diff++;
    }
  }
  return diff == lv.par && diff > 0;
}

// =================================================================== Girih Desenleri
//
// Beş girih karosu (kenar boyu 1, açılar 36°'nin katları). Karolar kenar kenara eklenerek bir yama büyütülür;
// bazı karolar çıkarılır, oyuncu doğru karoyu doğru açıyla boşluğa koyar.

class GPt {
  final double x, y;
  const GPt(this.x, this.y);
  GPt operator +(GPt o) => GPt(x + o.x, y + o.y);
  GPt operator -(GPt o) => GPt(x - o.x, y - o.y);
  GPt operator *(double k) => GPt(x * k, y * k);
  double get len => math.sqrt(x * x + y * y);
  bool near(GPt o, [double e = 1e-6]) => (x - o.x).abs() < e && (y - o.y).abs() < e;
}

/// İç açılar (36° biriminde): ongen, beşgen, eşkenar dörtgen, uzun altıgen, papyon.
const List<List<int>> kGirihAngles = [
  [4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  [3, 3, 3, 3, 3],
  [2, 3, 2, 3],
  [2, 4, 4, 2, 4, 4],
  [2, 2, 6, 2, 2, 6],
];

GPt girihUnit(int h) {
  final a = (h % 10) * math.pi / 5;
  return GPt(math.cos(a), math.sin(a));
}

class GTile {
  final int type;
  final List<GPt> v;
  final List<int> heading; // kenar i: v[i] -> v[i+1] yönü (36° birimi)
  const GTile(this.type, this.v, this.heading);
  int get rot => heading[0] % 10;
  GPt get center {
    var sx = 0.0, sy = 0.0;
    for (final p in v) {
      sx += p.x;
      sy += p.y;
    }
    return GPt(sx / v.length, sy / v.length);
  }
}

/// [type] karosunu, s numaralı kenarı [p0]'dan [h] yönünde başlayacak biçimde kurar.
GTile girihBuild(int type, GPt p0, int h, int s) {
  final a = kGirihAngles[type];
  final n = a.length;
  final v = List<GPt>.filled(n, p0);
  final hd = List<int>.filled(n, 0);
  var p = p0, hh = h;
  for (var i = 0; i < n; i++) {
    final j = (s + i) % n;
    v[j] = p;
    hd[j] = ((hh % 10) + 10) % 10;
    p = p + girihUnit(hh);
    hh += 5 - a[(j + 1) % n];
  }
  return GTile(type, v, hd);
}

/// Oyuncunun seçtiği karo ve açı [hole] ile aynı yere oturuyor mu?
bool girihMatches(GTile hole, int type, int rot) {
  if (hole.type != type && kGirihAngles[type].length != hole.v.length) return false;
  final t = girihBuild(type, const GPt(0, 0), rot, 0);
  final c1 = hole.center, c2 = t.center;
  for (final p in t.v) {
    final q = p - c2 + c1;
    if (!hole.v.any((x) => x.near(q, 1e-5))) return false;
  }
  return hole.v.length == t.v.length;
}

bool _inPoly(GPt p, List<GPt> poly) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) c = !c;
  }
  return c;
}

double _cross(GPt o, GPt a, GPt b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Kenarlar uç noktalar dışında kesişiyor ya da üst üste biniyorsa true.
bool _segClash(GPt a, GPt b, GPt c, GPt d) {
  const e = 1e-7;
  final same = (a.near(c, 1e-6) && b.near(d, 1e-6)) || (a.near(d, 1e-6) && b.near(c, 1e-6));
  if (same) return false;
  final d1 = _cross(c, d, a), d2 = _cross(c, d, b), d3 = _cross(a, b, c), d4 = _cross(a, b, d);
  if (d1.abs() < e && d2.abs() < e) {
    // Aynı doğru üzerinde: izdüşüm örtüşmesi.
    final ux = b.x - a.x, uy = b.y - a.y;
    double t(GPt p) => ((p.x - a.x) * ux + (p.y - a.y) * uy) / (ux * ux + uy * uy);
    final t1 = t(c), t2 = t(d);
    final lo = math.max(0.0, math.min(t1, t2)), hi = math.min(1.0, math.max(t1, t2));
    return hi - lo > 1e-4;
  }
  if (((d1 > e && d2 < -e) || (d1 < -e && d2 > e)) && ((d3 > e && d4 < -e) || (d3 < -e && d4 > e))) return true;
  return false;
}

List<GPt> _samples(GTile t) {
  final c = t.center;
  return [c, for (final p in t.v) c + (p - c) * 0.6, for (var i = 0; i < t.v.length; i++) c + ((t.v[i] + t.v[(i + 1) % t.v.length]) * 0.5 - c) * 0.7];
}

bool girihOverlap(GTile a, GTile b) {
  if ((a.center - b.center).len > 4.2) return false;
  for (var i = 0; i < a.v.length; i++) {
    for (var j = 0; j < b.v.length; j++) {
      if (_segClash(a.v[i], a.v[(i + 1) % a.v.length], b.v[j], b.v[(j + 1) % b.v.length])) return true;
    }
  }
  for (final p in _samples(a)) {
    if (_inPoly(p, b.v)) return true;
  }
  for (final p in _samples(b)) {
    if (_inPoly(p, a.v)) return true;
  }
  return false;
}

String _vk(GPt p) => '${(p.x * 1000).round()},${(p.y * 1000).round()}';

bool girihShareEdge(GTile a, GTile b) {
  for (var i = 0; i < a.v.length; i++) {
    final p = a.v[i], q = a.v[(i + 1) % a.v.length];
    for (var j = 0; j < b.v.length; j++) {
      if (b.v[j].near(q, 1e-5) && b.v[(j + 1) % b.v.length].near(p, 1e-5)) return true;
    }
  }
  return false;
}

class GirihLevel {
  final List<GTile> tiles;
  final List<int> holes;
  const GirihLevel(this.tiles, this.holes);
}

GirihLevel? makeGirihLevel(int d, SeededRandom r) {
  final target = 6 + d * 2;
  final nHoles = _cl(1 + (d + 1) ~/ 2 + (d > 6 ? 1 : 0), 2, 8);
  final tiles = <GTile>[girihBuild(0, const GPt(0, 0), r.nextInt(10), 0)];
  final angle = <String, int>{};
  void addAngles(GTile t) {
    final a = kGirihAngles[t.type];
    for (var i = 0; i < t.v.length; i++) {
      final k = _vk(t.v[i]);
      angle[k] = (angle[k] ?? 0) + a[i];
    }
  }

  addAngles(tiles[0]);
  const weights = [1, 5, 3, 5, 4];
  var fails = 0;
  while (tiles.length < target && fails < 60) {
    // Sınır kenarları.
    final edges = <List<Object>>[];
    for (final t in tiles) {
      for (var i = 0; i < t.v.length; i++) {
        final a = t.v[i], b = t.v[(i + 1) % t.v.length];
        var shared = false;
        for (final o in tiles) {
          if (identical(o, t)) continue;
          for (var j = 0; j < o.v.length && !shared; j++) {
            if (o.v[j].near(b, 1e-5) && o.v[(j + 1) % o.v.length].near(a, 1e-5)) shared = true;
          }
          if (shared) break;
        }
        if (!shared) {
          final mid = (a + b) * 0.5;
          edges.add([mid.len + r.nextDouble() * 1.6, a, b, t.heading[i]]);
        }
      }
    }
    edges.sort((x, y) => (x[0] as double).compareTo(y[0] as double));
    var placed = false;
    for (var ei = 0; ei < edges.length && ei < 6 && !placed; ei++) {
      final a = edges[ei][1] as GPt, b = edges[ei][2] as GPt;
      final h = ((edges[ei][3] as int) + 5) % 10;
      for (var tries = 0; tries < 6 && !placed; tries++) {
        final type = r.weighted(weights);
        final n = kGirihAngles[type].length;
        final s = r.nextInt(n);
        final t = girihBuild(type, b, h, s);
        if (!t.v[(s + 1) % n].near(a, 1e-5)) continue;
        final aa = kGirihAngles[type];
        var ok = true;
        for (var i = 0; i < n && ok; i++) {
          final sum = (angle[_vk(t.v[i])] ?? 0) + aa[i];
          if (sum > 10 || sum == 9) ok = false;
        }
        if (!ok) continue;
        for (final o in tiles) {
          if (girihOverlap(t, o)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        tiles.add(t);
        addAngles(t);
        placed = true;
      }
    }
    if (!placed) fails++;
  }
  if (tiles.length < target) return null;
  // Komşu olmayan boşluklar; her türden en az biri seçilmeye çalışılır.
  final order = List<int>.generate(tiles.length, (i) => i);
  r.shuffle(order);
  order.sort((x, y) {
    // Farklı türleri öne al.
    return tiles[x].type == 0 ? 1 : (tiles[y].type == 0 ? -1 : 0);
  });
  final holes = <int>[];
  final usedTypes = <int>{};
  for (final pass in const [0, 1]) {
    for (final i in order) {
      if (holes.length >= nHoles) break;
      if (holes.contains(i)) continue;
      if (pass == 0 && usedTypes.contains(tiles[i].type)) continue;
      if (holes.any((j) => girihShareEdge(tiles[i], tiles[j]))) continue;
      holes.add(i);
      usedTypes.add(tiles[i].type);
    }
  }
  if (holes.length < nHoles) return null;
  holes.sort();
  return GirihLevel(tiles, holes);
}

bool checkGirihLevel(GirihLevel lv) {
  if (lv.tiles.length < 6 || lv.holes.isEmpty) return false;
  for (var i = 0; i < lv.tiles.length; i++) {
    final t = lv.tiles[i];
    // Kapalı ve doğru açılı.
    final re = girihBuild(t.type, t.v[0], t.heading[0], 0);
    for (var k = 0; k < t.v.length; k++) {
      if (!re.v[k].near(t.v[k], 1e-6)) return false;
    }
    for (var j = i + 1; j < lv.tiles.length; j++) {
      if (girihOverlap(t, lv.tiles[j])) return false;
    }
  }
  for (final h in lv.holes) {
    if (h < 0 || h >= lv.tiles.length) return false;
    final t = lv.tiles[h];
    if (!girihMatches(t, t.type, t.rot)) return false;
    // Başka tür aynı boşluğa oturmamalı.
    for (var ty = 0; ty < 5; ty++) {
      if (ty == t.type) continue;
      for (var rot = 0; rot < 10; rot++) {
        if (girihMatches(t, ty, rot)) return false;
      }
    }
    for (final g in lv.holes) {
      if (g != h && girihShareEdge(t, lv.tiles[g])) return false;
    }
  }
  return true;
}

/// Karonun girih şeritleri: her kenar ortasından 54°'lik iki çizgi, köşede komşu kenarınkiyle buluşur.
List<List<GPt>> girihStraps(GTile t) {
  final n = t.v.length;
  final out = <List<GPt>>[];
  final c = t.center;
  for (var i = 0; i < n; i++) {
    final a = t.v[i], b = t.v[(i + 1) % n], q = t.v[(i + 2) % n];
    final m1 = (a + b) * 0.5, m2 = (b + q) * 0.5;
    // Köşe b'nin açıortayı üzerinde, kenarlarla 54° yapan çizgilerin kesişimi.
    final ang = kGirihAngles[t.type][(i + 1) % n] * math.pi / 5;
    final half = ang / 2;
    final gamma = math.pi - half - 54 * math.pi / 180;
    GPt x;
    if (gamma <= 0.2) {
      x = c;
    } else {
      final dist = 0.5 * math.sin(54 * math.pi / 180) / math.sin(gamma);
      final u1 = (a - b) * (1 / (a - b).len), u2 = (q - b) * (1 / (q - b).len);
      var bis = u1 + u2;
      if (bis.len < 1e-6) {
        bis = GPt(-u1.y, u1.x);
      }
      bis = bis * (1 / bis.len);
      if (ang > math.pi) bis = bis * -1;
      x = b + bis * dist;
      if (!_inPoly(x, t.v) || dist > 1.0) x = c;
    }
    out.add([m1, x, m2]);
  }
  return out;
}

// =================================================================== Batik Atölyesi
//
// Mumlu batik: kumaş boya banyolarına sırayla girer; mumlanan yer o andan sonra boya almaz. Bir hücrenin son rengi,
// mumlandığı ana kadar girdiği banyoların karışımıdır. Hedef kumaşı tutturmak için banyo sırasını ve her motifin
// hangi banyodan sonra mumlanacağını bulmak gerekir.

class BatikLevel {
  final int w, h;
  final List<List<bool>> motifs;
  final List<int> motifType;
  final List<int> dyes; // kullanılabilir boyalar (0 sarı, 1 kırmızı, 2 çivit, 3 soga kahvesi)
  final List<int> order; // çözüm banyo sırası
  final List<int> waxAt; // çözüm: motif kaç banyodan sonra mumlanır
  final List<int> target; // hücre başına boya maskesi
  const BatikLevel(this.w, this.h, this.motifs, this.motifType, this.dyes, this.order, this.waxAt, this.target);
}

List<bool> batikMotif(int type, int w, int h, SeededRandom r) {
  final m = List<bool>.filled(w * h, false);
  final p = 3 + r.nextInt(3);
  final ox = r.nextInt(p), oy = r.nextInt(p);
  final cx = (w - 1) / 2, cy = (h - 1) / 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Ortaya göre katlanmış koordinatlar: motif iki eksende aynalı olur.
      final fx = math.min(x, w - 1 - x), fy = math.min(y, h - 1 - y);
      bool v;
      switch (type) {
        case 0: // kawung: kafes noktaları çevresinde çapraz yapraklar
          final dx = ((fx + ox) % (p + 1)) - p / 2, dy = ((fy + oy) % (p + 1)) - p / 2;
          final s1 = dx.abs() + dy.abs();
          v = (dx.abs() - dy.abs()).abs() <= 0.6 && s1 >= 0.9 && s1 <= p * 0.75;
        case 1: // parang: çapraz şeritler
          v = ((fx + fy + ox) % (p + 1)) == 0;
        case 2: // ceplok: küçük baklavalar
          final dx = ((fx + ox) % (p + 1)) - p / 2, dy = ((fy + oy) % (p + 1)) - p / 2;
          v = dx.abs() + dy.abs() <= 1.01;
        case 3: // truntum: serpiştirilmiş çiçekçikler
          v = ((fx * 3 + fy * 5 + ox) % (p + 4)) == 0;
        case 4: // pinggir: kenar şeridi
          v = fx == 0 || fy == 0;
        case 5: // madalyon: ortada halka
          final dd = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
          final rr = math.min(w, h) * (0.22 + (ox % 3) * 0.04);
          v = dd <= rr && dd >= rr - 1.6;
        default: // lereng: çizgiler
          v = ((fx + ox) % p) == 0 && fy > 0;
      }
      m[y * w + x] = v;
    }
  }
  return m;
}

/// Banyo dizisi [order] ve mum zamanları [waxAt] ile oluşan maskeler.
List<int> batikResult(int w, int h, List<List<bool>> motifs, List<int> order, List<int?> waxAt, int bathsDone) {
  final out = List<int>.filled(w * h, 0);
  for (var i = 0; i < w * h; i++) {
    var t = bathsDone;
    for (var k = 0; k < motifs.length; k++) {
      final a = waxAt[k];
      if (a != null && motifs[k][i] && a < t) t = a;
    }
    var mask = 0;
    for (var b = 0; b < t; b++) {
      mask |= 1 << order[b];
    }
    out[i] = mask;
  }
  return out;
}

BatikLevel? makeBatikLevel(int d, SeededRandom r) {
  final w = _cl(9 + d ~/ 2, 9, 14), h = w + 2;
  final nd = d <= 3 ? 2 : 3;
  final nm = _cl(2 + (d + 1) ~/ 2, 3, 6);
  final pool = [0, 1, 2, 3];
  r.shuffle(pool);
  final dyes = pool.take(nd).toList();
  // Soga (3) hep en koyu: varsa en sona.
  final order = List<int>.of(dyes);
  r.shuffle(order);
  if (order.contains(3)) {
    order
      ..remove(3)
      ..add(3);
  }
  final types = List<int>.generate(7, (i) => i);
  r.shuffle(types);
  final mt = types.take(nm).toList();
  final motifs = [for (final t in mt) batikMotif(t, w, h, r)];
  for (final m in motifs) {
    final c = m.where((v) => v).length;
    if (c < 4 || c > w * h * 0.6) return null;
  }
  final waxAt = [for (var k = 0; k < nm; k++) r.nextInt(nd)];
  // Her banyodan önce en az bir motif mumlansın (sıra ipuçları görünsün).
  for (var b = 0; b < nd; b++) {
    if (!waxAt.contains(b)) waxAt[r.nextInt(nm)] = b;
  }
  dyes.sort();
  for (var rep = 0; rep < 12; rep++) {
    final target = batikResult(w, h, motifs, order, waxAt, nd);
    final lv = BatikLevel(w, h, motifs, mt, dyes, order, List<int>.of(waxAt), target);
    if (checkBatikLevel(lv)) return lv;
    // Etkisiz motiflerin mum zamanını değiştir.
    for (var k = 0; k < nm; k++) {
      if (!_batikMatters(lv, k)) waxAt[k] = r.nextInt(nd);
    }
  }
  return null;
}

bool checkBatikLevel(BatikLevel lv) {
  final nm = lv.motifs.length;
  if (nm < 2 || lv.order.length != lv.dyes.length || lv.waxAt.length != nm) return false;
  final res = batikResult(lv.w, lv.h, lv.motifs, lv.order, lv.waxAt, lv.order.length);
  for (var i = 0; i < res.length; i++) {
    if (res[i] != lv.target[i]) return false;
  }
  // Her motif sonucu değiştirmeli.
  for (var k = 0; k < nm; k++) {
    if (!_batikMatters(lv, k)) return false;
  }
  return lv.target.toSet().length >= 3;
}

bool _batikMatters(BatikLevel lv, int k) {
  final nm = lv.motifs.length;
  final w2 = <int?>[for (var j = 0; j < nm; j++) j == k ? null : lv.waxAt[j]];
  final r2 = batikResult(lv.w, lv.h, lv.motifs, lv.order, w2, lv.order.length);
  for (var i = 0; i < r2.length; i++) {
    if (r2[i] != lv.target[i]) return true;
  }
  return false;
}

// =================================================================== Minyatür Boyama
//
// Sayıyla boyama: prosedürel minyatür bahçesi, azulejo karosu ya da mandala. Aynı renkte bitişik hücreler bir bölge;
// çok küçük bölgeler komşusuna katılır. Her bölgenin numara yazılacak en iç hücresi hesaplanır.

class MiniLevel {
  final int n;
  final int style;
  final List<int> palette;
  final List<int> region; // hücre -> bölge
  final List<int> regionColor;
  final List<int> labelCell;
  const MiniLevel(this.n, this.style, this.palette, this.region, this.regionColor, this.labelCell);
  int get regions => regionColor.length;
}

const List<List<int>> kMiniPalettes = [
  // minyatür: lapis, altın, zümrüt, kiremit, gül, krem, gece mavisi, toprak, açık yeşil, mercan
  [0xFF26467A, 0xFFD9A441, 0xFF2E7D5B, 0xFFB5442E, 0xFFD98C8C, 0xFFF1E3C2, 0xFF1B2A44, 0xFF8A5A36, 0xFF9CC58A, 0xFFE07A5F],
  // azulejo: kobalt tonları, beyaz, sarı
  [0xFF1F4E9A, 0xFFF5F3EC, 0xFF6F9BD8, 0xFFE3B341, 0xFF0F2C5C, 0xFFA9C4EA, 0xFF3A7BC8, 0xFFD6E4F5, 0xFF8C6D2A, 0xFF4F6F8F],
  // mandala: canlı
  [0xFF7A4E7E, 0xFFE07A5F, 0xFF3A8D8C, 0xFFF2CC8F, 0xFF81B29A, 0xFF3D405B, 0xFFB23A48, 0xFFF4F1DE, 0xFFD9A441, 0xFF2E5E8C],
];

List<int> _miniPaint(int n, int style, int colors, SeededRandom r) {
  final g = List<int>.filled(n * n, 0);
  final c = (n - 1) / 2;
  int pc(int v) => v % colors;
  switch (style) {
    case 0: // minyatür bahçe (dikey aynalı)
      final horizon = n * (0.45 + r.nextDouble() * 0.12);
      final treeW = 0.18 + r.nextDouble() * 0.08;
      final flowerY = n * 0.82;
      final sun = r.chance(0.5);
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          final ax = (x - c).abs() / n;
          var v = y < horizon ? 6 : 2; // gök, çimen
          if (y >= horizon && ((y + (ax * n).round()) % 7 == 0)) v = 8;
          // Yan ağaçlar: yuvarlak taç ve gövde.
          final tx = (ax - 0.3).abs(), ty = (y - horizon * 0.95) / n;
          if (tx * tx + ty * ty * 0.7 < treeW * treeW * 0.55) v = 8;
          if (tx < 0.025 && y >= horizon * 0.95 && y < horizon + n * 0.1) v = 7;
          // Ortadaki selvi.
          final cy0 = horizon * 0.35, cy1 = horizon + n * 0.12;
          if (y >= cy0 && y <= cy1) {
            final t = (y - cy0) / (cy1 - cy0);
            if (ax < 0.08 * math.sin(t * math.pi * 0.95 + 0.1)) v = 2;
          }
          // Çiçek tarhı.
          final fx = ((ax * n) % 6) - 3, fy = y - flowerY;
          if (fx * fx + fy * fy < 4.5) v = (((ax * n) ~/ 6) % 2 == 0) ? 4 : 9;
          if (fx * fx + fy * fy < 1.2) v = 1;
          // Ay ya da yıldız benzeri altın daire (dini olmayan süs).
          final sx = x - c, sy = y - horizon * 0.22;
          if (sun && sx * sx + sy * sy < (n * 0.07) * (n * 0.07)) v = 1;
          // Çerçeve.
          if (x == 0 || y == 0 || x == n - 1 || y == n - 1) v = 3;
          if (x == 1 || y == 1 || x == n - 2 || y == n - 2) v = 1;
          g[y * n + x] = pc(v);
        }
      }
    case 1: // azulejo: 2×2 karo, sekiz katlı simetri
      final t = n / 2;
      final rr = [0.18 + r.nextDouble() * 0.08, 0.32 + r.nextDouble() * 0.08, 0.42 + r.nextDouble() * 0.05];
      final petals = 4 + 4 * r.nextInt(2);
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          var fx = ((x % t) - (t - 1) / 2).abs() / t, fy = ((y % t) - (t - 1) / 2).abs() / t;
          if (fy > fx) {
            final s = fx;
            fx = fy;
            fy = s;
          }
          final d0 = math.sqrt(fx * fx + fy * fy);
          final th = math.atan2(fy, fx);
          var v = 1;
          if (d0 < rr[0]) v = 0;
          if (d0 < rr[0] * 0.5) v = 3;
          if (d0 >= rr[0] && d0 < rr[1] && math.cos(th * petals) > 0.2) v = 2;
          if ((d0 - rr[1]).abs() < 0.035) v = 4;
          final dc = math.sqrt((0.5 - fx) * (0.5 - fx) + (0.5 - fy) * (0.5 - fy));
          if (dc < rr[2] - 0.2) v = 6;
          if (dc < (rr[2] - 0.2) * 0.5) v = 5;
          if (fx > 0.47) v = 0;
          g[y * n + x] = pc(v);
        }
      }
    default: // mandala
      final fold = [6, 8, 10, 12][r.nextInt(4)];
      final rings = <double>[0.1];
      while (rings.last < 0.95) {
        rings.add(rings.last + 0.1 + r.nextDouble() * 0.12);
      }
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          final dx = (x - c) / (n / 2), dy = (y - c) / (n / 2);
          final d0 = math.sqrt(dx * dx + dy * dy);
          final th = math.atan2(dy, dx);
          var ring = 0;
          while (ring < rings.length && d0 > rings[ring]) {
            ring++;
          }
          int v;
          if (ring >= rings.length) {
            v = ((x + y) % 2 == 0 && (x - c).abs() > n * 0.42 && (y - c).abs() > n * 0.42) ? 5 : 3;
          } else {
            final lo = ring == 0 ? 0.0 : rings[ring - 1], hi = rings[ring];
            final t = (d0 - lo) / (hi - lo);
            final k = fold * (ring.isEven ? 1 : 2);
            final wave = math.cos(th * k);
            v = ring + (wave > 1 - 2 * t ? 1 : 0) * 3;
          }
          g[y * n + x] = pc(v);
        }
      }
  }
  return g;
}

MiniLevel? makeMiniLevel(int d, SeededRandom r) {
  final n = 18 + d * 2;
  final style = r.nextInt(3);
  final colors = _cl(3 + (d + 1) ~/ 2 + 1, 4, 9);
  final g = _miniPaint(n, style, colors, r);
  // Küçük bölgeleri komşusuna kat.
  const minSize = 4;
  var region = List<int>.filled(n * n, -1);
  var sizes = <int>[];
  void label() {
    region = List<int>.filled(n * n, -1);
    sizes = [];
    for (var i = 0; i < n * n; i++) {
      if (region[i] >= 0) continue;
      final id = sizes.length;
      var cnt = 0;
      final st = [i];
      region[i] = id;
      while (st.isNotEmpty) {
        final p = st.removeLast();
        cnt++;
        final px = p % n, py = p ~/ n;
        for (final dd in const [
          [1, 0], [-1, 0], [0, 1], [0, -1],
        ]) {
          final qx = px + dd[0], qy = py + dd[1];
          if (qx < 0 || qy < 0 || qx >= n || qy >= n) continue;
          final q = qy * n + qx;
          if (region[q] < 0 && g[q] == g[i]) {
            region[q] = id;
            st.add(q);
          }
        }
      }
      sizes.add(cnt);
    }
  }

  for (var pass = 0; pass < 8; pass++) {
    label();
    var changed = false;
    for (var i = 0; i < n * n; i++) {
      if (sizes[region[i]] >= minSize) continue;
      final px = i % n, py = i ~/ n;
      for (final dd in const [
        [1, 0], [-1, 0], [0, 1], [0, -1],
      ]) {
        final qx = px + dd[0], qy = py + dd[1];
        if (qx < 0 || qy < 0 || qx >= n || qy >= n) continue;
        final q = qy * n + qx;
        if (g[q] != g[i]) {
          g[i] = g[q];
          changed = true;
          break;
        }
      }
    }
    if (!changed) break;
  }
  label();
  if (sizes.any((s) => s < minSize)) return null;
  final nr = sizes.length;
  if (nr < 6 || nr > 40 + d * 14) return null;
  final regionColor = List<int>.filled(nr, 0);
  for (var i = 0; i < n * n; i++) {
    regionColor[region[i]] = g[i];
  }
  // Renkleri 0..k-1'e sıkıştır (kullanılmayan numara kalmasın).
  final used = regionColor.toSet().toList()..sort();
  if (used.length < 3) return null;
  final remap = {for (var i = 0; i < used.length; i++) used[i]: i};
  final pal = kMiniPalettes[style];
  final palette = [for (final u in used) pal[u % pal.length]];
  for (var k = 0; k < nr; k++) {
    regionColor[k] = remap[regionColor[k]]!;
  }
  // Etiket hücresi: bölge sınırına en uzak hücre.
  final dist = List<int>.filled(n * n, 1 << 20);
  final q = <int>[];
  for (var i = 0; i < n * n; i++) {
    final px = i % n, py = i ~/ n;
    var edge = false;
    for (final dd in const [
      [1, 0], [-1, 0], [0, 1], [0, -1],
    ]) {
      final qx = px + dd[0], qy = py + dd[1];
      if (qx < 0 || qy < 0 || qx >= n || qy >= n || region[qy * n + qx] != region[i]) edge = true;
    }
    if (edge) {
      dist[i] = 0;
      q.add(i);
    }
  }
  for (var h = 0; h < q.length; h++) {
    final p = q[h];
    final px = p % n, py = p ~/ n;
    for (final dd in const [
      [1, 0], [-1, 0], [0, 1], [0, -1],
    ]) {
      final qx = px + dd[0], qy = py + dd[1];
      if (qx < 0 || qy < 0 || qx >= n || qy >= n) continue;
      final o = qy * n + qx;
      if (region[o] == region[p] && dist[o] > dist[p] + 1) {
        dist[o] = dist[p] + 1;
        q.add(o);
      }
    }
  }
  final labelCell = List<int>.filled(nr, -1);
  for (var i = 0; i < n * n; i++) {
    final k = region[i];
    if (labelCell[k] < 0 || dist[i] > dist[labelCell[k]]) labelCell[k] = i;
  }
  final lv = MiniLevel(n, style, palette, region, regionColor, labelCell);
  return checkMiniLevel(lv) ? lv : null;
}

bool checkMiniLevel(MiniLevel lv) {
  final n = lv.n;
  if (lv.region.length != n * n || lv.regions < 6) return false;
  final cnt = List<int>.filled(lv.regions, 0);
  for (final k in lv.region) {
    if (k < 0 || k >= lv.regions) return false;
    cnt[k]++;
  }
  if (cnt.any((c) => c < 4)) return false;
  for (var k = 0; k < lv.regions; k++) {
    final l = lv.labelCell[k];
    if (l < 0 || lv.region[l] != k) return false;
    if (lv.regionColor[k] < 0 || lv.regionColor[k] >= lv.palette.length) return false;
  }
  return lv.regionColor.toSet().length == lv.palette.length;
}

// =================================================================== Kağıt Oyma
//
// Kâğıt katlanır (1: dikey, 2: dikey + yatay, 3: + çapraz), katlı parçada hücreler kesilir, açınca desen
// katlama simetrisiyle çoğalır. Oyuncu hedef deseni veren kesikleri katlı parçaya yapar. Parça ekranda 90°'lik
// adımlarla döndürülmüş gösterilebilir; üst kenarda ip izi ve kesikli katlama çizgileri yönü belli eder.

class PaperLevel {
  final int s; // tabaka s×s
  final int fold; // 1, 2, 3
  final int rot; // gösterim dönüşü (0..3)
  final List<int> cut; // çözüm: parça hücreleri (tabaka indeksi y*s+x)
  final List<bool> target; // açılmış desen
  const PaperLevel(this.s, this.fold, this.rot, this.cut, this.target);
}

/// Parçaya ait tabaka hücreleri (sol üst bölge).
bool paperInPiece(int s, int fold, int x, int y) {
  final hs = s ~/ 2;
  if (x >= hs) return false;
  if (fold >= 2 && y >= hs) return false;
  if (fold >= 3 && y > x) return false;
  return true;
}

bool paperBorder(int s, int x, int y) => x == 0 || y == 0 || x == s - 1 || y == s - 1;

/// Bir hücrenin açılmış tabakadaki bütün kopyaları.
Set<int> paperOrbit(int s, int fold, int x, int y) {
  final out = <int>{};
  final pts = <List<int>>[
    [x, y],
  ];
  if (fold >= 3) pts.add([y, x]);
  final pts2 = <List<int>>[];
  for (final p in pts) {
    pts2.add(p);
    pts2.add([s - 1 - p[0], p[1]]);
  }
  final pts3 = <List<int>>[];
  for (final p in pts2) {
    pts3.add(p);
    if (fold >= 2) pts3.add([p[0], s - 1 - p[1]]);
  }
  for (final p in pts3) {
    out.add(p[1] * s + p[0]);
  }
  return out;
}

List<bool> paperUnfold(int s, int fold, Iterable<int> cuts) {
  final t = List<bool>.filled(s * s, false);
  for (final c in cuts) {
    for (final o in paperOrbit(s, fold, c % s, c ~/ s)) {
      t[o] = true;
    }
  }
  return t;
}

PaperLevel? makePaperLevel(int d, SeededRandom r) {
  final fold = d <= 2 ? 1 : (d <= 6 ? 2 : 3);
  final s = d <= 2 ? 8 : (d <= 5 ? 10 : 12);
  final rot = d <= 3 ? 0 : r.nextInt(4);
  final cells = <int>[];
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      if (paperInPiece(s, fold, x, y) && !paperBorder(s, x, y)) cells.add(y * s + x);
    }
  }
  final want = _cl((cells.length * (0.25 + r.nextDouble() * 0.15)).round(), 2, cells.length - 2);
  final cut = <int>{};
  final cellSet = cells.toSet();
  var guard = 0;
  while (cut.length < want && guard++ < 400) {
    var p = r.pick(cells);
    final len = 1 + r.nextInt(4);
    for (var k = 0; k < len && cut.length < want; k++) {
      cut.add(p);
      final dd = kPaperDirs[r.nextInt(4)];
      final q = p + dd[0] + dd[1] * s;
      if (cellSet.contains(q)) p = q;
    }
  }
  final lv = PaperLevel(s, fold, rot, cut.toList()..sort(), paperUnfold(s, fold, cut));
  return checkPaperLevel(lv) ? lv : null;
}

const List<List<int>> kPaperDirs = [
  [1, 0], [-1, 0], [0, 1], [0, -1],
];

bool checkPaperLevel(PaperLevel lv) {
  final s = lv.s;
  if (lv.cut.isEmpty) return false;
  for (final c in lv.cut) {
    if (!paperInPiece(s, lv.fold, c % s, c ~/ s) || paperBorder(s, c % s, c ~/ s)) return false;
  }
  final t = paperUnfold(s, lv.fold, lv.cut);
  var holes = 0;
  for (var i = 0; i < s * s; i++) {
    if (t[i] != lv.target[i]) return false;
    if (t[i]) holes++;
    if (t[i] && paperBorder(s, i % s, i ~/ s)) return false;
  }
  return holes >= 4 && holes < (s - 2) * (s - 2);
}

// =================================================================== Kına Deseni
//
// Kutupsal nokta ağı: merkez, R halka; her halkada sektör başına r nokta. Desen bir sektörde kurulur ve n katlı
// döndürülür. İlk sektör hazır gelir; oyuncu diğer sektörlere eksik çizgileri çizer.

class HennaLevel {
  final int n; // kat sayısı
  final int rings;
  final List<double> px, py; // nokta konumları (birim: halka aralığı)
  final List<List<int>> edges; // aday kenarlar (a, b, tür: 0 merkez, 1 yay, 2 ışın)
  final List<int> edgeSector; // kenarın sektörü (0 = hazır)
  final List<bool> inPattern;
  final bool guides;
  const HennaLevel(this.n, this.rings, this.px, this.py, this.edges, this.edgeSector, this.inPattern, this.guides);
  int get todo {
    var c = 0;
    for (var i = 0; i < edges.length; i++) {
      if (inPattern[i] && edgeSector[i] != 0) c++;
    }
    return c;
  }
}

/// Nokta ağı ve kenarlar; ayrıca her kenarın bir sektör döndürülmüş karşılığı.
class _HennaNet {
  final List<double> px = [], py = [], ang = [];
  final List<int> ring = [], idx = [];
  final List<int> ringStart = [];
  final List<List<int>> edges = [];
  final Map<String, int> edgeId = {};
  late List<int> rotEdge;
}

_HennaNet _hennaNet(int n, int rings) {
  final net = _HennaNet();
  net.px.add(0);
  net.py.add(0);
  net.ang.add(0);
  net.ring.add(0);
  net.idx.add(0);
  net.ringStart.add(0);
  for (var rr = 1; rr <= rings; rr++) {
    net.ringStart.add(net.px.length);
    final m = rr * n;
    final off = rr.isEven ? 0.5 : 0.0;
    for (var j = 0; j < m; j++) {
      final a = 2 * math.pi * (j + off) / m - math.pi / 2;
      net.px.add(rr * math.cos(a));
      net.py.add(rr * math.sin(a));
      net.ang.add(a);
      net.ring.add(rr);
      net.idx.add(j);
    }
  }
  int pt(int rr, int j) => rr == 0 ? 0 : net.ringStart[rr] + ((j % (rr * n)) + rr * n) % (rr * n);
  void add(int a, int b, int kind) {
    final key = a < b ? '$a-$b' : '$b-$a';
    if (net.edgeId.containsKey(key)) return;
    net.edgeId[key] = net.edges.length;
    net.edges.add([a, b, kind]);
  }

  for (var j = 0; j < n; j++) {
    add(0, pt(1, j), 0);
  }
  for (var rr = 1; rr <= rings; rr++) {
    final m = rr * n;
    for (var j = 0; j < m; j++) {
      add(pt(rr, j), pt(rr, j + 1), 1);
    }
    if (rr < rings) {
      // Dış halkadaki her nokta açıca en yakın iç noktaya bağlanır (eşitlikte ikisine).
      final mo = (rr + 1) * n;
      for (var j = 0; j < mo; j++) {
        final o = pt(rr + 1, j);
        var best = 1e9;
        final cand = <int>[];
        for (var i = 0; i < m; i++) {
          final q = pt(rr, i);
          var da = (net.ang[o] - net.ang[q]).abs() % (2 * math.pi);
          if (da > math.pi) da = 2 * math.pi - da;
          if (da < best - 1e-9) {
            best = da;
            cand
              ..clear()
              ..add(q);
          } else if ((da - best).abs() <= 1e-9) {
            cand.add(q);
          }
        }
        for (final q in cand) {
          add(q, o, 2);
        }
      }
    }
  }
  int rotPt(int p) => p == 0 ? 0 : pt(net.ring[p], net.idx[p] + net.ring[p]);
  net.rotEdge = [
    for (final e in net.edges)
      net.edgeId[(() {
        final a = rotPt(e[0]), b = rotPt(e[1]);
        return a < b ? '$a-$b' : '$b-$a';
      })()]!,
  ];
  return net;
}

HennaLevel? makeHennaLevel(int d, SeededRandom r) {
  final n = d <= 2 ? 4 : (d <= 5 ? [5, 6][r.nextInt(2)] : [6, 8][r.nextInt(2)]);
  final rings = d <= 2 ? 2 : (d <= 6 ? 3 : 4);
  final net = _hennaNet(n, rings);
  final ne = net.edges.length;
  // Yörüngeler: kenar -> sektörü ve temsilcisi.
  final orbit = List<int>.filled(ne, -1);
  final sector = List<int>.filled(ne, 0);
  final reps = <int>[];
  for (var e = 0; e < ne; e++) {
    if (orbit[e] >= 0) continue;
    final o = reps.length;
    reps.add(e);
    var x = e;
    for (var k = 0; k < n; k++) {
      if (orbit[x] >= 0) return null; // simetri bozuk
      orbit[x] = o;
      sector[x] = k;
      x = net.rotEdge[x];
    }
    if (x != e) return null;
  }
  // Sektör 0 desenini merkezden büyüt.
  final want = _cl(3 + d + (d > 6 ? 2 : 0), 4, 16);
  final chosen = <int>{};
  final touched = <int>{0};
  var guard = 0;
  while (chosen.length < want && guard++ < 500) {
    final cands = <int>[];
    for (var e = 0; e < ne; e++) {
      if (sector[e] != 0 || chosen.contains(orbit[e])) continue;
      final ed = net.edges[e];
      if (touched.contains(ed[0]) || touched.contains(ed[1])) cands.add(e);
    }
    if (cands.isEmpty) break;
    final e = r.pick(cands);
    chosen.add(orbit[e]);
    // Bütün yörünge noktaları dokunulmuş sayılır.
    var x = e;
    for (var k = 0; k < n; k++) {
      touched
        ..add(net.edges[x][0])
        ..add(net.edges[x][1]);
      x = net.rotEdge[x];
    }
  }
  // En dış halkaya ulaşsın.
  if (!touched.any((p) => net.ring[p] == rings)) return null;
  final inPattern = [for (var e = 0; e < ne; e++) chosen.contains(orbit[e])];
  final lv = HennaLevel(n, rings, net.px, net.py, net.edges, sector, inPattern, d <= 3);
  return checkHennaLevel(lv) ? lv : null;
}

bool checkHennaLevel(HennaLevel lv) {
  final ne = lv.edges.length;
  if (lv.inPattern.length != ne || lv.edgeSector.length != ne) return false;
  var given = 0;
  for (var e = 0; e < ne; e++) {
    if (lv.inPattern[e] && lv.edgeSector[e] == 0) given++;
  }
  final todo = lv.todo;
  return given >= 3 && todo >= 3 && todo == given * (lv.n - 1);
}

/// Dokunulan noktaya en yakın kenar ([lim] birimden yakınsa).
int hennaNearest(HennaLevel lv, double x, double y, {double lim = 0.32}) {
  var best = -1;
  var bd = lim;
  for (var e = 0; e < lv.edges.length; e++) {
    final a = lv.edges[e][0], b = lv.edges[e][1];
    double dd;
    if (lv.edges[e][2] == 1) {
      // Yay: yarıçap farkı + açısal aralık.
      final rr = math.sqrt(lv.px[a] * lv.px[a] + lv.py[a] * lv.py[a]);
      final pr = math.sqrt(x * x + y * y);
      final aa = math.atan2(lv.py[a], lv.px[a]), ab = math.atan2(lv.py[b], lv.px[b]), ap = math.atan2(y, x);
      double diff(double u, double v) {
        var t = (u - v) % (2 * math.pi);
        if (t < 0) t += 2 * math.pi;
        return t;
      }

      final span = diff(ab, aa), at = diff(ap, aa);
      final ins = at <= span || span > math.pi;
      dd = ins && span <= math.pi ? (pr - rr).abs() : 1e9;
      if (dd == 1e9) {
        final mx = (lv.px[a] + lv.px[b]) / 2, my = (lv.py[a] + lv.py[b]) / 2;
        dd = math.sqrt((x - mx) * (x - mx) + (y - my) * (y - my));
      }
    } else {
      final ax = lv.px[a], ay = lv.py[a], bx = lv.px[b], by = lv.py[b];
      final vx = bx - ax, vy = by - ay;
      var t = ((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy);
      t = t < 0 ? 0 : (t > 1 ? 1 : t);
      final qx = ax + vx * t - x, qy = ay + vy * t - y;
      dd = math.sqrt(qx * qx + qy * qy);
    }
    if (dd < bd) {
      bd = dd;
      best = e;
    }
  }
  return best;
}

/// Nokta karonun içinde mi?
bool girihContains(GTile t, GPt p) => _inPoly(p, t.v);
