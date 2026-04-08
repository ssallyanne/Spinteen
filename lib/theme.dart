import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditorialTheme {
  // 色彩令牌 (基於 code.html tailwind-config)
  static const Color primary = Color(0xFF785655);
  static const Color primaryContainer = Color(0xFFF7CAC9); // Rose Quartz
  static const Color secondaryFixedDim = Color(0xFFB1C7F2); // Serenity
  static const Color surface = Color(0xFFF8F9FB);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF504444);
  static const Color surfaceTint = Color(0xFF785655);

  // 規範 2.2: 標誌性漸變 (135度)
  static const LinearGradient sanctuaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryContainer, secondaryFixedDim],
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    // 規範 3: 使用 Plus Jakarta Sans
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(letterSpacing: -0.02 * 20), // 緊湊字距
      bodyMedium: GoogleFonts.plusJakartaSans(color: onSurfaceVariant), // 規範建議降低視覺振動
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white70,
      centerTitle: true,
      elevation: 0,
    ),
  );
}