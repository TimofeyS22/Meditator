import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class C {
  // Dark mode — signature purple-tinted palette
  static const bg = Color(0xFF050510);
  static const bgDeep = Color(0xFF030308);
  static const surface = Color(0xFF0C0C1E);
  static const surfaceLight = Color(0xFF16162E);
  static const card = Color(0xFF111128);
  static const surfaceGlass = Color(0x18FFFFFF);
  static const surfaceBorder = Color(0x10FFFFFF);
  static const shimmerBase = Color(0xFF16162E);
  static const shimmerHighlight = Color(0xFF222244);

  static const primary = Color(0xFF7C6FFF);
  static const primaryMuted = Color(0xFF6358E0);
  static const accent = Color(0xFF64FFDA);
  static const accentLight = Color(0xFF96FFE8);
  static const gold = Color(0xFFFFB86C);
  static const rose = Color(0xFFFF7B93);
  static const warm = Color(0xFFFFAA5C);

  static const calm = Color(0xFF7FB3D8);
  static const happy = Color(0xFFF5D76E);
  static const anxious = Color(0xFFE87461);
  static const sad = Color(0xFF9B93C9);
  static const energy = Color(0xFFFFAA5C);
  static const grateful = Color(0xFF64DFAC);

  static const text = Color(0xFFF0EEF6);
  static const textSec = Color(0xFF8B87A8);
  static const textDim = Color(0xFF5E5A78);

  static const error = Color(0xFFEF4444);
  static const ok = Color(0xFF64DFAC);

  static const glowPrimary = Color(0x407C6FFF);
  static const glowAccent = Color(0x4064FFDA);
  static const glowRose = Color(0x40FF7B93);

  // Light mode — warm, organic
  static const lBg = Color(0xFFF8F7F4);
  static const lBgDeep = Color(0xFFF3F1ED);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceLight = Color(0xFFEBE8E2);
  static const lCard = Color(0xFFF4F2EF);
  static const lSurfaceGlass = Color(0x12000000);
  static const lSurfaceBorder = Color(0x0A000000);
  static const lShimmerBase = Color(0xFFEBE8E2);
  static const lShimmerHighlight = Color(0xFFF4F2EF);
  static const lText = Color(0xFF1A1825);
  static const lTextSec = Color(0xFF6B6580);
  static const lTextDim = Color(0xFF9994AD);

  static const lGlowPrimary = Color(0x187C6FFF);
  static const lGlowAccent = Color(0x1864FFDA);
  static const lWarmGlow = Color(0x14FFB86C);

  static const gradientLightSoft = LinearGradient(
    colors: [Color(0xFFF8F7F4), Color(0xFFF3EEE8), Color(0xFFEEE8F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientLightWarm = LinearGradient(
    colors: [Color(0x0CFFB86C), Color(0x08FF7B93), Color(0x067C6FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF7C6FFF), Color(0xFF64FFDA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientNight = LinearGradient(
    colors: [Color(0xFF050510), Color(0xFF0C0C1E), Color(0xFF1A1040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const gradientSunset = LinearGradient(
    colors: [Color(0xFF7C6FFF), Color(0xFFFF7B93), Color(0xFFFFB86C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientGold = LinearGradient(
    colors: [Color(0xFFFFB86C), Color(0xFFFFAA5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientAurora = LinearGradient(
    colors: [Color(0xFF7C6FFF), Color(0xFF64FFDA), Color(0xFF7FB3D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientMystic = RadialGradient(
    colors: [Color(0x357C6FFF), Color(0x00000000)],
    radius: 0.8,
  );

  static const gradientMorning = LinearGradient(
    colors: [Color(0xFFFFB86C), Color(0xFFFFAA5C), Color(0xFFFF7B93)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientDaytime = LinearGradient(
    colors: [Color(0xFF7FB3D8), Color(0xFF7C6FFF), Color(0xFF64FFDA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ({Color blob1, Color blob2, Color blob3, String greeting}) timeOfDay() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 9) {
      return (
        blob1: const Color(0xFFFFB86C),
        blob2: const Color(0xFFFF7B93),
        blob3: const Color(0xFFFFAA5C),
        greeting: 'Доброе утро',
      );
    }
    if (h >= 9 && h < 17) {
      return (
        blob1: const Color(0xFF7FB3D8),
        blob2: const Color(0xFF7C6FFF),
        blob3: const Color(0xFF64FFDA),
        greeting: 'Добрый день',
      );
    }
    if (h >= 17 && h < 21) {
      return (
        blob1: const Color(0xFF7C6FFF),
        blob2: const Color(0xFFFF7B93),
        blob3: const Color(0xFFFFB86C),
        greeting: 'Добрый вечер',
      );
    }
    return (
      blob1: const Color(0xFF6358E0),
      blob2: const Color(0xFF9B93C9),
      blob3: const Color(0xFF64FFDA),
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
  static const double section = 40;
  static const double xxl = 56;
  static const double xxxl = 72;
  static const double minTapTarget = 44;
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
  static const pageTransition = Duration(milliseconds: 450);
  static const stagger = Duration(milliseconds: 100);
  static const borderRotation = Duration(seconds: 4);
  static const lightSweep = Duration(milliseconds: 1200);
  static const curve = Curves.easeOutCubic;
  static const curveGentle = Cubic(0.22, 1.0, 0.36, 1.0);
  static const curveMeditative = Cubic(0.4, 0.0, 0.0, 1.0);
  static const curveDecel = Curves.decelerate;
  static const curveDramatic = Cubic(0.25, 0.1, 0.0, 1.0);

  @Deprecated('Use curveGentle instead — bouncy curves are inappropriate for a meditation app')
  static const curveElastic = Curves.elasticOut;
  @Deprecated('Use curveGentle instead — bouncy curves are inappropriate for a meditation app')
  static const curveSpring = Curves.easeOutBack;
}

abstract class Display {
  static TextStyle style({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w300,
    Color color = C.text,
    double letterSpacing = -0.5,
    double? height,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle hero({Color color = C.text}) => style(
        fontSize: 48,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: -1.5,
        height: 1.05,
      );

  static TextStyle emotional({Color color = C.text}) => style(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: -0.8,
        height: 1.1,
      );

  static TextStyle quote({Color color = C.textSec}) => style(
        fontSize: 22,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 0.2,
        height: 1.45,
      );

  static TextStyle subtitle({Color color = C.textSec}) => style(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.8,
        height: 1.4,
      );
}

extension Cx on BuildContext {
  bool get _isL => Theme.of(this).brightness == Brightness.light;
  Color get cText => _isL ? C.lText : C.text;
  Color get cTextSec => _isL ? C.lTextSec : C.textSec;
  Color get cTextDim => _isL ? C.lTextDim : C.textDim;
  Color get cBg => _isL ? C.lBg : C.bg;
  Color get cBgDeep => _isL ? C.lBgDeep : C.bgDeep;
  Color get cSurface => _isL ? C.lSurface : C.surface;
  Color get cSurfaceLight => _isL ? C.lSurfaceLight : C.surfaceLight;
  Color get cCard => _isL ? C.lCard : C.card;
  Color get cSurfaceGlass => _isL ? C.lSurfaceGlass : C.surfaceGlass;
  Color get cSurfaceBorder => _isL ? C.lSurfaceBorder : C.surfaceBorder;
  Color get cShimmerBase => _isL ? C.lShimmerBase : C.shimmerBase;
  Color get cShimmerHL => _isL ? C.lShimmerHighlight : C.shimmerHighlight;
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: C.surfaceLight,
        contentTextStyle: const TextStyle(color: C.text, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.m)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: C.lSurfaceLight,
        contentTextStyle: const TextStyle(color: C.lText, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.m)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }

  static TextTheme _darkText(ThemeData base) {
    return GoogleFonts.spaceGroteskTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 44,
        fontWeight: FontWeight.w300,
        color: C.text,
        letterSpacing: -1.5,
        height: 1.05,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        color: C.text,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: C.text,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: C.text,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: C.text,
        letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: C.text,
      ),
      titleLarge: _t(16, FontWeight.w600),
      titleMedium: _t(14, FontWeight.w500),
      bodyLarge: _t(16, FontWeight.w400, height: 1.56),
      bodyMedium: _t(14, FontWeight.w400, color: C.textSec, height: 1.56),
      bodySmall: _t(12, FontWeight.w400, color: C.textDim, height: 1.4),
      labelLarge: _t(14, FontWeight.w600, letterSpacing: 0.4),
      labelSmall: _t(12, FontWeight.w500, color: C.textDim, letterSpacing: 0.2),
    );
  }

  static TextTheme _lightText(ThemeData base) {
    return GoogleFonts.spaceGroteskTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 44,
        fontWeight: FontWeight.w300,
        color: C.lText,
        letterSpacing: -1.5,
        height: 1.05,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        color: C.lText,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: C.lText,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: C.lText,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: C.lText,
        letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: C.lText,
      ),
      titleLarge: _t(16, FontWeight.w600, color: C.lText),
      titleMedium: _t(14, FontWeight.w500, color: C.lText),
      bodyLarge: _t(16, FontWeight.w400, color: C.lText, height: 1.56),
      bodyMedium: _t(14, FontWeight.w400, color: C.lTextSec, height: 1.56),
      bodySmall: _t(12, FontWeight.w400, color: C.lTextDim, height: 1.4),
      labelLarge: _t(14, FontWeight.w600, color: C.lText, letterSpacing: 0.4),
      labelSmall: _t(12, FontWeight.w500, color: C.lTextDim, letterSpacing: 0.2),
    );
  }

  static TextStyle _t(double size, FontWeight w,
          {Color color = C.text, double? height, double letterSpacing = 0}) =>
      TextStyle(
          fontSize: size,
          fontWeight: w,
          color: color,
          height: height,
          letterSpacing: letterSpacing);
}
