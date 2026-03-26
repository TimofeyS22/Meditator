import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class C {
  static const bg = Color(0xFF030712);
  static const bgDeep = Color(0xFF020617);
  static const surface = Color(0xFF0F172A);
  static const surfaceLight = Color(0xFF1E293B);
  static const card = Color(0xFF151A30);
  static const surfaceGlass = Color(0x1AFFFFFF);
  static const surfaceBorder = Color(0x12FFFFFF);
  static const shimmerBase = Color(0xFF1E293B);
  static const shimmerHighlight = Color(0xFF334155);

  static const primary = Color(0xFF6366F1);
  static const primaryMuted = Color(0xFF4F46E5);
  static const accent = Color(0xFF2DD4BF);
  static const accentLight = Color(0xFF5EEAD4);
  static const gold = Color(0xFFFBBF24);
  static const rose = Color(0xFFFB7185);
  static const warm = Color(0xFFF97316);

  static const calm = Color(0xFF38BDF8);
  static const happy = Color(0xFFFDE047);
  static const anxious = Color(0xFFF87171);
  static const sad = Color(0xFF818CF8);
  static const energy = Color(0xFFFB923C);
  static const grateful = Color(0xFF34D399);

  static const text = Color(0xFFF1F5F9);
  static const textSec = Color(0xFF94A3B8);
  static const textDim = Color(0xFF7A8AA3);

  static const error = Color(0xFFEF4444);
  static const ok = Color(0xFF34D399);

  static const glowPrimary = Color(0x406366F1);
  static const glowAccent = Color(0x402DD4BF);
  static const glowRose = Color(0x40FB7185);

  // Light mode
  static const lBg = Color(0xFFF8FAFC);
  static const lBgDeep = Color(0xFFF1F5F9);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceLight = Color(0xFFE2E8F0);
  static const lCard = Color(0xFFF1F5F9);
  static const lSurfaceGlass = Color(0x18000000);
  static const lSurfaceBorder = Color(0x10000000);
  static const lShimmerBase = Color(0xFFE2E8F0);
  static const lShimmerHighlight = Color(0xFFF1F5F9);
  static const lText = Color(0xFF0F172A);
  static const lTextSec = Color(0xFF64748B);
  static const lTextDim = Color(0xFF94A3B8);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientNight = LinearGradient(
    colors: [Color(0xFF030712), Color(0xFF0F172A), Color(0xFF1E1040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const gradientSunset = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFFFB7185), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientGold = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientAurora = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF2DD4BF), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientMystic = RadialGradient(
    colors: [Color(0x356366F1), Color(0x00000000)],
    radius: 0.8,
  );

  static const gradientMorning = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF97316), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientDaytime = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ({Color blob1, Color blob2, Color blob3, String greeting}) timeOfDay() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 9) {
      return (
        blob1: const Color(0xFFFBBF24),
        blob2: const Color(0xFFFB7185),
        blob3: const Color(0xFFF97316),
        greeting: 'Доброе утро',
      );
    }
    if (h >= 9 && h < 17) {
      return (
        blob1: const Color(0xFF38BDF8),
        blob2: const Color(0xFF6366F1),
        blob3: const Color(0xFF2DD4BF),
        greeting: 'Добрый день',
      );
    }
    if (h >= 17 && h < 21) {
      return (
        blob1: const Color(0xFF6366F1),
        blob2: const Color(0xFFFB7185),
        blob3: const Color(0xFFFBBF24),
        greeting: 'Добрый вечер',
      );
    }
    return (
      blob1: const Color(0xFF4F46E5),
      blob2: const Color(0xFF818CF8),
      blob3: const Color(0xFF2DD4BF),
      greeting: 'Доброй ночи',
    );
  }
}

abstract class S {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract class R {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double full = 999;
}

abstract class Anim {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 500);
  static const dramatic = Duration(milliseconds: 800);
  static const breathe = Duration(milliseconds: 4000);
  static const curve = Curves.easeOutCubic;
  static const curveElastic = Curves.elasticOut;
  static const curveSpring = Curves.easeOutBack;
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(
        primary: C.primary,
        secondary: C.accent,
        surface: C.surface,
        error: C.error,
      ),
      textTheme: _darkText(base),
      cardTheme: CardThemeData(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
          textStyle: _t(16, FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: const BorderSide(color: C.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: C.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.text),
        iconTheme: IconThemeData(color: C.text),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: C.lBg,
      colorScheme: const ColorScheme.light(
        primary: C.primary,
        secondary: C.accent,
        surface: C.lSurface,
        error: C.error,
      ),
      textTheme: _lightText(base),
      cardTheme: CardThemeData(
        color: C.lSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
          textStyle: _t(16, FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.lSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.m),
          borderSide: const BorderSide(color: C.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: C.lTextDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.lText),
        iconTheme: IconThemeData(color: C.lText),
      ),
    );
  }

  static TextTheme _darkText(ThemeData base) {
    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: C.text,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: C.text,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displaySmall: GoogleFonts.dmSerifDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        color: C.text,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: C.text,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: C.text,
      ),
      headlineSmall: GoogleFonts.dmSerifDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: C.text,
      ),
      titleLarge: _t(18, FontWeight.w600),
      titleMedium: _t(16, FontWeight.w500),
      bodyLarge: _t(16, FontWeight.w400, height: 1.5),
      bodyMedium: _t(14, FontWeight.w400, color: C.textSec, height: 1.5),
      bodySmall: _t(12, FontWeight.w400, color: C.textDim),
      labelLarge: _t(16, FontWeight.w600),
    );
  }

  static TextTheme _lightText(ThemeData base) {
    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: C.lText,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: C.lText,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displaySmall: GoogleFonts.dmSerifDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        color: C.lText,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: C.lText,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: C.lText,
      ),
      headlineSmall: GoogleFonts.dmSerifDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: C.lText,
      ),
      titleLarge: _t(18, FontWeight.w600, color: C.lText),
      titleMedium: _t(16, FontWeight.w500, color: C.lText),
      bodyLarge: _t(16, FontWeight.w400, color: C.lText, height: 1.5),
      bodyMedium: _t(14, FontWeight.w400, color: C.lTextSec, height: 1.5),
      bodySmall: _t(12, FontWeight.w400, color: C.lTextDim),
      labelLarge: _t(16, FontWeight.w600, color: C.lText),
    );
  }

  static TextStyle _t(double size, FontWeight w, {Color color = C.text, double? height}) =>
      TextStyle(fontSize: size, fontWeight: w, color: color, height: height);
}
