import 'dart:math';
import 'package:flutter/material.dart';

import 'heat_card.dart';
import 'track_data.dart';

/// État public visible sur la table pour chaque pilote (conformément aux règles :
/// levier de vitesse, Heat restant dans le moteur, tailles pioche/défausse,
/// carte du dessus de la défausse et cartes révélées ce tour — jamais la main cachée).
class RacerTrackState {
  RacerTrackState({
    required this.id,
    required this.name,
    required this.color,
    required this.isHuman,
    this.progress = 0,
    this.lane = 0,
    this.diceRoll = 1,
    this.gear = 1,
    this.previousGear = 1,
    this.shiftHeatPaid = 0,
    this.engineHeatCount = 5,
    this.drawPileCount = 0,
    this.discardPileCount = 0,
    this.discardPile = const [],
    this.topDiscardCard,
    this.revealedCardsThisRound = const [],
    this.hiddenPlayedCount = 0,
    this.turnSpeed = 0,
    this.lastHeatSpent = 0,
    this.lastHeatMissing = 0,
    this.lastCooledHeat = 0,
    this.lastSpunOut = false,
    this.finished = false,
    this.finishRank,
  });

  final String id;
  final String name;
  final Color color;
  final bool isHuman;

  int progress;
  int lane;
  int diceRoll;
  int gear;
  int previousGear;
  int shiftHeatPaid;
  int engineHeatCount;
  int drawPileCount;
  int discardPileCount;
  List<HeatCard> discardPile;
  HeatCard? topDiscardCard;

  /// Cartes révélées sur ce tour (visibles après résolution du pilote).
  List<HeatCard> revealedCardsThisRound;

  /// Nombre de cartes posées face cachée avant que le pilote ne révèle son tour.
  int hiddenPlayedCount;

  int turnSpeed;
  int lastHeatSpent;
  int lastHeatMissing;
  int lastCooledHeat;
  bool lastSpunOut;
  bool finished;
  int? finishRank;
}

/// Détail complet et transparent du tour d'un bot (sans jamais dévoiler sa main).
class BotTurnOutcome {
  const BotTurnOutcome({
    required this.botId,
    required this.botName,
    required this.botColor,
    required this.startProgress,
    required this.finalProgress,
    required this.finalLane,
    required this.pathProgresses,
    required this.previousGear,
    required this.gearBeforeSpinOut,
    required this.finalGear,
    required this.revealedCards,
    required this.speed,
    required this.shiftHeatPaid,
    required this.boostHeatPaid,
    required this.cornerHeatPaid,
    required this.cornerHeatMissing,
    required this.cooledHeatCount,
    required this.engineHeatRemaining,
    required this.usedAdrenaline,
    required this.usedSlipstream,
    required this.spunOut,
    required this.stressTaken,
    required this.clutteredHand,
    required this.actionDetails,
    required this.summary,
  });

  final String botId;
  final String botName;
  final Color botColor;
  final int startProgress;
  final int finalProgress;
  final int finalLane;
  final List<int> pathProgresses;

  final int previousGear;
  final int gearBeforeSpinOut;
  final int finalGear;
  final List<HeatCard> revealedCards;
  final int speed;

  final int shiftHeatPaid;
  final int boostHeatPaid;
  final int cornerHeatPaid;
  final int cornerHeatMissing;
  final int cooledHeatCount;
  final int engineHeatRemaining;

  final bool usedAdrenaline;
  final bool usedSlipstream;
  final bool spunOut;
  final int stressTaken;
  final bool clutteredHand;

  /// Liste détaillée des événements du tour (changement de vitesse, virages, Heat…).
  final List<String> actionDetails;
  final String summary;

  int get totalHeatSpent => shiftHeatPaid + boostHeatPaid + cornerHeatPaid;

  /// Formule lisible des chiffres des cartes jouées (ex: "3 + 4 = 7").
  String get cardsFormula {
    if (revealedCards.isEmpty) return 'Aucune carte';
    final parts = revealedCards.map((c) => c.shortLabel).join(' + ');
    return '$parts = $speed';
  }
}

/// Instantané complet de l'état d'un bot (utilisé pour Annuler / Recommencer le tour).
class ShadowBotSnapshot {
  const ShadowBotSnapshot({
    required this.progress,
    required this.lane,
    required this.diceRoll,
    required this.finished,
    required this.finishRank,
    required this.gear,
    required this.previousGear,
    required this.shiftHeatPaidThisRound,
    required this.roundStartProgress,
    required this.plannedCluttered,
    required this.drawPile,
    required this.hand,
    required this.playArea,
    required this.discardPile,
    required this.engineHeat,
    required this.lastRevealedCards,
    required this.lastTurnSpeed,
    required this.lastHeatSpent,
    required this.lastHeatMissing,
    required this.lastCooledHeat,
    required this.lastSpunOut,
  });

  final int progress;
  final int lane;
  final int diceRoll;
  final bool finished;
  final int? finishRank;
  final int gear;
  final int previousGear;
  final int shiftHeatPaidThisRound;
  final int roundStartProgress;
  final bool plannedCluttered;
  final List<HeatCard> drawPile;
  final List<HeatCard> hand;
  final List<HeatCard> playArea;
  final List<HeatCard> discardPile;
  final List<HeatCard> engineHeat;
  final List<HeatCard> lastRevealedCards;
  final int lastTurnSpeed;
  final int lastHeatSpent;
  final int lastHeatMissing;
  final int lastCooledHeat;
  final bool lastSpunOut;
}

/// Crée entre 0 et 7 bots adverses aux couleurs et styles distincts.
List<ShadowBot> createOpponentBots({
  required int botCount,
  required Random random,
  required bool includeStartingUpgrades,
}) {
  const profiles = <({String id, String name, Color color, double aggr})>[
    (id: 'bot_blue', name: 'Pilote Bleu', color: Color(0xFF1565C0), aggr: 0.65),
    (id: 'bot_green', name: 'Pilote Vert', color: Color(0xFF2E7D32), aggr: 0.40),
    (id: 'bot_yellow', name: 'Pilote Jaune', color: Color(0xFFC79100), aggr: 0.55),
    (id: 'bot_purple', name: 'Pilote Violet', color: Color(0xFF7B1FA2), aggr: 0.72),
    (id: 'bot_black', name: 'Pilote Noir', color: Color(0xFF37474F), aggr: 0.35),
    (id: 'bot_orange', name: 'Pilote Orange', color: Color(0xFFE65100), aggr: 0.80),
    (id: 'bot_silver', name: 'Pilote Argent', color: Color(0xFF546E7A), aggr: 0.50),
  ];

  final clamped = botCount.clamp(0, profiles.length);
  return [
    for (var i = 0; i < clamped; i++)
      ShadowBot(
        id: profiles[i].id,
        name: profiles[i].name,
        color: profiles[i].color,
        aggressiveness: profiles[i].aggr,
        random: random,
        includeStartingUpgrades: includeStartingUpgrades,
      ),
  ];
}

/// Pilote adverse contrôlé par le jeu : possède son propre paquet réel, son
/// moteur (5 Heat), sa main secrète (7 cartes) et sa défausse, et respecte
/// strictement toutes les règles (y compris 1 Heat pour ±2 vitesses, virages, etc.).
class ShadowBot {
  ShadowBot({
    required this.id,
    required this.name,
    required this.color,
    required this.aggressiveness,
    required this.random,
    bool includeStartingUpgrades = false,
  }) {
    reset(includeStartingUpgrades: includeStartingUpgrades);
  }

  final String id;
  final String name;
  final Color color;
  final double aggressiveness;
  final Random random;

  int progress = 0;
  int lane = 0;
  int diceRoll = 1;
  bool finished = false;
  int? finishRank;

  // État réel du bot
  int _gear = 1;
  int _previousGear = 1;
  int _shiftHeatPaidThisRound = 0;
  int _roundStartProgress = 0;
  bool _plannedCluttered = false;

  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];

  // Informations publiques du tour en cours / dernier tour révélé
  List<HeatCard> _lastRevealedCards = const [];
  int _lastTurnSpeed = 0;
  int _lastHeatSpent = 0;
  int _lastHeatMissing = 0;
  int _lastCooledHeat = 0;
  bool _lastSpunOut = false;

  int get gear => _gear;
  int get engineHeatCount => _engineHeat.length;

  ShadowBotSnapshot captureSnapshot() => ShadowBotSnapshot(
        progress: progress,
        lane: lane,
        diceRoll: diceRoll,
        finished: finished,
        finishRank: finishRank,
        gear: _gear,
        previousGear: _previousGear,
        shiftHeatPaidThisRound: _shiftHeatPaidThisRound,
        roundStartProgress: _roundStartProgress,
        plannedCluttered: _plannedCluttered,
        drawPile: List<HeatCard>.from(_drawPile),
        hand: List<HeatCard>.from(_hand),
        playArea: List<HeatCard>.from(_playArea),
        discardPile: List<HeatCard>.from(_discardPile),
        engineHeat: List<HeatCard>.from(_engineHeat),
        lastRevealedCards: List<HeatCard>.from(_lastRevealedCards),
        lastTurnSpeed: _lastTurnSpeed,
        lastHeatSpent: _lastHeatSpent,
        lastHeatMissing: _lastHeatMissing,
        lastCooledHeat: _lastCooledHeat,
        lastSpunOut: _lastSpunOut,
      );

  void restoreSnapshot(ShadowBotSnapshot s) {
    progress = s.progress;
    lane = s.lane;
    diceRoll = s.diceRoll;
    finished = s.finished;
    finishRank = s.finishRank;
    _gear = s.gear;
    _previousGear = s.previousGear;
    _shiftHeatPaidThisRound = s.shiftHeatPaidThisRound;
    _roundStartProgress = s.roundStartProgress;
    _plannedCluttered = s.plannedCluttered;
    _drawPile = List<HeatCard>.from(s.drawPile);
    _hand = List<HeatCard>.from(s.hand);
    _playArea = List<HeatCard>.from(s.playArea);
    _discardPile = List<HeatCard>.from(s.discardPile);
    _engineHeat = List<HeatCard>.from(s.engineHeat);
    _lastRevealedCards = List<HeatCard>.from(s.lastRevealedCards);
    _lastTurnSpeed = s.lastTurnSpeed;
    _lastHeatSpent = s.lastHeatSpent;
    _lastHeatMissing = s.lastHeatMissing;
    _lastCooledHeat = s.lastCooledHeat;
    _lastSpunOut = s.lastSpunOut;
  }

  RacerTrackState toTrackState() => RacerTrackState(
        id: id,
        name: name,
        color: color,
        isHuman: false,
        progress: progress,
        lane: lane,
        diceRoll: diceRoll,
        gear: _gear,
        previousGear: _previousGear,
        shiftHeatPaid: _shiftHeatPaidThisRound,
        engineHeatCount: _engineHeat.length,
        drawPileCount: _drawPile.length,
        discardPileCount: _discardPile.length,
        discardPile: List.unmodifiable(_discardPile),
        topDiscardCard: _discardPile.isEmpty ? null : _discardPile.last,
        revealedCardsThisRound: List.unmodifiable(_lastRevealedCards),
        hiddenPlayedCount: _playArea.length,
        turnSpeed: _lastTurnSpeed,
        lastHeatSpent: _lastHeatSpent,
        lastHeatMissing: _lastHeatMissing,
        lastCooledHeat: _lastCooledHeat,
        lastSpunOut: _lastSpunOut,
        finished: finished,
        finishRank: finishRank,
      );

  void reset({bool includeStartingUpgrades = false}) {
    progress = 0;
    lane = 0;
    diceRoll = 1;
    finished = false;
    finishRank = null;
    _gear = 1;
    _previousGear = 1;
    _shiftHeatPaidThisRound = 0;
    _roundStartProgress = 0;
    _plannedCluttered = false;

    _lastRevealedCards = const [];
    _lastTurnSpeed = 0;
    _lastHeatSpent = 0;
    _lastHeatMissing = 0;
    _lastCooledHeat = 0;
    _lastSpunOut = false;

    _drawPile = createDeutschlandStarterDeck(
      includeStartingUpgrades: includeStartingUpgrades,
    )..shuffle(random);
    _engineHeat = createDeutschlandEngineHeat();
    _hand = [];
    _playArea = [];
    _discardPile = [];
    _drawUpToSeven();
  }

  /// Réinitialise l'affichage des cartes révélées au début d'une nouvelle manche.
  void clearRoundDisplay() {
    _previousGear = _gear;
    _shiftHeatPaidThisRound = 0;
    _lastRevealedCards = const [];
    _lastTurnSpeed = 0;
    _lastHeatSpent = 0;
    _lastHeatMissing = 0;
    _lastCooledHeat = 0;
    _lastSpunOut = false;
  }

  /// Étapes 1 & 2 (simultanées avec le joueur).
  /// Paie réellement 1 Heat (Moteur → Défausse) en cas de changement ±2 vitesses !
  void planTurn({required int totalLaps}) {
    if (finished) return;
    _roundStartProgress = progress;
    _previousGear = _gear;
    _shiftHeatPaidThisRound = 0;
    _plannedCluttered = false;
    _playArea.clear();
    _lastRevealedCards = const [];
    _lastTurnSpeed = 0;
    _lastHeatSpent = 0;
    _lastHeatMissing = 0;
    _lastCooledHeat = 0;
    _lastSpunOut = false;

    final legalGears = <int>[];
    for (var g = 1; g <= 4; g++) {
      final diff = (g - _gear).abs();
      if (diff <= 1 || (diff == 2 && _engineHeat.isNotEmpty)) {
        legalGears.add(g);
      }
    }

    final playable = _hand.where((c) => c.canPlayNormally).toList();
    final heatInHand = _hand.where((c) => c.isHeat).length;
    final nextCorner = DeutschlandTrack.nextCornerInfo(
      progress: progress,
      totalLaps: totalLaps,
    );

    int bestGear = _gear;
    List<HeatCard>? bestCards;
    double bestScore = -1e9;

    for (final g in legalGears) {
      final shiftCost = (g - _gear).abs() == 2 ? 1 : 0;
      final availableHeat = _engineHeat.length - shiftCost;
      if (availableHeat < 0) continue;

      if (playable.length < g) {
        const score = -500.0;
        if (score > bestScore) {
          bestScore = score;
          bestGear = g;
          bestCards = null;
        }
        continue;
      }

      final combos = _combinations(playable, g);
      for (final combo in combos) {
        final stressCount = combo.where((c) => c.isStress).length;
        final fixedSum = combo.fold<int>(0, (s, c) => s + (c.speedValue ?? 0));
        final estSpeed = fixedSum + stressCount * 2.5;
        final worstSpeed = fixedSum + stressCount * 4;

        final targetEst = progress + estSpeed.round();
        final crossed = DeutschlandTrack.crossedCorners(
          fromProgress: progress,
          toProgress: targetEst,
          totalLaps: totalLaps,
        );
        final crossedWorst = DeutschlandTrack.crossedCorners(
          fromProgress: progress,
          toProgress: progress + worstSpeed,
          totalLaps: totalLaps,
        );

        var estHeatCost = 0;
        for (final c in crossed) {
          estHeatCost += max(0, estSpeed.round() - c.corner.speedLimit);
        }
        var worstHeatCost = 0;
        for (final c in crossedWorst) {
          worstHeatCost += max(0, worstSpeed - c.corner.speedLimit);
        }

        // Pénalité réaliste sur le ±2 vitesses (coûte 1 Heat précieux !)
        double score = estSpeed * 3.4 - shiftCost * 8.5;

        if (estHeatCost > availableHeat) {
          score -= 150.0 + (estHeatCost - availableHeat) * 25.0;
        } else {
          final heatPenalty = (4.2 - aggressiveness * 1.3);
          score -= estHeatCost * heatPenalty;
        }

        if (worstHeatCost > availableHeat && stressCount > 0) {
          score -= (1.0 - aggressiveness) * 26.0;
        }

        // Encourager le refroidissement en V1/V2 si la main contient du Heat
        if (heatInHand >= 2 && g == 1) score += 8.5;
        if (heatInHand >= 1 && g == 2) score += 3.5;

        if (nextCorner.spacesBeforeCorner >= 7 && stressCount > 0) {
          score += stressCount * 2.0;
        }

        score += random.nextDouble() * 1.1;

        if (score > bestScore) {
          bestScore = score;
          bestGear = g;
          bestCards = combo;
        }
      }
    }

    // Étape 1 : paiement effectif du Heat si changement de ±2 vitesses
    final shiftCost = (bestGear - _gear).abs() == 2 ? 1 : 0;
    if (shiftCost > 0) {
      _payHeat(shiftCost);
      _shiftHeatPaidThisRound = shiftCost;
    }
    _gear = bestGear;

    // Étape 2 : poser exactement `_gear` cartes dans _playArea
    if (bestCards == null) {
      _plannedCluttered = true;
      final chosen = <HeatCard>[...playable];
      final heats = _hand.where((c) => c.isHeat).take(_gear - chosen.length);
      chosen.addAll(heats);
      for (final c in chosen) {
        _hand.remove(c);
        _playArea.add(c);
      }
    } else {
      for (final c in bestCards) {
        _hand.remove(c);
        _playArea.add(c);
      }
    }
  }

  /// Étapes 3 à 9 du tour du bot dans l'ordre réel de la course.
  BotTurnOutcome resolveTurn({
    required bool hasAdrenaline,
    required int totalLaps,
    required List<HeatCard> sharedStressReserve,
    required bool Function(int currentProgress) hasSlipstreamTarget,
    required ({int progress, int lane}) Function(String botId, int desired)
        findOpenSpot,
  }) {
    final startProg = progress;
    final path = <int>[];
    final details = <String>[];
    final finishProgress = totalLaps * DeutschlandTrack.totalSpaces;
    final gearBeforeSpin = _gear;

    if (_shiftHeatPaidThisRound > 0) {
      details.add(
        'Levier V$_previousGear → V$_gear : 🔥 $_shiftHeatPaidThisRound Heat payé (Moteur → Défausse)',
      );
    } else if (_gear != _previousGear) {
      details.add('Levier V$_previousGear → V$_gear (gratuit)');
    } else {
      details.add('Levier maintenu en V$_gear');
    }

    void appendStepsTo(int from, int to) {
      if (to > from) {
        for (var p = from + 1; p <= to; p++) {
          path.add(p);
        }
      } else if (to < from) {
        path.add(to);
      }
    }

    if (_plannedCluttered) {
      final revealed = List<HeatCard>.from(_playArea);
      _gear = 1;
      _discardPile.addAll(_playArea);
      _playArea.clear();
      _drawUpToSeven();

      _lastRevealedCards = revealed;
      _lastTurnSpeed = 0;
      _lastHeatSpent = _shiftHeatPaidThisRound;
      _lastHeatMissing = 0;
      _lastCooledHeat = 0;
      _lastSpunOut = false;
      details.add('Main encombrée : reste sur place, levier remis en V1');

      return BotTurnOutcome(
        botId: id,
        botName: name,
        botColor: color,
        startProgress: startProg,
        finalProgress: progress,
        finalLane: lane,
        pathProgresses: const [],
        previousGear: _previousGear,
        gearBeforeSpinOut: gearBeforeSpin,
        finalGear: _gear,
        revealedCards: revealed,
        speed: 0,
        shiftHeatPaid: _shiftHeatPaidThisRound,
        boostHeatPaid: 0,
        cornerHeatPaid: 0,
        cornerHeatMissing: 0,
        cooledHeatCount: 0,
        engineHeatRemaining: _engineHeat.length,
        usedAdrenaline: false,
        usedSlipstream: false,
        spunOut: false,
        stressTaken: 0,
        clutteredHand: true,
        actionDetails: details,
        summary: '$name : main encombrée → reste sur place, levier remis en V1.',
      );
    }

    // Étape 3 : Révéler & résoudre Stress (+)
    var speed = 0;
    final stressCount = _playArea.where((c) => c.isStress).length;
    for (final c in _playArea) {
      if (c.speedValue != null) speed += c.speedValue!;
    }
    for (var i = 0; i < stressCount; i++) {
      final basic = _flipUntilBasicCard();
      if (basic != null) {
        _playArea.add(basic);
        speed += basic.speedValue ?? 0;
        details.add('Stress (+) → retourné ${basic.displayName}');
      }
    }

    var simProgress = startProg;
    var simLane = lane;

    final moved = findOpenSpot(id, simProgress + speed);
    appendStepsTo(simProgress, moved.progress);
    simProgress = moved.progress;
    simLane = moved.lane;

    // Étapes 4 & 5 : Réagir (Refroidissement, Adrénaline +1, Boost)
    final maxCooldown =
        (_gear == 1 ? 3 : (_gear == 2 ? 1 : 0)) + (hasAdrenaline ? 1 : 0);
    var cooled = 0;
    while (cooled < maxCooldown) {
      final heatIdx = _hand.indexWhere((c) => c.isHeat);
      if (heatIdx == -1) break;
      _engineHeat.add(_hand.removeAt(heatIdx));
      cooled++;
    }
    if (cooled > 0) {
      details.add('❄️ Refroidissement : +$cooled Heat (Main → Moteur)');
    }

    var usedAdrenalineSpeed = false;
    if (hasAdrenaline) {
      final nextProgress = simProgress + 1;
      final testCorners = DeutschlandTrack.crossedCorners(
        fromProgress: _roundStartProgress,
        toProgress: nextProgress,
        totalLaps: totalLaps,
      );
      final reqHeat = testCorners.fold<int>(
        0,
        (sum, e) => sum + max(0, (speed + 1) - e.corner.speedLimit),
      );
      if (reqHeat <= _engineHeat.length) {
        speed += 1;
        usedAdrenalineSpeed = true;
        final adrPos = findOpenSpot(id, nextProgress);
        appendStepsTo(simProgress, adrPos.progress);
        simProgress = adrPos.progress;
        simLane = adrPos.lane;
        details.add('⚡ Adrénaline : +1 Vitesse et +1 case');
      }
    }

    // Boost optionnel (1x/tour, paye 1 Heat) uniquement sur ligne droite dégagée
    var boostHeatPaid = 0;
    final infoAfterMove = DeutschlandTrack.nextCornerInfo(
      progress: simProgress,
      totalLaps: totalLaps,
    );
    if (_engineHeat.length >= 3 &&
        infoAfterMove.spacesBeforeCorner >= 8 &&
        random.nextDouble() < (0.15 + aggressiveness * 0.25)) {
      _payHeat(1);
      boostHeatPaid = 1;
      final boostCard = _flipUntilBasicCard();
      if (boostCard != null) {
        _playArea.add(boostCard);
        final add = boostCard.speedValue ?? 0;
        speed += add;
        final boostPos = findOpenSpot(id, simProgress + add);
        appendStepsTo(simProgress, boostPos.progress);
        simProgress = boostPos.progress;
        simLane = boostPos.lane;
        details.add(
          '🔥 Boost (-1 Heat Moteur → Défausse) : +$add (${boostCard.displayName})',
        );
      }
    }

    // Étape 6 : Aspiration (+2 cases, ne compte pas pour la vitesse en virage)
    var usedSlipstream = false;
    if (simProgress + 2 < finishProgress && hasSlipstreamTarget(simProgress)) {
      final slipCorners = DeutschlandTrack.crossedCorners(
        fromProgress: _roundStartProgress,
        toProgress: simProgress + 2,
        totalLaps: totalLaps,
      );
      final reqHeat = slipCorners.fold<int>(
        0,
        (sum, e) => sum + max(0, speed - e.corner.speedLimit),
      );
      if (reqHeat <= _engineHeat.length) {
        final slipPos = findOpenSpot(id, simProgress + 2);
        appendStepsTo(simProgress, slipPos.progress);
        simProgress = slipPos.progress;
        simLane = slipPos.lane;
        usedSlipstream = true;
        details.add('⏩ Aspiration : +2 cases');
      }
    }

    // Étape 7 : Vérifier les virages franchis
    final crossed = DeutschlandTrack.crossedCorners(
      fromProgress: _roundStartProgress,
      toProgress: simProgress,
      totalLaps: totalLaps,
    );
    var cornerHeatPaid = 0;
    var cornerHeatMissing = 0;
    var stressTaken = 0;
    TrackCorner? spinOutCorner;
    for (final event in crossed) {
      final excess = max(0, speed - event.corner.speedLimit);
      if (excess == 0) {
        details.add(
          '✓ ${event.corner.name} (lim. ${event.corner.speedLimit}) franchi à $speed → OK',
        );
        continue;
      }
      if (_engineHeat.length >= excess) {
        _payHeat(excess);
        cornerHeatPaid += excess;
        details.add(
          '🔥 ${event.corner.name} (lim. ${event.corner.speedLimit}, vit. $speed) : $excess Heat payé(s)',
        );
      } else {
        final paid = _engineHeat.length;
        final missing = excess - paid;
        if (paid > 0) _payHeat(paid);
        cornerHeatPaid += paid;
        cornerHeatMissing = missing;

        final stressPenalty = _gear <= 2 ? 1 : 2;
        for (var s = 0; s < stressPenalty; s++) {
          if (sharedStressReserve.isNotEmpty) {
            _hand.add(sharedStressReserve.removeLast());
            stressTaken++;
          }
        }
        final spinPos = findOpenSpot(id, event.spaceBeforeCornerProgress);
        appendStepsTo(simProgress, spinPos.progress);
        simProgress = spinPos.progress;
        simLane = spinPos.lane;
        _gear = 1;
        spinOutCorner = event.corner;
        details.add(
          '💥 TÊTE-À-QUEUE au ${event.corner.name} : manquait $missing Heat ! (+$stressTaken Stress, levier → V1)',
        );
        break;
      }
    }

    // Étape 8 : Défausse (jamais Stress ni Heat)
    final upcoming = DeutschlandTrack.nextCornerInfo(
      progress: simProgress,
      totalLaps: totalLaps,
    );
    final toDiscard = <HeatCard>[];
    for (final c in _hand) {
      if (!c.canDiscard) continue;
      final v = c.speedValue ?? 0;
      if (upcoming.spacesBeforeCorner >= 9 && v <= 1) {
        toDiscard.add(c);
      } else if (upcoming.corner != null &&
          upcoming.corner!.speedLimit <= 2 &&
          upcoming.spacesBeforeCorner <= 5 &&
          v >= 4) {
        toDiscard.add(c);
      }
      if (toDiscard.length >= 2) break;
    }
    for (final c in toDiscard) {
      _hand.remove(c);
      _discardPile.add(c);
    }

    // Étape 9 : Révélation sauvegardée + défausse zone de jeu + repioche à 7
    final revealed = List<HeatCard>.from(_playArea);
    _discardPile.addAll(_playArea);
    _playArea.clear();
    _drawUpToSeven();

    final totalSpent = _shiftHeatPaidThisRound + boostHeatPaid + cornerHeatPaid;
    _lastRevealedCards = revealed;
    _lastTurnSpeed = speed;
    _lastHeatSpent = totalSpent;
    _lastHeatMissing = cornerHeatMissing;
    _lastCooledHeat = cooled;
    _lastSpunOut = spinOutCorner != null;

    final spaceNum = DeutschlandTrack.spaceForProgress(simProgress).spaceNumber;
    final cardsLabel = revealed.map((c) => c.shortLabel).join('+');
    final heatSummary = cornerHeatMissing > 0
        ? 'manquait $cornerHeatMissing🔥 → Tête-à-queue'
        : 'moteur : ${_engineHeat.length}🔥${totalSpent > 0 ? " (-$totalSpent🔥)" : ""}';
    final summary =
        '$name (V$_previousGear→V$_gear) [$cardsLabel] = vit. $speed → case $spaceNum ($heatSummary).';

    return BotTurnOutcome(
      botId: id,
      botName: name,
      botColor: color,
      startProgress: startProg,
      finalProgress: simProgress,
      finalLane: simLane,
      pathProgresses: path,
      previousGear: _previousGear,
      gearBeforeSpinOut: gearBeforeSpin,
      finalGear: _gear,
      revealedCards: revealed,
      speed: speed,
      shiftHeatPaid: _shiftHeatPaidThisRound,
      boostHeatPaid: boostHeatPaid,
      cornerHeatPaid: cornerHeatPaid,
      cornerHeatMissing: cornerHeatMissing,
      cooledHeatCount: cooled,
      engineHeatRemaining: _engineHeat.length,
      usedAdrenaline: usedAdrenalineSpeed,
      usedSlipstream: usedSlipstream,
      spunOut: spinOutCorner != null,
      stressTaken: stressTaken,
      clutteredHand: false,
      actionDetails: details,
      summary: summary,
    );
  }

  HeatCard? _flipUntilBasicCard() {
    var guard = 0;
    while (guard < 60) {
      guard++;
      if (_drawPile.isEmpty) {
        if (_discardPile.isEmpty) break;
        _drawPile.addAll(_discardPile);
        _discardPile.clear();
        _drawPile.shuffle(random);
      }
      final card = _drawPile.removeLast();
      if (card.isBasic) {
        return card;
      } else {
        _discardPile.add(card);
      }
    }
    return null;
  }

  void _payHeat(int count) {
    for (var i = 0; i < count; i++) {
      if (_engineHeat.isEmpty) break;
      _discardPile.add(_engineHeat.removeLast());
    }
  }

  void _drawUpToSeven() {
    while (_hand.length < 7) {
      if (_drawPile.isEmpty) {
        if (_discardPile.isEmpty) break;
        _drawPile.addAll(_discardPile);
        _discardPile.clear();
        _drawPile.shuffle(random);
      }
      _hand.add(_drawPile.removeLast());
    }
  }

  List<List<HeatCard>> _combinations(List<HeatCard> list, int k) {
    final result = <List<HeatCard>>[];
    void helper(int start, List<HeatCard> current) {
      if (current.length == k) {
        result.add(List<HeatCard>.from(current));
        return;
      }
      for (var i = start; i <= list.length - (k - current.length); i++) {
        current.add(list[i]);
        helper(i + 1, current);
        current.removeLast();
      }
    }

    helper(0, []);
    return result;
  }
}
