import 'package:flutter/material.dart';

class AppTheme {
  // Spotaia Brand Colors
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonOrange = Color(0xFFFF9100);
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceLighter = Color(0xFF1E1E1E);
  static const Color error = Color(0xFFFF5252);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo', // Main Arabic font
      scaffoldBackgroundColor: backgroundDark,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surfaceLighter,
      contentTextStyle: TextStyle(color: neonBlue, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      behavior: SnackBarBehavior.floating,
    ),

      primaryColor: neonBlue,
      colorScheme: const ColorScheme.dark(
        primary: neonBlue,
        secondary: neonOrange,
        surface: surfaceDark,
        background: backgroundDark,
        error: Color(0xFFFF5252),
      ),
      splashColor: neonBlue.withOpacity(0.2),
      highlightColor: neonBlue.withOpacity(0.1),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonBlue,
          foregroundColor: backgroundDark, // Text color on button
          elevation: 4,
          shadowColor: neonBlue.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonBlue,
          side: const BorderSide(color: neonBlue, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neonBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: neonBlue.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: neonBlue, fontWeight: FontWeight.bold, fontFamily: 'Cairo');
          }
          return TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600, fontFamily: 'Cairo');
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: neonBlue, size: 28);
          }
          return IconThemeData(color: Colors.white.withOpacity(0.6), size: 24);
        }),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
        space: 24,
      ),
    );
  }
}
