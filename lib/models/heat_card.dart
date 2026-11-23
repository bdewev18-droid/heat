import 'package:flutter/material.dart';

/// Type de carte du jeu Heat (jeu de base, sans extension).
enum HeatCardType {
  speed,
  stress,
  heat,
}

/// Représente une carte du paquet joueur.
class HeatCard {
  const HeatCard({
    required this.id,
    required this.type,
    this.speedValue,
  });

  final String id;
  final HeatCardType type;

  /// Valeur de vitesse (1 à 4) pour les cartes Vitesse ; null pour Stress / Heat.
  final int? speedValue;

  String get title {
    switch (type) {
      case HeatCardType.speed:
        return '${speedValue ?? 0}';
      case HeatCardType.stress:
        return 'STRESS';
      case HeatCardType.heat:
        return 'HEAT';
    }
  }

  String get subtitle {
    switch (type) {
      case HeatCardType.speed:
        return 'Vitesse';
      case HeatCardType.stress:
        return '+? (Aléatoire)';
      case HeatCardType.heat:
        return 'Surchauffe';
    }
  }

  Color get accentColor {
    switch (type) {
      case HeatCardType.speed:
        switch (speedValue) {
          case 1:
            return const Color(0xFF4CAF50);
          case 2:
            return const Color(0xFF2196F3);
          case 3:
            return const Color(0xFFFF9800);
          case 4:
            return const Color(0xFFE53935);
          default:
            return Colors.grey;
        }
      case HeatCardType.stress:
        return const Color(0xFF8D6E63);
      case HeatCardType.heat:
        return const Color(0xFFD84315);
    }
  }
}

/// Construit le paquet de départ standard (jeu de base, sans extension) :
/// 3x1, 3x2, 3x3, 3x4 et 3 cartes Stress.
List<HeatCard> createBaseStarterDeck() {
  final cards = <HeatCard>[];
  var index = 0;

  for (var value = 1; value <= 4; value++) {
    for (var copy = 0; copy < 3; copy++) {
      cards.add(
        HeatCard(
          id: 'speed_${value}_${index++}',
          type: HeatCardType.speed,
          speedValue: value,
        ),
      );
    }
  }

  for (var copy = 0; copy < 3; copy++) {
    cards.add(
      HeatCard(
        id: 'stress_${index++}',
        type: HeatCardType.stress,
      ),
    );
  }

  return cards;
}

/// Construit les 6 cartes Heat initialement placées dans le moteur.
List<HeatCard> createBaseEngineHeatCards() {
  return List.generate(
    6,
    (i) => HeatCard(
      id: 'heat_$i',
      type: HeatCardType.heat,
    ),
  );
}
