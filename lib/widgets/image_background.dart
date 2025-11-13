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
              // Fallback to a subtle gradient if image is missing
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A5F), Color(0xFF2C4F7C)],
                  ),
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


