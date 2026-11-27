import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';
import 'package:heat/models/game_state.dart';
import 'package:heat/models/heat_card.dart';
import 'package:heat/services/race_history_service.dart';
import 'package:heat/theme/heat_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Green Hornet is green and fixed start position P5 works at 8 players', () {
    final controller = HeatGameController(
      playerCount: 8,
      fixedStartPosition: 5,
      random: Random(12),
    );
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.startPosition, 5);
    expect(controller.standings.length, 8);

    final player = controller.standings.firstWhere((r) => r.isHuman);
    expect(player.name, 'Green Hornet');
    expect(player.color, HeatColors.trackGreen);

    // P5 sur une grille à 2 voitures/case = index 4 -> progress -2, lane 0
    expect(player.progress, -2);
    expect(player.lane, 0);
  });

  test('White Bonus Card: speed 1, costs 1 Heat to play, grants +3 slipstream (+5 total)', () {
    final deck = createDeutschlandStarterDeck(includeBonusCards: true);
    expect(deck.any((c) => c.isBonus), isTrue);

    final bonus = deck.firstWhere((c) => c.isBonus);
    expect(bonus.speedValue, 1);
    expect(bonus.heatCost, 1);
    expect(bonus.slipstreamBonus, 3);

    // Vérifie la mécanique en partie réelle avec la carte bonus en main
    final controller = HeatGameController(
      playerCount: 2,
      fixedStartPosition: 2,
      includeBonusCards: true,
      random: Random(5),
    );

    // Si la carte bonus n'est pas dans la main initiale, on la cherche dans un autre seed ou on vérifie le coût Heat
    var foundController = controller;
    for (var seed = 0; seed < 30; seed++) {
      final c = HeatGameController(
        playerCount: 2,
        fixedStartPosition: 2,
        includeBonusCards: true,
        random: Random(seed),
      );
      if (c.hand.any((card) => card.isBonus)) {
        foundController = c;
        break;
      }
    }

    final bonusCard = foundController.hand.firstWhere((c) => c.isBonus);
    foundController.confirmShiftGear(); // V1
    expect(foundController.step, RoundStep.playCards);

    final heatBefore = foundController.engineHeat.length;
    foundController.onHandCardTapped(bonusCard);
    foundController.confirmPlayCards();

    // Jouer la carte bonus a coûté 1 Heat du moteur
    expect(foundController.engineHeat.length, heatBefore - 1);

    // Avancer les bots devant si besoin
    while (foundController.step == RoundStep.botTurn) {
      foundController.proceedAfterBotTurn();
    }

    expect(foundController.step, RoundStep.revealAndMove);
    expect(foundController.slipstreamDistance, 5); // +2 base + 3 bonus
  });

  test('Undo last action and Restart round restore exact state', () {
    final controller = HeatGameController(playerCount: 1, random: Random(7));
    final initialHandIds = controller.hand.map((c) => c.id).toList();
    final initialDrawIds = controller.drawPile.map((c) => c.id).toList();

    controller.selectTargetGear(3);
    controller.confirmShiftGear();
    expect(controller.gear, 3);
    expect(controller.engineHeat.length, 4);

    controller.undoLastAction();
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.gear, 1);
    expect(controller.engineHeat.length, 5);

    controller.selectTargetGear(2);
    controller.confirmShiftGear();
    for (final c in controller.hand.where((c) => c.canPlayNormally).take(2)) {
      controller.onHandCardTapped(c);
    }
    controller.confirmPlayCards();
    controller.autoFinishMovement();
    controller.proceedFromRevealAndMove();
    expect(controller.step, RoundStep.react);

    final speedBefore = controller.turnSpeed;
    final heatBefore = controller.engineHeat.length;
    controller.activateBoost();
    expect(controller.boostUsed, isTrue);
    controller.undoLastAction();
    expect(controller.boostUsed, isFalse);
    expect(controller.engineHeat.length, heatBefore);
    expect(controller.turnSpeed, speedBefore);

    controller.restartCurrentRound();
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.hand.map((c) => c.id).toList(), initialHandIds);
    expect(controller.drawPile.map((c) => c.id).toList(), initialDrawIds);
  });

  test('Local RaceHistoryService saves records and computes max summary', () async {
    await RaceHistoryService.addRecord(
      const RaceResultRecord(
        id: '1',
        playedAtIso: '2026-11-27T12:00:00Z',
        trackName: 'Deutschland',
        playerName: 'Green Hornet',
        playerCount: 8,
        totalLaps: 2,
        startPosition: 5,
        finalRank: 2,
        roundsCount: 11,
        finishLineDistance: 4,
        includeStartingUpgrades: false,
        includeBonusCards: true,
      ),
    );
    final list = await RaceHistoryService.addRecord(
      const RaceResultRecord(
        id: '2',
        playedAtIso: '2026-11-27T13:00:00Z',
        trackName: 'Deutschland',
        playerName: 'Green Hornet',
        playerCount: 8,
        totalLaps: 2,
        startPosition: 2,
        finalRank: 1,
        roundsCount: 10,
        finishLineDistance: 7,
        includeStartingUpgrades: false,
        includeBonusCards: false,
      ),
    );

    final summary = RaceHistoryService.computeSummary(list);
    expect(summary.totalRaces, 2);
    expect(summary.winsCount, 1);
    expect(summary.top3Count, 2);
    expect(summary.bestRank, 1);
    expect(summary.bestRoundsTwoLaps, 10);
    expect(summary.maxFinishLineDistance, 7);
  });

  testWidgets('HP has Bonus option & History, Track setup has fixed start P5 without in-game dice', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Green Hornet'), findsOneWidget);
    expect(find.textContaining('Cartes Bonus (Deckbuild)'), findsOneWidget);
    expect(find.text('HISTORIQUE & RECORDS'), findsOneWidget);

    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    // Sélectionner 8 joueurs et Position fixe P5
    await tester.ensureVisible(find.text('8'));
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Position fixe'));
    await tester.tap(find.textContaining('Position fixe'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('LANCER LA COURSE'));
    await tester.tap(find.text('LANCER LA COURSE'));
    await tester.pumpAndSettle();

    // Démarre directement à l'Étape 1 sans jet de dés en jeu
    expect(find.textContaining('1. Changer de vitesse'), findsOneWidget);
  });
}
