import 'package:flutter/material.dart';

/// Professional light theme configuration for Group Trip module
class GroupTripTheme {
  // Primary Colors - Vibrant Orange/Coral Palette
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color primaryOrangeDark = Color(0xFFFF5722);
  static const Color primaryOrangeLight = Color(0xFFFFAB91);
  static const Color accentCoral = Color(0xFFFF6E40);

  // Secondary Colors - Complementary Peach/Amber
  static const Color secondaryPeach = Color(0xFFFFB347);
  static const Color secondaryPeachLight = Color(0xFFFFCC80);
  static const Color accentAmber = Color(0xFFFFA726);

  // Additional Vibrant Accent Colors
  static const Color accentTeal = Color(0xFF26A69A);
  static const Color accentPurple = Color(0xFFAB47BC);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color accentPink = Color(0xFFEC407A);

  // Success & Action Colors
  static const Color successGreen = Color(0xFF66BB6A);
  static const Color successGreenLight = Color(0xFF81C784);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFEF5350);
  static const Color infoBlue = Color(0xFF29B6F6);

  // Role Colors - More Vibrant
  static const Color ownerColor = Color(0xFFFF6F00); // Deep Orange
  static const Color editorColor = Color(0xFFFF7043); // Coral
  static const Color viewerColor = Color(0xFFFFB74D); // Amber

  // Background Colors - Light & Warm with Gradient Options
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundPeach = Color(0xFFFFF3E0);
  static const Color backgroundLightPeach = Color(0xFFFFFBF5);
  static const Color backgroundCream = Color(0xFFFFFAF0);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundAccent = Color(0xFFFFF8F0);

  // Text Colors - Warm Hierarchy
  static const Color textPrimary = Color(0xFF3E2723);
  static const Color textSecondary = Color(0xFF5D4037);
  static const Color textTertiary = Color(0xFF795548);
  static const Color textHint = Color(0xFFBCAAA4);

  // Border & Divider Colors
  static const Color borderLight = Color(0xFFFFE0B2);
  static const Color borderMedium = Color(0xFFFFCC80);
  static const Color dividerColor = Color(0xFFFFF3E0);

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient peachGradient = LinearGradient(
    colors: [Color(0xFFFFB74D), Color(0xFFFFA726)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [Color(0xFFFFF8F0), Color(0xFFFFE0B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFFB347), Color(0xFFFFA726)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient travelGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF26A69A), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Definitions
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryOrange.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  // Backward compatibility aliases
  static const Color primaryBlue = primaryOrange;
  static const Color primaryBlueDark = primaryOrangeDark;
  static const Color primaryBlueLight = primaryOrangeLight;
  static const Color secondaryPurple = secondaryPeach;
  static const Color secondaryPurpleLight = secondaryPeachLight;
  static const Color backgroundGray = backgroundPeach;
  static const Color backgroundLightGray = backgroundLightPeach;

  // Border Radius
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius =
      BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius =
      BorderRadius.all(Radius.circular(24));

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Text Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textTertiary,
  );

  // Component Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: mediumRadius,
        boxShadow: cardShadow,
        border: Border.all(color: borderLight, width: 1),
      );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: largeRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration get gradientCardDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: largeRadius,
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration infoBoxDecoration(Color color) => BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: mediumRadius,
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      );

  static BoxDecoration badgeDecoration(Color color) => BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // Input Decoration
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    int? maxLength,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: primaryOrange) : null,
        suffixIcon: suffixIcon,
        counterText: maxLength != null ? null : '',
        filled: true,
        fillColor: backgroundLightGray,
        border: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: errorRed),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: bodyMedium.copyWith(color: textSecondary),
        hintStyle: bodyMedium.copyWith(color: textHint),
      );

  // Button Styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: primaryOrange,
        side: BorderSide(color: primaryOrange, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );

  static ButtonStyle successButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: successGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: mediumRadius),
  );

  static ButtonStyle errorButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: errorRed,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: mediumRadius),
  );

  // Icon Styles
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // Role-specific styling helpers
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return ownerColor;
      case 'editor':
        return editorColor;
      case 'viewer':
        return viewerColor;
      default:
        return textTertiary;
    }
  }

  static IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.workspace_premium;
      case 'editor':
        return Icons.edit;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  // Activity type colors
  static Color getActivityColor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'created':
        return successGreen;
      case 'edited':
        return primaryOrange;
      case 'memberadded':
        return secondaryPeach;
      case 'memberremoved':
        return warningOrange;
      case 'rolechanged':
        return accentAmber;
      case 'commentadded':
        return accentCoral;
      case 'shared':
        return secondaryPeachLight;
      case 'deleted':
        return errorRed;
      default:
        return textTertiary;
    }
  }

  static IconData getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'created':
        return Icons.add_circle;
      case 'edited':
        return Icons.edit;
      case 'memberadded':
        return Icons.person_add;
      case 'memberremoved':
        return Icons.person_remove;
      case 'rolechanged':
        return Icons.swap_horiz;
      case 'commentadded':
        return Icons.comment;
      case 'shared':
        return Icons.share;
      case 'deleted':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  // App Bar Theme
  static AppBarTheme get appBarTheme => AppBarTheme(
        backgroundColor: backgroundWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headlineMedium,
        iconTheme: const IconThemeData(color: textPrimary),
      );

  // Card Theme
  static CardThemeData get cardTheme => CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
          side: BorderSide(color: borderLight),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      );

  // Chip Theme
  static ChipThemeData get chipTheme => ChipThemeData(
        backgroundColor: backgroundGray,
        deleteIconColor: textSecondary,
        disabledColor: backgroundGray,
        selectedColor: primaryOrangeLight,
        secondarySelectedColor: primaryOrangeLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: labelMedium,
        secondaryLabelStyle: labelMedium,
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      );

  // Divider Theme
  static DividerThemeData get dividerTheme => const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      );

  // Snackbar Theme
  static SnackBarThemeData get snackBarTheme => SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        behavior: SnackBarBehavior.floating,
        actionTextColor: primaryOrangeLight,
      );

  // Dialog Theme
  static DialogThemeData get dialogTheme => DialogThemeData(
        backgroundColor: cardBackground,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: largeRadius),
        titleTextStyle: headlineMedium,
        contentTextStyle: bodyMedium,
      );

  // Complete ThemeData
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: backgroundPeach,
        cardColor: cardBackground,
        dividerColor: dividerColor,
        appBarTheme: appBarTheme,
        cardTheme: cardTheme,
        chipTheme: chipTheme,
        dividerTheme: dividerTheme,
        snackBarTheme: snackBarTheme,
        dialogTheme: dialogTheme,
        colorScheme: const ColorScheme.light(
          primary: primaryOrange,
          secondary: secondaryPeach,
          error: errorRed,
          surface: cardBackground,
          background: backgroundPeach,
        ),
        textTheme: const TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          headlineLarge: headlineLarge,
          headlineMedium: headlineMedium,
          titleLarge: titleLarge,
          titleMedium: titleMedium,
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          bodySmall: bodySmall,
          labelLarge: labelLarge,
          labelMedium: labelMedium,
        ),
      );
}
