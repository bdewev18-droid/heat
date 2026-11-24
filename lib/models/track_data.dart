import 'dart:math' as math;
import 'dart:ui';

/// Représente une ligne de virage officielle sur le circuit.
class TrackCorner {
  const TrackCorner({
    required this.id,
    required this.name,
    required this.afterSpaceNumber,
    required this.speedLimit,
    required this.linePosition,
  });

  final int id;
  final String name;

  /// Numéro de la case (1..62) située juste AVANT la ligne de virage (repère "0").
  /// Franchir la ligne correspond au passage de `afterSpaceNumber` à `afterSpaceNumber + 1`.
  final int afterSpaceNumber;

  /// Limite de vitesse indiquée dans le cercle blanc sur le plateau.
  final int speedLimit;

  /// Position normalisée (x, y) du milieu de la ligne de virage sur l'image.
  final Offset linePosition;
}

/// Occurrence d'un virage franchi pendant un tour précis.
class CrossedCornerEvent {
  const CrossedCornerEvent({
    required this.corner,
    required this.spaceBeforeCornerProgress,
  });

  final TrackCorner corner;

  /// Progression exacte de la case juste avant cette ligne de virage
  /// (utilisée pour replacer la voiture en cas de tête-à-queue).
  final int spaceBeforeCornerProgress;
}

/// Information de repère calculée entre la voiture et le prochain virage.
class NextCornerInfo {
  const NextCornerInfo({
    required this.corner,
    required this.spacesBeforeCorner,
    required this.markerProgressList,
  });

  /// Prochain virage à venir (null si seule la ligne d'arrivée finale reste devant).
  final TrackCorner? corner;

  /// Nombre exact de cases pouvant être parcourues SANS franchir le prochain virage
  /// (0 = voiture collée à la ligne de virage, donc +1 la franchit).
  final int spacesBeforeCorner;

  /// Progressions des cases situées entre la voiture et la ligne du prochain virage.
  final List<int> markerProgressList;

  int get spacesToCrossCorner => spacesBeforeCorner + 1;
}

/// Représente une case du circuit sur l'image normalisée [0..1] x [0..1].
class TrackSpace {
  const TrackSpace({
    required this.index,
    required this.spaceNumber,
    required this.position,
    required this.angle,
    required this.distanceToNextCorner,
    required this.nextCornerSpeedLimit,
  });

  /// Index 0..61 (0 = case 1 juste après la ligne d'arrivée, 61 = case 62 sur la grille).
  final int index;

  /// Numéro de case 1..62.
  final int spaceNumber;

  /// Position normalisée (x, y) entre 0.0 et 1.0 sur l'image du plateau.
  final Offset position;

  /// Orientation de la voiture en radians (sens horaire autour du circuit).
  final double angle;

  /// Compte à rebours jusqu'au prochain virage (0 = juste avant la ligne de virage).
  final int distanceToNextCorner;

  /// Limite de vitesse du prochain virage.
  final int nextCornerSpeedLimit;

  /// Position centrée sur la case :
  /// - Si la voiture est seule sur la case (`isSharedSpace == false`), elle est
  ///   placée exactement au centre géométrique de la case (`position`).
  /// - Si 2 voitures partagent la case, elles se répartissent proprement au
  ///   centre de chaque demi-voie (corde / extérieur).
  Offset positionForLane(int lane, {bool isSharedSpace = false}) {
    if (!isSharedSpace) return position;
    final nx = -math.sin(angle);
    final ny = math.cos(angle);
    final sign = lane == 0 ? 1.0 : -1.0;
    const visualOffset = 0.0105;
    return Offset(
      position.dx + (nx * visualOffset * sign) / DeutschlandTrack.imageAspectRatio,
      position.dy + (ny * visualOffset * sign),
    );
  }
}

class _TrackSegmentSpec {
  const _TrackSegmentSpec({
    required this.spaceCount,
    required this.points,
    required this.nextCornerSpeedLimit,
    required this.countdownEnd,
  });

  final int spaceCount;
  final List<Offset> points;
  final int nextCornerSpeedLimit;
  final int countdownEnd;
}

/// Circuit de l'Allemagne (Deutschland) :
/// 62 cases, 2 tours, 6 virages (5, 2, 2, 6, 4, 4), 5 Heat moteur, 3 Stress.
class DeutschlandTrack {
  DeutschlandTrack._();

  static const String name = 'Deutschland';
  static const int totalSpaces = 62;
  static const int defaultLaps = 2;
  static const int engineHeatCount = 5;
  static const int stressCount = 3;
  static const double imageAspectRatio = 1024 / 699;

  static const List<TrackCorner> corners = [
    TrackCorner(
      id: 1,
      name: 'Virage 1 (Épingle Nord-Ouest)',
      afterSpaceNumber: 11,
      speedLimit: 5,
      linePosition: Offset(0.078, 0.235),
    ),
    TrackCorner(
      id: 2,
      name: 'Virage 2 (Entrée Chicane)',
      afterSpaceNumber: 23,
      speedLimit: 2,
      linePosition: Offset(0.526, 0.185),
    ),
    TrackCorner(
      id: 3,
      name: 'Virage 3 (Sortie Chicane)',
      afterSpaceNumber: 24,
      speedLimit: 2,
      linePosition: Offset(0.578, 0.180),
    ),
    TrackCorner(
      id: 4,
      name: 'Virage 4 (Courbe Sud-Est)',
      afterSpaceNumber: 37,
      speedLimit: 6,
      linePosition: Offset(0.870, 0.835),
    ),
    TrackCorner(
      id: 5,
      name: 'Virage 5 (Épingle Sud)',
      afterSpaceNumber: 45,
      speedLimit: 4,
      linePosition: Offset(0.520, 0.840),
    ),
    TrackCorner(
      id: 6,
      name: 'Virage 6 (Retour Ligne Droite)',
      afterSpaceNumber: 52,
      speedLimit: 4,
      linePosition: Offset(0.790, 0.705),
    ),
  ];

  static final List<TrackSpace> spaces = _buildSpaces();

  /// Retourne la case visuelle correspondant à une progression `progress`.
  /// - `progress == 0` : case 62 (grille positions 1 & 2, juste derrière la ligne)
  /// - `progress == -1` : case 61 (grille positions 3 & 4)
  /// - `progress >= 1` : case `((progress - 1) % 62) + 1`
  static TrackSpace spaceForProgress(int progress) {
    final idx = ((progress - 1) % totalSpaces + totalSpaces) % totalSpaces;
    return spaces[idx];
  }

  /// Numéro de tour courant (1..totalLaps, ou > totalLaps si ligne finale franchie).
  static int lapForProgress(int progress) {
    if (progress <= 0) return 1;
    return ((progress - 1) ~/ totalSpaces) + 1;
  }

  /// Calcule dynamiquement les repères entre la position actuelle `progress`
  /// de la voiture et le prochain virage (ou la ligne d'arrivée finale).
  static NextCornerInfo nextCornerInfo({
    required int progress,
    int totalLaps = defaultLaps,
  }) {
    final finishProgress = totalLaps * totalSpaces;
    if (progress >= finishProgress) {
      return const NextCornerInfo(
        corner: null,
        spacesBeforeCorner: 0,
        markerProgressList: [],
      );
    }

    // Parcours pas à pas à partir de progress jusqu'au premier virage ou à l'arrivée
    final markers = <int>[];
    for (var p = progress; p < finishProgress; p++) {
      if (p > 0) {
        final spaceNum = ((p - 1) % totalSpaces) + 1;
        for (final corner in corners) {
          if (corner.afterSpaceNumber == spaceNum) {
            return NextCornerInfo(
              corner: corner,
              spacesBeforeCorner: markers.length,
              markerProgressList: markers,
            );
          }
        }
      }
      markers.add(p + 1);
    }

    // Plus aucun virage avant la ligne d'arrivée finale
    return NextCornerInfo(
      corner: null,
      spacesBeforeCorner: markers.length,
      markerProgressList: markers,
    );
  }

  /// Liste ordonnée des lignes de virages franchies en avançant de `fromProgress`
  /// à `toProgress` (en ignorant tout virage après la ligne d'arrivée finale, p. 7).
  static List<CrossedCornerEvent> crossedCorners({
    required int fromProgress,
    required int toProgress,
    int totalLaps = defaultLaps,
  }) {
    if (toProgress <= fromProgress) return const [];

    final finishProgress = totalLaps * totalSpaces;
    final crossed = <CrossedCornerEvent>[];

    for (var p = fromProgress; p < toProgress; p++) {
      if (p >= finishProgress) break;
      if (p <= 0) continue;

      final spaceNum = ((p - 1) % totalSpaces) + 1;
      for (final corner in corners) {
        if (corner.afterSpaceNumber == spaceNum) {
          crossed.add(
            CrossedCornerEvent(
              corner: corner,
              spaceBeforeCornerProgress: p,
            ),
          );
        }
      }
    }
    return crossed;
  }

  static const List<_TrackSegmentSpec> _segments = [
    // Segment 0 : Ligne d'arrivée -> Virage 1 (5) : 11 cases (10..0)
    _TrackSegmentSpec(
      spaceCount: 11,
      nextCornerSpeedLimit: 5,
      countdownEnd: 0,
      points: [
        Offset(0.457, 0.470),
        Offset(0.325, 0.479),
        Offset(0.210, 0.460),
        Offset(0.112, 0.368),
        Offset(0.078, 0.235),
      ],
    ),
    // Segment 1 : Virage 1 (5) -> Virage 2 (2) : 12 cases (11..0)
    _TrackSegmentSpec(
      spaceCount: 12,
      nextCornerSpeedLimit: 2,
      countdownEnd: 0,
      points: [
        Offset(0.078, 0.235),
        Offset(0.092, 0.138),
        Offset(0.165, 0.098),
        Offset(0.300, 0.112),
        Offset(0.440, 0.148),
        Offset(0.526, 0.185),
      ],
    ),
    // Segment 2 : Virage 2 (2) -> Virage 3 (2) : 1 case (0)
    _TrackSegmentSpec(
      spaceCount: 1,
      nextCornerSpeedLimit: 2,
      countdownEnd: 0,
      points: [
        Offset(0.526, 0.185),
        Offset(0.578, 0.180),
      ],
    ),
    // Segment 3 : Virage 3 (2) -> Virage 4 (6) : 13 cases (12..0)
    _TrackSegmentSpec(
      spaceCount: 13,
      nextCornerSpeedLimit: 6,
      countdownEnd: 0,
      points: [
        Offset(0.578, 0.180),
        Offset(0.670, 0.270),
        Offset(0.780, 0.390),
        Offset(0.840, 0.495),
        Offset(0.870, 0.625),
        Offset(0.882, 0.755),
        Offset(0.870, 0.835),
      ],
    ),
    // Segment 4 : Virage 4 (6) -> Virage 5 (4) : 8 cases (7..0)
    _TrackSegmentSpec(
      spaceCount: 8,
      nextCornerSpeedLimit: 4,
      countdownEnd: 0,
      points: [
        Offset(0.870, 0.835),
        Offset(0.818, 0.885),
        Offset(0.680, 0.903),
        Offset(0.562, 0.893),
        Offset(0.520, 0.840),
      ],
    ),
    // Segment 5 : Virage 5 (4) -> Virage 6 (4) : 7 cases (6..0)
    _TrackSegmentSpec(
      spaceCount: 7,
      nextCornerSpeedLimit: 4,
      countdownEnd: 0,
      points: [
        Offset(0.520, 0.840),
        Offset(0.515, 0.765),
        Offset(0.560, 0.708),
        Offset(0.655, 0.728),
        Offset(0.745, 0.742),
        Offset(0.790, 0.700),
      ],
    ),
    // Segment 6 : Virage 6 (4) -> Ligne d'arrivée : 10 cases (20..11)
    _TrackSegmentSpec(
      spaceCount: 10,
      nextCornerSpeedLimit: 5,
      countdownEnd: 11,
      points: [
        Offset(0.790, 0.700),
        Offset(0.805, 0.618),
        Offset(0.768, 0.548),
        Offset(0.685, 0.495),
        Offset(0.585, 0.468),
        Offset(0.457, 0.470),
      ],
    ),
  ];

  static List<TrackSpace> _buildSpaces() {
    final result = <TrackSpace>[];
    var spaceIdx = 0;

    for (final seg in _segments) {
      final pts = seg.points;
      final cumLen = <double>[0.0];
      var totalLen = 0.0;

      for (var i = 0; i < pts.length - 1; i++) {
        final dx = (pts[i + 1].dx - pts[i].dx) * imageAspectRatio;
        final dy = pts[i + 1].dy - pts[i].dy;
        totalLen += math.sqrt(dx * dx + dy * dy);
        cumLen.add(totalLen);
      }

      Offset sampleAt(double targetDist) {
        final d = targetDist.clamp(0.0, totalLen);
        for (var i = 0; i < pts.length - 1; i++) {
          if (d <= cumLen[i + 1] || i == pts.length - 2) {
            final segLen = cumLen[i + 1] - cumLen[i];
            final t = segLen == 0 ? 0.0 : (d - cumLen[i]) / segLen;
            return Offset(
              pts[i].dx + (pts[i + 1].dx - pts[i].dx) * t,
              pts[i].dy + (pts[i + 1].dy - pts[i].dy) * t,
            );
          }
        }
        return pts.last;
      }

      for (var k = 0; k < seg.spaceCount; k++) {
        final dist = ((k + 0.5) / seg.spaceCount) * totalLen;
        final aheadDist = math.min(totalLen, dist + totalLen * 0.04);
        final behindDist = math.max(0.0, dist - totalLen * 0.04);
        final pos = sampleAt(dist);
        final p1 = sampleAt(behindDist);
        final p2 = sampleAt(aheadDist);
        final angle = math.atan2(
          p2.dy - p1.dy,
          (p2.dx - p1.dx) * imageAspectRatio,
        );
        final countdown = seg.countdownEnd + (seg.spaceCount - 1 - k);

        result.add(
          TrackSpace(
            index: spaceIdx,
            spaceNumber: spaceIdx + 1,
            position: pos,
            angle: angle,
            distanceToNextCorner: countdown,
            nextCornerSpeedLimit: seg.nextCornerSpeedLimit,
          ),
        );
        spaceIdx++;
      }
    }

    return result;
  }
}
