import 'package:flutter/material.dart';
import 'dart:math' as math;

class StarField extends StatefulWidget {
  final double opacity;
  final double offset;

  const StarField({super.key, this.opacity = 0.35, this.offset = 0.0});

  @override
  StarFieldState createState() => StarFieldState();
}

class StarFieldState extends State<StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> _stars = [];
  final List<Color> _starColors = [];
  final List<double> _twinklePhases = [];
  final int _starCount = 90; // a bit more dense feels nicer

  // Shooting stars
  final List<ShootingStar> _shooters = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 24), // slightly longer cycle
      vsync: this,
    )..repeat();

    // Background stars
    for (int i = 0; i < _starCount; i++) {
      _stars.add(
        Offset(
          _random.nextDouble() * 1400 - 700,
          _random.nextDouble() * 1400 - 700,
        ),
      );

      // Slightly richer color variation
      final hueRoll = _random.nextInt(6);
      Color col;
      switch (hueRoll) {
        case 0:
          col = Colors.white;
          break;
        case 1:
          col = const Color(0xFFDDEEFF); // soft blue
          break;
        case 2:
          col = const Color(0xFFFFF0D0); // warm cream
          break;
        case 3:
          col = const Color(0xFFCCFFEE).withOpacity(0.75); // pale cyan
          break;
        case 4:
          col = const Color(0xFFFFDD99).withOpacity(0.65); // soft gold
          break;
        default:
          col = const Color(0xFFEEEEFF).withOpacity(0.8); // very pale violet
      }
      _starColors.add(col);
      _twinklePhases.add(_random.nextDouble() * math.pi * 4); // more variety
    }

    // Shooting stars spawn via listener
    _controller.addListener(() {
      if (_shooters.length < 2 && _random.nextDouble() < 0.007) {
        _spawnShootingStar();
      }
    });
  }

  void _spawnShootingStar() {
    // Start above screen, can drift left/right a bit
    final startX = _random.nextDouble() * 800 - 200;
    final startY = -80.0 - _random.nextDouble() * 200;

    // Speed & angle — mostly ~30–60° downward (realistic meteor feel)
    final speed = 6.0 + _random.nextDouble() * 14.0;
    final angle =
        math.pi / 4 + (_random.nextDouble() - 0.5) * 0.9; // wider variation

    final vx = math.cos(angle) * speed;
    final vy = math.sin(angle) * speed;

    final trailLength = 90.0 + _random.nextDouble() * 180.0;
    final lifetime = 0.7 + _random.nextDouble() * 1.4;

    _shooters.add(
      ShootingStar(
        position: Offset(startX, startY),
        velocity: Offset(vx, vy),
        maxLife: lifetime,
        currentLife: 0.0,
        trailLength: trailLength,
        hue: _random.nextBool() ? 0.04 : 0.55 + _random.nextDouble() * 0.12,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _StarPainter(
            stars: _stars,
            colors: _starColors,
            twinklePhases: _twinklePhases,
            shooters: _shooters,
            animationValue: _controller.value,
            opacity: widget.opacity,
            offset: widget.offset,
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class ShootingStar {
  Offset position;
  final Offset velocity;
  final double maxLife;
  double currentLife;
  final double trailLength;
  final double hue;

  ShootingStar({
    required this.position,
    required this.velocity,
    required this.maxLife,
    required this.currentLife,
    required this.trailLength,
    required this.hue,
  });
}

class _StarPainter extends CustomPainter {
  final List<Offset> stars;
  final List<Color> colors;
  final List<double> twinklePhases;
  final List<ShootingStar> shooters;
  final double animationValue;
  final double opacity;
  final double offset;
  final Size size;

  _StarPainter({
    required this.stars,
    required this.colors,
    required this.twinklePhases,
    required this.shooters,
    required this.animationValue,
    required this.opacity,
    required this.offset,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = animationValue;

    // ────────────────────────────────────────────────
    // Twinkling background stars (with gentle parallax feel via offset)
    // ────────────────────────────────────────────────
    for (int i = 0; i < stars.length; i++) {
      double x = stars[i].dx + size.width * 0.5;
      double y = stars[i].dy + offset + size.height * 0.5;

      // Seamless toroidal wrap
      x = x % size.width;
      y = y % size.height;
      if (x < 0) x += size.width;
      if (y < 0) y += size.height;

      // Twinkle: slower base + fast shimmer
      final phase = twinklePhases[i];
      final slowTwinkle = math.sin(t * 1.8 + phase) * 0.4 + 0.6;
      final fastTwinkle = math.sin(t * 9.2 + phase * 2.3) * 0.15 + 0.85;
      final brightness = slowTwinkle * fastTwinkle;

      final baseOpacity = opacity * 0.4 + opacity * 0.6 * brightness;
      final radius = 0.7 + brightness * 1.8;

      final paint = Paint()
        ..color = colors[i].withOpacity(baseOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // ────────────────────────────────────────────────
    // Shooting stars — no wrapping, natural exit
    // ────────────────────────────────────────────────
    final toRemove = <ShootingStar>[];

    for (final shooter in shooters) {
      shooter.currentLife += 0.016; // ~60 fps assumption
      if (shooter.currentLife >= shooter.maxLife) {
        toRemove.add(shooter);
        continue;
      }

      // Move
      shooter.position += shooter.velocity * 0.016 * 60;

      final progress = shooter.currentLife / shooter.maxLife;
      // Nice smooth fade: quadratic then cubic tail-off
      final fade = 1.0 - progress;
      final alpha = fade * fade * (1.0 + fade); // starts strong, ends soft

      if (alpha < 0.015) continue;

      final head = shooter.position;

      // Early out if completely off-screen
      if (head.dx < -80 ||
          head.dx > size.width + 80 ||
          head.dy < -80 ||
          head.dy > size.height + 80) {
        continue;
      }

      final dirNorm = shooter.velocity / shooter.velocity.distance;
      final tail = head + dirNorm * (-shooter.trailLength * (0.6 + fade * 0.4));

      // Trail
      final trailPaint = Paint()
        ..color = Colors.white.withOpacity(alpha * 0.8)
        ..strokeWidth = 1.8 + alpha * 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      // Head glow
      final headColor = HSVColor.fromAHSV(
        alpha * 0.95,
        shooter.hue * 360,
        0.88,
        1.0,
      ).toColor();
      final headPaint = Paint()
        ..color = headColor
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      canvas.drawLine(head, tail, trailPaint);
      canvas.drawCircle(head, 2.8 + alpha * 4.5, headPaint);
    }

    for (final r in toRemove) {
      shooters.remove(r);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.opacity != opacity ||
        oldDelegate.offset != offset ||
        oldDelegate.shooters != shooters; // reference equality is fine here
  }
}
