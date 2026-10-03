import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system TransConnect (charte des maquettes).
abstract final class TC {
  // Primaires
  static const primary900 = Color(0xFF0F2947);
  static const primary700 = Color(0xFF163A6B);
  static const primary = Color(0xFF1E4E8C);
  static const primary300 = Color(0xFF5B85B8);
  static const primary100 = Color(0xFFEAF1FA);
  // Secondaires
  static const secondary700 = Color(0xFFB9770E);
  static const secondary = Color(0xFFF39C12);
  static const secondary100 = Color(0xFFFEF5E7);
  // Sémantiques
  static const success = Color(0xFF27AE60);
  static const warning = Color(0xFFF39C12);
  static const error = Color(0xFFE74C3C);
  static const info = Color(0xFF3498DB);
  // Neutres
  static const gray900 = Color(0xFF2C3E50);
  static const gray700 = Color(0xFF4A5A6A);
  /// Texte secondaire des maquettes (contraste AA sur blanc)
  static const gray600 = Color(0xFF5F6B76);
  static const gray500 = Color(0xFF7F8C8D);
  static const gray300 = Color(0xFFB0BEC5);
  static const gray200 = Color(0xFFE0E6ED);
  static const gray100 = Color(0xFFF5F7FA);
  static const white = Color(0xFFFFFFFF);

  // Barre latérale du back-office (maquette A01)
  static const sidebar = Color(0xFF163A6B);
  static const sidebarText = Color(0xFFC7D4E5);
  static const positive = Color(0xFF1E8449);

  // Rayons
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 24.0;

  // Ombres
  static const shadowMd = [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))];
  static const shadowSm = [BoxShadow(color: Color(0x0F2C3E50), blurRadius: 8, offset: Offset(0, 2))];

  static TextStyle h1 = GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, height: 34 / 26, color: gray900);
  static TextStyle h2 = GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, height: 30 / 22, color: gray900);
  static TextStyle h3 = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16, color: gray900);
  static TextStyle kpi = GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, height: 36 / 28, color: gray900);
  static TextStyle body = GoogleFonts.inter(fontSize: 14, height: 22 / 14, color: gray900);
  static TextStyle label = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: gray700);
  static TextStyle caption = GoogleFonts.inter(fontSize: 12, height: 16 / 12, color: gray600);
  static TextStyle muted = GoogleFonts.inter(fontSize: 14, height: 22 / 14, color: gray600);
  static TextStyle tableHeader =
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: gray600);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: white,
      ),
      scaffoldBackgroundColor: gray100,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));
    final buttonText = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: GoogleFonts.inter().fontFamily, bodyColor: gray900, displayColor: gray900),
      dividerColor: gray200,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          disabledBackgroundColor: gray300,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary, textStyle: buttonText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: gray500),
        hintStyle: GoogleFonts.inter(color: gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: gray200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: gray200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
    );
  }
}

/// Couleurs et libellés des statuts (badges).
abstract final class Statuts {
  static const demande = <String, (String, Color)>{
    'EN_ATTENTE': ('En attente', Color(0xFF9A5B0B)),
    'REPRESENTANT_ASSIGNE': ('Assigné', Color(0xFF1B6FA8)),
    'EN_EVALUATION': ('En évaluation', Color(0xFF6C3483)),
    'PRIX_PROPOSE': ('Prix proposé', Color(0xFFA04000)),
    'EN_NEGOCIATION': ('En négociation', Color(0xFF873600)),
    'PAIEMENT_EN_ATTENTE': ('Paiement attendu', Color(0xFF7D6608)),
    'PAYE': ('Payé', Color(0xFF1E7046)),
    'EN_TRANSIT': ('En transit', Color(0xFF1F5F99)),
    'LIVRE': ('Livré', Color(0xFF145A32)),
    'ANNULE': ('Annulé', Color(0xFF5D6D7E)),
    'LITIGE': ('Litige', Color(0xFFA93226)),
  };

  static const compte = <String, (String, Color)>{
    'actif': ('Actif', Color(0xFF1E7046)),
    'en_attente_validation': ('À valider', Color(0xFF9A5B0B)),
    'suspendu': ('Suspendu', Color(0xFFA93226)),
  };

  static const kyc = <String, (String, Color)>{
    'en_attente': ('À vérifier', Color(0xFF9A5B0B)),
    'valide': ('Validé', Color(0xFF1E7046)),
    'rejete': ('Rejeté', Color(0xFFA93226)),
  };

  static const paiement = <String, (String, Color)>{
    'initie': ('Initié', Color(0xFF5D6D7E)),
    'en_cours': ('En cours', Color(0xFF1F5F99)),
    'reussi': ('Réussi', Color(0xFF1E7046)),
    'echoue': ('Échoué', Color(0xFFA93226)),
    'rembourse': ('Remboursé', Color(0xFF6C3483)),
  };

  static const sequestre = <String, (String, Color)>{
    'bloque': ('Bloqué', Color(0xFF9A5B0B)),
    'libere': ('Libéré', Color(0xFF1E7046)),
    'rembourse_total': ('Remboursé', Color(0xFF6C3483)),
    'rembourse_partiel': ('Remb. partiel', Color(0xFF6C3483)),
  };

  static const litige = <String, (String, Color)>{
    'ouvert': ('Ouvert', Color(0xFFA93226)),
    'en_cours': ('En cours', Color(0xFF9A5B0B)),
    'resolu': ('Résolu', Color(0xFF1E7046)),
  };

  static const roles = <String, String>{
    'marchand': 'Marchand',
    'representant': 'Représentant',
    'chauffeur': 'Chauffeur',
    'admin': 'Administrateur',
  };
}
