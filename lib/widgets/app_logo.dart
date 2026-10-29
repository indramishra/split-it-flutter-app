import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Authentic signature brand logo for SplitIt.
///
/// Designed around the app's motto: "Split bills and share expenses with friends & groups."
/// Features an itemized restaurant/expense bill cleanly divided into two balanced shares
/// that slide apart along a precision diagonal cut, forming an abstract 'S' monogram.
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

  /// Paint the SplitIt emblem vector directly onto any custom canvas
  static void paintEmblem(
    Canvas canvas,
    Size size, {
    Color billColor = Colors.white,
    Color lineColor = const Color(0x59148E74),
    Color dotColor = const Color(0xFF1CC29F),
  }) {
    final painter = _SplitItLogoPainter(
      billColor: billColor,
      lineColor: lineColor,
      dotColor: dotColor,
    );
    painter.paint(canvas, size);
  }

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
            billColor: useWhiteEmblem ? Colors.white : AppTheme.teal,
            lineColor: useWhiteEmblem
                ? const Color(0x80FFFFFF)
                : Colors.white.withValues(alpha: 0.75),
            dotColor: useWhiteEmblem ? Colors.white : AppTheme.tealDark,
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
      padding: EdgeInsets.all(size * 0.16),
      child: const CustomPaint(
        painter: _SplitItLogoPainter(
          billColor: Colors.white,
          lineColor: Color(0x59148E74),
          dotColor: Color(0xFF1CC29F),
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

/// Precision vector painter for the SplitIt brand mark: "The Precision Split Bill".
class _SplitItLogoPainter extends CustomPainter {
  final Color billColor;
  final Color lineColor;
  final Color dotColor;

  const _SplitItLogoPainter({
    required this.billColor,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate space normalized to 200x200 centered at (0, 0)
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);

    // Dynamic 15-degree posture
    canvas.rotate(-15 * math.pi / 180);

    final billPaint = Paint()
      ..color = billColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Displacement along the precision diagonal slice
    const double shiftX = 5.5;
    const double shiftY = 6.5;

    // --- TOP-RIGHT RECEIPT HALF (Person A / Group Share 1) ---
    canvas.save();
    canvas.translate(shiftX, -shiftY);

    final topHalf = Path()
      ..moveTo(-44, 12)
      ..lineTo(-44, -46)
      ..cubicTo(-44, -58, -34, -58, -26, -58)
      // Serrated tear notches
      ..lineTo(-18, -58)
      ..lineTo(-14, -53)
      ..lineTo(-10, -58)
      ..lineTo(-2, -58)
      ..lineTo(2, -53)
      ..lineTo(6, -58)
      ..lineTo(14, -58)
      ..lineTo(18, -53)
      ..lineTo(22, -58)
      ..lineTo(34, -58)
      ..cubicTo(44, -58, 44, -48, 44, -46)
      ..lineTo(44, -24)
      ..lineTo(-44, 12)
      ..close();

    canvas.drawPath(topHalf, billPaint);

    // Itemized receipt lines & share token
    canvas.drawLine(const Offset(-28, -42), const Offset(14, -42), linePaint);
    canvas.drawLine(const Offset(-28, -30), const Offset(-2, -30), linePaint);
    canvas.drawCircle(const Offset(22, -30), 4.8, dotPaint);

    canvas.restore();

    // --- BOTTOM-LEFT RECEIPT HALF (Person B / Group Share 2) ---
    // 180-degree rotational symmetry
    canvas.save();
    canvas.translate(-shiftX, shiftY);

    final bottomHalf = Path()
      ..moveTo(44, -12)
      ..lineTo(44, 46)
      ..cubicTo(44, 58, 34, 58, 26, 58)
      // Serrated tear notches
      ..lineTo(18, 58)
      ..lineTo(14, 53)
      ..lineTo(10, 58)
      ..lineTo(2, 58)
      ..lineTo(-2, 53)
      ..lineTo(-6, 58)
      ..lineTo(-14, 58)
      ..lineTo(-18, 53)
      ..lineTo(-22, 58)
      ..lineTo(-34, 58)
      ..cubicTo(-44, 58, -44, 48, -44, 46)
      ..lineTo(-44, 24)
      ..lineTo(44, -12)
      ..close();

    canvas.drawPath(bottomHalf, billPaint);

    // Itemized receipt lines & share token
    canvas.drawLine(const Offset(-14, 42), const Offset(28, 42), linePaint);
    canvas.drawLine(const Offset(2, 30), const Offset(28, 30), linePaint);
    canvas.drawCircle(const Offset(-22, 30), 4.8, dotPaint);

    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplitItLogoPainter oldDelegate) {
    return oldDelegate.billColor != billColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.dotColor != dotColor;
  }
}
