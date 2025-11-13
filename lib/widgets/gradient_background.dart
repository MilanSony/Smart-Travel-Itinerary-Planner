import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../config/theme.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Professional cool gradient for light mode
    final lightGradient = const LinearGradient(
      colors: [
        Color(0xFFEAF3FF), // sky tint
        Color(0xFFF1F5FF), // soft lavender
        Color(0xFFF8FBFF), // near white
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.55, 1.0],
    );

    // Dark gradient
    final darkGradient = const LinearGradient(
      colors: [
        Color(0xFF1A1A1A),
        Color(0xFF2C2C2C),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: themeProvider.isDarkMode ? darkGradient : lightGradient,
      ),
      child: Stack(
        children: [
          // Decorative blurred circle top-right
          if (!themeProvider.isDarkMode)
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.35),
                ),
              ),
            ),
          // Decorative gradient blob bottom-left
          if (!themeProvider.isDarkMode)
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4C74E0).withOpacity(0.18),
                      const Color(0xFF26A69A).withOpacity(0.15),
                    ],
                  ),
                ),
              ),
            ),
          // Subtle diagonal lines overlay
          if (!themeProvider.isDarkMode)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DiagonalStripesPainter(),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5;

    const double gap = 28;
    for (double i = -size.height; i < size.width; i += gap) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}