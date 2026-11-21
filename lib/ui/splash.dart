import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
        ..forward();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const Shell(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ));
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Scaffold(
      backgroundColor: P.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_c, _spin]),
        builder: (context, _) {
          final t = Curves.easeOut.transform(_c.value);
          final fade = Curves.easeOut.transform(((_c.value - .15) / .4).clamp(0.0, 1.0));
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _LinesPainter(t)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: Transform.rotate(
                        angle: _spin.value * 2 * math.pi,
                        child: CustomPaint(painter: _CompassPainter()),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - fade)),
                        child: Column(
                          children: [
                            Text('HISTO',
                                style: display('en', 60)
                                    .copyWith(letterSpacing: 7, height: 1)),
                            const SizedBox(height: 8),
                            Text(tr(lang, 'tagline'),
                                style: lang == 'ar'
                                    ? display('ar', 20, color: P.muted, weight: FontWeight.w400)
                                    : display('en', 19, color: P.muted, weight: FontWeight.w500)
                                        .copyWith(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 105,
                right: 105,
                bottom: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _c.value,
                    minHeight: 3,
                    backgroundColor: P.line,
                    color: P.red,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 58,
                child: Center(
                  child: Text(tr(lang, 'loadingSources'),
                      style: body(lang, 12, color: P.muted)
                          .copyWith(letterSpacing: lang == 'ar' ? 0 : 1.6)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  final double t;
  _LinesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = P.tan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final w = size.width;
    final h = size.height;
    final ys = [.24, .31, .76, .83];
    for (var i = 0; i < ys.length; i++) {
      final y = h * ys[i];
      final p = Path()
        ..moveTo(-20, y)
        ..cubicTo(w * .2, y - 60, w * .35, y + 60, w * .62, y)
        ..cubicTo(w * .85, y - 50, w * .95, y - 60, w + 20, y - 20);
      for (final m in p.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * t), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => old.t != t;
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = P.paper);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = P.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final dashPaint = Paint()
      ..color = P.tan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r - 12),
        c + Offset(math.cos(a), math.sin(a)) * (r - 6),
        dashPaint,
      );
    }
    final ns = Path()
      ..moveTo(c.dx, c.dy - r + 10)
      ..lineTo(c.dx + 10, c.dy)
      ..lineTo(c.dx, c.dy + r - 10)
      ..lineTo(c.dx - 10, c.dy)
      ..close();
    canvas.drawPath(ns, Paint()..color = P.ink);
    final north = Path()
      ..moveTo(c.dx, c.dy - r + 10)
      ..lineTo(c.dx + 10, c.dy)
      ..lineTo(c.dx - 10, c.dy)
      ..close();
    canvas.drawPath(north, Paint()..color = P.red);
    final ew = Path()
      ..moveTo(c.dx - r + 10, c.dy)
      ..lineTo(c.dx, c.dy - 10)
      ..lineTo(c.dx + r - 10, c.dy)
      ..lineTo(c.dx, c.dy + 10)
      ..close();
    canvas.drawPath(ew, Paint()..color = P.tan);
    canvas.drawPath(ns, Paint()..color = P.ink);
    canvas.drawPath(north, Paint()..color = P.red);
    canvas.drawCircle(c, 7, Paint()..color = P.bg);
    canvas.drawCircle(
        c,
        7,
        Paint()
          ..color = P.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
