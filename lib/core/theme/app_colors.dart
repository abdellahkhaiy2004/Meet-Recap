import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';

abstract final class AppColors {
  // ── Brand palette (architecture §9) ─────────────────────────────────────
  static const primarySeed = Color(0xFF7C3AED); // purple — ColorScheme seed
  static const secondary   = Color(0xFF06B6D4); // cyan   — accents, links
  static const tertiary    = Color(0xFFF59E0B); // amber  — recording highlights
  static const recording   = Color(0xFFEF4444); // red    — active record state

  // ── Category tokens ──────────────────────────────────────────────────────
  static const categoryWork      = Color(0xFF3B82F6); // blue
  static const categoryEducation = Color(0xFF10B981); // emerald
  static const categoryPersonal  = Color(0xFF8B5CF6); // violet
  static const categoryHealth    = Color(0xFFEF4444); // red
  static const categoryFinance   = Color(0xFFF59E0B); // amber
  static const categoryLegal     = Color(0xFF64748B); // slate
  static const categoryOther     = Color(0xFF7C3AED); // purple (primary seed)

  // ── Folder card preset palette (12 swatches for NewFolderPage) ───────────
  static const folderSwatches = <Color>[
    Color(0xFF7C3AED), // purple
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // emerald
    Color(0xFF8B5CF6), // violet
    Color(0xFFEF4444), // red
    Color(0xFFF59E0B), // amber
    Color(0xFF06B6D4), // cyan
    Color(0xFFEC4899), // pink
    Color(0xFF84CC16), // lime
    Color(0xFFF97316), // orange
    Color(0xFF64748B), // slate
    Color(0xFFF472B6), // rose
  ];

  // ── Dark-mode base surface ───────────────────────────────────────────────
  static const darkSurface = Color(0xFF0F172A);

  // Returns the color token for a Category enum value.
  static Color forCategoryEnum(Category c) => switch (c) {
    Category.work      => categoryWork,
    Category.education => categoryEducation,
    Category.personal  => categoryPersonal,
    Category.health    => categoryHealth,
    Category.finance   => categoryFinance,
    Category.legal     => categoryLegal,
    Category.other     => categoryOther,
  };

  // Returns the category color for a stored string key (DB / legacy).
  static Color forCategory(String category) => switch (category.toLowerCase()) {
    'work'      => categoryWork,
    'education' => categoryEducation,
    'personal'  => categoryPersonal,
    'health'    => categoryHealth,
    'finance'   => categoryFinance,
    'legal'     => categoryLegal,
    // legacy names kept for backwards-compat with any existing data
    'school'    => categoryEducation,
    'family'    => categoryPersonal,
    _           => primarySeed,
  };

  // Returns black or white depending on background luminance.
  static Color contrastOn(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
          ? Colors.white
          : Colors.black;

  // Parses a 6-digit hex string (no '#') to a Color.
  static Color hexToColor(String hex) {
    final buffer = StringBuffer('ff');
    buffer.write(hex.replaceAll('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
