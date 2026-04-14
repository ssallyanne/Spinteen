import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditorialTheme {
  // 🚀 1. 保留「中性質感」的色彩令牌
  static const Color surface = Color(0xFFF8F9FB);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF504444);
  
  // 🚀 2. 將原本 SVT 的專屬色定義為「預設值」或「參考值」
  // 但在 RoulettePage 中，我們會優先使用 GroupData 提供的顏色
  static const Color defaultPrimary = Color(0xFF785655);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    
    // 🚀 3. 核心規範：統一字體（這就是精品感的來源）
    // 不管切換到哪個團體，字體、間距、排版比例必須保持一致
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        letterSpacing: -0.4, 
        fontWeight: FontWeight.bold,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: onSurfaceVariant,
        letterSpacing: 0.2,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1.0, // 用於標籤，增加高級感
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}