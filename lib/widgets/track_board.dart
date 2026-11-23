import 'package:flutter/material.dart';
import '../models/track_data.dart';

/// Affiche le plateau Deutschland avec la voiture du joueur et les repères de cases.
class TrackBoard extends StatelessWidget {
  const TrackBoard({
    super.key,
    required this.carSpaceIndex,
    required this.showSpaceMarkers,
    this.onSpaceTapped,
  });

  final int carSpaceIndex;
  final bool showSpaceMarkers;
  final ValueChanged<int>? onSpaceTapped;

  @override
  Widget build(BuildContext context) {
    final currentSpace =
        DeutschlandTrack.spaces[carSpaceIndex % DeutschlandTrack.totalSpaces];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFF121417),
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.5,
          boundaryMargin: const EdgeInsets.all(24),
          child: Center(
            child: AspectRatio(
              aspectRatio: DeutschlandTrack.imageAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final carSize = (width * 0.042).clamp(22.0, 44.0);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/deutschland.jpg',
                        fit: BoxFit.fill,
                      ),
                      if (showSpaceMarkers)
                        ...DeutschlandTrack.spaces.map((space) {
                          final isCurrent = space.index == currentSpace.index;
                          final markerSize = (width * 0.018).clamp(10.0, 18.0);
                          return Positioned(
                            left: space.position.dx * width - markerSize / 2,
                            top: space.position.dy * height - markerSize / 2,
                            child: GestureDetector(
                              onTap: onSpaceTapped == null
                                  ? null
                                  : () => onSpaceTapped!(space.index),
                              child: Container(
                                width: markerSize,
                                height: markerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent
                                      ? Colors.amber
                                      : Colors.black.withValues(alpha: 0.65),
                                  border: Border.all(
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.white54,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${space.index + 1}',
                                  style: TextStyle(
                                    fontSize: markerSize * 0.52,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: currentSpace.position.dx * width - carSize / 2,
                        top: currentSpace.position.dy * height - carSize / 2,
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: currentSpace.angle,
                            child: _RaceCarWidget(size: carSize),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RaceCarWidget extends StatelessWidget {
  const _RaceCarWidget({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.58,
      child: CustomPaint(
        painter: _RaceCarPainter(),
      ),
    );
  }
}

class _RaceCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ombre portée sous la voiture
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.14, w * 0.9, h * 0.8),
        Radius.circular(h * 0.25),
      ),
      shadowPaint,
    );

    // 4 pneus noirs
    final tirePaint = Paint()..color = const Color(0xFF1A1A1A);
    final tireW = w * 0.22;
    final tireH = h * 0.24;
    // Arrière
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, 0, tireW, tireH),
        const Radius.circular(2),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h - tireH, tireW, tireH),
        const Radius.circular(2),
      ),
      tirePaint,
    );
    // Avant
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.64, h * 0.04, tireW * 0.85, tireH * 0.9),
        const Radius.circular(2),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.64, h - tireH * 0.94, tireW * 0.85, tireH * 0.9),
        const Radius.circular(2),
      ),
      tirePaint,
    );

    // Carrosserie rouge racing (nez orienté vers la droite)
    final bodyPath = Path()
      ..moveTo(w * 0.06, h * 0.20)
      ..lineTo(w * 0.45, h * 0.16)
      ..lineTo(w * 0.96, h * 0.40)
      ..lineTo(w * 0.96, h * 0.60)
      ..lineTo(w * 0.45, h * 0.84)
      ..lineTo(w * 0.06, h * 0.80)
      ..close();

    final bodyPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawPath(bodyPath, bodyPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(bodyPath, borderPaint);

    // Cockpit / casque
    canvas.drawCircle(
      Offset(w * 0.44, h * 0.50),
      h * 0.16,
      Paint()..color = const Color(0xFF212121),
    );
    canvas.drawCircle(
      Offset(w * 0.46, h * 0.50),
      h * 0.10,
      Paint()..color = const Color(0xFFFFCA28),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
