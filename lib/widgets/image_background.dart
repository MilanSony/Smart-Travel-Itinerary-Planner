import 'package:flutter/material.dart';

class ImageBackground extends StatelessWidget {
  final String imagePath;
  final Widget child;
  final double overlayOpacity;

  const ImageBackground({
    super.key,
    required this.imagePath,
    required this.child,
    this.overlayOpacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Professional fallback gradients based on image path
              LinearGradient fallbackGradient;
              
              if (imagePath.contains('plan_trip') || imagePath.contains('destination')) {
                // Warm, inviting gradient for trip planning
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667EEA), // Soft purple-blue
                    Color(0xFF764BA2), // Deep purple
                    Color(0xFFF093FB),  // Soft pink
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('find_rides') || imagePath.contains('rides')) {
                // Dynamic, energetic gradient for ride sharing
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A90E2), // Sky blue
                    Color(0xFF357ABD), // Ocean blue
                    Color(0xFF26A69A), // Teal
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('offer_ride')) {
                // Friendly, approachable gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF11998E), // Teal green
                    Color(0xFF38EF7D), // Fresh green
                    Color(0xFF4A90E2), // Light blue
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('my_trips') || imagePath.contains('trips')) {
                // Nostalgic, warm gradient for memories
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B6B), // Coral
                    Color(0xFFFFA07A), // Light salmon
                    Color(0xFFFFD93D), // Golden yellow
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('profile')) {
                // Professional, sophisticated gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6C5CE7), // Royal purple
                    Color(0xFFA29BFE), // Lavender
                    Color(0xFF74B9FF), // Sky blue
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('my_matches') || imagePath.contains('matches')) {
                // Connection, friendship gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE17055), // Warm coral
                    Color(0xFFFF7675), // Soft red
                    Color(0xFFFD79A8), // Pink
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('ride_matching') || imagePath.contains('matching')) {
                // Dynamic, connection gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00B894), // Mint green
                    Color(0xFF00CEC9), // Turquoise
                    Color(0xFF55EFC4), // Light mint
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else if (imagePath.contains('notifications')) {
                // Alert, attention gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFDCB6E), // Golden yellow
                    Color(0xFFE17055), // Coral
                    Color(0xFFFF7675), // Soft red
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              } else {
                // Default professional gradient
                fallbackGradient = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A5F), // Navy
                    Color(0xFF2C4F7C), // Light navy
                    Color(0xFF4A90E2), // Blue
                  ],
                  stops: [0.0, 0.5, 1.0],
                );
              }
              
              return Container(
                decoration: BoxDecoration(
                  gradient: fallbackGradient,
                ),
              );
            },
          ),
        ),
        // Dark overlay for readability
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(overlayOpacity),
          ),
        ),
        child,
      ],
    );
  }
}


