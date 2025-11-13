import 'package:flutter/material.dart';

class TravelBackground extends StatelessWidget {
  final Widget child;
  final bool showGradient;
  
  const TravelBackground({
    super.key,
    required this.child,
    this.showGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Travel-themed gradient background
        gradient: showGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E3A5F), // Navy blue
                  const Color(0xFF2C4F7C), // Lighter navy
                  const Color(0xFF4A90E2).withOpacity(0.3), // Sky blue
                  const Color(0xFF87CEEB).withOpacity(0.2), // Light sky blue
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              )
            : null,
        color: showGradient ? null : const Color(0xFFF5F7FA),
      ),
      child: Stack(
        children: [
          // Decorative travel elements
          if (showGradient) ...[
            // Airplane silhouette effect
            Positioned(
              top: -50,
              right: -50,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  size: 300,
                  color: Colors.white,
                ),
              ),
            ),
            // Compass/globe effect
            Positioned(
              bottom: -100,
              left: -100,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.explore_rounded,
                  size: 400,
                  color: Colors.white,
                ),
              ),
            ),
            // Location pin effect
            Positioned(
              top: 150,
              left: 50,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.location_on_rounded,
                  size: 200,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          // Content
          child,
        ],
      ),
    );
  }
}


