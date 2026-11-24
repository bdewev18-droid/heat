/// Types de cartes du jeu de base Heat: Pedal to the Metal (sans extension).
enum HeatCardType {
  /// Cartes Vitesse de base (1 à 4), identifiées par le symbole tachymètre.
  basic,

  /// Cartes Amélioration de départ à valeur fixe (0 et 5) — chevrons jaunes.
  /// Ne comptent PAS comme des cartes Basic lors d'un symbole (+).
  upgradeSpeed,

  /// Cartes Stress (+) — impossible à défausser.
  stress,

  /// Cartes Heat (Surchauffe) — impossible à défausser ni à jouer normalement.
  heat,
}

/// Représente une carte du paquet joueur.
class HeatCard {
  const HeatCard({
    required this.id,
    required this.type,
    this.speedValue,
    this.isStartingUpgrade = false,
  });

  final String id;
  final HeatCardType type;

  /// Valeur de vitesse (1..4 pour basic, 0 ou 5 pour upgradeSpeed, null sinon).
  final int? speedValue;

  /// Indique si la carte porte les chevrons d'amélioration de départ.
  final bool isStartingUpgrade;

  bool get isBasic => type == HeatCardType.basic;
  bool get isHeat => type == HeatCardType.heat;
  bool get isStress => type == HeatCardType.stress;

  /// Règle p. 6 : on ne peut jamais choisir de défausser une carte Stress ou Heat.
  bool get canDiscard => !isStress && !isHeat;

  /// Règle p. 4 & 7 : on peut jouer toutes les cartes sauf les cartes Heat
  /// (sauf en cas de main encombrée / Cluttered Hand).
  bool get canPlayNormally => !isHeat;

  String get shortLabel {
    switch (type) {
      case HeatCardType.basic:
      case HeatCardType.upgradeSpeed:
        return '${speedValue ?? 0}';
      case HeatCardType.stress:
        return '+';
      case HeatCardType.heat:
        return 'HEAT';
    }
  }

  String get displayName {
    switch (type) {
      case HeatCardType.basic:
        return 'Vitesse $speedValue';
      case HeatCardType.upgradeSpeed:
        return 'Amélioration $speedValue';
      case HeatCardType.stress:
        return 'Stress (+)';
      case HeatCardType.heat:
        return isStartingUpgrade ? 'Heat (Départ)' : 'Heat';
    }
  }
}

/// Construit le paquet de départ pour le circuit Deutschland (3 Stress) :
/// - Mode Compétition (`includeStartingUpgrades: false`, par défaut) :
///   12 cartes Basic (3x1, 3x2, 3x3, 3x4) + 3 Stress = 15 cartes.
/// - Mode Initiation (`includeStartingUpgrades: true`) :
///   ajoute les 3 cartes Amélioration de départ (0, 5 et +1 Heat) = 18 cartes.
List<HeatCard> createDeutschlandStarterDeck({
  bool includeStartingUpgrades = false,
}) {
  final cards = <HeatCard>[];
  var index = 0;

  for (var value = 1; value <= 4; value++) {
    for (var copy = 0; copy < 3; copy++) {
      cards.add(
        HeatCard(
          id: 'basic_${value}_${index++}',
          type: HeatCardType.basic,
          speedValue: value,
        ),
      );
    }
  }

  if (includeStartingUpgrades) {
    cards.add(
      HeatCard(
        id: 'upgrade_0_${index++}',
        type: HeatCardType.upgradeSpeed,
        speedValue: 0,
        isStartingUpgrade: true,
      ),
    );
    cards.add(
      HeatCard(
        id: 'upgrade_5_${index++}',
        type: HeatCardType.upgradeSpeed,
        speedValue: 5,
        isStartingUpgrade: true,
      ),
    );
    cards.add(
      HeatCard(
        id: 'upgrade_heat_${index++}',
        type: HeatCardType.heat,
        isStartingUpgrade: true,
      ),
    );
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

/// Construit les 5 cartes Heat placées dans le Moteur pour Deutschland
/// (indiqué par l'icône rouge "5" sur le plateau allemand).
List<HeatCard> createDeutschlandEngineHeat() {
  return List.generate(
    5,
    (i) => HeatCard(
      id: 'engine_heat_$i',
      type: HeatCardType.heat,
    ),
  );
}

/// Réserve de cartes Stress en cas de tête-à-queue (Spin Out).
List<HeatCard> createStressReserve() {
  return List.generate(
    30,
    (i) => HeatCard(
      id: 'reserve_stress_$i',
      type: HeatCardType.stress,
    ),
  );
}
