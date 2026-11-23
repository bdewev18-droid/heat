import 'package:flutter/material.dart';
import '../models/track_data.dart';
import '../theme/heat_theme.dart';

/// Plateau Deutschland zoomable avec voiture animée, repères de cases/virages
/// et interaction directe sur la case suivante pour avancer pas à pas.
class TrackBoard extends StatefulWidget {
  const TrackBoard({
    super.key,
    required this.carProgress,
    required this.pendingStepsToMove,
    required this.showSpaceMarkers,
    this.onStepForwardTapped,
  });

  final int carProgress;
  final int pendingStepsToMove;
  final bool showSpaceMarkers;
  final VoidCallback? onStepForwardTapped;

  @override
  State<TrackBoard> createState() => _TrackBoardState();
}

class _TrackBoardState extends State<TrackBoard> {
  final TransformationController _transformController =
      TransformationController();
  Size _viewportSize = Size.zero;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.5;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  double get _currentScale => _transformController.value.getMaxScaleOnAxis();

  void _zoomBy(double factor) {
    if (_viewportSize == Size.zero) return;
    final currentScale = _currentScale;
    final nextScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final actualFactor = nextScale / currentScale;
    if ((actualFactor - 1.0).abs() < 0.001) return;

    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final matrix = _transformController.value.clone();
    final sceneCenter = _transformController.toScene(center);

    matrix.translateByDouble(sceneCenter.dx, sceneCenter.dy, 0, 1);
    matrix.scaleByDouble(actualFactor, actualFactor, 1, 1);
    matrix.translateByDouble(-sceneCenter.dx, -sceneCenter.dy, 0, 1);

    setState(() {
      _transformController.value = _clampMatrix(matrix, nextScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _centerOnCar() {
    if (_viewportSize == Size.zero) return;
    final carSpace = DeutschlandTrack.spaceForProgress(widget.carProgress);
    final targetScale = _currentScale < 2.2 ? 2.6 : _currentScale;

    // Calcul du rectangle de l'image à l'intérieur du viewport (AspectRatio centré).
    final boardRect = _computeBoardRect(_viewportSize);
    final carSceneX = boardRect.left + carSpace.position.dx * boardRect.width;
    final carSceneY = boardRect.top + carSpace.position.dy * boardRect.height;

    final tx = _viewportSize.width / 2 - carSceneX * targetScale;
    final ty = _viewportSize.height / 2 - carSceneY * targetScale;

    final matrix = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(targetScale, targetScale, 1, 1);

    setState(() {
      _transformController.value = _clampMatrix(matrix, targetScale);
    });
  }

  Matrix4 _clampMatrix(Matrix4 matrix, double scale) {
    if (scale <= 1.01) return Matrix4.identity();
    final minTx = _viewportSize.width * (1 - scale) - 40;
    final maxTx = 40.0;
    final minTy = _viewportSize.height * (1 - scale) - 40;
    final maxTy = 40.0;

    final tx = matrix.storage[12].clamp(minTx, maxTx);
    final ty = matrix.storage[13].clamp(minTy, maxTy);
    matrix.storage[12] = tx;
    matrix.storage[13] = ty;
    return matrix;
  }

  Rect _computeBoardRect(Size viewport) {
    const ratio = DeutschlandTrack.imageAspectRatio;
    final viewRatio = viewport.width / viewport.height;
    if (viewRatio > ratio) {
      final h = viewport.height;
      final w = h * ratio;
      return Rect.fromLTWH((viewport.width - w) / 2, 0, w, h);
    } else {
      final w = viewport.width;
      final h = w / ratio;
      return Rect.fromLTWH(0, (viewport.height - h) / 2, w, h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSpace = DeutschlandTrack.spaceForProgress(widget.carProgress);

    // Prévisualisation des prochaines cases à parcourir pendant le mouvement
    final previewSpaces = <TrackSpace>[];
    for (var s = 1; s <= widget.pendingStepsToMove; s++) {
      previewSpaces.add(
        DeutschlandTrack.spaceForProgress(widget.carProgress + s),
      );
    }
    final nextSpace = previewSpaces.isEmpty ? null : previewSpaces.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: HeatColors.asphaltDark,
          border: Border.all(color: HeatColors.navyHeader, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            _viewportSize = viewportConstraints.biggest;

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(60),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: DeutschlandTrack.imageAspectRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final height = constraints.maxHeight;
                          final carSize = (width * 0.044).clamp(22.0, 44.0);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/deutschland.jpg',
                                fit: BoxFit.fill,
                              ),

                              // Repères de toutes les cases (optionnel)
                              if (widget.showSpaceMarkers) ...[
                                ...DeutschlandTrack.spaces.map((space) {
                                  final isCurrent =
                                      space.index == currentSpace.index;
                                  final markerSize =
                                      (width * 0.018).clamp(11.0, 18.0);
                                  return Positioned(
                                    left: space.position.dx * width -
                                        markerSize / 2,
                                    top: space.position.dy * height -
                                        markerSize / 2,
                                    child: Container(
                                      width: markerSize,
                                      height: markerSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCurrent
                                            ? HeatColors.heatGold
                                            : Colors.black
                                                .withValues(alpha: 0.65),
                                        border: Border.all(
                                          color: isCurrent
                                              ? Colors.white
                                              : Colors.white54,
                                          width: 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${space.spaceNumber}',
                                        style: TextStyle(
                                          fontSize: markerSize * 0.5,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                ...DeutschlandTrack.corners.map((corner) {
                                  final badgeSize =
                                      (width * 0.025).clamp(16.0, 24.0);
                                  return Positioned(
                                    left: corner.linePosition.dx * width -
                                        badgeSize / 2,
                                    top: corner.linePosition.dy * height -
                                        badgeSize / 2,
                                    child: Container(
                                      width: badgeSize,
                                      height: badgeSize,
                                      decoration: BoxDecoration(
                                        color: HeatColors.heatRed,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${corner.speedLimit}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: badgeSize * 0.56,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],

                              // Points de trajectoire restants à avancer
                              ...previewSpaces.skip(1).map((space) {
                                final dotSize =
                                    (width * 0.017).clamp(10.0, 16.0);
                                return Positioned(
                                  left: space.position.dx * width - dotSize / 2,
                                  top: space.position.dy * height - dotSize / 2,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: dotSize,
                                      height: dotSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: HeatColors.heatGold
                                            .withValues(alpha: 0.72),
                                        border: Border.all(
                                          color: HeatColors.navyHeader,
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              // Case suivante cliquable pour avancer +1 directement sur la carte
                              if (nextSpace != null)
                                Positioned(
                                  left: nextSpace.position.dx * width -
                                      (carSize * 0.42),
                                  top: nextSpace.position.dy * height -
                                      (carSize * 0.42),
                                  child: GestureDetector(
                                    onTap: widget.onStepForwardTapped,
                                    child: Container(
                                      width: carSize * 0.84,
                                      height: carSize * 0.84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: HeatColors.heatGold
                                            .withValues(alpha: 0.92),
                                        border: Border.all(
                                          color: HeatColors.heatRed,
                                          width: 2.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: HeatColors.heatOrange
                                                .withValues(alpha: 0.65),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '+1',
                                        style: TextStyle(
                                          fontSize: (carSize * 0.34)
                                              .clamp(9.0, 14.0),
                                          fontWeight: FontWeight.w900,
                                          color: HeatColors.navyHeader,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Voiture du joueur
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                left: currentSpace.position.dx * width -
                                    carSize / 2,
                                top: currentSpace.position.dy * height -
                                    carSize / 2,
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

                // Contrôles de zoom flottants (accessibles mobile, web et desktop)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: HeatColors.navyHeader.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: HeatColors.heatGold.withValues(alpha: 0.65),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ZoomIconButton(
                          icon: Icons.add,
                          tooltip: 'Zoomer',
                          onPressed: () => _zoomBy(1.35),
                        ),
                        _ZoomIconButton(
                          icon: Icons.remove,
                          tooltip: 'Dézoomer',
                          onPressed: () => _zoomBy(1 / 1.35),
                        ),
                        const Divider(
                          height: 6,
                          thickness: 1,
                          color: Colors.white24,
                        ),
                        _ZoomIconButton(
                          icon: Icons.my_location,
                          tooltip: 'Centrer sur la voiture',
                          onPressed: _centerOnCar,
                        ),
                        _ZoomIconButton(
                          icon: Icons.fit_screen,
                          tooltip: 'Vue entière du circuit',
                          onPressed: _resetZoom,
                        ),
                      ],
                    ),
                  ),
                ),

                // Indicateur discret prochain virage en haut à gauche
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: HeatColors.navyHeader.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HeatColors.heatGold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.turn_right,
                          size: 16,
                          color: HeatColors.heatGold,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Prochain virage : ${currentSpace.distanceToNextCorner} cases • Limite ${currentSpace.nextCornerSpeedLimit}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ZoomIconButton extends StatelessWidget {
  const _ZoomIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19, color: Colors.white),
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
      child: CustomPaint(painter: _RaceCarPainter()),
    );
  }
}

class _RaceCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

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

    final tirePaint = Paint()..color = const Color(0xFF1A1A1A);
    final tireW = w * 0.22;
    final tireH = h * 0.24;
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

    final bodyPath = Path()
      ..moveTo(w * 0.06, h * 0.20)
      ..lineTo(w * 0.45, h * 0.16)
      ..lineTo(w * 0.96, h * 0.40)
      ..lineTo(w * 0.96, h * 0.60)
      ..lineTo(w * 0.45, h * 0.84)
      ..lineTo(w * 0.06, h * 0.80)
      ..close();

    canvas.drawPath(bodyPath, Paint()..color = HeatColors.heatRed);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Bande jaune racing sur le capot
    canvas.drawLine(
      Offset(w * 0.52, h * 0.50),
      Offset(w * 0.92, h * 0.50),
      Paint()
        ..color = HeatColors.heatGold
        ..strokeWidth = h * 0.12,
    );

    canvas.drawCircle(
      Offset(w * 0.44, h * 0.50),
      h * 0.16,
      Paint()..color = const Color(0xFF212121),
    );
    canvas.drawCircle(
      Offset(w * 0.46, h * 0.50),
      h * 0.10,
      Paint()..color = HeatColors.heatGold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
