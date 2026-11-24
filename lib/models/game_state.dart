import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/heat_theme.dart';
import 'heat_card.dart';
import 'shadow_bot.dart';
import 'track_data.dart';

/// Étapes officielles d'un tour (livret p. 4–6) + jet de dés + tour d'un bot.
enum RoundStep {
  diceRoll(0, 'Jet de dés', true),
  shiftGears(1, 'Changer de vitesse', true),
  playCards(2, 'Jouer des cartes', true),
  botTurn(3, 'Tour adverse', true),
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

/// Entrée dans la file d'ordre de passage de la manche (du 1er au dernier).
class TurnOrderEntry {
  const TurnOrderEntry({
    required this.racerId,
    required this.name,
    required this.color,
    required this.isHuman,
  });

  final String racerId;
  final String name;
  final Color color;
  final bool isHuman;
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

/// Entrée structurée du récapitulatif des actions (cartes jouées, levier de
/// vitesse, Heat restant / dépensé / manquant, refroidissement).
class RaceRecapEntry {
  const RaceRecapEntry({
    required this.roundNumber,
    required this.racerId,
    required this.racerName,
    required this.racerColor,
    required this.isHuman,
    required this.previousGear,
    required this.finalGear,
    required this.shiftHeatPaid,
    required this.cards,
    required this.speed,
    required this.spaceNumber,
    required this.engineHeatRemaining,
    required this.heatSpent,
    required this.heatMissing,
    required this.cooledHeat,
    required this.spunOut,
    required this.details,
  });

  final int roundNumber;
  final String racerId;
  final String racerName;
  final Color racerColor;
  final bool isHuman;
  final int previousGear;
  final int finalGear;
  final int shiftHeatPaid;
  final List<HeatCard> cards;
  final int speed;
  final int spaceNumber;
  final int engineHeatRemaining;
  final int heatSpent;
  final int heatMissing;
  final int cooledHeat;
  final bool spunOut;
  final List<String> details;
}

/// Moteur complet des règles de base de Heat (circuit Deutschland) avec :
/// - Mode Compétition (sans 0/5 par défaut) ou Initiation (avec 0/5/+1 Heat)
/// - 2 Bots Shadow sans triche avec suivi visuel tour par tour (1er devant commence)
/// - Jet de dés de départ & notifications explicites des cartes Heat / Moteur
class HeatGameController extends ChangeNotifier {
  HeatGameController({
    int totalLaps = DeutschlandTrack.defaultLaps,
    bool includeStartingUpgrades = false,
    Random? random,
  })  : _totalLaps = totalLaps,
        _includeStartingUpgrades = includeStartingUpgrades,
        _random = random ?? Random() {
    resetRace(
      totalLaps: totalLaps,
      includeStartingUpgrades: includeStartingUpgrades,
    );
  }

  final Random _random;
  int _totalLaps;
  bool _includeStartingUpgrades;

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

  // Étape en cours & ordre de passage de la manche
  RoundStep _step = RoundStep.diceRoll;
  List<TurnOrderEntry> _turnOrderQueue = [];
  int _activeTurnIndex = -1;
  bool _playerClutteredThisRound = false;

  // Animation pas à pas du bot actif
  Timer? _botAnimTimer;
  BotTurnOutcome? _activeBotOutcome;
  int _botAnimStepIdx = 0;
  bool _isBotAnimating = false;

  bool _adrenalineEligible = false;
  bool _adrenalineEnabled = false;
  bool _adrenalineSpeedUsed = false;
  bool _boostUsed = false;
  bool _slipstreamUsed = false;
  int _cooldownsUsed = 0;
  bool _cornersResolved = false;
  List<CornerCheckResult> _lastCornerResults = const [];

  // Notification explicite pour les mouvements de cartes Heat / Moteur
  String? _lastHeatNotice;
  bool _lastHeatNoticeIsCooldown = false;

  // Cartes du joueur
  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];
  List<HeatCard> _stressReserve = [];

  // 2 adversaires en mode Shadow
  late List<ShadowBot> _bots;
  String? _lastCarIdThisRound;

  final Set<String> _selectedCardIds = {};
  final List<String> _eventLog = [];
  final List<RaceRecapEntry> _recapEntries = [];

  int _playerShiftHeatPaid = 0;
  int _playerHeatSpentThisRound = 0;
  int _playerHeatMissingThisRound = 0;
  int _playerCooledThisRound = 0;
  bool _playerSpunOutThisRound = false;
  final List<String> _playerRoundDetails = [];

  @override
  void dispose() {
    _botAnimTimer?.cancel();
    super.dispose();
  }

  // Getters publics
  int get totalLaps => _totalLaps;
  bool get includeStartingUpgrades => _includeStartingUpgrades;
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

  List<TurnOrderEntry> get turnOrderQueue => List.unmodifiable(_turnOrderQueue);
  int get activeTurnIndex => _activeTurnIndex;
  BotTurnOutcome? get activeBotOutcome => _activeBotOutcome;
  bool get isBotAnimating => _isBotAnimating;

  bool get adrenalineEligible => _adrenalineEligible;
  bool get adrenalineEnabled => _adrenalineEnabled;
  bool get adrenalineSpeedUsed => _adrenalineSpeedUsed;
  bool get boostUsed => _boostUsed;
  bool get slipstreamUsed => _slipstreamUsed;
  bool get cornersResolved => _cornersResolved;
  List<CornerCheckResult> get lastCornerResults =>
      List.unmodifiable(_lastCornerResults);

  String? get lastHeatNotice => _lastHeatNotice;
  bool get lastHeatNoticeIsCooldown => _lastHeatNoticeIsCooldown;

  List<HeatCard> get drawPile => List.unmodifiable(_drawPile);
  List<HeatCard> get hand => List.unmodifiable(_hand);
  List<HeatCard> get playArea => List.unmodifiable(_playArea);
  List<HeatCard> get discardPile => List.unmodifiable(_discardPile);
  List<HeatCard> get engineHeat => List.unmodifiable(_engineHeat);
  List<HeatCard> get stressReserve => List.unmodifiable(_stressReserve);
  Set<String> get selectedCardIds => Set.unmodifiable(_selectedCardIds);
  List<String> get eventLog => List.unmodifiable(_eventLog);
  List<RaceRecapEntry> get recapEntries => List.unmodifiable(_recapEntries);

  /// États publics des 2 adversaires (ordre fixe Bleu / Vert pour la stabilité visuelle).
  List<RacerTrackState> get opponentStates =>
      _bots.map((b) => b.toTrackState()).toList();

  TrackSpace get currentSpace => DeutschlandTrack.spaceForProgress(_carProgress);
  int get currentLap => DeutschlandTrack.lapForProgress(_carProgress);
  bool get hasCrossedFinishLine => _carProgress >= finishProgress;
  int? get playerFinishRank => _playerFinishRank;

  int get heatCardsInHandCount => _hand.where((c) => c.isHeat).length;

  /// Vrai si le joueur a des cartes Heat en main qu'il peut refroidir maintenant.
  bool get canCooldownNow =>
      _step == RoundStep.react &&
      remainingCooldowns > 0 &&
      heatCardsInHandCount > 0;

  NextCornerInfo get nextCornerInfo => DeutschlandTrack.nextCornerInfo(
        progress: _carProgress,
        totalLaps: _totalLaps,
      );

  /// Classement en direct (du 1er devant au dernier ; corde départage les égalités).
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
        previousGear: _roundStartGear,
        shiftHeatPaid: _playerShiftHeatPaid,
        engineHeatCount: _engineHeat.length,
        drawPileCount: _drawPile.length,
        discardPileCount: _discardPile.length,
        topDiscardCard: _discardPile.isEmpty ? null : _discardPile.last,
        revealedCardsThisRound: List.unmodifiable(_playArea),
        turnSpeed: _turnSpeed,
        lastHeatSpent: _playerHeatSpentThisRound,
        lastHeatMissing: _playerHeatMissingThisRound,
        lastCooledHeat: _playerCooledThisRound,
        lastSpunOut: _playerSpunOutThisRound,
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

  /// Ordre d'affichage pour le suivi de la manche au-dessus des étapes.
  List<TurnOrderEntry> get displayedTurnOrder {
    if (_turnOrderQueue.isNotEmpty) return _turnOrderQueue;
    return standings
        .where((r) => !r.finished)
        .map(
          (r) => TurnOrderEntry(
            racerId: r.id,
            name: r.name,
            color: r.color,
            isHuman: r.isHuman,
          ),
        )
        .toList();
  }

  /// Nom du prochain pilote dans la file (ou null si fin de manche).
  TurnOrderEntry? get nextDriverInQueue {
    final nextIdx = _activeTurnIndex + 1;
    if (nextIdx >= 0 && nextIdx < _turnOrderQueue.length) {
      return _turnOrderQueue[nextIdx];
    }
    return null;
  }

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

  bool get hasRealSlipstreamTarget =>
      _hasSlipstreamTargetFor('player', _carProgress);

  bool get canUseSlipstream {
    if (_step != RoundStep.slipstream || _slipstreamUsed) return false;
    if (_pendingStepsToMove > 0) return false;
    if (!hasRealSlipstreamTarget) return false;
    if (_carProgress + 2 >= finishProgress) return false;
    return true;
  }

  void resetRace({int? totalLaps, bool? includeStartingUpgrades}) {
    _botAnimTimer?.cancel();
    if (totalLaps != null) _totalLaps = totalLaps;
    if (includeStartingUpgrades != null) {
      _includeStartingUpgrades = includeStartingUpgrades;
    }

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
    _turnOrderQueue = [];
    _activeTurnIndex = -1;
    _playerClutteredThisRound = false;
    _activeBotOutcome = null;
    _botAnimStepIdx = 0;
    _isBotAnimating = false;

    _adrenalineEligible = false;
    _adrenalineEnabled = false;
    _adrenalineSpeedUsed = false;
    _boostUsed = false;
    _slipstreamUsed = false;
    _cooldownsUsed = 0;
    _cornersResolved = false;
    _lastCornerResults = const [];
    _lastHeatNotice = null;
    _lastHeatNoticeIsCooldown = false;
    _selectedCardIds.clear();
    _lastCarIdThisRound = null;

    _drawPile = createDeutschlandStarterDeck(
      includeStartingUpgrades: _includeStartingUpgrades,
    )..shuffle(_random);
    _engineHeat = createDeutschlandEngineHeat();
    _stressReserve = createStressReserve();
    _hand = [];
    _playArea = [];
    _discardPile = [];
    _eventLog.clear();
    _recapEntries.clear();
    _playerShiftHeatPaid = 0;
    _playerHeatSpentThisRound = 0;
    _playerHeatMissingThisRound = 0;
    _playerCooledThisRound = 0;
    _playerSpunOutThisRound = false;
    _playerRoundDetails.clear();

    _bots = [
      ShadowBot(
        id: 'bot_blue',
        name: 'Pilote Bleu',
        color: const Color(0xFF1565C0),
        aggressiveness: 0.65,
        random: _random,
        includeStartingUpgrades: _includeStartingUpgrades,
      ),
      ShadowBot(
        id: 'bot_green',
        name: 'Pilote Vert',
        color: const Color(0xFF2E7D32),
        aggressiveness: 0.40,
        random: _random,
        includeStartingUpgrades: _includeStartingUpgrades,
      ),
    ];

    _drawUpToSeven();
    final modeLabel = _includeStartingUpgrades
        ? 'Avec cartes 0/5 (+1 Heat)'
        : 'Mode Compétition (sans 0/5)';
    _log(
      'Prêt au départ sur Deutschland ($_totalLaps tours • $modeLabel) : '
      'lance les dés pour la grille !',
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 0 : Jet de dés
  // ---------------------------------------------------------------------------

  void rollStartingDice() {
    if (_step != RoundStep.diceRoll) return;

    final faces = [1, 2, 3, 4, 5, 6]..shuffle(_random);
    _playerDiceRoll = faces[0];
    _bots[0].diceRoll = faces[1];
    _bots[1].diceRoll = faces[2];
    _diceRolled = true;

    final entries = <({String id, String name, int roll})>[
      (id: 'player', name: 'Toi (Rouge)', roll: _playerDiceRoll),
      (id: _bots[0].id, name: _bots[0].name, roll: _bots[0].diceRoll),
      (id: _bots[1].id, name: _bots[1].name, roll: _bots[1].diceRoll),
    ]..sort((a, b) => b.roll.compareTo(a.roll));

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
  // ÉTAPE 1 : Changer de vitesse
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

    _lastHeatNotice = null;
    _playerShiftHeatPaid = cost;
    if (cost > 0) {
      _payHeat(cost, reason: 'Changement de vitesse ±2 ($_roundStartGear → $_selectedTargetGear)');
      _playerRoundDetails.add('Levier V$_roundStartGear → V$_selectedTargetGear : 🔥 -1 Heat');
    } else if (_selectedTargetGear != _roundStartGear) {
      _log('Étape 1 : Vitesse $_roundStartGear → $_selectedTargetGear.');
      _playerRoundDetails.add('Levier V$_roundStartGear → V$_selectedTargetGear');
    } else {
      _playerRoundDetails.add('Levier maintenu en V$_selectedTargetGear');
      _log('Étape 1 : Maintien en vitesse $_selectedTargetGear.');
    }

    _gear = _selectedTargetGear;
    _selectedCardIds.clear();
    _step = RoundStep.playCards;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 2 : Jouer des cartes (simultané) → lancement de l'ordre de passage
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

    // 1. Les 2 bots planifient simultanément leurs vraies cartes (mode shadow)
    for (final bot in _bots) {
      if (!bot.finished) {
        bot.planTurn(totalLaps: _totalLaps);
      }
    }

    // 2. Jouer les cartes du joueur face cachée dans _playArea
    final chosen = _hand.where((c) => _selectedCardIds.contains(c.id)).toList();
    _hand.removeWhere((c) => _selectedCardIds.contains(c.id));
    _playArea.addAll(chosen);
    _selectedCardIds.clear();
    _playerClutteredThisRound = chosen.any((c) => c.isHeat);

    // 3. Figer l'ordre de résolution : TOUJOURS le pilote devant qui commence !
    final activeOrder = standings.where((r) => !r.finished).toList();
    _lastCarIdThisRound = activeOrder.isNotEmpty ? activeOrder.last.id : null;
    _adrenalineEligible = _lastCarIdThisRound == 'player';

    _turnOrderQueue = activeOrder
        .map(
          (r) => TurnOrderEntry(
            racerId: r.id,
            name: r.name,
            color: r.color,
            isHuman: r.isHuman,
          ),
        )
        .toList();
    _activeTurnIndex = 0;

    _beginTurnForCurrentQueueIndex();
  }

  /// Lance le tour (Étapes 3–9) du pilote actif dans `_turnOrderQueue`.
  void _beginTurnForCurrentQueueIndex() {
    _botAnimTimer?.cancel();
    _isBotAnimating = false;
    _activeBotOutcome = null;

    if (_activeTurnIndex < 0 || _activeTurnIndex >= _turnOrderQueue.length) {
      _finishCurrentRound();
      return;
    }

    final current = _turnOrderQueue[_activeTurnIndex];
    if (current.isHuman) {
      if (_playerClutteredThisRound) {
        _log(
          'Main encombrée (p. 7) : tu n\'avances pas ce tour, boîte remise en V1.',
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
    } else {
      final bot = _bots.firstWhere((b) => b.id == current.racerId);
      _startVisibleBotTurn(bot);
    }
  }

  /// Résout le tour d'un bot et anime sa voiture case par case sur le circuit !
  void _startVisibleBotTurn(ShadowBot bot) {
    final hasAdrenaline = _lastCarIdThisRound == bot.id;
    final outcome = bot.resolveTurn(
      hasAdrenaline: hasAdrenaline,
      totalLaps: _totalLaps,
      sharedStressReserve: _stressReserve,
      hasSlipstreamTarget: (p) => _hasSlipstreamTargetFor(bot.id, p),
      findOpenSpot: (botId, desired) =>
          _findOpenSpot(racerId: botId, desiredProgress: desired),
    );

    _step = RoundStep.botTurn;
    _activeBotOutcome = outcome;
    _botAnimStepIdx = 0;
    _log(outcome.summary);
    _addRecapEntry(
      RaceRecapEntry(
        roundNumber: _roundNumber,
        racerId: outcome.botId,
        racerName: outcome.botName,
        racerColor: outcome.botColor,
        isHuman: false,
        previousGear: outcome.previousGear,
        finalGear: outcome.finalGear,
        shiftHeatPaid: outcome.shiftHeatPaid,
        cards: outcome.revealedCards,
        speed: outcome.speed,
        spaceNumber:
            DeutschlandTrack.spaceForProgress(outcome.finalProgress).spaceNumber,
        engineHeatRemaining: outcome.engineHeatRemaining,
        heatSpent: outcome.totalHeatSpent,
        heatMissing: outcome.cornerHeatMissing,
        cooledHeat: outcome.cooledHeatCount,
        spunOut: outcome.spunOut,
        details: outcome.actionDetails,
      ),
    );

    if (outcome.pathProgresses.isEmpty) {
      bot.progress = outcome.finalProgress;
      bot.lane = outcome.finalLane;
      _isBotAnimating = false;
      notifyListeners();
      return;
    }

    _isBotAnimating = true;
    // Premier pas immédiat pour que la voiture commence tout de suite à bouger
    _applyBotAnimStep(bot, outcome);
    notifyListeners();

    if (_isBotAnimating) {
      _botAnimTimer = Timer.periodic(const Duration(milliseconds: 210), (t) {
        _applyBotAnimStep(bot, outcome);
        if (!_isBotAnimating) {
          t.cancel();
        }
        notifyListeners();
      });
    }
  }

  void _applyBotAnimStep(ShadowBot bot, BotTurnOutcome outcome) {
    if (_botAnimStepIdx < outcome.pathProgresses.length) {
      bot.progress = outcome.pathProgresses[_botAnimStepIdx];
      _botAnimStepIdx++;
      if (_botAnimStepIdx >= outcome.pathProgresses.length) {
        bot.progress = outcome.finalProgress;
        bot.lane = outcome.finalLane;
        _isBotAnimating = false;
      } else {
        bot.lane = _visualLaneFor(bot.id, bot.progress);
      }
    } else {
      bot.progress = outcome.finalProgress;
      bot.lane = outcome.finalLane;
      _isBotAnimating = false;
    }
  }

  /// Termine l'animation du bot actif (si en cours) et passe au pilote suivant !
  void proceedAfterBotTurn() {
    if (_step != RoundStep.botTurn) return;
    _botAnimTimer?.cancel();
    if (_activeBotOutcome != null) {
      final bot = _bots.firstWhere((b) => b.id == _activeBotOutcome!.botId);
      bot.progress = _activeBotOutcome!.finalProgress;
      bot.lane = _activeBotOutcome!.finalLane;
    }
    _isBotAnimating = false;
    _activeBotOutcome = null;
    _activeTurnIndex++;
    _beginTurnForCurrentQueueIndex();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 3 : Révéler & Avancer (Joueur)
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
      'À ton tour (Étape 3) : ${revealedSummary.join(', ')} → Vitesse $_turnSpeed.',
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
      _carLane = _visualLaneFor('player', _carProgress);
    }
    notifyListeners();
  }

  void stepCarBackward() {
    if (_carProgress <= _moveFloorProgress) return;
    _carProgress--;
    _pendingStepsToMove++;
    if (_turnSpacesMoved > 0) _turnSpacesMoved--;
    _carLane = _visualLaneFor('player', _carProgress);
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

  void _applyPlayerFinalPlacement() {
    final desired = _carProgress;
    final placed = _findOpenSpot(racerId: 'player', desiredProgress: desired);
    _carProgress = placed.progress;
    _carLane = placed.lane;
    if (placed.progress < desired) {
      _log(
        'Case bloquée par 2 voitures ! Replacé sur la case libre derrière '
        '(case ${currentSpace.spaceNumber}).',
      );
    }
  }

  int _visualLaneFor(String racerId, int progress) {
    final lane0Occupied = (racerId != 'player' &&
            !_playerFinished &&
            _carProgress == progress &&
            _carLane == 0) ||
        _bots.any(
          (b) =>
              b.id != racerId &&
              !b.finished &&
              b.progress == progress &&
              b.lane == 0,
        );
    return lane0Occupied ? 1 : 0;
  }

  void proceedFromRevealAndMove() {
    if (_step != RoundStep.revealAndMove || _pendingStepsToMove > 0) return;
    if (_adrenalineEligible) {
      _step = RoundStep.adrenaline;
    } else {
      _adrenalineEnabled = false;
      _step = RoundStep.react;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 4 : Adrénaline
  // ---------------------------------------------------------------------------

  void chooseAdrenaline({required bool activate}) {
    if (_step != RoundStep.adrenaline) return;
    _adrenalineEnabled = activate && _adrenalineEligible;
    if (_adrenalineEnabled) {
      _log('Étape 4 : Adrénaline activée (+1 Vitesse/case et +1 Refroidissement).');
    }
    _step = RoundStep.react;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 5 : Réagir (Refroidissement explicite, Boost, Adrénaline +1)
  // ---------------------------------------------------------------------------

  void cooldownOneHeat() {
    if (!canCooldownNow) return;
    final card = _hand.firstWhere((c) => c.isHeat);
    _cooldownHeatCard(card);
  }

  void cooldownAllPossibleHeat() {
    if (!canCooldownNow) return;
    var count = 0;
    while (remainingCooldowns > 0) {
      final idx = _hand.indexWhere((c) => c.isHeat);
      if (idx == -1) break;
      _engineHeat.add(_hand.removeAt(idx));
      _cooldownsUsed++;
      count++;
    }
    if (count > 0) {
      _playerCooledThisRound += count;
      _playerRoundDetails.add('❄️ Refroidissement : +$count Heat (Main → Moteur)');
      _lastHeatNotice =
          '❄️ $count carte(s) Heat renvoyée(s) : Main → Moteur (${_engineHeat.length} dans le moteur)';
      _lastHeatNoticeIsCooldown = true;
      _log(
        'Étape 5 (Refroidissement) : $count Heat renvoyée(s) de la main vers le moteur.',
      );
      notifyListeners();
    }
  }

  void _cooldownHeatCard(HeatCard card) {
    if (_step != RoundStep.react || remainingCooldowns <= 0) return;
    if (!card.isHeat) return;
    _hand.remove(card);
    _engineHeat.add(card);
    _cooldownsUsed++;
    _playerCooledThisRound++;
    _playerRoundDetails.add('❄️ Refroidissement : +1 Heat (Main → Moteur)');
    _lastHeatNotice =
        '❄️ 1 Heat renvoyée : Main → Moteur (${_engineHeat.length} dans le moteur)';
    _lastHeatNoticeIsCooldown = true;
    _log(
      'Étape 5 (Refroidissement) : 1 Heat renvoyée au moteur (restant : $remainingCooldowns).',
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
    _log('Étape 5 (Adrénaline +1) : +1 Vitesse (total $_turnSpeed) et +1 case.');
    notifyListeners();
  }

  void activateBoost() {
    if (_step != RoundStep.react || _boostUsed || _engineHeat.isEmpty) return;
    _boostUsed = true;
    _payHeat(1, reason: 'Boost');
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
  // ÉTAPE 6 : Aspiration
  // ---------------------------------------------------------------------------

  void activateSlipstream() {
    if (!canUseSlipstream) return;
    _slipstreamUsed = true;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove += 2;
    _log('Étape 6 (Aspiration) : +2 cases (ne compte pas pour les virages).');
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
  // ÉTAPE 7 : Vérifier les virages
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
            _payHeat(excess, reason: event.corner.name);
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
          } else {
            final paid = _engineHeat.length;
            final missing = excess - paid;
            _playerHeatMissingThisRound = missing;
            _playerSpunOutThisRound = true;
            if (paid > 0) {
              _payHeat(paid, reason: 'Tête-à-queue (${event.corner.name})');
            }

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
            _playerRoundDetails.add(
              '💥 Tête-à-queue (${event.corner.name}) : manquait $missing🔥, +$actualStress Stress, levier → V1',
            );

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
  // ÉTAPE 8 : Défausser
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
  // ÉTAPE 9 : Compléter sa main → passe au pilote suivant dans la file !
  // ---------------------------------------------------------------------------

  void replenishAndStartNextRound() {
    if (_step != RoundStep.replenishHand) return;

    final playedSnapshot = List<HeatCard>.from(_playArea);
    _addRecapEntry(
      RaceRecapEntry(
        roundNumber: _roundNumber,
        racerId: 'player',
        racerName: 'Toi (Rouge)',
        racerColor: HeatColors.heatRed,
        isHuman: true,
        previousGear: _roundStartGear,
        finalGear: _gear,
        shiftHeatPaid: _playerShiftHeatPaid,
        cards: playedSnapshot,
        speed: _turnSpeed,
        spaceNumber: currentSpace.spaceNumber,
        engineHeatRemaining: _engineHeat.length,
        heatSpent: _playerHeatSpentThisRound,
        heatMissing: _playerHeatMissingThisRound,
        cooledHeat: _playerCooledThisRound,
        spunOut: _playerSpunOutThisRound,
        details: List<String>.from(_playerRoundDetails),
      ),
    );

    if (_playArea.isNotEmpty) {
      _discardPile.addAll(_playArea);
      _playArea.clear();
    }
    _drawUpToSeven();

    // Passer au pilote suivant dans l'ordre de la manche (les bots derrière toi)
    _activeTurnIndex++;
    _beginTurnForCurrentQueueIndex();
  }

  void _finishCurrentRound() {
    _assignFinishRanksForRound();

    if (_playerFinished) {
      _step = RoundStep.finished;
      _turnOrderQueue = [];
      _activeTurnIndex = -1;
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
    _turnOrderQueue = [];
    _activeTurnIndex = -1;
    _playerClutteredThisRound = false;
    _adrenalineEligible = false;
    _adrenalineEnabled = false;
    _adrenalineSpeedUsed = false;
    _boostUsed = false;
    _slipstreamUsed = false;
    _cooldownsUsed = 0;
    _cornersResolved = false;
    _lastCornerResults = const [];
    _selectedCardIds.clear();
    _playerShiftHeatPaid = 0;
    _playerHeatSpentThisRound = 0;
    _playerHeatMissingThisRound = 0;
    _playerCooledThisRound = 0;
    _playerSpunOutThisRound = false;
    _playerRoundDetails.clear();
    _step = RoundStep.shiftGears;
    notifyListeners();
  }

  void shuffleDrawPile() {
    _drawPile.shuffle(_random);
    _log('Pioche mélangée (${_drawPile.length} cartes).');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _hasSlipstreamTargetFor(String racerId, int currentProgress) {
    if (racerId != 'player' && !_playerFinished) {
      if (_carProgress == currentProgress ||
          _carProgress == currentProgress + 1) {
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

    newlyFinished.sort((a, b) {
      if (a.progress != b.progress) return b.progress.compareTo(a.progress);
      return a.lane.compareTo(b.lane);
    });

    var nextRank = 1;
    if (_playerFinishRank != null) {
      nextRank = max(nextRank, _playerFinishRank! + 1);
    }
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

  void _payHeat(int count, {required String reason}) {
    var paid = 0;
    for (var i = 0; i < count; i++) {
      if (_engineHeat.isEmpty) break;
      _discardPile.add(_engineHeat.removeLast());
      paid++;
    }
    if (paid > 0) {
      _playerHeatSpentThisRound += paid;
      _playerRoundDetails.add('🔥 $paid Heat ($reason)');
      _lastHeatNotice =
          '🔥 $paid Heat défaussée(s) : Moteur → Défausse ($reason • reste ${_engineHeat.length} dans le moteur)';
      _lastHeatNoticeIsCooldown = false;
      _log(
        'Heat payé ($reason) : $paid carte(s) Moteur → Défausse (reste ${_engineHeat.length}).',
      );
    }
  }

  void _addRecapEntry(RaceRecapEntry entry) {
    _recapEntries.insert(0, entry);
    if (_recapEntries.length > 30) {
      _recapEntries.removeRange(30, _recapEntries.length);
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
