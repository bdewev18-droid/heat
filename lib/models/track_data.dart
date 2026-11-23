import 'dart:math' as math;
import 'dart:ui';

/// Représente une case du circuit sur l'image normalisée [0..1] x [0..1].
class TrackSpace {
  const TrackSpace({
    required this.index,
    required this.position,
    required this.angle,
  });

  /// Index de la case (0 = première case après la ligne d'arrivée, jusqu'à 61).
  final int index;

  /// Position normalisée (x, y) entre 0.0 et 1.0 sur l'image du plateau.
  final Offset position;

  /// Orientation de la voiture en radians (sens horaire autour du circuit).
  final double angle;
}

/// Circuit de l'Allemagne (Deutschland) : 62 cases, sens horaire.
class DeutschlandTrack {
  DeutschlandTrack._();

  static const int totalSpaces = 62;
  static const int totalLaps = 2;
  static const double imageAspectRatio = 1024 / 699;

  static final List<TrackSpace> spaces = _buildSpaces();

  /// Points de passage tracés le long de la piste (sens horaire, départ juste
  /// après la ligne d'arrivée à damier).
  static const List<Offset> _waypoints = [
    Offset(0.435, 0.502), // Juste après la ligne d'arrivée
    Offset(0.300, 0.495), // Ligne droite vers la gauche
    Offset(0.175, 0.460), // Entrée épingle gauche
    Offset(0.098, 0.365), // Courbe gauche
    Offset(0.078, 0.250), // Sommet courbe gauche
    Offset(0.105, 0.145), // Sortie virage (5)
    Offset(0.220, 0.115), // Ligne droite haute gauche
    Offset(0.380, 0.115), // Ligne droite haute milieu
    Offset(0.520, 0.140), // Entrée chicane (2)
    Offset(0.585, 0.155), // Sortie chicane (2)
    Offset(0.680, 0.245), // Diagonale haut-droite
    Offset(0.790, 0.365), // Diagonale milieu-droite
    Offset(0.865, 0.500), // Courbe droite entrée
    Offset(0.890, 0.670), // Courbe droite milieu
    Offset(0.880, 0.840), // Virage (6) bas-droite
    Offset(0.780, 0.895), // Ligne droite basse droite
    Offset(0.600, 0.890), // Ligne droite basse gauche
    Offset(0.525, 0.835), // Virage (4) bas-gauche
    Offset(0.535, 0.720), // Épingle intérieure gauche
    Offset(0.640, 0.660), // Épingle intérieure haut
    Offset(0.750, 0.675), // Virage (4) intérieur droite
    Offset(0.680, 0.590), // Grille de départ droite
    Offset(0.560, 0.530), // Grille de départ gauche
    Offset(0.470, 0.505), // Juste avant la ligne d'arrivée
  ];

  static List<TrackSpace> _buildSpaces() {
    // Calcul des longueurs cumulées sur le polygone fermé.
    final n = _waypoints.length;
    final cumLengths = <double>[0.0];
    var totalLength = 0.0;

    for (var i = 0; i < n; i++) {
      final a = _waypoints[i];
      final b = _waypoints[(i + 1) % n];
      // Pondération par le ratio d'aspect pour une distance visuelle homogène.
      final dx = (b.dx - a.dx) * imageAspectRatio;
      final dy = b.dy - a.dy;
      totalLength += math.sqrt(dx * dx + dy * dy);
      cumLengths.add(totalLength);
    }

    Offset sampleAt(double targetDist) {
      final d = targetDist % totalLength;
      for (var i = 0; i < n; i++) {
        if (d <= cumLengths[i + 1] || i == n - 1) {
          final segLen = cumLengths[i + 1] - cumLengths[i];
          final t = segLen == 0 ? 0.0 : (d - cumLengths[i]) / segLen;
          final a = _waypoints[i];
          final b = _waypoints[(i + 1) % n];
          return Offset(
            a.dx + (b.dx - a.dx) * t,
            a.dy + (b.dy - a.dy) * t,
          );
        }
      }
      return _waypoints.first;
    }

    final result = <TrackSpace>[];
    for (var i = 0; i < totalSpaces; i++) {
      final dist = (i / totalSpaces) * totalLength;
      final pos = sampleAt(dist);
      final nextPos = sampleAt(dist + totalLength / (totalSpaces * 4));
      final angle = math.atan2(
        nextPos.dy - pos.dy,
        (nextPos.dx - pos.dx) * imageAspectRatio,
      );
      result.add(TrackSpace(index: i, position: pos, angle: angle));
    }
    return result;
  }
}
