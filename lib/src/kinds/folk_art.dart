import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core.dart';

/// Kodla çizilen özgün gölge oyunu çizimleri: perde, Hacivat ve Karagöz
/// tasvirleri, sahne eşyaları ve Nasreddin Hoca simgeleri.

// =================================================================== perde

/// Işıklı perde: ahşap çerçeve, mum ışığı, alt kuşak. (0,0)-(w,h) alanına.
void paintCurtain(Canvas c, double w, double h, {double glow = 1}) {
  final frame = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(h * 0.04));
  c.drawRRect(frame, fill(const Color(0xFF5A3A22)));
  final inner = Rect.fromLTWH(w * 0.03, h * 0.05, w * 0.94, h * 0.80);
  final light = Paint()
    ..shader = RadialGradient(
      colors: [Color.lerp(const Color(0xFFFFF3D6), const Color(0xFFF3DDAF), 1 - glow)!, const Color(0xFFE8C98E), const Color(0xFFB98A4E)],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCenter(center: inner.center + Offset(0, inner.height * 0.15), width: inner.width * 1.1, height: inner.height * 1.4));
  c.drawRect(inner, light);
  c.drawRect(inner, stroke(const Color(0xFF3B2414), h * 0.012));
  // Alt kuşak (peşkir): baklava dizisi.
  final band = Rect.fromLTWH(w * 0.03, h * 0.86, w * 0.94, h * 0.10);
  c.drawRect(band, fill(const Color(0xFF7A2E22)));
  final n = 14;
  for (var i = 0; i < n; i++) {
    final cx = band.left + (i + 0.5) * band.width / n;
    final p = Path()
      ..moveTo(cx, band.top + band.height * 0.15)
      ..lineTo(cx + band.width / n * 0.35, band.center.dy)
      ..lineTo(cx, band.bottom - band.height * 0.15)
      ..lineTo(cx - band.width / n * 0.35, band.center.dy)
      ..close();
    c.drawPath(p, fill(i.isEven ? const Color(0xFFD9A441) : const Color(0xFF2E5E8C)));
  }
}

// =================================================================== tasvirler

/// Deri tasvirlerin delik süsleri.
void _punch(Canvas c, Offset at, double r, Color col) {
  c.drawCircle(at, r, fill(col));
}

/// Hacivat ya da Karagöz tasviri. [base] ayak hizası; [s] boy birimi
/// (tasvir yaklaşık 11·s yüksekliğinde). [right]: yüzü sağa dönük.
void paintPuppet(Canvas c, Offset base, double s, {required bool hacivat, required bool right, double lift = 0, double arm = 0}) {
  c.save();
  c.translate(base.dx, base.dy - lift * s);
  c.scale(right ? s : -s, s);
  final robe = hacivat ? const Color(0xD92E7D6B) : const Color(0xD9B23A3A);
  final trim = hacivat ? const Color(0xE6D9A441) : const Color(0xE6E8B54A);
  final skin = const Color(0xE6E0B07A);
  final ink = const Color(0xFF2A1A10);
  // Çubuk (perdenin arkasından tutulan) gölgesi.
  c.drawLine(const Offset(-0.2, -5.4), const Offset(-1.6, 1.8), stroke(const Color(0x55301C0E), 0.18));
  // Entari.
  final body = Path()
    ..moveTo(-1.1, -6.2)
    ..lineTo(1.2, -6.2)
    ..quadraticBezierTo(2.2, -3.0, 2.3, 0)
    ..lineTo(-2.0, 0)
    ..quadraticBezierTo(-1.9, -3.2, -1.1, -6.2)
    ..close();
  c.drawPath(body, fill(robe));
  c.drawPath(body, stroke(ink, 0.12));
  // Kuşak ve süs delikleri.
  c.drawRect(const Rect.fromLTWH(-1.7, -3.7, 3.7, 0.45), fill(trim));
  for (var i = 0; i < 4; i++) {
    _punch(c, Offset(-1.2 + i * 0.95, -1.4), 0.17, const Color(0xCCFFF3D6));
    _punch(c, Offset(-0.7 + i * 0.7, -5.0), 0.12, const Color(0xAAFFF3D6));
  }
  // Kol: omuzdan ele, mafsal noktasıyla.
  final elbow = Offset(1.4, -4.4 + arm * 0.4);
  final hand = Offset(2.6 + arm * 0.6, -4.6 - arm * 1.4);
  c.drawLine(const Offset(0.6, -5.8), elbow, stroke(robe.withValues(alpha: 1), 0.55));
  c.drawLine(elbow, hand, stroke(robe.withValues(alpha: 1), 0.45));
  c.drawCircle(elbow, 0.16, fill(ink));
  c.drawCircle(hand, 0.32, fill(skin));
  // Baş.
  final head = const Offset(0.2, -7.2);
  c.drawCircle(head, 1.05, fill(skin));
  c.drawCircle(head, 1.05, stroke(ink, 0.1));
  // Burun.
  final nose = Path()
    ..moveTo(1.15, -7.5)
    ..lineTo(1.7, -7.0)
    ..lineTo(1.1, -6.9)
    ..close();
  c.drawPath(nose, fill(skin));
  if (hacivat) {
    // Sivri sakal, ince göz, uzun kavuk.
    final beard = Path()
      ..moveTo(-0.3, -6.5)
      ..lineTo(1.2, -6.6)
      ..lineTo(0.5, -5.2)
      ..close();
    c.drawPath(beard, fill(const Color(0xEE3B2A1E)));
    c.drawLine(const Offset(0.6, -7.5), const Offset(1.0, -7.5), stroke(ink, 0.14));
    final hat = Path()
      ..moveTo(-0.9, -7.9)
      ..lineTo(1.2, -7.9)
      ..lineTo(0.9, -10.6)
      ..quadraticBezierTo(0.2, -11.2, -0.5, -10.6)
      ..close();
    c.drawPath(hat, fill(const Color(0xE6E8E2D0)));
    c.drawPath(hat, stroke(ink, 0.1));
    c.drawRect(const Rect.fromLTWH(-1.0, -8.35, 2.3, 0.45), fill(const Color(0xE63C5A99)));
  } else {
    // Yuvarlak kara sakal, iri kara göz, yana yatık basık kavuk.
    c.drawCircle(const Offset(0.6, -6.2), 0.75, fill(const Color(0xF01E1410)));
    c.drawCircle(const Offset(0.75, -7.45), 0.28, fill(ink));
    c.drawCircle(const Offset(0.82, -7.52), 0.08, fill(const Color(0xFFFFF3D6)));
    c.save();
    c.translate(0.1, -8.2);
    c.rotate(-0.25);
    final hat = RRect.fromRectAndRadius(const Rect.fromLTWH(-1.2, -0.9, 2.4, 1.0), const Radius.circular(0.45));
    c.drawRRect(hat, fill(const Color(0xE6C8553D)));
    c.drawRRect(hat, stroke(ink, 0.1));
    c.drawRect(const Rect.fromLTWH(-1.25, -0.15, 2.5, 0.3), fill(const Color(0xE6E8E2D0)));
    c.restore();
  }
  c.restore();
}

// =================================================================== sahne eşyaları

/// Eşya simgesi; [r] kutusuna sığdırılır. 0 merdiven 1 ekmek 2 şemsiye 3 davul
/// 4 fener 5 anahtar 6 süpürge 7 çay 8 incir sepeti 9 ip 10 uçurtma 11 kazan.
void paintProp(Canvas c, int id, Rect r, {bool shadow = false}) {
  c.save();
  c.translate(r.left, r.top);
  c.scale(r.width / 10, r.height / 10);
  Color k(Color col) => shadow ? const Color(0xCC2A1A10) : col;
  final ink = k(const Color(0xFF2A1A10));
  final wood = k(const Color(0xFF9C6B3F));
  switch (id) {
    case 0:
      c.drawLine(const Offset(3, 0.6), const Offset(2.4, 9.4), stroke(wood, 0.7));
      c.drawLine(const Offset(7, 0.6), const Offset(7.6, 9.4), stroke(wood, 0.7));
      for (var i = 0; i < 5; i++) {
        final y = 1.8 + i * 1.7;
        c.drawLine(Offset(2.9 - i * 0.12, y), Offset(7.1 + i * 0.12, y), stroke(wood, 0.5));
      }
    case 1:
      c.drawOval(const Rect.fromLTWH(1, 3, 8, 4.4), fill(k(const Color(0xFFD9A05B))));
      for (var i = 0; i < 3; i++) {
        c.drawLine(Offset(3.2 + i * 1.6, 3.8), Offset(2.6 + i * 1.6, 6.4), stroke(k(const Color(0xFF8A5A2B)), 0.35));
      }
    case 2:
      final dome = Path()
        ..moveTo(0.8, 4.6)
        ..quadraticBezierTo(5, -1.6, 9.2, 4.6)
        ..close();
      c.drawPath(dome, fill(k(const Color(0xFF2E5E8C))));
      c.drawLine(const Offset(5, 4.4), const Offset(5, 8.6), stroke(ink, 0.45));
      c.drawArc(const Rect.fromLTWH(5, 7.6, 2, 2), 0, math.pi, false, stroke(ink, 0.45));
    case 3:
      c.drawRect(const Rect.fromLTWH(1.6, 3.2, 6.8, 4.2), fill(k(const Color(0xFFB23A48))));
      c.drawOval(const Rect.fromLTWH(1.6, 2.2, 6.8, 2), fill(k(const Color(0xFFF2E3C2))));
      for (var i = 0; i < 4; i++) {
        c.drawLine(Offset(1.8 + i * 2.2, 3.4), Offset(2.9 + i * 2.2, 7.3), stroke(k(const Color(0xFFD9A441)), 0.3));
      }
      c.drawLine(const Offset(7.6, 1.0), const Offset(9.4, 0.2), stroke(wood, 0.4));
    case 4:
      c.drawLine(const Offset(5, 0.4), const Offset(5, 1.8), stroke(ink, 0.35));
      c.drawArc(const Rect.fromLTWH(3.8, 0.2, 2.4, 2.4), math.pi, math.pi, false, stroke(ink, 0.3));
      c.drawRect(const Rect.fromLTWH(3.2, 2, 3.6, 6.2), fill(k(const Color(0xFFF5D06A))));
      c.drawRect(const Rect.fromLTWH(3.2, 2, 3.6, 6.2), stroke(ink, 0.35));
      c.drawCircle(const Offset(5, 5.1), 1.0, fill(k(const Color(0xFFE07A2F))));
      c.drawRect(const Rect.fromLTWH(2.8, 8.2, 4.4, 0.8), fill(ink));
    case 5:
      c.drawCircle(const Offset(3, 5), 2.0, stroke(k(const Color(0xFFD9A441)), 0.8));
      c.drawLine(const Offset(5, 5), const Offset(9.2, 5), stroke(k(const Color(0xFFD9A441)), 0.8));
      c.drawLine(const Offset(8.2, 5), const Offset(8.2, 6.8), stroke(k(const Color(0xFFD9A441)), 0.7));
      c.drawLine(const Offset(6.8, 5), const Offset(6.8, 6.4), stroke(k(const Color(0xFFD9A441)), 0.7));
    case 6:
      c.drawLine(const Offset(6.8, 0.6), const Offset(4.6, 6.2), stroke(wood, 0.55));
      final b = Path()
        ..moveTo(3.4, 5.6)
        ..lineTo(6.0, 6.6)
        ..lineTo(5.0, 9.6)
        ..lineTo(1.2, 8.6)
        ..close();
      c.drawPath(b, fill(k(const Color(0xFFD9B36A))));
      for (var i = 0; i < 4; i++) {
        c.drawLine(Offset(3.2 + i * 0.7, 6.2 + i * 0.25), Offset(1.8 + i * 0.85, 8.8 + i * 0.2), stroke(k(const Color(0xFF8A6A30)), 0.18));
      }
    case 7:
      final glass = Path()
        ..moveTo(3.2, 1.6)
        ..lineTo(6.8, 1.6)
        ..quadraticBezierTo(5.6, 4.6, 6.6, 7.6)
        ..lineTo(3.4, 7.6)
        ..quadraticBezierTo(4.4, 4.6, 3.2, 1.6)
        ..close();
      c.drawPath(glass, fill(k(const Color(0xFFB0303F))));
      c.drawPath(glass, stroke(k(const Color(0xFFF2E3C2)), 0.3));
      c.drawOval(const Rect.fromLTWH(1.6, 7.6, 6.8, 1.6), fill(k(const Color(0xFF2E5E8C))));
    case 8:
      final bk = Path()
        ..moveTo(1, 4.2)
        ..lineTo(9, 4.2)
        ..lineTo(7.8, 9)
        ..lineTo(2.2, 9)
        ..close();
      c.drawPath(bk, fill(k(const Color(0xFFB7834F))));
      for (var i = 0; i < 3; i++) {
        c.drawLine(Offset(1.4 + i * 0.4, 5.6 + i * 1.2), Offset(8.6 - i * 0.4, 5.6 + i * 1.2), stroke(k(const Color(0xFF7A5230)), 0.3));
      }
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(2.6 + i * 1.6, 3.6 - (i % 2) * 0.5), 1.0, fill(k(const Color(0xFF7A4E7E))));
      }
      c.drawArc(const Rect.fromLTWH(2.4, 0.8, 5.2, 6), math.pi, math.pi, false, stroke(k(const Color(0xFF7A5230)), 0.45));
    case 9:
      for (var i = 0; i < 4; i++) {
        c.drawOval(Rect.fromCenter(center: const Offset(5, 5.4), width: 7.4 - i * 1.6, height: 5.2 - i * 1.1), stroke(k(const Color(0xFFC9A36A)), 0.55));
      }
      c.drawLine(const Offset(8.4, 5.6), const Offset(9.6, 9.2), stroke(k(const Color(0xFFC9A36A)), 0.55));
    case 10:
      final kite = Path()
        ..moveTo(5, 0.4)
        ..lineTo(8.4, 4)
        ..lineTo(5, 7.4)
        ..lineTo(1.6, 4)
        ..close();
      c.drawPath(kite, fill(k(const Color(0xFFE07A5F))));
      c.drawLine(const Offset(5, 0.4), const Offset(5, 7.4), stroke(ink, 0.25));
      c.drawLine(const Offset(1.6, 4), const Offset(8.4, 4), stroke(ink, 0.25));
      final tail = Path()
        ..moveTo(5, 7.4)
        ..quadraticBezierTo(6.4, 8.4, 5.4, 9.0)
        ..quadraticBezierTo(4.4, 9.6, 6.0, 9.8);
      c.drawPath(tail, stroke(ink, 0.25));
    default:
      final pot = Path()
        ..moveTo(1.4, 3.6)
        ..lineTo(8.6, 3.6)
        ..quadraticBezierTo(9.2, 8.8, 5, 9.0)
        ..quadraticBezierTo(0.8, 8.8, 1.4, 3.6)
        ..close();
      c.drawPath(pot, fill(k(const Color(0xFF5B4636))));
      c.drawRect(const Rect.fromLTWH(0.8, 3.0, 8.4, 0.9), fill(k(const Color(0xFF8C7A68))));
      c.drawArc(const Rect.fromLTWH(-0.4, 3.6, 2, 2.2), math.pi / 2, math.pi, false, stroke(ink, 0.4));
      c.drawArc(const Rect.fromLTWH(8.4, 3.6, 2, 2.2), -math.pi / 2, math.pi, false, stroke(ink, 0.4));
  }
  c.restore();
}

// =================================================================== Nasreddin Hoca

/// Fıkra simgesi: kavuklu Hoca ve fıkranın nesnesi; [r] kutusuna.
void paintHocaEmblem(Canvas c, int tale, Rect r) {
  c.save();
  c.translate(r.left, r.top);
  c.scale(r.width / 10, r.height / 10);
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 10, 10), const Radius.circular(1.2)), fill(const Color(0xFFF2E3C2)));
  // Hoca: kocaman sarık, ak sakal.
  c.drawCircle(const Offset(3.2, 4.4), 1.4, fill(const Color(0xFFE0B07A)));
  c.drawOval(const Rect.fromLTWH(1.3, 1.0, 3.8, 2.6), fill(const Color(0xFFFBF7EE)));
  c.drawOval(const Rect.fromLTWH(1.3, 1.0, 3.8, 2.6), stroke(const Color(0xFFB9AE9B), 0.2));
  c.drawCircle(const Offset(3.2, 1.2), 0.45, fill(const Color(0xFF4F7F52)));
  final beard = Path()
    ..moveTo(2.0, 4.8)
    ..quadraticBezierTo(3.2, 7.6, 4.4, 4.8)
    ..close();
  c.drawPath(beard, fill(const Color(0xFFFBF7EE)));
  c.drawCircle(const Offset(3.7, 4.1), 0.18, fill(const Color(0xFF2A1A10)));
  final robe = Path()
    ..moveTo(1.2, 9.6)
    ..quadraticBezierTo(3.2, 5.6, 5.2, 9.6)
    ..close();
  c.drawPath(robe, fill(const Color(0xFF3A8D8C)));
  // Nesne (sağ yarı).
  const obj = Rect.fromLTWH(5.2, 3.2, 4.4, 4.4);
  switch (tale) {
    case 0:
      paintProp(c, 11, obj);
    case 1: // kürk
      final coat = Path()
        ..moveTo(6, 3.4)
        ..lineTo(8.8, 3.4)
        ..lineTo(9.4, 8.6)
        ..lineTo(5.4, 8.6)
        ..close();
      c.drawPath(coat, fill(const Color(0xFF8A5A33)));
      c.drawLine(const Offset(7.4, 3.4), const Offset(7.4, 8.6), stroke(const Color(0xFFE6D2A8), 0.5));
    case 2: // göl ve kâse
      c.drawOval(const Rect.fromLTWH(5.2, 6.0, 4.6, 2.2), fill(const Color(0xFF3E6FB0)));
      c.drawArc(const Rect.fromLTWH(6.0, 3.2, 3.0, 3.0), 0, math.pi, true, fill(const Color(0xFFFBF7EE)));
    case 3:
    case 7: // eşek
      c.drawOval(const Rect.fromLTWH(5.6, 4.6, 3.8, 2.6), fill(const Color(0xFF8C8A84)));
      c.drawCircle(Offset(tale == 3 ? 5.8 : 9.2, 4.4), 0.9, fill(const Color(0xFF8C8A84)));
      c.drawLine(Offset(tale == 3 ? 5.6 : 9.4, 3.8), Offset(tale == 3 ? 5.2 : 9.8, 2.6), stroke(const Color(0xFF8C8A84), 0.35));
      for (final x in const [6.2, 8.8]) {
        c.drawLine(Offset(x, 7.0), Offset(x, 8.8), stroke(const Color(0xFF6B6963), 0.35));
      }
      if (tale == 7) c.drawCircle(const Offset(9.4, 2.0), 0.4, stroke(const Color(0xFFC8553D), 0.25));
    case 4: // dam
      final roof = Path()
        ..moveTo(5.2, 5.4)
        ..lineTo(7.4, 3.0)
        ..lineTo(9.6, 5.4)
        ..close();
      c.drawPath(roof, fill(const Color(0xFFB5523B)));
      c.drawRect(const Rect.fromLTWH(5.8, 5.4, 3.2, 3.2), fill(const Color(0xFFD9C3A0)));
    case 5: // terazi
      c.drawLine(const Offset(7.4, 3.0), const Offset(7.4, 8.6), stroke(const Color(0xFF5B4636), 0.35));
      c.drawLine(const Offset(5.4, 4.0), const Offset(9.4, 4.0), stroke(const Color(0xFF5B4636), 0.35));
      c.drawArc(const Rect.fromLTWH(5.0, 4.0, 1.6, 1.4), 0, math.pi, true, fill(const Color(0xFFD9A441)));
      c.drawArc(const Rect.fromLTWH(8.6, 4.0, 1.6, 1.4), 0, math.pi, true, fill(const Color(0xFFD9A441)));
    case 6:
      paintProp(c, 5, obj);
    case 8: // kuyu ve ay
      c.drawRect(const Rect.fromLTWH(5.6, 6.0, 3.8, 2.8), fill(const Color(0xFF8C7A68)));
      c.drawCircle(const Offset(8.4, 3.6), 1.0, fill(const Color(0xFFF5D06A)));
      c.drawCircle(const Offset(8.8, 3.4), 0.85, fill(const Color(0xFFF2E3C2)));
    case 9: // kürsü
      c.drawRect(const Rect.fromLTWH(6.0, 4.6, 3.0, 4.2), fill(const Color(0xFF9C6B3F)));
      c.drawRect(const Rect.fromLTWH(5.6, 4.0, 3.8, 0.8), fill(const Color(0xFF7A5230)));
    case 10: // yorgan
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5.4, 3.8, 4.2, 4.6), const Radius.circular(0.6)), fill(const Color(0xFFB23A48)));
      for (var i = 0; i < 3; i++) {
        c.drawLine(Offset(5.6, 4.9 + i * 1.3), Offset(9.4, 4.9 + i * 1.3), stroke(const Color(0xFFF2E3C2), 0.2));
      }
    default: // kedi
      c.drawOval(const Rect.fromLTWH(5.8, 5.2, 3.4, 3.0), fill(const Color(0xFF5B4636)));
      c.drawCircle(const Offset(8.6, 4.6), 1.0, fill(const Color(0xFF5B4636)));
      final ears = Path()
        ..moveTo(7.9, 4.0)
        ..lineTo(8.1, 3.0)
        ..lineTo(8.6, 3.8)
        ..lineTo(9.1, 3.0)
        ..lineTo(9.3, 4.0)
        ..close();
      c.drawPath(ears, fill(const Color(0xFF5B4636)));
      c.drawLine(const Offset(6.0, 7.6), const Offset(5.0, 5.8), stroke(const Color(0xFF5B4636), 0.35));
  }
  c.restore();
}
