import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

enum TravelTheme {
  planTrip,
  findRides,
  offerRide,
  myTrips,
  profile,
  myMatches,
  notifications,
  rideMatching,
  adminDashboard,
  defaultTheme,
}

enum _PatternType { diagonal, curved, waves, grid, dots, vertical }

class _ThemePalette {
  final List<Color> colors;
  final Color accent;
  final Alignment begin;
  final Alignment end;
  final _PatternType pattern;

  const _ThemePalette({
    required this.colors,
    required this.accent,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.pattern = _PatternType.diagonal,
  });
}

class TravelThemeBackground extends StatelessWidget {
  final Widget child;
  final TravelTheme theme;

  const TravelThemeBackground({
    super.key,
    required this.child,
    this.theme = TravelTheme.defaultTheme,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (themeProvider.isDarkMode) {
      return _buildDarkBackground(context);
    }

    return _buildLightBackground(context);
  }

  Widget _buildLightBackground(BuildContext context) {
    final palette = _paletteForTheme(theme);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: palette.begin,
          end: palette.end,
          colors: palette.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: _BlurBlob(
              diameter: 220,
              color: palette.accent.withOpacity(0.28),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: _BlurBlob(
              diameter: 260,
              color: palette.accent.withOpacity(0.18),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ProfessionalPatternPainter(
                  palette.accent.withOpacity(0.08),
                  palette.pattern,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDarkBackground(BuildContext context) {
    final palette = _paletteForTheme(theme);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF111827),
            palette.accent.withOpacity(0.25),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _BlurBlob(
              diameter: 200,
              color: palette.accent.withOpacity(0.32),
            ),
          ),
          child,
        ],
      ),
    );
  }

  _ThemePalette _paletteForTheme(TravelTheme theme) {
    switch (theme) {
      case TravelTheme.planTrip:
        return const _ThemePalette(
          colors: [
            Color(0xFFFDECE2),
            Color(0xFFFBD7C3),
            Color(0xFFF7BE9E),
          ],
          accent: Color(0xFFE87B58),
          pattern: _PatternType.diagonal,
        );
      case TravelTheme.findRides:
        return const _ThemePalette(
          colors: [
            Color(0xFFE3F2FF),
            Color(0xFFCFE4FF),
            Color(0xFFB7D6FF),
          ],
          accent: Color(0xFF5B8DEF),
          pattern: _PatternType.vertical,
        );
      case TravelTheme.offerRide:
        return const _ThemePalette(
          colors: [
            Color(0xFFE7FBF6),
            Color(0xFFCFF5ED),
            Color(0xFFB8EEE3),
          ],
          accent: Color(0xFF30C4A8),
          pattern: _PatternType.curved,
        );
      case TravelTheme.myTrips:
        return const _ThemePalette(
          colors: [
            Color(0xFFFFF2F5),
            Color(0xFFFEE4ED),
            Color(0xFFFDD6E3),
          ],
          accent: Color(0xFFEB7395),
          pattern: _PatternType.dots,
        );
      case TravelTheme.profile:
        return const _ThemePalette(
          colors: [
            Color(0xFFE6F3FF),
            Color(0xFFD3EBFF),
            Color(0xFFBEE2FF),
          ],
          accent: Color(0xFF4AA1FF),
          pattern: _PatternType.grid,
        );
      case TravelTheme.myMatches:
        return const _ThemePalette(
          colors: [
            Color(0xFFFFF4F3),
            Color(0xFFFFE5E2),
            Color(0xFFFFD6D1),
          ],
          accent: Color(0xFFF08573),
          pattern: _PatternType.curved,
        );
      case TravelTheme.notifications:
        return const _ThemePalette(
          colors: [
            Color(0xFFFFF8EC),
            Color(0xFFFFF0D1),
            Color(0xFFFFE5B0),
          ],
          accent: Color(0xFFF2B34C),
          pattern: _PatternType.grid,
        );
      case TravelTheme.rideMatching:
        return const _ThemePalette(
          colors: [
            Color(0xFFE7FBFF),
            Color(0xFFD0F2FF),
            Color(0xFFB8E8FF),
          ],
          accent: Color(0xFF33BDE0),
          pattern: _PatternType.waves,
        );
      case TravelTheme.adminDashboard:
        return const _ThemePalette(
          colors: [
            Color(0xFFF5F7FA),
            Color(0xFFE8ECF1),
            Color(0xFFDCE2E8),
          ],
          accent: Color(0xFF475569),
          pattern: _PatternType.grid,
        );
      default:
        return const _ThemePalette(
          colors: [
            Color(0xFFF1F4FF),
            Color(0xFFE2E9FF),
            Color(0xFFD2DCFF),
          ],
          accent: Color(0xFF7388F5),
        );
    }
  }
}

class _BlurBlob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _BlurBlob({
    required this.diameter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalPatternPainter extends CustomPainter {
  final Color color;
  final _PatternType type;

  _ProfessionalPatternPainter(this.color, this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    switch (type) {
      case _PatternType.vertical:
        for (double x = 0; x < size.width; x += 80) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case _PatternType.grid:
        for (double x = 0; x < size.width; x += 70) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += 70) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case _PatternType.dots:
        paint.style = PaintingStyle.fill;
        for (double x = 20; x < size.width; x += 60) {
          for (double y = 20; y < size.height; y += 60) {
            canvas.drawCircle(Offset(x, y), 2, paint);
          }
        }
        break;
      case _PatternType.curved:
        for (double y = 0; y < size.height; y += 80) {
          final path = Path();
          path.moveTo(0, y);
          for (double x = 0; x < size.width; x += 80) {
            path.quadraticBezierTo(x + 40, y + 20, x + 80, y);
          }
          canvas.drawPath(path, paint);
        }
        break;
      case _PatternType.waves:
        for (double y = 0; y < size.height; y += 60) {
          final path = Path();
          path.moveTo(0, y);
          for (double x = 0; x < size.width; x += 60) {
            path.cubicTo(
              x + 20,
              y - 8,
              x + 40,
              y + 8,
              x + 60,
              y,
            );
          }
          canvas.drawPath(path, paint);
        }
        break;
      case _PatternType.diagonal:
      default:
        for (double i = -size.height; i < size.width; i += 70) {
          canvas.drawLine(
            Offset(i, 0),
            Offset(i + size.height, size.height),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

