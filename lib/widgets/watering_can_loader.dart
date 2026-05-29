import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading indicator shown while the app boots: a watering can that
/// repeatedly fills up with water. The water level rises from empty to full
/// on a loop, with a gentle wave on its surface.
class WateringCanLoader extends StatefulWidget {
  /// Overall size of the (square) animation.
  final double size;

  /// Optional caption rendered beneath the can.
  final String? label;

  const WateringCanLoader({super.key, this.size = 120, this.label});

  @override
  State<WateringCanLoader> createState() => _WateringCanLoaderState();
}

class _WateringCanLoaderState extends State<WateringCanLoader>
    with TickerProviderStateMixin {
  // Drives the water level rising from empty to full and back to empty.
  late final AnimationController _fill;
  // Free-running clock for the surface ripple, independent of the fill cycle.
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  // A natural, leafy green for the can (and a darker green for its outline),
  // with a fresh blue for the water.
  static const Color _canColor = Color(0xFFE8F5E9);
  static const Color _canOutline = Color(0xFF1B5E20);
  static const Color _waterColor = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_fill, _wave]),
            builder: (context, _) {
              // Ease the fill so it lingers a touch at empty and full.
              final level = Curves.easeInOut.transform(_fill.value);
              return CustomPaint(
                painter: _WateringCanPainter(
                  level: level,
                  wavePhase: _wave.value * 2 * math.pi,
                  canColor: _canColor,
                  canOutline: _canOutline,
                  waterColor: _waterColor,
                ),
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }
}

class _WateringCanPainter extends CustomPainter {
  /// Water level, 0 (empty) to 1 (full).
  final double level;

  /// Phase of the surface ripple, in radians.
  final double wavePhase;

  /// Fill colour of the can body.
  final Color canColor;

  /// Colour of the can's outline and details.
  final Color canOutline;
  final Color waterColor;

  _WateringCanPainter({
    required this.level,
    required this.wavePhase,
    required this.canColor,
    required this.canOutline,
    required this.waterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Work in a 100x100 design space, then scale to the real size.
    final s = size.width / 100.0;
    canvas.scale(s);

    // The can body: a slightly tapered tub, wider at the top.
    final body = Path()
      ..moveTo(34, 44)
      ..lineTo(78, 44)
      ..lineTo(72, 90)
      ..quadraticBezierTo(71, 94, 66, 94)
      ..lineTo(46, 94)
      ..quadraticBezierTo(41, 94, 40, 90)
      ..close();

    // Solid can body behind the water so it reads as a real vessel.
    canvas.drawPath(body, Paint()..color = canColor);

    // Water clipped to the inside of the body, rising with [level].
    canvas.save();
    canvas.clipPath(body);
    final topY = 44.0; // inner top of the can
    final bottomY = 92.0; // inner bottom of the can
    final surfaceY = bottomY - (bottomY - topY) * level;
    final water = Path()..moveTo(30, 96);
    water.lineTo(30, surfaceY);
    // Two ripples across the surface.
    const segments = 24;
    const amplitude = 1.6;
    for (var i = 0; i <= segments; i++) {
      final x = 30 + (50 * i / segments);
      final y = surfaceY +
          math.sin(wavePhase + (i / segments) * 2 * math.pi * 2) * amplitude;
      water.lineTo(x, y);
    }
    water
      ..lineTo(80, 96)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..color = waterColor
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    final stroke = Paint()
      ..color = canOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Top rim of the can.
    canvas.drawLine(const Offset(31, 44), const Offset(81, 44), stroke);

    // The body outline.
    canvas.drawPath(body, stroke);

    // Handle: an arc curving over the top of the can.
    final handle = Path()
      ..moveTo(44, 44)
      ..quadraticBezierTo(56, 22, 74, 44);
    canvas.drawPath(handle, stroke);

    // Spout: a tube rising up to the left, ending in a sprinkler rose.
    final spout = Path()
      ..moveTo(34, 56)
      ..lineTo(12, 40)
      ..lineTo(8, 30);
    canvas.drawPath(spout, stroke);
    // The rose (sprinkler head), a short angled cap on the spout's end.
    canvas.drawLine(const Offset(2, 33), const Offset(14, 25), stroke);
  }

  @override
  bool shouldRepaint(_WateringCanPainter old) =>
      old.level != level ||
      old.wavePhase != wavePhase ||
      old.canColor != canColor ||
      old.canOutline != canOutline ||
      old.waterColor != waterColor;
}
