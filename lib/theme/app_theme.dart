import 'package:flutter/material.dart';

class AppTheme {
  // 苹果风格颜色
  static const Color appleBlue = Color(0xFF007AFF);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color appleGray = Color(0xFF8E8E93);
  static const Color appleLightGray = Color(0xFFE5E5EA);
  static const Color appleDarkGray = Color(0xFF1C1C1E);
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Colors.white;
  
  // 龙虾主题颜色
  static const Color lobsterRed = Color(0xFFFF6B6B);
  static const Color lobsterOrange = Color(0xFFFF8E53);
  static const Color lobsterDark = Color(0xFFE85D4E);
  
  // 深色模式颜色
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkSurface = Color(0xFF2C2C2E);
  
  // 气泡颜色
  static const Color userBubble = Color(0xFF007AFF);
  static const Color aiBubble = Color(0xFFE5E5EA);
  static const Color darkAiBubble = Color(0xFF2C2C2E);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: appleBlue,
        secondary: appleGreen,
        surface: appleCard,
        background: appleBackground,
        error: appleRed,
      ),
      scaffoldBackgroundColor: appleBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: appleCard,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: appleBlue),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: appleCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: appleCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: appleLightGray,
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          color: Colors.black,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: appleGray,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: appleBlue,
        secondary: appleGreen,
        surface: darkCard,
        background: darkBackground,
        error: appleRed,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: appleBlue),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkSurface,
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: Colors.white70,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: appleGray,
        ),
      ),
    );
  }
}
