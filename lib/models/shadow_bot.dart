import 'dart:math';
import 'package:flutter/material.dart';

import 'heat_card.dart';
import 'track_data.dart';

/// État public minimal d'un pilote sur la piste (mode shadow : aucun plateau ni
/// main du bot n'est exposé dans l'interface).
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
    this.finished = false,
    this.finishRank,
  });

  final String id;
  final String name;
  final Color color;
  final bool isHuman;

  int progress;
  int lane; // 0 = corde (Race Line), 1 = extérieur
  int diceRoll;
  int gear;
  bool finished;
  int? finishRank;
}

/// Résultat animable du tour d'un bot en mode Shadow.
class BotTurnOutcome {
  const BotTurnOutcome({
    required this.botId,
    required this.botName,
    required this.botColor,
    required this.startProgress,
    required this.finalProgress,
    required this.finalLane,
    required this.pathProgresses,
    required this.speed,
    required this.gear,
    required this.usedSlipstream,
    required this.spunOut,
    required this.summary,
  });

  final String botId;
  final String botName;
  final Color botColor;
  final int startProgress;
  final int finalProgress;
  final int finalLane;

  /// Suite des cases parcourues une par une (pour voir la voiture avancer !).
  final List<int> pathProgresses;
  final int speed;
  final int gear;
  final bool usedSlipstream;
  final bool spunOut;
  final String summary;
}

/// Pilote adverse en mode Shadow : possède son propre deck complet, son moteur
/// (5 Heat), sa main (7 cartes) et sa défausse, et applique exactement les
/// mêmes règles que le joueur, sans aucune triche.
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

  // État privé réel du bot (jamais affiché en mode shadow)
  int _gear = 1;
  int _roundStartProgress = 0;
  bool _plannedCluttered = false;
  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];

  int get gear => _gear;

  RacerTrackState toTrackState() => RacerTrackState(
        id: id,
        name: name,
        color: color,
        isHuman: false,
        progress: progress,
        lane: lane,
        diceRoll: diceRoll,
        gear: _gear,
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
    _roundStartProgress = 0;
    _plannedCluttered = false;

    _drawPile = createDeutschlandStarterDeck(
      includeStartingUpgrades: includeStartingUpgrades,
    )..shuffle(random);
    _engineHeat = createDeutschlandEngineHeat();
    _hand = [];
    _playArea = [];
    _discardPile = [];
    _drawUpToSeven();
  }

  /// Étapes 1 & 2 (simultanées avec le joueur).
  void planTurn({required int totalLaps}) {
    if (finished) return;
    _roundStartProgress = progress;
    _plannedCluttered = false;
    _playArea.clear();

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

        double score = estSpeed * 3.8 - shiftCost * 4.2;

        if (estHeatCost > availableHeat) {
          score -= 140.0 + (estHeatCost - availableHeat) * 25.0;
        } else {
          final heatPenalty = (3.4 - aggressiveness * 1.4);
          score -= estHeatCost * heatPenalty;
        }

        if (worstHeatCost > availableHeat && stressCount > 0) {
          score -= (1.0 - aggressiveness) * 24.0;
        }

        if (heatInHand >= 2 && g == 1) score += 7.5;
        if (heatInHand >= 1 && g == 2) score += 3.0;

        if (nextCorner.spacesBeforeCorner >= 7 && stressCount > 0) {
          score += stressCount * 2.2;
        }

        score += random.nextDouble() * 0.9;

        if (score > bestScore) {
          bestScore = score;
          bestGear = g;
          bestCards = combo;
        }
      }
    }

    final shiftCost = (bestGear - _gear).abs() == 2 ? 1 : 0;
    if (shiftCost > 0) {
      _payHeat(shiftCost);
    }
    _gear = bestGear;

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
  /// Retourne le chemin case par case pour animer visuellement la voiture.
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
    final finishProgress = totalLaps * DeutschlandTrack.totalSpaces;

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
      _gear = 1;
      _discardPile.addAll(_playArea);
      _playArea.clear();
      _drawUpToSeven();
      return BotTurnOutcome(
        botId: id,
        botName: name,
        botColor: color,
        startProgress: startProg,
        finalProgress: progress,
        finalLane: lane,
        pathProgresses: const [],
        speed: 0,
        gear: _gear,
        usedSlipstream: false,
        spunOut: false,
        summary: '$name : main encombrée → reste sur place, boîte remise en V1.',
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
      }
    }

    var simProgress = startProg;
    var simLane = lane;

    final moved = findOpenSpot(id, simProgress + speed);
    appendStepsTo(simProgress, moved.progress);
    simProgress = moved.progress;
    simLane = moved.lane;

    // Étapes 4 & 5 : Réagir (Cooldown, Adrénaline +1, Boost)
    final maxCooldown =
        (_gear == 1 ? 3 : (_gear == 2 ? 1 : 0)) + (hasAdrenaline ? 1 : 0);
    var cooled = 0;
    while (cooled < maxCooldown) {
      final heatIdx = _hand.indexWhere((c) => c.isHeat);
      if (heatIdx == -1) break;
      _engineHeat.add(_hand.removeAt(heatIdx));
      cooled++;
    }

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
        final adrPos = findOpenSpot(id, nextProgress);
        appendStepsTo(simProgress, adrPos.progress);
        simProgress = adrPos.progress;
        simLane = adrPos.lane;
      }
    }

    final infoAfterMove = DeutschlandTrack.nextCornerInfo(
      progress: simProgress,
      totalLaps: totalLaps,
    );
    if (_engineHeat.length >= 3 &&
        infoAfterMove.spacesBeforeCorner >= 7 &&
        random.nextDouble() < (0.25 + aggressiveness * 0.35)) {
      _payHeat(1);
      final boostCard = _flipUntilBasicCard();
      if (boostCard != null) {
        _playArea.add(boostCard);
        final add = boostCard.speedValue ?? 0;
        speed += add;
        final boostPos = findOpenSpot(id, simProgress + add);
        appendStepsTo(simProgress, boostPos.progress);
        simProgress = boostPos.progress;
        simLane = boostPos.lane;
      }
    }

    // Étape 6 : Aspiration
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
      }
    }

    // Étape 7 : Vérifier les virages franchis
    final crossed = DeutschlandTrack.crossedCorners(
      fromProgress: _roundStartProgress,
      toProgress: simProgress,
      totalLaps: totalLaps,
    );
    var totalHeatPaidCorners = 0;
    TrackCorner? spinOutCorner;
    for (final event in crossed) {
      final excess = max(0, speed - event.corner.speedLimit);
      if (excess == 0) continue;
      if (_engineHeat.length >= excess) {
        _payHeat(excess);
        totalHeatPaidCorners += excess;
      } else {
        final paid = _engineHeat.length;
        if (paid > 0) _payHeat(paid);
        final stressPenalty = _gear <= 2 ? 1 : 2;
        for (var s = 0; s < stressPenalty; s++) {
          if (sharedStressReserve.isNotEmpty) {
            _hand.add(sharedStressReserve.removeLast());
          }
        }
        final spinPos = findOpenSpot(id, event.spaceBeforeCornerProgress);
        appendStepsTo(simProgress, spinPos.progress);
        simProgress = spinPos.progress;
        simLane = spinPos.lane;
        _gear = 1;
        spinOutCorner = event.corner;
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

    // Étape 9 : Défausse zone de jeu + repioche à 7
    _discardPile.addAll(_playArea);
    _playArea.clear();
    _drawUpToSeven();

    final spaceNum = DeutschlandTrack.spaceForProgress(simProgress).spaceNumber;
    final notes = <String>[];
    if (usedSlipstream) notes.add('aspiration +2');
    if (spinOutCorner != null) {
      notes.add('TÊTE-À-QUEUE au ${spinOutCorner.name} !');
    } else if (totalHeatPaidCorners > 0) {
      notes.add('virage franchi');
    }
    if (simProgress >= finishProgress) {
      notes.add('LIGNE D\'ARRIVÉE FRANCHIE !');
    }

    final extra = notes.isEmpty ? '' : ' (${notes.join(', ')})';
    final summary = '$name (V$_gear) : vitesse $speed → case $spaceNum$extra.';

    return BotTurnOutcome(
      botId: id,
      botName: name,
      botColor: color,
      startProgress: startProg,
      finalProgress: simProgress,
      finalLane: simLane,
      pathProgresses: path,
      speed: speed,
      gear: _gear,
      usedSlipstream: usedSlipstream,
      spunOut: spinOutCorner != null,
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
