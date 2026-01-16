import 'package:flutter/material.dart';
import 'dart:math' as math;

class StarField extends StatefulWidget {
  final double opacity;
  final double offset;

  const StarField({super.key, this.opacity = 0.3, this.offset = 0.0});

  @override
  StarFieldState createState() => StarFieldState();
}

class StarFieldState extends State<StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> _stars = [];
  final List<Color> _starColors = [];
  final int _starCount = 50;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    for (int i = 0; i < _starCount; i++) {
      _stars.add(
        Offset(
          math.Random().nextDouble() * 1000 - 500,
          math.Random().nextDouble() * 1000 - 500,
        ),
      );
      final random = math.Random().nextInt(3);
      _starColors.add(
        random == 0
            ? Colors.white
            : random == 1
            ? const Color(0xFF00FFFF).withOpacity(0.5)
            : const Color(0xFFFFFF00).withOpacity(0.5),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the CustomPaint has proper constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _StarPainter(
            stars: _stars,
            colors: _starColors,
            animationValue: _controller.value,
            opacity: widget.opacity,
            offset: widget.offset,
          ),
        );
      },
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<Offset> stars;
  final List<Color> colors;
  final double animationValue;
  final double opacity;
  final double offset;

  _StarPainter({
    required this.stars,
    required this.colors,
    required this.animationValue,
    required this.opacity,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Skip painting if size is invalid
    if (size.width <= 0 || size.height <= 0) return;

    for (int i = 0; i < stars.length; i++) {
      final paint = Paint()..color = colors[i].withOpacity(opacity);
      final scale = 1.0 + math.sin(animationValue * 2 * math.pi) * 0.3;
      final radius = 1.5 * scale;

      // Ensure radius is positive and valid
      if (radius <= 0 || radius.isNaN) continue;

      // Normalize positions to stay within canvas bounds
      double xPos = stars[i].dx % size.width;
      double yPos = (stars[i].dy + offset) % size.height;

      // Handle negative modulo results
      if (xPos < 0) xPos += size.width;
      if (yPos < 0) yPos += size.height;

      canvas.drawCircle(Offset(xPos, yPos), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    // Repaint only if animation value, opacity, or offset changes
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.opacity != opacity ||
        oldDelegate.offset != offset;
  }
}
