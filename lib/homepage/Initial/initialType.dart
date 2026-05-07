import 'package:flutter/material.dart';

class AppTheme {
  // Primary accent (orange) used for buttons and highlights
  static const Color primaryColor = Color(0xFFF26522);

  // Background / surface colors for a dark themed UI
  static const Color backgroundColor = Color(0xFF21232A);
  static const Color surfaceColor = Color(0xFF2B2F36);

  // Text color on dark backgrounds
  static const Color textColor = Color(0xFFFFFFFF);

  static const String fontFamily = "Boldonse";

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      dialogBackgroundColor: surfaceColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor, fontFamily: fontFamily),
        bodyMedium: TextStyle(color: textColor, fontFamily: fontFamily),
        bodySmall: TextStyle(color: textColor, fontFamily: fontFamily),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 6,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: textColor),
      ),
      // Use cardColor / surfaceColor for bottom bars; keep theme minimal for SDK compatibility
    );
  }

  // Light (day) theme variant using the same primary accent
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF5F5F5),
      dialogBackgroundColor: const Color(0xFFF5F5F5),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.black87, fontFamily: fontFamily),
        bodyMedium: TextStyle(color: Colors.black87, fontFamily: fontFamily),
        bodySmall: TextStyle(color: Colors.black87, fontFamily: fontFamily),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 6,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
    );
  }
}
