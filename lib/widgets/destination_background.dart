import 'package:flutter/material.dart';

class DestinationBackground extends StatelessWidget {
  final Widget child;
  final DestinationType type;
  
  const DestinationBackground({
    super.key,
    required this.child,
    this.type = DestinationType.beach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getGradientForType(type),
      ),
      child: Stack(
        children: [
          // Background decorative elements
          _buildBackgroundElements(type),
          // Overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }

  LinearGradient _getGradientForType(DestinationType type) {
    switch (type) {
      case DestinationType.beach:
        // Beach sunset gradient (Goa/Maldives style)
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF87CEEB), // Sky blue
            Color(0xFF4682B4), // Steel blue
            Color(0xFFFFB347), // Peach
            Color(0xFFFF6B6B), // Coral
            Color(0xFF4A90E2), // Ocean blue
          ],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
        );
      case DestinationType.mountain:
        // Mountain landscape gradient (Himalayas style)
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF87CEEB), // Sky
            Color(0xFFB0C4DE), // Light steel blue
            Color(0xFF708090), // Slate gray
            Color(0xFF2F4F4F), // Dark slate gray
            Color(0xFF1C1C1C), // Dark
          ],
          stops: [0.0, 0.2, 0.4, 0.7, 1.0],
        );
      case DestinationType.city:
        // City skyline gradient (Mumbai/Dubai style)
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F), // Navy
            Color(0xFF2C4F7C), // Dark blue
            Color(0xFF4A90E2), // Blue
            Color(0xFFFF6B35), // Orange
            Color(0xFF2C2C2C), // Dark gray
          ],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
        );
    }
  }

  Widget _buildBackgroundElements(DestinationType type) {
    switch (type) {
      case DestinationType.beach:
        return Stack(
          children: [
            // Sun
            Positioned(
              top: 100,
              right: 80,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.orange.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Waves
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: _WavesPainter(),
              ),
            ),
            // Palm tree silhouette
            Positioned(
              bottom: 50,
              left: 50,
              child: Opacity(
                opacity: 0.2,
                child: Icon(
                  Icons.park_rounded,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      case DestinationType.mountain:
        return Stack(
          children: [
            // Mountains silhouette
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _MountainsPainter(),
              ),
            ),
            // Clouds
            Positioned(
              top: 80,
              left: 100,
              child: Opacity(
                opacity: 0.3,
                child: Icon(
                  Icons.cloud_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: 80,
              child: Opacity(
                opacity: 0.25,
                child: Icon(
                  Icons.cloud_rounded,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      case DestinationType.city:
        return Stack(
          children: [
            // City skyline
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 180),
                painter: _CitySkylinePainter(),
              ),
            ),
            // Stars
            ...List.generate(15, (index) {
              return Positioned(
                top: 50.0 + (index * 30.0),
                left: (index * 50.0) % 400,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              );
            }),
          ],
        );
    }
  }
}

enum DestinationType {
  beach,
  mountain,
  city,
}

// Waves painter for beach background
class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.6, size.height * 0.8);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 1.0, size.width, size.height * 0.8);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Mountains painter for mountain background
class _MountainsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.2, size.height * 0.6);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// City skyline painter for city background
class _CitySkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw building silhouettes
    final buildings = [
      [0.0, 0.8, 0.15, 1.0],
      [0.15, 0.6, 0.3, 1.0],
      [0.3, 0.9, 0.45, 1.0],
      [0.45, 0.5, 0.6, 1.0],
      [0.6, 0.7, 0.75, 1.0],
      [0.75, 0.4, 0.9, 1.0],
      [0.9, 0.85, 1.0, 1.0],
    ];

    for (var building in buildings) {
      final rect = Rect.fromLTRB(
        size.width * building[0],
        size.height * building[1],
        size.width * building[2],
        size.height * building[3],
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


