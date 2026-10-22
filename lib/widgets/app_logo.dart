import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Authentic brand logo for SplitIt using vector canvas paths
/// styled with the official AppTheme teal palette.
class SplitItLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final bool useWhiteEmblem;
  final BorderRadius? borderRadius;

  const SplitItLogo({
    super.key,
    this.size = 48,
    this.showBackground = true,
    this.useWhiteEmblem = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.28);

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _SplitItLogoPainter(
            primaryColor: useWhiteEmblem ? Colors.white : AppTheme.teal,
            secondaryColor: useWhiteEmblem ? Colors.white70 : AppTheme.tealDark,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.teal,
            AppTheme.tealDark,
          ],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.teal.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.2),
      child: CustomPaint(
        painter: const _SplitItLogoPainter(
          primaryColor: Colors.white,
          secondaryColor: Color(0xFFD4FAF1),
        ),
      ),
    );
  }
}

/// Logo with typographic brand name
class SplitItBrandHeader extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final bool isVertical;

  const SplitItBrandHeader({
    super.key,
    this.logoSize = 56,
    this.fontSize = 32,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SplitItLogo(size: logoSize),
          SizedBox(height: logoSize * 0.28),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Split',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoal,
                    letterSpacing: -0.8,
                  ),
                ),
                TextSpan(
                  text: 'It',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.teal,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SplitItLogo(size: logoSize),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Split',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.charcoal,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'It',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitItLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const _SplitItLogoPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint1 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final strokePaint2 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint1 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final fillPaint2 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // --- Upper 'S' Arc flowing Right-Up with Arrow Head ---
    final topPath = Path()
      ..moveTo(22, 60)
      ..cubicTo(20, 38, 38, 22, 60, 22)
      ..cubicTo(74, 22, 82, 30, 84, 42);
    canvas.drawPath(topPath, strokePaint1);

    // Top arrow tip (pointing up-right)
    final topArrow = Path()
      ..moveTo(84, 32)
      ..lineTo(94, 44)
      ..lineTo(78, 50)
      ..close();
    canvas.drawPath(topArrow, fillPaint1);

    // --- Lower 'S' Arc flowing Left-Down with Arrow Head ---
    final bottomPath = Path()
      ..moveTo(78, 40)
      ..cubicTo(80, 62, 62, 78, 40, 78)
      ..cubicTo(26, 78, 18, 70, 16, 58);
    canvas.drawPath(bottomPath, strokePaint2);

    // Bottom arrow tip (pointing down-left)
    final bottomArrow = Path()
      ..moveTo(16, 68)
      ..lineTo(6, 56)
      ..lineTo(22, 50)
      ..close();
    canvas.drawPath(bottomArrow, fillPaint2);

    // --- Center Split Division Node (subtle connecting pulse) ---
    final centerPulse = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(50, 50), 4.5, centerPulse);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplitItLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
