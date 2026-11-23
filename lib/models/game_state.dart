import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/heat_theme.dart';
import 'heat_card.dart';
import 'shadow_bot.dart';
import 'track_data.dart';

/// Étapes officielles d'un tour (livret p. 4–6) + jet de dés initial + arrivée.
enum RoundStep {
  diceRoll(0, 'Jet de dés', true),
  shiftGears(1, 'Changer de vitesse', true),
  playCards(2, 'Jouer des cartes', true),
  revealAndMove(3, 'Révéler & Avancer', true),
  adrenaline(4, 'Adrénaline', false),
  react(5, 'Réagir', false),
  slipstream(6, 'Aspiration', false),
  checkCorner(7, 'Vérifier les virages', false),
  discard(8, 'Défausser', false),
  replenishHand(9, 'Compléter sa main', true),
  finished(10, 'Arrivée', true);

  const RoundStep(this.number, this.label, this.isMandatory);

  final int number;
  final String label;
  final bool isMandatory;
}

/// Résultat d'évaluation d'un virage franchi pendant le tour.
class CornerCheckResult {
  const CornerCheckResult({
    required this.corner,
    required this.speed,
    required this.heatRequired,
    required this.heatPaid,
    required this.spunOut,
    required this.stressTaken,
  });

  final TrackCorner corner;
  final int speed;
  final int heatRequired;
  final int heatPaid;
  final bool spunOut;
  final int stressTaken;
}

/// Moteur complet des règles de base de Heat (circuit Deutschland) avec
/// 2 adversaires en mode Shadow (sans triche) et jet de dés de départ.
class HeatGameController extends ChangeNotifier {
  HeatGameController({
    int totalLaps = DeutschlandTrack.defaultLaps,
    Random? random,
  })  : _totalLaps = totalLaps,
        _random = random ?? Random() {
    resetRace(totalLaps: totalLaps);
  }

  final Random _random;
  int _totalLaps;

  // État piste & voiture du joueur
  int _roundNumber = 1;
  int _carProgress = 0;
  int _carLane = 0;
  int _playerDiceRoll = 0;
  bool _diceRolled = false;
  bool _playerFinished = false;
  int? _playerFinishRank;

  int _roundStartProgress = 0;
  int _moveFloorProgress = 0;
  int _pendingStepsToMove = 0;
  int _turnSpacesMoved = 0;
  int _turnSpeed = 0;

  // Boîte de vitesses
  int _gear = 1;
  int _roundStartGear = 1;
  int _selectedTargetGear = 1;

  // Étape en cours
  RoundStep _step = RoundStep.diceRoll;
  bool _adrenalineEligible = false;
  bool _adrenalineEnabled = false;
  bool _adrenalineSpeedUsed = false;
  bool _boostUsed = false;
  bool _slipstreamUsed = false;
  int _cooldownsUsed = 0;
  bool _cornersResolved = false;
  List<CornerCheckResult> _lastCornerResults = const [];

  // Cartes du joueur
  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];
  List<HeatCard> _stressReserve = [];

  // 2 adversaires en mode Shadow (vrais paquets, aucune triche)
  late List<ShadowBot> _bots;
  List<ShadowBot> _botsPendingAfterPlayer = [];
  String? _lastCarIdThisRound;

  // Sélections UI (Step 2 et Step 8)
  final Set<String> _selectedCardIds = {};

  // Journal de course
  final List<String> _eventLog = [];

  // Getters publics
  int get totalLaps => _totalLaps;
  int get finishProgress => _totalLaps * DeutschlandTrack.totalSpaces;
  int get roundNumber => _roundNumber;
  int get carProgress => _carProgress;
  int get carLane => _carLane;
  int get playerDiceRoll => _playerDiceRoll;
  bool get diceRolled => _diceRolled;
  int get pendingStepsToMove => _pendingStepsToMove;
  int get turnSpacesMoved => _turnSpacesMoved;
  int get turnSpeed => _turnSpeed;
  int get gear => _gear;
  int get roundStartGear => _roundStartGear;
  int get selectedTargetGear => _selectedTargetGear;
  RoundStep get step => _step;
  bool get adrenalineEligible => _adrenalineEligible;
  bool get adrenalineEnabled => _adrenalineEnabled;
  bool get adrenalineSpeedUsed => _adrenalineSpeedUsed;
  bool get boostUsed => _boostUsed;
  bool get slipstreamUsed => _slipstreamUsed;
  bool get cornersResolved => _cornersResolved;
  List<CornerCheckResult> get lastCornerResults =>
      List.unmodifiable(_lastCornerResults);

  List<HeatCard> get drawPile => List.unmodifiable(_drawPile);
  List<HeatCard> get hand => List.unmodifiable(_hand);
  List<HeatCard> get playArea => List.unmodifiable(_playArea);
  List<HeatCard> get discardPile => List.unmodifiable(_discardPile);
  List<HeatCard> get engineHeat => List.unmodifiable(_engineHeat);
  List<HeatCard> get stressReserve => List.unmodifiable(_stressReserve);
  Set<String> get selectedCardIds => Set.unmodifiable(_selectedCardIds);
  List<String> get eventLog => List.unmodifiable(_eventLog);

  TrackSpace get currentSpace => DeutschlandTrack.spaceForProgress(_carProgress);
  int get currentLap => DeutschlandTrack.lapForProgress(_carProgress);
  bool get hasCrossedFinishLine => _carProgress >= finishProgress;
  int? get playerFinishRank => _playerFinishRank;

  /// Calcul dynamique des repères entre la voiture du joueur et le prochain virage.
  NextCornerInfo get nextCornerInfo => DeutschlandTrack.nextCornerInfo(
        progress: _carProgress,
        totalLaps: _totalLaps,
      );

  /// Liste triée par classement de course (1er devant, corde départage les égalités).
  List<RacerTrackState> get standings {
    final list = <RacerTrackState>[
      RacerTrackState(
        id: 'player',
        name: 'Toi (Rouge)',
        color: HeatColors.heatRed,
        isHuman: true,
        progress: _carProgress,
        lane: _carLane,
        diceRoll: _playerDiceRoll,
        gear: _gear,
        finished: _playerFinished,
        finishRank: _playerFinishRank,
      ),
      ..._bots.map((b) => b.toTrackState()),
    ];

    list.sort((a, b) {
      if (a.finishRank != null && b.finishRank != null) {
        return a.finishRank!.compareTo(b.finishRank!);
      }
      if (a.finishRank != null) return -1;
      if (b.finishRank != null) return 1;
      if (a.progress != b.progress) {
        return b.progress.compareTo(a.progress);
      }
      return a.lane.compareTo(b.lane);
    });
    return list;
  }

  /// Nombre de Refroidissements (Cooldown) disponibles à l'étape 5.
  int get totalCooldownAvailable {
    var base = 0;
    if (_gear == 1) base = 3;
    if (_gear == 2) base = 1;
    if (_adrenalineEnabled) base += 1;
    return base;
  }

  int get remainingCooldowns =>
      max(0, totalCooldownAvailable - _cooldownsUsed);

  List<CrossedCornerEvent> get crossedCornersThisTurn =>
      DeutschlandTrack.crossedCorners(
        fromProgress: _roundStartProgress,
        toProgress: _carProgress,
        totalLaps: _totalLaps,
      );

  int get playableCardsInHandCount =>
      _hand.where((c) => c.canPlayNormally).length;

  bool get isClutteredHand => playableCardsInHandCount < _gear;

  int shiftHeatCost(int targetGear) {
    final diff = (targetGear - _roundStartGear).abs();
    if (diff <= 1) return 0;
    if (diff == 2) return 1;
    return 99;
  }

  bool canSelectGear(int targetGear) {
    if (targetGear < 1 || targetGear > 4) return false;
    final diff = (targetGear - _roundStartGear).abs();
    if (diff <= 1) return true;
    if (diff == 2) return _engineHeat.isNotEmpty;
    return false;
  }

  /// Vrai si une voiture adverse est sur la même case ou 1 case devant le joueur.
  bool get hasRealSlipstreamTarget => _hasSlipstreamTargetFor('player', _carProgress);

  bool get canUseSlipstream {
    if (_step != RoundStep.slipstream || _slipstreamUsed) return false;
    if (_pendingStepsToMove > 0) return false;
    if (!hasRealSlipstreamTarget) return false;
    // Règle p. 7 : interdit pour franchir ou après avoir franchi la ligne d'arrivée finale.
    if (_carProgress + 2 >= finishProgress) return false;
    return true;
  }

  /// Réinitialise complètement une nouvelle course (avant jet de dés).
  void resetRace({int? totalLaps}) {
    if (totalLaps != null) _totalLaps = totalLaps;
    _roundNumber = 1;
    _carProgress = 0;
    _carLane = 0;
    _playerDiceRoll = 0;
    _diceRolled = false;
    _playerFinished = false;
    _playerFinishRank = null;

    _roundStartProgress = 0;
    _moveFloorProgress = 0;
    _pendingStepsToMove = 0;
    _turnSpacesMoved = 0;
    _turnSpeed = 0;

    _gear = 1;
    _roundStartGear = 1;
    _selectedTargetGear = 1;
    _step = RoundStep.diceRoll;

    _adrenalineEligible = false;
    _adrenalineEnabled = false;
    _adrenalineSpeedUsed = false;
    _boostUsed = false;
    _slipstreamUsed = false;
    _cooldownsUsed = 0;
    _cornersResolved = false;
    _lastCornerResults = const [];
    _selectedCardIds.clear();
    _botsPendingAfterPlayer = [];
    _lastCarIdThisRound = null;

    _drawPile = createDeutschlandStarterDeck()..shuffle(_random);
    _engineHeat = createDeutschlandEngineHeat();
    _stressReserve = createStressReserve();
    _hand = [];
    _playArea = [];
    _discardPile = [];
    _eventLog.clear();

    _bots = [
      ShadowBot(
        id: 'bot_blue',
        name: 'Pilote Bleu',
        color: const Color(0xFF1565C0),
        aggressiveness: 0.65,
        random: _random,
      ),
      ShadowBot(
        id: 'bot_green',
        name: 'Pilote Vert',
        color: const Color(0xFF2E7D32),
        aggressiveness: 0.40,
        random: _random,
      ),
    ];

    _drawUpToSeven();
    _log(
      'Prêt au départ sur Deutschland ($_totalLaps tours, 3 pilotes) : '
      'lance les dés pour déterminer la grille de départ !',
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 0 : Jet de dés pour la grille de départ
  // ---------------------------------------------------------------------------

  void rollStartingDice() {
    if (_step != RoundStep.diceRoll) return;

    // Tirage de dés 1..6 distincts pour un départage clair et équitable
    final faces = [1, 2, 3, 4, 5, 6]..shuffle(_random);
    _playerDiceRoll = faces[0];
    _bots[0].diceRoll = faces[1];
    _bots[1].diceRoll = faces[2];
    _diceRolled = true;

    // Tri décroissant pour attribuer Pole Position (1), P2 et P3 sur la grille
    final entries = <({String id, String name, int roll})>[
      (id: 'player', name: 'Toi (Rouge)', roll: _playerDiceRoll),
      (id: _bots[0].id, name: _bots[0].name, roll: _bots[0].diceRoll),
      (id: _bots[1].id, name: _bots[1].name, roll: _bots[1].diceRoll),
    ]..sort((a, b) => b.roll.compareTo(a.roll));

    // Grille : P1 = (0, lane 0), P2 = (0, lane 1), P3 = (-1, lane 0)
    const gridSlots = [
      (progress: 0, lane: 0),
      (progress: 0, lane: 1),
      (progress: -1, lane: 0),
    ];

    for (var i = 0; i < entries.length; i++) {
      final slot = gridSlots[i];
      if (entries[i].id == 'player') {
        _carProgress = slot.progress;
        _carLane = slot.lane;
        _roundStartProgress = _carProgress;
        _moveFloorProgress = _carProgress;
      } else {
        final bot = _bots.firstWhere((b) => b.id == entries[i].id);
        bot.progress = slot.progress;
        bot.lane = slot.lane;
      }
    }

    _log(
      'Jet de dés : ${entries.asMap().entries.map((e) => "P${e.key + 1} ${e.value.name} (${e.value.roll})").join(' • ')}.',
    );
    notifyListeners();
  }

  void startRaceAfterDiceRoll() {
    if (_step != RoundStep.diceRoll || !_diceRolled) return;
    _step = RoundStep.shiftGears;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 1 : Changer de vitesse (Shift Gears)
  // ---------------------------------------------------------------------------

  void selectTargetGear(int targetGear) {
    if (_step != RoundStep.shiftGears) return;
    if (!canSelectGear(targetGear)) return;
    _selectedTargetGear = targetGear;
    notifyListeners();
  }

  void confirmShiftGear() {
    if (_step != RoundStep.shiftGears) return;
    final cost = shiftHeatCost(_selectedTargetGear);
    if (cost > _engineHeat.length) return;

    if (cost > 0) {
      _payHeat(cost);
      _log(
        'Étape 1 : Vitesse $_roundStartGear → $_selectedTargetGear '
        '(±2 rapports : 1 Heat payé).',
      );
    } else if (_selectedTargetGear != _roundStartGear) {
      _log('Étape 1 : Vitesse $_roundStartGear → $_selectedTargetGear.');
    } else {
      _log('Étape 1 : Maintien en vitesse $_selectedTargetGear.');
    }

    _gear = _selectedTargetGear;
    _selectedCardIds.clear();
    _step = RoundStep.playCards;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 2 : Jouer des cartes (Play Cards — simultané avec les 2 bots)
  // ---------------------------------------------------------------------------

  bool canToggleCardInHand(HeatCard card) {
    if (_step == RoundStep.playCards) {
      if (_selectedCardIds.contains(card.id)) return true;
      if (_selectedCardIds.length >= _gear) return false;
      if (card.canPlayNormally) return true;
      if (isClutteredHand) {
        final selectedPlayable = _hand
            .where((c) => _selectedCardIds.contains(c.id) && c.canPlayNormally)
            .length;
        return selectedPlayable == playableCardsInHandCount;
      }
      return false;
    }

    if (_step == RoundStep.react) {
      return card.isHeat && remainingCooldowns > 0;
    }

    if (_step == RoundStep.discard) {
      return card.canDiscard;
    }

    return false;
  }

  void onHandCardTapped(HeatCard card) {
    if (_step == RoundStep.playCards) {
      if (_selectedCardIds.contains(card.id)) {
        _selectedCardIds.remove(card.id);
        notifyListeners();
        return;
      }
      if (!canToggleCardInHand(card)) return;
      _selectedCardIds.add(card.id);
      notifyListeners();
      return;
    }

    if (_step == RoundStep.react) {
      if (card.isHeat && remainingCooldowns > 0) {
        _cooldownHeatCard(card);
      }
      return;
    }

    if (_step == RoundStep.discard) {
      if (!card.canDiscard) return;
      if (_selectedCardIds.contains(card.id)) {
        _selectedCardIds.remove(card.id);
      } else {
        _selectedCardIds.add(card.id);
      }
      notifyListeners();
    }
  }

  bool get canConfirmPlayCards =>
      _step == RoundStep.playCards && _selectedCardIds.length == _gear;

  void confirmPlayCards() {
    if (!canConfirmPlayCards) return;

    // 1. Les 2 bots choisissent simultanément leur vitesse et leurs cartes réelles
    for (final bot in _bots) {
      if (!bot.finished) {
        bot.planTurn(totalLaps: _totalLaps);
      }
    }

    // 2. Déterminer l'ordre de résolution du tour (du 1er au dernier non arrivé)
    final activeOrder = standings.where((r) => !r.finished).toList();
    _lastCarIdThisRound = activeOrder.isNotEmpty ? activeOrder.last.id : null;
    _adrenalineEligible = _lastCarIdThisRound == 'player';

    final playerIdxInOrder = activeOrder.indexWhere((r) => r.isHuman);
    final botsBeforePlayer = <ShadowBot>[];
    _botsPendingAfterPlayer = <ShadowBot>[];

    for (var i = 0; i < activeOrder.length; i++) {
      final racer = activeOrder[i];
      if (racer.isHuman) continue;
      final bot = _bots.firstWhere((b) => b.id == racer.id);
      if (i < playerIdxInOrder) {
        botsBeforePlayer.add(bot);
      } else {
        _botsPendingAfterPlayer.add(bot);
      }
    }

    // 3. Les bots devant le joueur résolvent d'abord leur tour (règle p. 4)
    for (final bot in botsBeforePlayer) {
      _runShadowBotResolution(bot);
    }

    // 4. Jouer les cartes du joueur
    final chosen = _hand.where((c) => _selectedCardIds.contains(c.id)).toList();
    _hand.removeWhere((c) => _selectedCardIds.contains(c.id));
    _playArea.addAll(chosen);
    _selectedCardIds.clear();

    if (chosen.any((c) => c.isHeat)) {
      _log(
        'Main encombrée (p. 7) : tu ne avances pas ce tour, boîte remise en V1.',
      );
      _gear = 1;
      _discardPile.addAll(_playArea);
      _playArea.clear();
      _step = RoundStep.replenishHand;
      notifyListeners();
      return;
    }

    _step = RoundStep.revealAndMove;
    _resolveRevealedCards();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 3 : Révéler & Avancer (Reveal & Move)
  // ---------------------------------------------------------------------------

  void _resolveRevealedCards() {
    var speed = 0;
    final stressCards = _playArea.where((c) => c.isStress).toList();
    final revealedSummary = <String>[];

    for (final card in _playArea) {
      if (card.speedValue != null) {
        speed += card.speedValue!;
        revealedSummary.add(card.displayName);
      }
    }

    for (var i = 0; i < stressCards.length; i++) {
      final result = _flipUntilBasicCard(reason: 'Stress (+)');
      if (result != null) {
        _playArea.add(result);
        speed += result.speedValue ?? 0;
        revealedSummary.add('Stress → ${result.displayName}');
      }
    }

    _turnSpeed = speed;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove = speed;
    _log(
      'Étape 3 : ${revealedSummary.join(', ')} → Vitesse $_turnSpeed. '
      'Avance ta voiture de $_turnSpeed cases.',
    );
  }

  HeatCard? _flipUntilBasicCard({required String reason}) {
    final discardedNames = <String>[];
    var guard = 0;
    while (guard < 60) {
      guard++;
      if (_drawPile.isEmpty) {
        if (_discardPile.isEmpty) break;
        _reshuffleDiscardIntoDraw(silent: true);
      }
      final flipped = _drawPile.removeLast();
      if (flipped.isBasic) {
        if (discardedNames.isNotEmpty) {
          _log(
            '$reason : défaussé [${discardedNames.join(', ')}] → '
            '${flipped.displayName} (+${flipped.speedValue}).',
          );
        } else {
          _log('$reason : ${flipped.displayName} (+${flipped.speedValue}).');
        }
        return flipped;
      } else {
        discardedNames.add(flipped.displayName);
        _discardPile.add(flipped);
      }
    }
    return null;
  }

  void stepCarForward() {
    if (_pendingStepsToMove <= 0) return;
    _carProgress++;
    _pendingStepsToMove--;
    _turnSpacesMoved++;
    if (_pendingStepsToMove == 0) {
      _applyPlayerFinalPlacement();
    } else {
      _updatePlayerVisualLane();
    }
    notifyListeners();
  }

  void stepCarBackward() {
    if (_carProgress <= _moveFloorProgress) return;
    _carProgress--;
    _pendingStepsToMove++;
    if (_turnSpacesMoved > 0) _turnSpacesMoved--;
    _updatePlayerVisualLane();
    notifyListeners();
  }

  void autoFinishMovement() {
    if (_pendingStepsToMove <= 0) return;
    _carProgress += _pendingStepsToMove;
    _turnSpacesMoved += _pendingStepsToMove;
    _pendingStepsToMove = 0;
    _applyPlayerFinalPlacement();
    notifyListeners();
  }

  /// Applique la règle de blocage (p. 5) et de voie libre quand un déplacement se termine.
  void _applyPlayerFinalPlacement() {
    final desired = _carProgress;
    final placed = _findOpenSpot(racerId: 'player', desiredProgress: desired);
    _carProgress = placed.progress;
    _carLane = placed.lane;
    if (placed.progress < desired) {
      _log(
        'Case bloquée par 2 voitures ! Tu es replacé sur la case libre derrière '
        '(case ${currentSpace.spaceNumber}).',
      );
    }
  }

  void _updatePlayerVisualLane() {
    final occupiedLane0 = _bots.any(
      (b) => !b.finished && b.progress == _carProgress && b.lane == 0,
    );
    _carLane = occupiedLane0 ? 1 : 0;
  }

  void proceedFromRevealAndMove() {
    if (_step != RoundStep.revealAndMove || _pendingStepsToMove > 0) return;
    if (_adrenalineEligible) {
      _step = RoundStep.adrenaline;
    } else {
      // Pas dernier → l'étape 4 ne s'applique pas, passage direct à l'étape 5
      _adrenalineEnabled = false;
      _step = RoundStep.react;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 4 : Adrénaline (uniquement si dernier pilote du tour)
  // ---------------------------------------------------------------------------

  void chooseAdrenaline({required bool activate}) {
    if (_step != RoundStep.adrenaline) return;
    _adrenalineEnabled = activate && _adrenalineEligible;
    if (_adrenalineEnabled) {
      _log(
        'Étape 4 : Adrénaline activée (+1 Vitesse/case et +1 Refroidissement disponibles).',
      );
    }
    _step = RoundStep.react;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 5 : Réagir (Cooldown, Boost, Adrénaline +1)
  // ---------------------------------------------------------------------------

  void _cooldownHeatCard(HeatCard card) {
    if (_step != RoundStep.react || remainingCooldowns <= 0) return;
    if (!card.isHeat) return;
    _hand.remove(card);
    _engineHeat.add(card);
    _cooldownsUsed++;
    _log(
      'Étape 5 (Refroidissement) : 1 Heat renvoyée au moteur '
      '(restant : $remainingCooldowns).',
    );
    notifyListeners();
  }

  void activateAdrenalineSpeedBonus() {
    if (_step != RoundStep.react ||
        !_adrenalineEnabled ||
        _adrenalineSpeedUsed) {
      return;
    }
    _adrenalineSpeedUsed = true;
    _turnSpeed += 1;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove += 1;
    _log(
      'Étape 5 (Adrénaline +1) : +1 Vitesse (total $_turnSpeed) et +1 case.',
    );
    notifyListeners();
  }

  void activateBoost() {
    if (_step != RoundStep.react || _boostUsed || _engineHeat.isEmpty) return;
    _boostUsed = true;
    _payHeat(1);
    final card = _flipUntilBasicCard(reason: 'Boost (1 Heat)');
    if (card != null) {
      _playArea.add(card);
      final add = card.speedValue ?? 0;
      _turnSpeed += add;
      _moveFloorProgress = _carProgress;
      _pendingStepsToMove += add;
      _log('Étape 5 (Boost) : +$add cases et +$add Vitesse (total $_turnSpeed).');
    }
    notifyListeners();
  }

  void proceedFromReact() {
    if (_step != RoundStep.react || _pendingStepsToMove > 0) return;
    _step = RoundStep.slipstream;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 6 : Aspiration (Slipstream — détectée sur les vraies positions des bots)
  // ---------------------------------------------------------------------------

  void activateSlipstream() {
    if (!canUseSlipstream) return;
    _slipstreamUsed = true;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove += 2;
    _log(
      'Étape 6 (Aspiration) : +2 cases (n\'augmente PAS la vitesse en virage).',
    );
    notifyListeners();
  }

  void proceedFromSlipstream() {
    if (_step != RoundStep.slipstream || _pendingStepsToMove > 0) return;
    _step = RoundStep.checkCorner;
    _cornersResolved = false;
    _lastCornerResults = const [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 7 : Vérifier les virages (Check Corner & Spin Out)
  // ---------------------------------------------------------------------------

  void resolveCornersAndProceed() {
    if (_step != RoundStep.checkCorner) return;

    if (!_cornersResolved) {
      final crossed = crossedCornersThisTurn;
      final results = <CornerCheckResult>[];

      if (crossed.isEmpty) {
        _log('Étape 7 : Aucun virage franchi ce tour.');
      } else {
        for (final event in crossed) {
          final limit = event.corner.speedLimit;
          final excess = max(0, _turnSpeed - limit);

          if (excess == 0) {
            results.add(
              CornerCheckResult(
                corner: event.corner,
                speed: _turnSpeed,
                heatRequired: 0,
                heatPaid: 0,
                spunOut: false,
                stressTaken: 0,
              ),
            );
            _log(
              'Étape 7 : ${event.corner.name} (limite $limit) franchi à $_turnSpeed → OK !',
            );
          } else if (_engineHeat.length >= excess) {
            _payHeat(excess);
            results.add(
              CornerCheckResult(
                corner: event.corner,
                speed: _turnSpeed,
                heatRequired: excess,
                heatPaid: excess,
                spunOut: false,
                stressTaken: 0,
              ),
            );
            _log(
              'Étape 7 : ${event.corner.name} (limite $limit) à $_turnSpeed → '
              '$excess Heat payé(s).',
            );
          } else {
            final paid = _engineHeat.length;
            if (paid > 0) _payHeat(paid);

            final stressCount = _gear <= 2 ? 1 : 2;
            var actualStress = 0;
            for (var i = 0; i < stressCount; i++) {
              if (_stressReserve.isNotEmpty) {
                _hand.add(_stressReserve.removeLast());
                actualStress++;
              }
            }

            final placed = _findOpenSpot(
              racerId: 'player',
              desiredProgress: event.spaceBeforeCornerProgress,
            );
            _carProgress = placed.progress;
            _carLane = placed.lane;
            _gear = 1;

            results.add(
              CornerCheckResult(
                corner: event.corner,
                speed: _turnSpeed,
                heatRequired: excess,
                heatPaid: paid,
                spunOut: true,
                stressTaken: actualStress,
              ),
            );
            _log(
              'TÊTE-À-QUEUE au ${event.corner.name} ! '
              'Replacé avant le virage (case ${currentSpace.spaceNumber}), '
              '+$actualStress Stress, vitesse 1.',
            );
            break;
          }
        }
      }

      _lastCornerResults = results;
      _cornersResolved = true;
      notifyListeners();
      return;
    }

    _selectedCardIds.clear();
    _step = RoundStep.discard;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 8 : Défausser (Discard)
  // ---------------------------------------------------------------------------

  void confirmDiscard() {
    if (_step != RoundStep.discard) return;
    if (_selectedCardIds.isNotEmpty) {
      final toDiscard = _hand
          .where((c) => _selectedCardIds.contains(c.id) && c.canDiscard)
          .toList();
      _hand.removeWhere((c) => _selectedCardIds.contains(c.id) && c.canDiscard);
      _discardPile.addAll(toDiscard);
      _log('Étape 8 : ${toDiscard.length} carte(s) défaussée(s).');
    }
    _selectedCardIds.clear();
    _step = RoundStep.replenishHand;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 9 : Compléter sa main + résolution des bots derrière le joueur
  // ---------------------------------------------------------------------------

  void replenishAndStartNextRound() {
    if (_step != RoundStep.replenishHand) return;

    if (_playArea.isNotEmpty) {
      _discardPile.addAll(_playArea);
      _playArea.clear();
    }

    _drawUpToSeven();

    // Les bots derrière le joueur jouent leur tour (Étapes 3–9)
    final remainingBots = List<ShadowBot>.from(_botsPendingAfterPlayer);
    _botsPendingAfterPlayer.clear();
    for (final bot in remainingBots) {
      _runShadowBotResolution(bot);
    }

    // Attribuer les rangs d'arrivée à tous les pilotes ayant franchi la ligne ce tour
    _assignFinishRanksForRound();

    if (_playerFinished) {
      _step = RoundStep.finished;
      _log(
        'ARRIVÉE ! Tu termines ${_playerFinishRank}e sur Deutschland en $_roundNumber manches !',
      );
      notifyListeners();
      return;
    }

    _roundNumber++;
    _roundStartProgress = _carProgress;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove = 0;
    _turnSpacesMoved = 0;
    _turnSpeed = 0;
    _roundStartGear = _gear;
    _selectedTargetGear = _gear;
    _adrenalineEligible = false;
    _adrenalineEnabled = false;
    _adrenalineSpeedUsed = false;
    _boostUsed = false;
    _slipstreamUsed = false;
    _cooldownsUsed = 0;
    _cornersResolved = false;
    _lastCornerResults = const [];
    _selectedCardIds.clear();
    _step = RoundStep.shiftGears;
    notifyListeners();
  }

  void shuffleDrawPile() {
    _drawPile.shuffle(_random);
    _log('Pioche mélangée (${_drawPile.length} cartes).');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers Bots, Placement, Blocage & Classement
  // ---------------------------------------------------------------------------

  void _runShadowBotResolution(ShadowBot bot) {
    if (bot.finished) return;
    final hasAdrenaline = _lastCarIdThisRound == bot.id;
    final summary = bot.resolveTurn(
      hasAdrenaline: hasAdrenaline,
      totalLaps: _totalLaps,
      sharedStressReserve: _stressReserve,
      hasSlipstreamTarget: (p) => _hasSlipstreamTargetFor(bot.id, p),
      placeBotAt: (b, desired) {
        final placed = _findOpenSpot(racerId: b.id, desiredProgress: desired);
        b.progress = placed.progress;
        b.lane = placed.lane;
      },
    );
    if (summary.isNotEmpty) {
      _log(summary);
    }
  }

  bool _hasSlipstreamTargetFor(String racerId, int currentProgress) {
    // Un pilote peut prendre l'aspiration s'il y a une autre voiture sur sa case
    // ou 1 case devant lui (p. 6).
    if (racerId != 'player' && !_playerFinished) {
      if (_carProgress == currentProgress || _carProgress == currentProgress + 1) {
        return true;
      }
    }
    for (final bot in _bots) {
      if (bot.id == racerId || bot.finished) continue;
      if (bot.progress == currentProgress ||
          bot.progress == currentProgress + 1) {
        return true;
      }
    }
    return false;
  }

  /// Trouve la case libre la plus avancée <= `desiredProgress` (max 2 voitures/case)
  /// et attribue la corde (lane 0) en priorité (règle p. 5).
  ({int progress, int lane}) _findOpenSpot({
    required String racerId,
    required int desiredProgress,
  }) {
    var p = desiredProgress;
    while (true) {
      final occupiedLanes = <int>{};
      if (racerId != 'player' && !_playerFinished && _carProgress == p) {
        occupiedLanes.add(_carLane);
      }
      for (final bot in _bots) {
        if (bot.id != racerId && !bot.finished && bot.progress == p) {
          occupiedLanes.add(bot.lane);
        }
      }

      if (occupiedLanes.length < 2) {
        final lane = occupiedLanes.contains(0) ? 1 : 0;
        return (progress: p, lane: lane);
      }
      p--;
    }
  }

  void _assignFinishRanksForRound() {
    final newlyFinished = <({String id, int progress, int lane})>[];
    if (!_playerFinished && _carProgress >= finishProgress) {
      newlyFinished.add((id: 'player', progress: _carProgress, lane: _carLane));
    }
    for (final bot in _bots) {
      if (!bot.finished && bot.progress >= finishProgress) {
        newlyFinished.add((id: bot.id, progress: bot.progress, lane: bot.lane));
      }
    }
    if (newlyFinished.isEmpty) return;

    // Règle p. 7 : le plus loin après la ligne gagne, la corde départage les égalités
    newlyFinished.sort((a, b) {
      if (a.progress != b.progress) return b.progress.compareTo(a.progress);
      return a.lane.compareTo(b.lane);
    });

    var nextRank = 1;
    if (_playerFinishRank != null) nextRank = max(nextRank, _playerFinishRank! + 1);
    for (final bot in _bots) {
      if (bot.finishRank != null) nextRank = max(nextRank, bot.finishRank! + 1);
    }

    for (final entry in newlyFinished) {
      if (entry.id == 'player') {
        _playerFinished = true;
        _playerFinishRank = nextRank++;
      } else {
        final bot = _bots.firstWhere((b) => b.id == entry.id);
        bot.finished = true;
        bot.finishRank = nextRank++;
      }
    }
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
        _reshuffleDiscardIntoDraw(silent: true);
      }
      _hand.add(_drawPile.removeLast());
    }
  }

  void _reshuffleDiscardIntoDraw({bool silent = false}) {
    if (_discardPile.isEmpty) return;
    _drawPile.addAll(_discardPile);
    _discardPile.clear();
    _drawPile.shuffle(_random);
    if (!silent) {
      _log('Pioche vide : défausse remélangée (${_drawPile.length} cartes).');
    }
  }

  void _log(String message) {
    _eventLog.insert(0, '[M$_roundNumber] $message');
    if (_eventLog.length > 50) {
      _eventLog.removeRange(50, _eventLog.length);
    }
  }
}
