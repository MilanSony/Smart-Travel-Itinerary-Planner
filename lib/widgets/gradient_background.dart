import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final lightGradient = const LinearGradient(
      colors: [Color(0xFFCDBEFF), Color(0xFFBEE0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final darkGradient = const LinearGradient(
      colors: [Color(0xFF23154E), Color(0xFF1F123D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: themeProvider.isDarkMode ? darkGradient : lightGradient,
      ),
      child: child,
    );
  }
}