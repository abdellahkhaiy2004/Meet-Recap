import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Primary text theme — Inter for all Latin / French / English content.
  static TextTheme textTheme(ColorScheme scheme) =>
      GoogleFonts.interTextTheme().copyWith(
        displaySmall: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      );

  // Arabic / Darija content (transcripts and summaries that contain Arabic).
  static TextStyle cairo({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}
