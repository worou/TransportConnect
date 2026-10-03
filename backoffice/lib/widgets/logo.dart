import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Logo TransportConnect (piste « Maillons ») : symbole + « transport » léger, « connect » gras.
class TcLogo extends StatelessWidget {
  const TcLogo({super.key, this.dark = false, this.markSize = 22, this.fontSize = 20, this.showText = true});

  /// Sur fond bleu marine (#163A6B) : maillon et texte en blanc.
  final bool dark;

  /// Hauteur du symbole (le dessin est horizontal : largeur = hauteur × 63/26).
  final double markSize;
  final double fontSize;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final color = dark ? TC.white : TC.sidebar;
    final mark = SvgPicture.asset(
      dark ? 'assets/logo/mark-dark.svg' : 'assets/logo/mark.svg',
      width: markSize * 63 / 26,
      height: markSize,
      semanticsLabel: 'TransportConnect',
    );
    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: markSize * 0.35),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'transport', style: GoogleFonts.poppins(fontWeight: FontWeight.w400)),
              TextSpan(text: 'connect', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ]),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: fontSize, color: color, letterSpacing: -fontSize * 0.03, height: 1),
          ),
        ),
      ],
    );
  }
}
