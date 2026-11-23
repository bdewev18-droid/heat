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

  /// Valeur du compte à rebours sur la dernière case du segment (0 avant un virage,
  /// 11 juste avant la ligne d'arrivée).
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

  /// Les 6 virages officiels lus directement sur le plateau Deutschland :
  /// Segments : 11 + 12 + 1 + 13 + 8 + 7 + 10 = 62 cases exactes.
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

  /// Retourne la case visuelle correspondant à une progression totale `progress`.
  /// `progress == 0` correspond à la Pole Position (case 62, juste derrière la ligne).
  static TrackSpace spaceForProgress(int progress) {
    if (progress <= 0) {
      return spaces[totalSpaces - 1];
    }
    final index = (progress - 1) % totalSpaces;
    return spaces[index];
  }

  /// Numéro de tour courant (1..totalLaps, ou > totalLaps si ligne finale franchie).
  static int lapForProgress(int progress) {
    if (progress <= 0) return 1;
    return ((progress - 1) ~/ totalSpaces) + 1;
  }

  /// Liste ordonnée des lignes de virages franchies en avançant de `fromProgress`
  /// à `toProgress` (en ignorant tout virage situé après la ligne d'arrivée finale,
  /// conformément à la règle p. 7).
  static List<CrossedCornerEvent> crossedCorners({
    required int fromProgress,
    required int toProgress,
    int totalLaps = defaultLaps,
  }) {
    if (toProgress <= fromProgress) return const [];

    final finishProgress = totalLaps * totalSpaces;
    final crossed = <CrossedCornerEvent>[];

    for (var p = fromProgress; p < toProgress; p++) {
      // Après la ligne d'arrivée finale, on ignore les limites de virages (p. 7).
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
        Offset(0.457, 0.473),
        Offset(0.325, 0.480),
        Offset(0.210, 0.462),
        Offset(0.112, 0.370),
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
        Offset(0.842, 0.495),
        Offset(0.876, 0.625),
        Offset(0.885, 0.760),
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
        Offset(0.680, 0.905),
        Offset(0.562, 0.895),
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
        Offset(0.660, 0.728),
        Offset(0.752, 0.750),
        Offset(0.790, 0.705),
      ],
    ),
    // Segment 6 : Virage 6 (4) -> Ligne d'arrivée : 10 cases (20..11)
    _TrackSegmentSpec(
      spaceCount: 10,
      nextCornerSpeedLimit: 5,
      countdownEnd: 11,
      points: [
        Offset(0.790, 0.705),
        Offset(0.800, 0.625),
        Offset(0.730, 0.542),
        Offset(0.610, 0.502),
        Offset(0.530, 0.476),
        Offset(0.457, 0.473),
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
