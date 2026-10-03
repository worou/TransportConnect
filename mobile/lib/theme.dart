import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte TransportConnect (maquettes M et R).
abstract final class TC {
  static const primary900 = Color(0xFF0F2947);
  static const navy = Color(0xFF163A6B);
  static const primary = Color(0xFF1E4E8C);
  static const primary100 = Color(0xFFEAF1FA);
  static const secondary = Color(0xFFF39C12);
  static const success = Color(0xFF1E8449);
  static const successBg = Color(0xFFE8F6EE);
  static const error = Color(0xFFC0392B);
  static const ink = Color(0xFF2C3E50);
  static const muted = Color(0xFF5F6B76);
  static const border = Color(0xFFE0E6ED);
  static const ground = Color(0xFFF5F7FA);
  static const segment = Color(0xFFE9EEF3);
  static const white = Color(0xFFFFFFFF);

  static const radius = 12.0;
  static const cardShadow = [BoxShadow(color: Color(0x0F2C3E50), blurRadius: 8, offset: Offset(0, 2))];

  static TextStyle h1 = GoogleFonts.poppins(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700, color: ink);
  static TextStyle h2 = GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: ink);
  static TextStyle h3 = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: ink);
  static TextStyle title = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: ink);
  static TextStyle body = GoogleFonts.inter(fontSize: 15, height: 22 / 15, color: ink);
  static TextStyle bodyMuted = GoogleFonts.inter(fontSize: 15, height: 22 / 15, color: muted);
  static TextStyle label = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: ink);
  static TextStyle small = GoogleFonts.inter(fontSize: 13, color: muted);
  static TextStyle caption = GoogleFonts.inter(fontSize: 12, color: muted);
  static TextStyle strong = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: ink);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary, surface: white),
      scaffoldBackgroundColor: ground,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final text = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
    OutlineInputBorder outline(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: GoogleFonts.inter().fontFamily, bodyColor: ink, displayColor: ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          disabledBackgroundColor: const Color(0xFFB0BEC5),
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: text,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: text,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary, minimumSize: const Size(44, 44), textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: GoogleFonts.inter(color: muted, fontSize: 15),
        border: outline(border, 1.5),
        enabledBorder: outline(border, 1.5),
        focusedBorder: outline(primary, 2),
        errorBorder: outline(error, 2),
        focusedErrorBorder: outline(error, 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerColor: border,
    );
  }

}

/// Statuts de demande : libellé, couleur, avancement (barre de progression des cartes).
abstract final class Statuts {
  static const demande = <String, (String, Color, double)>{
    'EN_ATTENTE': ('En attente', Color(0xFF9A5B0B), 0.10),
    'REPRESENTANT_ASSIGNE': ('Représentant assigné', Color(0xFF1B6FA8), 0.25),
    'EN_EVALUATION': ('En évaluation', Color(0xFF6C3483), 0.40),
    'PRIX_PROPOSE': ('Prix proposé', Color(0xFFA04000), 0.50),
    'EN_NEGOCIATION': ('En négociation', Color(0xFF873600), 0.55),
    'PAIEMENT_EN_ATTENTE': ('Paiement attendu', Color(0xFF7D6608), 0.60),
    'PAYE': ('Payé', Color(0xFF1E7046), 0.70),
    'EN_TRANSIT': ('En transit', Color(0xFF1F5F99), 0.85),
    'LIVRE': ('Livré', Color(0xFF145A32), 1.0),
    'ANNULE': ('Annulée', Color(0xFF5D6D7E), 0.0),
    'LITIGE': ('Litige', Color(0xFFA93226), 1.0),
  };

  /// Étapes de la frise de suivi (M08), dans l'ordre.
  static const etapes = [
    ('EN_ATTENTE', 'Demande créée'),
    ('REPRESENTANT_ASSIGNE', 'Représentant assigné'),
    ('EN_EVALUATION', 'En évaluation'),
    ('PRIX_PROPOSE', 'Prix proposé'),
    ('PAYE', 'Paiement'),
    ('EN_TRANSIT', 'En transit'),
    ('LIVRE', 'Livré'),
  ];

  static const types = {
    'standard': 'Standard',
    'alimentaire': 'Alimentaire',
    'fragile': 'Fragile',
    'dangereuse': 'Dangereuse',
    'betail': 'Bétail',
  };

  static const enCours = ['EN_ATTENTE', 'REPRESENTANT_ASSIGNE', 'EN_EVALUATION', 'PRIX_PROPOSE', 'EN_NEGOCIATION', 'PAIEMENT_EN_ATTENTE', 'PAYE', 'EN_TRANSIT'];
  static const annulables = ['EN_ATTENTE', 'REPRESENTANT_ASSIGNE', 'EN_EVALUATION', 'PRIX_PROPOSE', 'EN_NEGOCIATION'];
}
