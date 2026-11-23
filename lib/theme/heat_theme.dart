import 'package:flutter/material.dart';

/// Palette et composants graphiques inspirés du livret de règles Heat.
class HeatColors {
  HeatColors._();

  static const Color paperCream = Color(0xFFF6EDD8);
  static const Color paperCard = Color(0xFFFCF7EA);
  static const Color paperBorder = Color(0xFFD9C79E);

  static const Color navyHeader = Color(0xFF0B2E4C);
  static const Color navyMid = Color(0xFF134873);
  static const Color asphaltDark = Color(0xFF1B232B);
  static const Color inkDark = Color(0xFF231F20);
  static const Color inkMuted = Color(0xFF5D574C);

  static const Color heatRed = Color(0xFFD8231D);
  static const Color heatOrange = Color(0xFFF26519);
  static const Color heatGold = Color(0xFFF4B624);

  static const Color cooldownBlue = Color(0xFF1976B5);
  static const Color stressPurple = Color(0xFF5B418B);
  static const Color trackGreen = Color(0xFF2E7D32);
}

ThemeData buildHeatTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: HeatColors.paperCream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HeatColors.heatRed,
      primary: HeatColors.heatRed,
      secondary: HeatColors.navyHeader,
      surface: HeatColors.paperCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HeatColors.navyHeader,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: HeatColors.paperCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HeatColors.paperBorder, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HeatColors.heatRed,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

/// Bandeau bleu pétrole style livret de règles avec barre jaune et titre dégradé.
class HeatSectionBanner extends StatelessWidget {
  const HeatSectionBanner({
    super.key,
    required this.title,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            HeatColors.navyHeader,
            HeatColors.navyMid,
            Color(0xFF1E5F8F),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: compact ? 18 : 24,
            decoration: BoxDecoration(
              color: HeatColors.heatGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFD84D),
                  HeatColors.heatOrange,
                  HeatColors.heatRed,
                ],
              ).createShader(bounds),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: compact ? 14 : 18,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Logo HEAT: Pedal to the Metal inspiré de la couverture du livret PDF.
class HeatLogoWidget extends StatelessWidget {
  const HeatLogoWidget({super.key, this.scale = 1.0});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Ombre portée vintage
            Transform.translate(
              offset: Offset(3 * scale, 4 * scale),
              child: Text(
                'HEAT',
                style: TextStyle(
                  fontSize: 82 * scale,
                  height: 0.92,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6 * scale,
                  color: HeatColors.navyHeader.withValues(alpha: 0.35),
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFC91C17),
                  Color(0xFFE63B19),
                  Color(0xFFF6821F),
                  Color(0xFFFAC726),
                ],
              ).createShader(bounds),
              child: Text(
                'HEAT',
                style: TextStyle(
                  fontSize: 82 * scale,
                  height: 0.92,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6 * scale,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4 * scale),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: HeatColors.navyHeader,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: HeatColors.heatGold, width: 1.5),
          ),
          child: Text(
            'PEDAL TO THE METAL',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 3 * scale,
              color: HeatColors.heatGold,
            ),
          ),
        ),
      ],
    );
  }
}
