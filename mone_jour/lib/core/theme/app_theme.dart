import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme MoneJour — Dark Mode (OLED) Only according to ui-ux-pro-max.
class AppTheme {
  // ── Palette chính (OLED) ──
  static const primaryBlue = Color(0xFF1E40AF); // Blue 800
  static const secondaryBlue = Color(0xFF3B82F6); // Blue 500
  
  static const scaffoldBg = Color(0xFF0F172A); // Slate 900
  static const cardBg = Color(0xFF101A34); // Muted
  static const borderColor = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const inputBorderColor = Color(0x28FFFFFF);
  
  // ── Màu ngữ nghĩa ──
  static const incomeGreen = Color(0xFF059669);  // Emerald 600
  static const expenseRed = Color(0xFFDC2626);   // Red 600
  static const dangerRed = expenseRed;
  static const warningAmber = Color(0xFFF5A623); 
  static const actionGreen = Color(0xFF059669);

  // ── Text ──
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0AEC0);
  static const textHint = Color(0xFF636E72); 

  /// Theme duy nhất (Dark Mode)
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
    );

    final colorScheme = const ColorScheme.dark(
      primary: secondaryBlue,
      onPrimary: Colors.white,
      primaryContainer: primaryBlue,
      onPrimaryContainer: Colors.white,
      secondary: secondaryBlue,
      onSecondary: Colors.white,
      secondaryContainer: cardBg,
      onSecondaryContainer: textPrimary,
      surface: cardBg,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: scaffoldBg,
      outline: borderColor,
      error: expenseRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: textTheme.titleLarge,
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Navigation Bar ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: secondaryBlue.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: secondaryBlue);
          }
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: secondaryBlue, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
      ),

      // ── FilledButton ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: secondaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      // ── TextButton ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryBlue,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── FloatingActionButton ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── BottomSheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1.0,
      ),

      // ── InputDecoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 14),
      ),
    );
  }
  
  // Tương thích mã cũ, luôn trả về Dark Mode
  static ThemeData get light => darkTheme;
  static ThemeData get dark => darkTheme;

  // Constants tương thích mã cũ
  static const primaryPastel = secondaryBlue;
  static const primaryLight = primaryBlue;
}
