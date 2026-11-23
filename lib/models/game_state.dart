import 'dart:math';
import 'package:flutter/foundation.dart';
import 'heat_card.dart';
import 'track_data.dart';

/// Les 9 étapes officielles d'un tour (livret de règles p. 4–6) + fin de course.
enum RoundStep {
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

/// Moteur complet des règles de base de Heat (circuit Deutschland).
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

  // État piste & voiture
  int _roundNumber = 1;
  int _carProgress = 0; // 0 = Pole Position (case 62, juste derrière la ligne)
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
  RoundStep _step = RoundStep.shiftGears;
  bool _adrenalineEnabled = false;
  bool _adrenalineSpeedUsed = false;
  bool _boostUsed = false;
  bool _slipstreamUsed = false;
  int _cooldownsUsed = 0;
  bool _cornersResolved = false;
  List<CornerCheckResult> _lastCornerResults = const [];

  // Cartes
  List<HeatCard> _drawPile = [];
  List<HeatCard> _hand = [];
  List<HeatCard> _playArea = [];
  List<HeatCard> _discardPile = [];
  List<HeatCard> _engineHeat = [];
  List<HeatCard> _stressReserve = [];

  // Sélections UI (Step 2 et Step 8)
  final Set<String> _selectedCardIds = {};

  // Journal de course (règles expliquées en temps réel)
  final List<String> _eventLog = [];

  // Getters publics
  int get totalLaps => _totalLaps;
  int get finishProgress => _totalLaps * DeutschlandTrack.totalSpaces;
  int get roundNumber => _roundNumber;
  int get carProgress => _carProgress;
  int get pendingStepsToMove => _pendingStepsToMove;
  int get turnSpacesMoved => _turnSpacesMoved;
  int get turnSpeed => _turnSpeed;
  int get gear => _gear;
  int get roundStartGear => _roundStartGear;
  int get selectedTargetGear => _selectedTargetGear;
  RoundStep get step => _step;
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

  /// Virages franchis depuis le début de ce tour (avant la ligne d'arrivée finale).
  List<CrossedCornerEvent> get crossedCornersThisTurn =>
      DeutschlandTrack.crossedCorners(
        fromProgress: _roundStartProgress,
        toProgress: _carProgress,
        totalLaps: _totalLaps,
      );

  /// Nombre de cartes jouables normalement en main (tout sauf Heat).
  int get playableCardsInHandCount =>
      _hand.where((c) => c.canPlayNormally).length;

  /// Indique si le joueur est en situation de "Main encombrée" (Cluttered Hand p. 7).
  bool get isClutteredHand => playableCardsInHandCount < _gear;

  /// Coût en Heat pour changer vers `targetGear` à l'étape 1.
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

  bool get canUseSlipstream {
    if (_step != RoundStep.slipstream || _slipstreamUsed) return false;
    if (_pendingStepsToMove > 0) return false;
    // Règle p. 7 : impossible d'utiliser l'Aspiration pour franchir ou après
    // avoir franchi la ligne d'arrivée finale.
    if (_carProgress + 2 >= finishProgress) return false;
    return true;
  }

  /// Réinitialise complètement une nouvelle course sur Deutschland.
  void resetRace({int? totalLaps}) {
    if (totalLaps != null) _totalLaps = totalLaps;
    _roundNumber = 1;
    _carProgress = 0;
    _roundStartProgress = 0;
    _moveFloorProgress = 0;
    _pendingStepsToMove = 0;
    _turnSpacesMoved = 0;
    _turnSpeed = 0;

    _gear = 1;
    _roundStartGear = 1;
    _selectedTargetGear = 1;
    _step = RoundStep.shiftGears;

    _adrenalineEnabled = false;
    _adrenalineSpeedUsed = false;
    _boostUsed = false;
    _slipstreamUsed = false;
    _cooldownsUsed = 0;
    _cornersResolved = false;
    _lastCornerResults = const [];
    _selectedCardIds.clear();

    _drawPile = createDeutschlandStarterDeck()..shuffle(_random);
    _engineHeat = createDeutschlandEngineHeat();
    _stressReserve = createStressReserve();
    _hand = [];
    _playArea = [];
    _discardPile = [];
    _eventLog.clear();

    _drawUpToSeven();
    _log(
      'Départ sur Deutschland ($_totalLaps tours, 62 cases) : '
      '5 Heat dans le moteur, 18 cartes dans la pioche, 7 cartes en main.',
    );
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
        'Étape 1 : Changement de vitesse $_roundStartGear → $_selectedTargetGear '
        '(±2 rapports : 1 Heat payé du moteur vers la défausse).',
      );
    } else if (_selectedTargetGear != _roundStartGear) {
      _log(
        'Étape 1 : Changement de vitesse $_roundStartGear → $_selectedTargetGear (gratuit).',
      );
    } else {
      _log('Étape 1 : Maintien en vitesse $_selectedTargetGear.');
    }

    _gear = _selectedTargetGear;
    _selectedCardIds.clear();
    _step = RoundStep.playCards;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 2 : Jouer des cartes (Play Cards)
  // ---------------------------------------------------------------------------

  bool canToggleCardInHand(HeatCard card) {
    if (_step == RoundStep.playCards) {
      if (_selectedCardIds.contains(card.id)) return true;
      if (_selectedCardIds.length >= _gear) return false;
      if (card.canPlayNormally) return true;
      // Cas "Main encombrée" (p. 7) : autorise de compléter avec Heat si toutes
      // les cartes jouables sont déjà sélectionnées.
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

    final chosen = _hand.where((c) => _selectedCardIds.contains(c.id)).toList();
    _hand.removeWhere((c) => _selectedCardIds.contains(c.id));
    _playArea.addAll(chosen);
    _selectedCardIds.clear();

    // Cas Main encombrée (p. 7) : si au moins une carte Heat a dû être jouée.
    if (chosen.any((c) => c.isHeat)) {
      _log(
        'Main encombrée (p. 7) : impossible de jouer $_gear cartes sans Heat ! '
        'La voiture n\'avance pas, la vitesse retombe en 1ère et les cartes jouées sont défaussées.',
      );
      _gear = 1;
      _discardPile.addAll(_playArea);
      _playArea.clear();
      _step = RoundStep.replenishHand;
      notifyListeners();
      return;
    }

    // Passage à l'étape 3 : Révélation et résolution des Stress (+)
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

    // Résolution de chaque carte Stress (+) : retourner jusqu'à trouver une Basic
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
      'Étape 3 : Cartes révélées (${revealedSummary.join(', ')}) → '
      'Vitesse totale = $_turnSpeed. Avance ta voiture de $_turnSpeed cases.',
    );
  }

  /// Retourne des cartes de la pioche jusqu'à trouver une carte Basic (1..4).
  /// Les cartes non-Basic (Amélioration 0/5, Stress, Heat) vont directement en défausse.
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
            '$reason : défaussé [${discardedNames.join(', ')}] puis trouvé '
            '${flipped.displayName} (+${flipped.speedValue}).',
          );
        } else {
          _log('$reason : trouvé ${flipped.displayName} (+${flipped.speedValue}).');
        }
        return flipped;
      } else {
        discardedNames.add(flipped.displayName);
        _discardPile.add(flipped);
      }
    }
    _log('$reason : aucune carte Basic disponible dans la pioche.');
    return null;
  }

  /// Avance manuellement la voiture d'1 case (tant qu'il reste des cases à avancer).
  void stepCarForward() {
    if (_pendingStepsToMove <= 0) return;
    _carProgress++;
    _pendingStepsToMove--;
    _turnSpacesMoved++;
    notifyListeners();
  }

  /// Recule d'1 case dans le segment d'avancement en cours (pour corriger un clic).
  void stepCarBackward() {
    if (_carProgress <= _moveFloorProgress) return;
    _carProgress--;
    _pendingStepsToMove++;
    if (_turnSpacesMoved > 0) _turnSpacesMoved--;
    notifyListeners();
  }

  /// Avance automatiquement toutes les cases restantes du segment en cours.
  void autoFinishMovement() {
    if (_pendingStepsToMove <= 0) return;
    _carProgress += _pendingStepsToMove;
    _turnSpacesMoved += _pendingStepsToMove;
    _pendingStepsToMove = 0;
    notifyListeners();
  }

  void proceedFromRevealAndMove() {
    if (_step != RoundStep.revealAndMove || _pendingStepsToMove > 0) return;
    _step = RoundStep.adrenaline;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 4 : Adrénaline
  // ---------------------------------------------------------------------------

  void chooseAdrenaline({required bool activate}) {
    if (_step != RoundStep.adrenaline) return;
    _adrenalineEnabled = activate;
    if (activate) {
      _log(
        'Étape 4 : Adrénaline activée (+1 Vitesse/case optionnel et +1 Refroidissement à l\'étape 5).',
      );
    } else {
      _log('Étape 4 : Pas d\'Adrénaline ce tour.');
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
      'Étape 5 (Refroidissement) : 1 carte Heat renvoyée de la main vers le moteur '
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
      'Étape 5 (Adrénaline +1) : +1 Vitesse (total $_turnSpeed) et +1 case à avancer.',
    );
    notifyListeners();
  }

  void activateBoost() {
    if (_step != RoundStep.react || _boostUsed || _engineHeat.isEmpty) return;
    _boostUsed = true;
    _payHeat(1);
    final card = _flipUntilBasicCard(reason: 'Boost (1 Heat payé)');
    if (card != null) {
      _playArea.add(card);
      final add = card.speedValue ?? 0;
      _turnSpeed += add;
      _moveFloorProgress = _carProgress;
      _pendingStepsToMove += add;
      _log(
        'Étape 5 (Boost) : +$add cases et +$add Vitesse (total $_turnSpeed).',
      );
    }
    notifyListeners();
  }

  void proceedFromReact() {
    if (_step != RoundStep.react || _pendingStepsToMove > 0) return;
    _step = RoundStep.slipstream;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 6 : Aspiration (Slipstream)
  // ---------------------------------------------------------------------------

  void activateSlipstream() {
    if (!canUseSlipstream) return;
    _slipstreamUsed = true;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove += 2;
    _log(
      'Étape 6 (Aspiration) : +2 cases à avancer (n\'augmente PAS la vitesse pour les virages !).',
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
        _log('Étape 7 : Aucune ligne de virage franchie ce tour.');
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
              'Étape 7 : ${event.corner.name} (limite $limit) franchi à vitesse $_turnSpeed → OK !',
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
              'Étape 7 : ${event.corner.name} (limite $limit) franchi à vitesse $_turnSpeed → '
              '$excess Heat payé(s) du moteur vers la défausse.',
            );
          } else {
            // TÊTE-À-QUEUE (SPIN OUT - p. 6)
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

            _carProgress = event.spaceBeforeCornerProgress;
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
              'TÊTE-À-QUEUE au ${event.corner.name} (limite $limit, vitesse $_turnSpeed, '
              '$excess Heat requis mais seulement $paid disponible) ! '
              'Voiture replacée avant le virage (case ${currentSpace.spaceNumber}), '
              '+$actualStress Stress en main, boîte remise en 1ère vitesse !',
            );
            // En cas de tête-à-queue, on ne franchit pas les virages suivants.
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
      _log(
        'Étape 8 : ${toDiscard.length} carte(s) défaussée(s) '
        '(${toDiscard.map((c) => c.displayName).join(', ')}).',
      );
    } else {
      _log('Étape 8 : Aucune carte défaussée.');
    }
    _selectedCardIds.clear();
    _step = RoundStep.replenishHand;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ÉTAPE 9 : Compléter sa main (Replenish Hand)
  // ---------------------------------------------------------------------------

  void replenishAndStartNextRound() {
    if (_step != RoundStep.replenishHand) return;

    if (_playArea.isNotEmpty) {
      _discardPile.addAll(_playArea);
      _playArea.clear();
    }

    final before = _hand.length;
    _drawUpToSeven();
    final drawn = _hand.length - before;

    if (hasCrossedFinishLine) {
      _step = RoundStep.finished;
      _log(
        'ARRIVÉE ! Tu as franchi la ligne d\'arrivée de Deutschland en $_roundNumber tours !',
      );
      notifyListeners();
      return;
    }

    _log(
      'Étape 9 : Zone de jeu défaussée, +$drawn carte(s) piochée(s) (main : ${_hand.length}/7). '
      'Début du tour ${_roundNumber + 1}.',
    );

    _roundNumber++;
    _roundStartProgress = _carProgress;
    _moveFloorProgress = _carProgress;
    _pendingStepsToMove = 0;
    _turnSpacesMoved = 0;
    _turnSpeed = 0;
    _roundStartGear = _gear;
    _selectedTargetGear = _gear;
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

  /// Mélange manuel de la pioche (action utilitaire).
  void shuffleDrawPile() {
    _drawPile.shuffle(_random);
    _log('Pioche mélangée (${_drawPile.length} cartes).');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers internes
  // ---------------------------------------------------------------------------

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
    _eventLog.insert(0, '[Tour $_roundNumber] $message');
    if (_eventLog.length > 40) {
      _eventLog.removeRange(40, _eventLog.length);
    }
  }
}
