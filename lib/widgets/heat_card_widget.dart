import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/heat_card.dart';
import '../theme/heat_theme.dart';

/// Visuel stylisé des cartes Heat fidèle à la charte du livret PDF (p. 2, 5, 7).
class HeatCardWidget extends StatelessWidget {
  const HeatCardWidget({
    super.key,
    required this.card,
    this.width = 76,
    this.height = 108,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final HeatCard card;
  final double width;
  final double height;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? HeatColors.heatGold
                : (enabled ? const Color(0xFFD8D0C0) : Colors.black26),
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? HeatColors.heatOrange.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: selected ? 10 : 4,
              offset: Offset(0, selected ? 6 : 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3.5),
        child: Opacity(
          opacity: enabled || selected ? 1.0 : 0.52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CustomPaint(
              painter: _HeatCardArtPainter(card: card),
              child: _buildCardOverlay(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardOverlay() {
    switch (card.type) {
      case HeatCardType.basic:
        return _buildSpeedOverlay(isBasic: true);
      case HeatCardType.upgradeSpeed:
        return _buildSpeedOverlay(isBasic: false);
      case HeatCardType.stress:
        return _buildStressOverlay();
      case HeatCardType.heat:
        return _buildHeatOverlay();
    }
  }

  Widget _buildSpeedOverlay({required bool isBasic}) {
    final value = '${card.speedValue ?? 0}';
    final compact = width < 64;

    return Stack(
      children: [
        // Coins supérieurs avec le chiffre de vitesse
        Positioned(
          top: 3,
          left: 4,
          child: _CornerNumberBadge(
            text: value,
            color: const Color(0xFF155B96),
            fontSize: compact ? 13 : 16,
          ),
        ),
        Positioned(
          top: 3,
          right: 4,
          child: _CornerNumberBadge(
            text: value,
            color: const Color(0xFF155B96),
            fontSize: compact ? 13 : 16,
          ),
        ),
        // Symbole tachymètre (Basic) au centre haut
        if (isBasic)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: compact ? 16 : 20,
                height: compact ? 16 : 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HeatColors.navyHeader,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.speed,
                  size: compact ? 11 : 13,
                  color: HeatColors.heatRed,
                ),
              ),
            ),
          ),
        // Grand chiffre discret en bas
        Positioned(
          bottom: 3,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: HeatColors.navyHeader.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isBasic ? 'BASIC' : 'UPGRADE',
                style: TextStyle(
                  fontSize: compact ? 6.5 : 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: isBasic ? Colors.white : HeatColors.heatGold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStressOverlay() {
    final compact = width < 64;
    return Stack(
      children: [
        Positioned(
          top: 3,
          left: 4,
          child: _CornerNumberBadge(
            text: '+',
            color: HeatColors.stressPurple,
            fontSize: compact ? 14 : 17,
          ),
        ),
        Positioned(
          top: 3,
          right: 4,
          child: _CornerNumberBadge(
            text: '+',
            color: HeatColors.stressPurple,
            fontSize: compact ? 14 : 17,
          ),
        ),
        // Symbole "Ne peut pas être défaussée"
        Positioned(
          top: compact ? 22 : 26,
          right: 4,
          child: _NoDiscardIcon(size: compact ? 13 : 16),
        ),
        Positioned(
          bottom: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: HeatColors.stressPurple.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'STRESS',
                style: TextStyle(
                  fontSize: compact ? 7 : 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeatOverlay() {
    final compact = width < 64;
    return Stack(
      children: [
        Positioned(
          top: 4,
          left: 4,
          child: _NoDiscardIcon(size: compact ? 13 : 16),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _NoDiscardIcon(size: compact ? 13 : 16),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: compact ? 26 : 34,
                color: const Color(0xFFFFE066),
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF7D110A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: HeatColors.heatGold.withValues(alpha: 0.7),
                  width: 0.8,
                ),
              ),
              child: Text(
                'HEAT',
                style: TextStyle(
                  fontSize: compact ? 7.5 : 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: const Color(0xFFFFDF70),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dos de carte damier noir et blanc (comme sur les plateaux joueurs p. 3 & 5).
class HeatCardBackWidget extends StatelessWidget {
  const HeatCardBackWidget({
    super.key,
    this.width = 64,
    this.height = 90,
    this.count,
    this.onTap,
  });

  final double width;
  final double height;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HeatColors.navyHeader, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _CheckeredBackPainter()),
              if (count != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: HeatColors.navyHeader.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HeatColors.heatGold, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerNumberBadge extends StatelessWidget {
  const _CornerNumberBadge({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
      ),
    );
  }
}

class _NoDiscardIcon extends StatelessWidget {
  const _NoDiscardIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF8C1410),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white70, width: 0.8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.delete_outline, size: size * 0.72, color: Colors.white70),
          Icon(Icons.close, size: size * 0.82, color: const Color(0xFFFF5252)),
        ],
      ),
    );
  }
}

class _HeatCardArtPainter extends CustomPainter {
  const _HeatCardArtPainter({required this.card});

  final HeatCard card;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (card.isHeat) {
      _paintHeatBackground(canvas, w, h);
    } else if (card.isStress) {
      _paintStressBackground(canvas, w, h);
    } else {
      _paintSpeedBackground(canvas, w, h, card.speedValue ?? 1);
    }

    // Chevrons jaunes sur les côtés pour les cartes Amélioration de départ (p. 2 & 7)
    if (card.isStartingUpgrade) {
      _paintUpgradeChevrons(canvas, w, h);
    }
  }

  void _paintSpeedBackground(Canvas canvas, double w, double h, int value) {
    // Ciel d'été vintage -> herbe -> piste asphalte
    final skyColors = switch (value) {
      0 => [const Color(0xFF9AC5DC), const Color(0xFFE7DFB8)],
      1 => [const Color(0xFF7CB6D4), const Color(0xFFD6E4D2)],
      2 => [const Color(0xFF5FA6D1), const Color(0xFFD8DFB7)],
      3 => [const Color(0xFF3E8DC7), const Color(0xFFF0D49B)],
      4 => [const Color(0xFF2873B8), const Color(0xFFF2BE7A)],
      _ => [const Color(0xFF1A5A9E), const Color(0xFFF6A55D)],
    };

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.56),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: skyColors,
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.56)),
    );

    // Colline / verdure vintage
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.48, w, h * 0.16),
      Paint()..color = const Color(0xFF6B8E4E),
    );

    // Piste asphalte en perspective
    final roadPath = Path()
      ..moveTo(w * 0.34, h * 0.52)
      ..lineTo(w * 0.66, h * 0.52)
      ..lineTo(w * 1.05, h)
      ..lineTo(-w * 0.05, h)
      ..close();
    canvas.drawPath(roadPath, Paint()..color = const Color(0xFF474E56));

    // Ligne blanche centrale
    canvas.drawLine(
      Offset(w * 0.5, h * 0.54),
      Offset(w * 0.5, h * 0.96),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.4,
    );

    // Silhouette de voiture de course vintage (plus proche quand la vitesse est haute)
    final carScale = (0.45 + value * 0.11).clamp(0.45, 0.95);
    final carW = w * 0.58 * carScale;
    final carH = h * 0.20 * carScale;
    final cx = w * 0.5;
    final cy = h * 0.69;

    // Pneus
    final tirePaint = Paint()..color = const Color(0xFF1A1D21);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - carW * 0.44, cy + carH * 0.1),
          width: carW * 0.22,
          height: carH * 0.72,
        ),
        const Radius.circular(3),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + carW * 0.44, cy + carH * 0.1),
          width: carW * 0.22,
          height: carH * 0.72,
        ),
        const Radius.circular(3),
      ),
      tirePaint,
    );

    // Carrosserie bleu & bande blanche racing
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: carW * 0.66, height: carH),
      Radius.circular(carH * 0.45),
    );
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFF1A6AB3));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: carW * 0.14,
        height: carH * 0.95,
      ),
      Paint()..color = Colors.white,
    );
  }

  void _paintStressBackground(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF473373),
            Color(0xFFC5CEB0),
            Color(0xFF3E3A47),
          ],
          stops: [0.0, 0.46, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Rayons de vitesse floutés
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(w * 0.5, h * 0.34),
        Offset(w * (0.5 + i * 0.28), h),
        rayPaint,
      );
    }

    // Volant de course au centre bas
    final wheelCenter = Offset(w * 0.5, h * 0.66);
    final wheelRadius = w * 0.26;
    canvas.drawCircle(
      wheelCenter,
      wheelRadius,
      Paint()
        ..color = const Color(0xFF231F26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      Offset(wheelCenter.dx - wheelRadius, wheelCenter.dy),
      Offset(wheelCenter.dx + wheelRadius, wheelCenter.dy),
      Paint()
        ..color = const Color(0xFF9EA4B0)
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      wheelCenter,
      Offset(wheelCenter.dx, wheelCenter.dy + wheelRadius),
      Paint()
        ..color = const Color(0xFF9EA4B0)
        ..strokeWidth = 2.5,
    );
  }

  void _paintHeatBackground(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.95,
          colors: [
            Color(0xFFFFC12B),
            Color(0xFFF25C19),
            Color(0xFFB71B15),
            Color(0xFF5D0D0A),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Cylindres / moteur stylisé en arrière-plan
    final enginePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final y = h * (0.28 + i * 0.16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.5, y), width: w * 0.55, height: 10),
          const Radius.circular(3),
        ),
        enginePaint,
      );
    }
  }

  void _paintUpgradeChevrons(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = HeatColors.heatGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final y = h * (0.34 + i * 0.10);
      // Gauche
      final left = Path()
        ..moveTo(2, y + 4)
        ..lineTo(6.5, y)
        ..lineTo(11, y + 4);
      canvas.drawPath(left, paint);
      // Droite
      final right = Path()
        ..moveTo(w - 11, y + 4)
        ..lineTo(w - 6.5, y)
        ..lineTo(w - 2, y + 4);
      canvas.drawPath(right, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatCardArtPainter oldDelegate) =>
      oldDelegate.card.id != card.id;
}

class _CheckeredBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cols = 4;
    const rows = 6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final isDark = (r + c).isEven;
        // Légère distorsion de perspective façon drapeau
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW + 0.5, cellH + 0.5);
        canvas.drawRect(
          rect,
          Paint()
            ..color = isDark
                ? const Color(0xFF1A1E24)
                : const Color(0xFFF5F1E6),
        );
      }
    }

    // Subtil reflet diagonal
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            Colors.black.withValues(alpha: math.pi * 0.05),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
