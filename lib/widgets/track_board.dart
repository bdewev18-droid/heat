import 'package:flutter/material.dart';
import '../models/shadow_bot.dart';
import '../models/track_data.dart';
import '../theme/heat_theme.dart';

/// Plateau Deutschland zoomable et déplaçable librement, avec les 3 voitures
/// (joueur + 2 bots shadow), repères dynamiques entre la voiture et le prochain
/// virage, et pastille "+1" cliquable pendant le déplacement.
class TrackBoard extends StatefulWidget {
  const TrackBoard({
    super.key,
    required this.racers,
    required this.playerProgress,
    required this.nextCornerInfo,
    required this.pendingStepsToMove,
    required this.showSpaceMarkers,
    this.activeRacerId,
    this.onStepForwardTapped,
    this.onBoardTouchChanged,
  });

  final List<RacerTrackState> racers;
  final int playerProgress;
  final NextCornerInfo nextCornerInfo;
  final int pendingStepsToMove;
  final bool showSpaceMarkers;
  final String? activeRacerId;
  final VoidCallback? onStepForwardTapped;
  final ValueChanged<bool>? onBoardTouchChanged;

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
      _transformController.value =
          nextScale <= 1.01 ? Matrix4.identity() : matrix;
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _centerOnCar() {
    if (_viewportSize == Size.zero) return;
    final carSpace = DeutschlandTrack.spaceForProgress(widget.playerProgress);
    final targetScale = _currentScale < 2.0 ? 2.4 : _currentScale;

    final boardRect = _computeBoardRect(_viewportSize);
    final carSceneX = boardRect.left + carSpace.position.dx * boardRect.width;
    final carSceneY = boardRect.top + carSpace.position.dy * boardRect.height;

    final tx = _viewportSize.width / 2 - carSceneX * targetScale;
    final ty = _viewportSize.height / 2 - carSceneY * targetScale;

    final matrix = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(targetScale, targetScale, 1, 1);

    setState(() {
      _transformController.value = matrix;
    });
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
    final previewSpaces = <TrackSpace>[];
    for (var s = 1; s <= widget.pendingStepsToMove; s++) {
      previewSpaces.add(
        DeutschlandTrack.spaceForProgress(widget.playerProgress + s),
      );
    }
    final nextSpace = previewSpaces.isEmpty ? null : previewSpaces.first;
    final cornerInfo = widget.nextCornerInfo;

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

            return Listener(
              onPointerDown: (_) => widget.onBoardTouchChanged?.call(true),
              onPointerUp: (_) => widget.onBoardTouchChanged?.call(false),
              onPointerCancel: (_) => widget.onBoardTouchChanged?.call(false),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: _minScale,
                      maxScale: _maxScale,
                      panEnabled: true,
                      scaleEnabled: true,
                      panAxis: PanAxis.free,
                      boundaryMargin: const EdgeInsets.all(260),
                      child: SizedBox(
                        width: _viewportSize.width,
                        height: _viewportSize.height,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: DeutschlandTrack.imageAspectRatio,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final height = constraints.maxHeight;
                                // Taille proportionnelle à 1 voie de la piste
                                final carLength =
                                    (width * 0.027).clamp(13.0, 25.0);
                                final carThickness = carLength * 0.54;

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      'assets/images/deutschland.jpg',
                                      fit: BoxFit.fill,
                                    ),

                                    // Repères dynamiques calculés UNIQUEMENT entre
                                    // la voiture du joueur et le prochain virage
                                    if (widget.showSpaceMarkers) ...[
                                      ...cornerInfo.markerProgressList
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final stepDistance = entry.key + 1;
                                        final space =
                                            DeutschlandTrack.spaceForProgress(
                                          entry.value,
                                        );
                                        final isLastBeforeCorner =
                                            stepDistance ==
                                                cornerInfo.spacesBeforeCorner;
                                        final markerSize =
                                            (width * 0.017).clamp(11.0, 17.0);
                                        return Positioned(
                                          left: space.position.dx * width -
                                              markerSize / 2,
                                          top: space.position.dy * height -
                                              markerSize / 2,
                                          child: IgnorePointer(
                                            child: Container(
                                              width: markerSize,
                                              height: markerSize,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isLastBeforeCorner
                                                    ? HeatColors.heatOrange
                                                    : HeatColors.navyHeader
                                                        .withValues(alpha: 0.86),
                                                border: Border.all(
                                                  color: HeatColors.heatGold,
                                                  width: isLastBeforeCorner
                                                      ? 1.6
                                                      : 1.0,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$stepDistance',
                                                style: TextStyle(
                                                  fontSize: markerSize * 0.54,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (cornerInfo.corner != null)
                                        Positioned(
                                          left: cornerInfo
                                                      .corner!.linePosition.dx *
                                                  width -
                                              (width * 0.013).clamp(9.0, 13.0),
                                          top: cornerInfo
                                                      .corner!.linePosition.dy *
                                                  height -
                                              (width * 0.013).clamp(9.0, 13.0),
                                          child: IgnorePointer(
                                            child: Container(
                                              width: (width * 0.026)
                                                  .clamp(18.0, 26.0),
                                              height: (width * 0.026)
                                                  .clamp(18.0, 26.0),
                                              decoration: BoxDecoration(
                                                color: HeatColors.heatRed,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: HeatColors.heatGold,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: HeatColors.heatRed
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${cornerInfo.corner!.speedLimit}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: (width * 0.014)
                                                      .clamp(10.0, 14.0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],

                                    // Trajectoire restante pendant un déplacement
                                    ...previewSpaces.skip(1).map((space) {
                                      final dotSize =
                                          (width * 0.014).clamp(8.0, 13.0);
                                      return Positioned(
                                        left: space.position.dx * width -
                                            dotSize / 2,
                                        top: space.position.dy * height -
                                            dotSize / 2,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: dotSize,
                                            height: dotSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: HeatColors.heatGold
                                                  .withValues(alpha: 0.78),
                                              border: Border.all(
                                                color: HeatColors.navyHeader,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                    // Pastille "+1" cliquable sur la case suivante
                                    if (nextSpace != null)
                                      Positioned(
                                        left: nextSpace.position.dx * width -
                                            (carLength * 0.52),
                                        top: nextSpace.position.dy * height -
                                            (carLength * 0.52),
                                        child: GestureDetector(
                                          onTap: widget.onStepForwardTapped,
                                          child: Container(
                                            width: carLength * 1.04,
                                            height: carLength * 1.04,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: HeatColors.heatGold
                                                  .withValues(alpha: 0.94),
                                              border: Border.all(
                                                color: HeatColors.heatRed,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: HeatColors.heatOrange
                                                      .withValues(alpha: 0.65),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '+1',
                                              style: TextStyle(
                                                fontSize: (carLength * 0.42)
                                                    .clamp(8.0, 12.0),
                                                fontWeight: FontWeight.w900,
                                                color: HeatColors.navyHeader,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Affichage des 3 voitures (bots puis joueur au-dessus)
                                    ...widget.racers
                                        .where((r) => !r.isHuman)
                                        .map(
                                          (bot) => _buildPositionedCar(
                                            racer: bot,
                                            width: width,
                                            height: height,
                                            carLength: carLength,
                                            carThickness: carThickness,
                                          ),
                                        ),
                                    ...widget.racers
                                        .where((r) => r.isHuman)
                                        .map(
                                          (player) => _buildPositionedCar(
                                            racer: player,
                                            width: width,
                                            height: height,
                                            carLength: carLength,
                                            carThickness: carThickness,
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
                  ),

                  // Contrôles de zoom flottants
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: HeatColors.navyHeader.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: HeatColors.heatGold.withValues(alpha: 0.7),
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
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
                            height: 4,
                            thickness: 1,
                            color: Colors.white24,
                          ),
                          _ZoomIconButton(
                            icon: Icons.my_location,
                            tooltip: 'Centrer sur ta voiture',
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

                  // Bandeau repère dynamique : distance voiture → prochain virage
                  Positioned(
                    left: 8,
                    top: 8,
                    right: 54,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: HeatColors.navyHeader.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HeatColors.heatGold),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cornerInfo.corner != null
                                  ? Icons.turn_right
                                  : Icons.sports_score,
                              size: 15,
                              color: HeatColors.heatGold,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                cornerInfo.corner != null
                                    ? 'Avant virage : ${cornerInfo.spacesBeforeCorner} case(s) • '
                                        'Franchit à ${cornerInfo.spacesToCrossCorner}+ • '
                                        'Limite ${cornerInfo.corner!.speedLimit}'
                                    : 'Ligne d\'arrivée finale dans ${cornerInfo.spacesBeforeCorner} case(s) !',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPositionedCar({
    required RacerTrackState racer,
    required double width,
    required double height,
    required double carLength,
    required double carThickness,
  }) {
    final space = DeutschlandTrack.spaceForProgress(racer.progress);
    final carsOnSameSpace = widget.racers
        .where((other) => !other.finished && other.progress == racer.progress)
        .length;
    final pos = space.positionForLane(
      racer.lane,
      isSharedSpace: carsOnSameSpace > 1,
    );
    final isActive = widget.activeRacerId == racer.id;

    return AnimatedPositioned(
      key: ValueKey('car_${racer.id}'),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      left: pos.dx * width - carLength / 2,
      top: pos.dy * height - carThickness / 2,
      child: IgnorePointer(
        child: Transform.rotate(
          alignment: Alignment.center,
          angle: space.angle,
          child: Container(
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(carThickness),
                    boxShadow: [
                      BoxShadow(
                        color: HeatColors.heatGold.withValues(alpha: 0.9),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: _RaceCarWidget(
              width: carLength,
              height: carThickness,
              bodyColor: racer.color,
              isPlayer: racer.isHuman,
            ),
          ),
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
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _RaceCarWidget extends StatelessWidget {
  const _RaceCarWidget({
    required this.width,
    required this.height,
    required this.bodyColor,
    required this.isPlayer,
  });

  final double width;
  final double height;
  final Color bodyColor;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _RaceCarPainter(
          bodyColor: bodyColor,
          isPlayer: isPlayer,
        ),
      ),
    );
  }
}

class _RaceCarPainter extends CustomPainter {
  const _RaceCarPainter({
    required this.bodyColor,
    required this.isPlayer,
  });

  final Color bodyColor;
  final bool isPlayer;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.14, w * 0.9, h * 0.8),
        Radius.circular(h * 0.25),
      ),
      shadowPaint,
    );

    final tirePaint = Paint()..color = const Color(0xFF141619);
    final tireW = w * 0.22;
    final tireH = h * 0.26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, 0, tireW, tireH),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h - tireH, tireW, tireH),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.64, h * 0.04, tireW * 0.85, tireH * 0.9),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.64, h - tireH * 0.94, tireW * 0.85, tireH * 0.9),
        const Radius.circular(1.5),
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

    canvas.drawPath(bodyPath, Paint()..color = bodyColor);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = isPlayer ? HeatColors.heatGold : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPlayer ? 1.4 : 1.0,
    );

    canvas.drawLine(
      Offset(w * 0.52, h * 0.50),
      Offset(w * 0.90, h * 0.50),
      Paint()
        ..color = isPlayer ? HeatColors.heatGold : Colors.white70
        ..strokeWidth = h * 0.14,
    );

    canvas.drawCircle(
      Offset(w * 0.44, h * 0.50),
      h * 0.17,
      Paint()..color = const Color(0xFF1F2227),
    );
    canvas.drawCircle(
      Offset(w * 0.46, h * 0.50),
      h * 0.10,
      Paint()..color = isPlayer ? HeatColors.heatGold : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RaceCarPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor || oldDelegate.isPlayer != isPlayer;
}
