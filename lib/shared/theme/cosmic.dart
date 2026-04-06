import 'package:flutter/material.dart';

// ─── Color tokens ────────────────────────────────────────────────────────────

abstract final class Cosmic {
  static const bg = Color(0xFF020108);
  static const surface = Color(0xFF0A0A1A);
  static const surfaceLight = Color(0xFF14142A);
  static const surfaceBorder = Color(0x18FFFFFF);

  static const primary = Color(0xFF8B7FFF);
  static const primaryMuted = Color(0xFF6E63E0);
  static const accent = Color(0xFF5CE1E6);
  static const warm = Color(0xFFFFB156);
  static const rose = Color(0xFFFF6B8A);
  static const green = Color(0xFF56E09A);

  static const text = Color(0xFFF0ECF9);
  static const textMuted = Color(0xFF8A84A8);
  static const textDim = Color(0xFF6E6890);

  static const glowPrimary = Color(0x508B7FFF);
  static const glowAccent = Color(0x505CE1E6);
  static const glowWarm = Color(0x50FFB156);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF8B7FFF), Color(0xFF5CE1E6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientWarm = LinearGradient(
    colors: [Color(0xFFFFB156), Color(0xFFFF6B8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Spacing (4px grid) ──────────────────────────────────────────────────────

abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

// ─── Border radii ────────────────────────────────────────────────────────────

abstract final class Radii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double full = 9999;
}

// ─── Animation tokens ────────────────────────────────────────────────────────

abstract final class Anim {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 400);
  static const slow = Duration(milliseconds: 800);
  static const breath = Duration(milliseconds: 4000);
  static const cosmic = Duration(seconds: 20);

  static const curve = Cubic(0.16, 1.0, 0.3, 1.0);
  static const curveSmooth = Cubic(0.4, 0.0, 0.0, 1.0);
}
