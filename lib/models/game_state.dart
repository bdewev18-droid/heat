import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/heat_theme.dart';
import 'heat_card.dart';
import 'shadow_bot.dart';
import 'track_data.dart';

/// Étapes officielles d'un tour (livret p. 4–6) + tour d'un bot + arrivée.
enum RoundStep {
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

  String get cardsFormula {
    if (cards.isEmpty) return '0';
    return '${cards.map((c) => c.shortLabel).join(' + ')} = $speed';
  }
}

/// Instantané complet du jeu permettant d'annuler une action ou de recommencer la manche.
class _GameSnapshot {
  const _GameSnapshot({
    required this.roundNumber,
    required this.carProgress,
    required this.carLane,
    required this.playerDiceRoll,
    required this.diceRolled,
    required this.playerFinished,
    required this.playerFinishRank,
    required this.roundStartProgress,
    required this.moveFloorProgress,
    required this.pendingStepsToMove,
    required this.turnSpacesMoved,
    required this.turnSpeed,
    required this.gear,
    required this.roundStartGear,
    required this.selectedTargetGear,
    required this.step,
    required this.turnOrderQueue,
    required this.activeTurnIndex,
    required this.playerClutteredThisRound,
    required this.activeBotOutcome,
    required this.adrenalineEligible,
    required this.adrenalineEnabled,
    required this.adrenalineSpeedUsed,
    required this.boostUsed,
    required this.slipstreamUsed,
    required this.cooldownsUsed,
    required this.cornersResolved,
    required this.lastCornerResults,
    required this.lastHeatNotice,
    required this.lastHeatNoticeIsCooldown,
    required this.drawPile,
    required this.hand,
    required this.playArea,
    required this.discardPile,
    required this.engineHeat,
    required this.stressReserve,
    required this.adrenalineRacerIds,
    required this.selectedCardIds,
    required this.eventLog,
    required this.recapEntries,
    required this.playerShiftHeatPaid,
    required this.playerHeatSpentThisRound,
    required this.playerHeatMissingThisRound,
    required this.playerCooledThisRound,
    required this.playerSpunOutThisRound,
    required this.playerRoundDetails,
    required this.botSnapshots,
  });

  final int roundNumber;
  final int carProgress;
  final int carLane;
  final int playerDiceRoll;
  final bool diceRolled;
  final bool playerFinished;
  final int? playerFinishRank;
  final int roundStartProgress;
  final int moveFloorProgress;
  final int pendingStepsToMove;
  final int turnSpacesMoved;
  final int turnSpeed;
  final int gear;
  final int roundStartGear;
  final int selectedTargetGear;
  final RoundStep step;
  final List<TurnOrderEntry> turnOrderQueue;
  final int activeTurnIndex;
  final bool playerClutteredThisRound;
  final BotTurnOutcome? activeBotOutcome;
  final bool adrenalineEligible;
  final bool adrenalineEnabled;
  final bool adrenalineSpeedUsed;
  final bool boostUsed;
  final bool slipstreamUsed;
  final int cooldownsUsed;
  final bool cornersResolved;
  final List<CornerCheckResult> lastCornerResults;
  final String? lastHeatNotice;
  final bool lastHeatNoticeIsCooldown;
  final List<HeatCard> drawPile;
  final List<HeatCard> hand;
  final List<HeatCard> playArea;
  final List<HeatCard> discardPile;
  final List<HeatCard> engineHeat;
  final List<HeatCard> stressReserve;
  final Set<String> adrenalineRacerIds;
  final Set<String> selectedCardIds;
  final List<String> eventLog;
  final List<RaceRecapEntry> recapEntries;
  final int playerShiftHeatPaid;
  final int playerHeatSpentThisRound;
  final int playerHeatMissingThisRound;
  final int playerCooledThisRound;
  final bool playerSpunOutThisRound;
  final List<String> playerRoundDetails;
  final List<ShadowBotSnapshot> botSnapshots;
}

/// Moteur complet des règles de base de Heat (circuit Deutschland) :
/// - Joueur : Green Hornet (Vert), position fixe ou aléatoire choisie avant le départ
/// - 1 à 8 joueurs (0 à 7 bots réels sans triche)
/// - Mode Compétition (sans 0/5 par défaut) & Cartes Bonus Deckbuild
/// - Annulation action par action + Recommencer la manche en cours
class HeatGameController extends ChangeNotifier {
  HeatGameController({
    int totalLaps = DeutschlandTrack.defaultLaps,
    bool includeStartingUpgrades = false,
    bool includeBonusCards = false,
    int playerCount = 3,
    int? fixedStartPosition,
    Random? random,
  })  : _totalLaps = totalLaps,
        _includeStartingUpgrades = includeStartingUpgrades,
        _includeBonusCards = includeBonusCards,
        _playerCount = playerCount.clamp(1, 8),
        _fixedStartPosition = fixedStartPosition,
        _random = random ?? Random() {
    resetRace(
      totalLaps: totalLaps,
      includeStartingUpgrades: includeStartingUpgrades,
      includeBonusCards: includeBonusCards,
      playerCount: _playerCount,
      fixedStartPosition: fixedStartPosition,
    );
  }

  static const String playerDisplayName = 'Green Hornet';

  final Random _random;
  int _totalLaps;
  bool _includeStartingUpgrades;
  bool _includeBonusCards;
  int _playerCount;
  int? _fixedStartPosition;
  int _playerStartPosition = 1;

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
  RoundStep _step = RoundStep.shiftGears;
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

  String? _lastHeatNotice;
  bool _lastHeatNoticeIsCooldown = false;

  // Cartes du joueur
  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];
  List<HeatCard> _stressReserve = [];

  // Bots adverses (0 à 7)
  late List<ShadowBot> _bots;
  Set<String> _adrenalineRacerIdsThisRound = {};

  final Set<String> _selectedCardIds = {};
  final List<String> _eventLog = [];
  final List<RaceRecapEntry> _recapEntries = [];

  int _playerShiftHeatPaid = 0;
  int _playerHeatSpentThisRound = 0;
  int _playerHeatMissingThisRound = 0;
  int _playerCooledThisRound = 0;
  bool _playerSpunOutThisRound = false;
  final List<String> _playerRoundDetails = [];

  // Historique d'annulation (action précédente & début de la manche en cours)
  final List<_GameSnapshot> _undoStack = [];
  _GameSnapshot? _roundStartSnapshot;

  @override
  void dispose() {
    _botAnimTimer?.cancel();
    super.dispose();
  }

  // Getters publics
  int get totalLaps => _totalLaps;
  bool get includeStartingUpgrades => _includeStartingUpgrades;
  bool get includeBonusCards => _includeBonusCards;
  int get playerCount => _playerCount;
  int? get fixedStartPosition => _fixedStartPosition;
  int get startPosition => _playerStartPosition;
  int get botCount => _bots.length;
  int get finishProgress => _totalLaps * DeutschlandTrack.totalSpaces;
  int get finishLineDistance => max(0, _carProgress - finishProgress);
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

  bool get canUndo =>
      _undoStack.isNotEmpty && _step != RoundStep.finished;

  bool get canRestartRound =>
      _roundStartSnapshot != null &&
      _undoStack.isNotEmpty &&
      _step != RoundStep.finished;

  List<RacerTrackState> get opponentStates =>
      _bots.map((b) => b.toTrackState()).toList();

  TrackSpace get currentSpace => DeutschlandTrack.spaceForProgress(_carProgress);
  int get currentLap => DeutschlandTrack.lapForProgress(_carProgress);
  bool get hasCrossedFinishLine => _carProgress >= finishProgress;
  int? get playerFinishRank => _playerFinishRank;

  int get heatCardsInHandCount => _hand.where((c) => c.isHeat).length;

  bool get canCooldownNow =>
      _step == RoundStep.react &&
      remainingCooldowns > 0 &&
      heatCardsInHandCount > 0;

  NextCornerInfo get nextCornerInfo => DeutschlandTrack.nextCornerInfo(
        progress: _carProgress,
        totalLaps: _totalLaps,
      );

  List<RacerTrackState> get standings {
    final list = <RacerTrackState>[
      RacerTrackState(
        id: 'player',
        name: playerDisplayName,
        color: HeatColors.trackGreen,
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
        discardPile: List.unmodifiable(_discardPile),
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

  /// Bonus supplémentaire d'aspiration provenant des cartes Bonus jouées ce tour.
  int get bonusSlipstreamFromCards =>
      _playArea.fold(0, (sum, c) => sum + c.slipstreamBonus);

  /// Distance totale d'aspiration (+2 de base + bonus éventuel des cartes jouées).
  int get slipstreamDistance => 2 + bonusSlipstreamFromCards;

  bool get canUseSlipstream {
    if (_step != RoundStep.slipstream || _slipstreamUsed) return false;
    if (_pendingStepsToMove > 0) return false;
    if (!hasRealSlipstreamTarget) return false;
    if (_carProgress + slipstreamDistance >= finishProgress) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Snapshots : Annuler la dernière action / Recommencer la manche en cours
  // ---------------------------------------------------------------------------

  _GameSnapshot _captureSnapshot() => _GameSnapshot(
        roundNumber: _roundNumber,
        carProgress: _carProgress,
        carLane: _carLane,
        playerDiceRoll: _playerDiceRoll,
        diceRolled: _diceRolled,
        playerFinished: _playerFinished,
        playerFinishRank: _playerFinishRank,
        roundStartProgress: _roundStartProgress,
        moveFloorProgress: _moveFloorProgress,
        pendingStepsToMove: _pendingStepsToMove,
        turnSpacesMoved: _turnSpacesMoved,
        turnSpeed: _turnSpeed,
        gear: _gear,
        roundStartGear: _roundStartGear,
        selectedTargetGear: _selectedTargetGear,
        step: _step,
        turnOrderQueue: List<TurnOrderEntry>.from(_turnOrderQueue),
        activeTurnIndex: _activeTurnIndex,
        playerClutteredThisRound: _playerClutteredThisRound,
        activeBotOutcome: _activeBotOutcome,
        adrenalineEligible: _adrenalineEligible,
        adrenalineEnabled: _adrenalineEnabled,
        adrenalineSpeedUsed: _adrenalineSpeedUsed,
        boostUsed: _boostUsed,
        slipstreamUsed: _slipstreamUsed,
        cooldownsUsed: _cooldownsUsed,
        cornersResolved: _cornersResolved,
        lastCornerResults: List<CornerCheckResult>.from(_lastCornerResults),
        lastHeatNotice: _lastHeatNotice,
        lastHeatNoticeIsCooldown: _lastHeatNoticeIsCooldown,
        drawPile: List<HeatCard>.from(_drawPile),
        hand: List<HeatCard>.from(_hand),
        playArea: List<HeatCard>.from(_playArea),
        discardPile: List<HeatCard>.from(_discardPile),
        engineHeat: List<HeatCard>.from(_engineHeat),
        stressReserve: List<HeatCard>.from(_stressReserve),
        adrenalineRacerIds: Set<String>.from(_adrenalineRacerIdsThisRound),
        selectedCardIds: Set<String>.from(_selectedCardIds),
        eventLog: List<String>.from(_eventLog),
        recapEntries: List<RaceRecapEntry>.from(_recapEntries),
        playerShiftHeatPaid: _playerShiftHeatPaid,
        playerHeatSpentThisRound: _playerHeatSpentThisRound,
        playerHeatMissingThisRound: _playerHeatMissingThisRound,
        playerCooledThisRound: _playerCooledThisRound,
        playerSpunOutThisRound: _playerSpunOutThisRound,
        playerRoundDetails: List<String>.from(_playerRoundDetails),
        botSnapshots: _bots.map((b) => b.captureSnapshot()).toList(),
      );

  void _restoreSnapshot(_GameSnapshot s) {
    _botAnimTimer?.cancel();
    _isBotAnimating = false;
    _botAnimStepIdx = 0;

    _roundNumber = s.roundNumber;
    _carProgress = s.carProgress;
    _carLane = s.carLane;
    _playerDiceRoll = s.playerDiceRoll;
    _diceRolled = s.diceRolled;
    _playerFinished = s.playerFinished;
    _playerFinishRank = s.playerFinishRank;
    _roundStartProgress = s.roundStartProgress;
    _moveFloorProgress = s.moveFloorProgress;
    _pendingStepsToMove = s.pendingStepsToMove;
    _turnSpacesMoved = s.turnSpacesMoved;
    _turnSpeed = s.turnSpeed;
    _gear = s.gear;
    _roundStartGear = s.roundStartGear;
    _selectedTargetGear = s.selectedTargetGear;
    _step = s.step;
    _turnOrderQueue = List<TurnOrderEntry>.from(s.turnOrderQueue);
    _activeTurnIndex = s.activeTurnIndex;
    _playerClutteredThisRound = s.playerClutteredThisRound;
    _activeBotOutcome = s.activeBotOutcome;
    _adrenalineEligible = s.adrenalineEligible;
    _adrenalineEnabled = s.adrenalineEnabled;
    _adrenalineSpeedUsed = s.adrenalineSpeedUsed;
    _boostUsed = s.boostUsed;
    _slipstreamUsed = s.slipstreamUsed;
    _cooldownsUsed = s.cooldownsUsed;
    _cornersResolved = s.cornersResolved;
    _lastCornerResults = List<CornerCheckResult>.from(s.lastCornerResults);
    _lastHeatNotice = s.lastHeatNotice;
    _lastHeatNoticeIsCooldown = s.lastHeatNoticeIsCooldown;
    _drawPile = List<HeatCard>.from(s.drawPile);
    _hand = List<HeatCard>.from(s.hand);
    _playArea = List<HeatCard>.from(s.playArea);
    _discardPile = List<HeatCard>.from(s.discardPile);
    _engineHeat = List<HeatCard>.from(s.engineHeat);
    _stressReserve = List<HeatCard>.from(s.stressReserve);
    _adrenalineRacerIdsThisRound = Set<String>.from(s.adrenalineRacerIds);
    _selectedCardIds
      ..clear()
      ..addAll(s.selectedCardIds);
    _eventLog
      ..clear()
      ..addAll(s.eventLog);
    _recapEntries
      ..clear()
      ..addAll(s.recapEntries);
    _playerShiftHeatPaid = s.playerShiftHeatPaid;
    _playerHeatSpentThisRound = s.playerHeatSpentThisRound;
    _playerHeatMissingThisRound = s.playerHeatMissingThisRound;
    _playerCooledThisRound = s.playerCooledThisRound;
    _playerSpunOutThisRound = s.playerSpunOutThisRound;
    _playerRoundDetails
      ..clear()
      ..addAll(s.playerRoundDetails);

    for (var i = 0; i < _bots.length && i < s.botSnapshots.length; i++) {
      _bots[i].restoreSnapshot(s.botSnapshots[i]);
    }
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > 35) {
      _undoStack.removeAt(0);
    }
  }

  void _markRoundStartSnapshot() {
    _undoStack.clear();
    _roundStartSnapshot = _captureSnapshot();
  }

  /// Annule la dernière action effectuée (ex: Boost, Adrénaline, changement de vitesse…).
  void undoLastAction() {
    if (!canUndo) return;
    final previous = _undoStack.removeLast();
    _restoreSnapshot(previous);
    notifyListeners();
  }

  /// Revient complètement au début de la manche en cours (Étape 1 : Changer de vitesse).
  void restartCurrentRound() {
    if (!canRestartRound) return;
    final start = _roundStartSnapshot!;
    _restoreSnapshot(start);
    _undoStack.clear();
    _log('Retour au début de la manche #$_roundNumber (Étape 1).');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Initialisation de la course
  // ---------------------------------------------------------------------------

  void resetRace({
    int? totalLaps,
    bool? includeStartingUpgrades,
    bool? includeBonusCards,
    int? playerCount,
    int? fixedStartPosition,
  }) {
    _botAnimTimer?.cancel();
    if (totalLaps != null) _totalLaps = totalLaps;
    if (includeStartingUpgrades != null) {
      _includeStartingUpgrades = includeStartingUpgrades;
    }
    if (includeBonusCards != null) _includeBonusCards = includeBonusCards;
    if (playerCount != null) _playerCount = playerCount.clamp(1, 8);
    if (fixedStartPosition != null) {
      _fixedStartPosition = fixedStartPosition.clamp(1, _playerCount);
    }

    _roundNumber = 1;
    _carProgress = 0;
    _carLane = 0;
    _playerDiceRoll = 0;
    _diceRolled = true;
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
    _adrenalineRacerIdsThisRound = {};

    _drawPile = createDeutschlandStarterDeck(
      includeStartingUpgrades: _includeStartingUpgrades,
      includeBonusCards: _includeBonusCards,
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
    _undoStack.clear();
    _roundStartSnapshot = null;

    _bots = createOpponentBots(
      botCount: _playerCount - 1,
      random: _random,
      includeStartingUpgrades: _includeStartingUpgrades,
    );

    _drawUpToSeven();
    _assignStartingGrid();

    final modeLabel = _includeStartingUpgrades
        ? 'Avec cartes 0/5'
        : 'Compétition (sans 0/5)';
    final bonusLabel = _includeBonusCards ? ' • Carte Bonus Blanche' : '';

    _step = RoundStep.shiftGears;
    _log(
      'Départ sur Deutschland ($_totalLaps tours • $_playerCount joueurs • '
      '$modeLabel$bonusLabel) — $playerDisplayName part P$_playerStartPosition !',
    );
    _markRoundStartSnapshot();
    notifyListeners();
  }

  /// Place tous les pilotes sur la grille (position fixe ou aléatoire décidée avant le départ).
  void _assignStartingGrid() {
    final orderedIds = <String>[];
    if (_bots.isEmpty) {
      _playerStartPosition = 1;
      orderedIds.add('player');
    } else if (_fixedStartPosition != null) {
      final pos = _fixedStartPosition!.clamp(1, _playerCount);
      _playerStartPosition = pos;
      final botIds = _bots.map((b) => b.id).toList()..shuffle(_random);
      var botIdx = 0;
      for (var slot = 1; slot <= _playerCount; slot++) {
        if (slot == pos) {
          orderedIds.add('player');
        } else {
          orderedIds.add(botIds[botIdx++]);
        }
      }
    } else {
      final allIds = <String>['player', ..._bots.map((b) => b.id)]
        ..shuffle(_random);
      orderedIds.addAll(allIds);
      _playerStartPosition = orderedIds.indexOf('player') + 1;
    }

    for (var i = 0; i < orderedIds.length; i++) {
      final gridProgress = -(i ~/ 2);
      final gridLane = i % 2;
      if (orderedIds[i] == 'player') {
        _carProgress = gridProgress;
        _carLane = gridLane;
        _roundStartProgress = _carProgress;
        _moveFloorProgress = _carProgress;
      } else {
        final bot = _bots.firstWhere((b) => b.id == orderedIds[i]);
        bot.progress = gridProgress;
        bot.lane = gridLane;
      }
    }
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

    _pushUndoSnapshot();
    _lastHeatNotice = null;
    _playerShiftHeatPaid = cost;
    if (cost > 0) {
      _payHeat(
        cost,
        reason: 'Changement de vitesse ±2 ($_roundStartGear → $_selectedTargetGear)',
      );
      _playerRoundDetails.add(
        'Levier V$_roundStartGear → V$_selectedTargetGear : 🔥 -1 Heat',
      );
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
  // ÉTAPE 2 : Jouer des cartes (simultané) → ordre de passage
  // ---------------------------------------------------------------------------

  bool canToggleCardInHand(HeatCard card) {
    if (_step == RoundStep.playCards) {
      if (_selectedCardIds.contains(card.id)) return true;
      if (_selectedCardIds.length >= _gear) return false;
      if (card.heatCost > 0) {
        final alreadySelectedHeatCost = _hand
            .where((c) => _selectedCardIds.contains(c.id))
            .fold<int>(0, (sum, c) => sum + c.heatCost);
        if (_engineHeat.length < alreadySelectedHeatCost + card.heatCost) {
          return false;
        }
      }
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
        _pushUndoSnapshot();
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

    _pushUndoSnapshot();

    // 1. Les bots planifient simultanément leurs vraies cartes
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

    // Coût en Heat des cartes Bonus jouées (ex: Carte Blanche -1 Heat)
    final cardHeatCost = chosen.fold<int>(0, (sum, c) => sum + c.heatCost);
    if (cardHeatCost > 0) {
      _payHeat(cardHeatCost, reason: 'Carte Bonus Blanche');
    }

    // 3. Figer l'ordre de résolution : TOUJOURS le pilote devant qui commence !
    final activeOrder = standings.where((r) => !r.finished).toList();

    // Règle officielle p. 5 : Adrénaline pour le dernier pilote (ou les 2 derniers si >= 5 joueurs au départ)
    _adrenalineRacerIdsThisRound = {};
    if (_playerCount >= 2 && activeOrder.isNotEmpty) {
      final adrCount = _playerCount >= 5 ? 2 : 1;
      for (var k = 0; k < adrCount && k < activeOrder.length; k++) {
        _adrenalineRacerIdsThisRound.add(
          activeOrder[activeOrder.length - 1 - k].id,
        );
      }
    }
    _adrenalineEligible = _adrenalineRacerIdsThisRound.contains('player');

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

  void _startVisibleBotTurn(ShadowBot bot) {
    final hasAdrenaline = _adrenalineRacerIdsThisRound.contains(bot.id);
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
    _applyBotAnimStep(bot, outcome);
    notifyListeners();

    if (_isBotAnimating) {
      _botAnimTimer = Timer.periodic(const Duration(milliseconds: 190), (t) {
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
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();
    _adrenalineEnabled = activate && _adrenalineEligible;
    if (_adrenalineEnabled) {
      _log('Étape 4 : Adrénaline activée (+1 Vitesse/case et +1 Refroidissement).');
    }
    _step = RoundStep.react;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 5 : Réagir (Refroidissement, Boost, Adrénaline +1)
  // ---------------------------------------------------------------------------

  void cooldownOneHeat() {
    if (!canCooldownNow) return;
    _pushUndoSnapshot();
    final card = _hand.firstWhere((c) => c.isHeat);
    _cooldownHeatCard(card);
  }

  void cooldownAllPossibleHeat() {
    if (!canCooldownNow) return;
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();
    _adrenalineSpeedUsed = true;
    _turnSpeed += 1;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove += 1;
    _playerRoundDetails.add('⚡ Adrénaline +1 Vitesse');
    _log('Étape 5 (Adrénaline +1) : +1 Vitesse (total $_turnSpeed) et +1 case.');
    notifyListeners();
  }

  void activateBoost() {
    if (_step != RoundStep.react || _boostUsed || _engineHeat.isEmpty) return;
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();
    _step = RoundStep.slipstream;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 6 : Aspiration
  // ---------------------------------------------------------------------------

  void activateSlipstream() {
    if (!canUseSlipstream) return;
    _pushUndoSnapshot();
    _slipstreamUsed = true;
    _moveFloorProgress = _carProgress;
    final dist = slipstreamDistance;
    final bonus = bonusSlipstreamFromCards;
    _pendingStepsToMove += dist;
    _playerRoundDetails.add(
      bonus > 0
          ? '⏩ Aspiration (+$dist cases : +2 & +$bonus Bonus)'
          : '⏩ Aspiration (+$dist cases)',
    );
    _log(
      'Étape 6 (Aspiration) : +$dist cases (ne compte pas pour les virages).',
    );
    notifyListeners();
  }

  void proceedFromSlipstream() {
    if (_step != RoundStep.slipstream || _pendingStepsToMove > 0) return;
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();

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
    _pushUndoSnapshot();
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
    _pushUndoSnapshot();

    final playedSnapshot = List<HeatCard>.from(_playArea);
    _addRecapEntry(
      RaceRecapEntry(
        roundNumber: _roundNumber,
        racerId: 'player',
        racerName: playerDisplayName,
        racerColor: HeatColors.trackGreen,
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

    _activeTurnIndex++;
    _beginTurnForCurrentQueueIndex();
  }

  void _finishCurrentRound() {
    _assignFinishRanksForRound();

    if (_playerFinished) {
      _step = RoundStep.finished;
      _turnOrderQueue = [];
      _activeTurnIndex = -1;
      _undoStack.clear();
      _roundStartSnapshot = null;
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
    _markRoundStartSnapshot();
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
    if (_recapEntries.length > 40) {
      _recapEntries.removeRange(40, _recapEntries.length);
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
    if (_eventLog.length > 60) {
      _eventLog.removeRange(60, _eventLog.length);
    }
  }
}
