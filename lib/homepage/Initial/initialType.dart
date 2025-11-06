import 'package:flutter/material.dart';

class AppTheme {
  static const Color textColor = Color(0xFFE8F5E9); // Szövegszín
  static const Color backgroundColor = Color(0xFFE8F5E9);
  static const String fontFamily = "Boldonse";

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: textColor,
          fontFamily: fontFamily,
        ), // Szöveg színe
      ),
    );
  }
}
