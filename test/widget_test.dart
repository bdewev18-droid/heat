import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';
import 'package:heat/models/game_state.dart';
import 'package:heat/models/heat_card.dart';

void main() {
  test('Competition deck removes 0 and 5 cards unless enabled', () {
    final compDeck = createDeutschlandStarterDeck();
    expect(compDeck.length, 15);
    expect(compDeck.any((c) => c.speedValue == 0 || c.speedValue == 5), isFalse);

    final initDeck = createDeutschlandStarterDeck(includeStartingUpgrades: true);
    expect(initDeck.length, 18);
    expect(initDeck.any((c) => c.speedValue == 0), isTrue);
    expect(initDeck.any((c) => c.speedValue == 5), isTrue);
  });

  test('Player count supports 1 (Solo) up to 8 players (7 bots)', () {
    final solo = HeatGameController(playerCount: 1, random: Random(1));
    expect(solo.botCount, 0);
    expect(solo.standings.length, 1);
    expect(solo.step, RoundStep.shiftGears);

    final eight = HeatGameController(playerCount: 8, random: Random(2));
    expect(eight.botCount, 7);
    expect(eight.standings.length, 8);
    expect(eight.step, RoundStep.diceRoll);

    eight.rollStartingDice();
    expect(eight.diceRolled, isTrue);
    final distinctRolls = eight.standings.map((r) => r.diceRoll).toSet();
    expect(distinctRolls.length, 8);
  });

  test('Undo last action (e.g. Boost) and Restart round restore exact state', () {
    final controller = HeatGameController(playerCount: 1, random: Random(7));
    final initialHandIds = controller.hand.map((c) => c.id).toList();
    final initialDrawIds = controller.drawPile.map((c) => c.id).toList();

    // Shift V1 -> V3 (costs 1 Heat)
    controller.selectTargetGear(3);
    controller.confirmShiftGear();
    expect(controller.gear, 3);
    expect(controller.engineHeat.length, 4);
    expect(controller.canUndo, isTrue);

    // Undo shift -> back to V1 with 5 Heat
    controller.undoLastAction();
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.gear, 1);
    expect(controller.engineHeat.length, 5);

    // Proceed to Step 5 (React) in Gear 2
    controller.selectTargetGear(2);
    controller.confirmShiftGear();
    for (final c in controller.hand.where((c) => c.canPlayNormally).take(2)) {
      controller.onHandCardTapped(c);
    }
    controller.confirmPlayCards();
    controller.autoFinishMovement();
    controller.proceedFromRevealAndMove();
    expect(controller.step, RoundStep.react);

    // Trigger Boost, then Undo Boost!
    final speedBeforeBoost = controller.turnSpeed;
    final heatBeforeBoost = controller.engineHeat.length;
    controller.activateBoost();
    expect(controller.boostUsed, isTrue);
    expect(controller.engineHeat.length, heatBeforeBoost - 1);
    expect(controller.turnSpeed, greaterThan(speedBeforeBoost));

    controller.undoLastAction();
    expect(controller.boostUsed, isFalse);
    expect(controller.engineHeat.length, heatBeforeBoost);
    expect(controller.turnSpeed, speedBeforeBoost);

    // Restart entire round -> back to exact initial hand, draw pile, Step 1
    expect(controller.canRestartRound, isTrue);
    controller.restartCurrentRound();
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.carProgress, 0);
    expect(controller.engineHeat.length, 5);
    expect(controller.hand.map((c) => c.id).toList(), initialHandIds);
    expect(controller.drawPile.map((c) => c.id).toList(), initialDrawIds);
  });

  test('Turn order resolves frontmost first with bot card formulas & discard piles', () {
    final controller = HeatGameController(playerCount: 3, random: Random(42));
    controller.rollStartingDice();
    controller.startRaceAfterDiceRoll();

    controller.selectTargetGear(3);
    controller.confirmShiftGear();
    for (final c in controller.hand.where((c) => c.canPlayNormally).take(3)) {
      controller.onHandCardTapped(c);
    }
    controller.confirmPlayCards();

    while (controller.step == RoundStep.botTurn) {
      final outcome = controller.activeBotOutcome!;
      expect(outcome.cardsFormula, contains('='));
      if ((outcome.gearBeforeSpinOut - outcome.previousGear).abs() == 2) {
        expect(outcome.shiftHeatPaid, 1);
      } else {
        expect(outcome.shiftHeatPaid, 0);
      }
      controller.proceedAfterBotTurn();
    }

    expect(controller.step, RoundStep.revealAndMove);
    controller.autoFinishMovement();
    controller.proceedFromRevealAndMove();
    if (controller.step == RoundStep.adrenaline) {
      controller.chooseAdrenaline(activate: false);
    }
    controller.proceedFromReact();
    controller.proceedFromSlipstream();
    controller.resolveCornersAndProceed();
    controller.resolveCornersAndProceed();
    controller.confirmDiscard();
    controller.replenishAndStartNextRound();

    while (controller.step == RoundStep.botTurn) {
      controller.proceedAfterBotTurn();
    }

    expect(controller.roundNumber, 2);
    expect(controller.recapEntries.length, 3);
    // Défausses accessibles pour le joueur et les bots après la manche 1
    expect(controller.discardPile, isNotEmpty);
    expect(
      controller.opponentStates.every((b) => b.discardPile.isNotEmpty),
      isTrue,
    );
  });

  testWidgets('Home -> choose player count -> Launch -> Undo button available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nombre de joueurs : 3'), findsOneWidget);
    // Sélectionner 5 joueurs (Toi + 4 bots)
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nombre de joueurs : 5'), findsOneWidget);

    await tester.ensureVisible(find.text('LANCER LA COURSE'));
    await tester.tap(find.text('LANCER LA COURSE'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lancer les dés !'));
    await tester.tap(find.text('Lancer les dés !'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Démarrer la course !'));
    await tester.tap(find.text('Démarrer la course !'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1. Changer de vitesse'), findsOneWidget);
  });
}
