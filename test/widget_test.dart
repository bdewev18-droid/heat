import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';
import 'package:heat/models/game_state.dart';
import 'package:heat/models/heat_card.dart';
import 'package:heat/models/track_data.dart';

void main() {
  test('Competition deck removes 0 and 5 cards unless enabled', () {
    final compDeck = createDeutschlandStarterDeck();
    expect(compDeck.length, 15); // 12 Basic + 3 Stress
    expect(compDeck.any((c) => c.speedValue == 0 || c.speedValue == 5), isFalse);

    final initDeck = createDeutschlandStarterDeck(includeStartingUpgrades: true);
    expect(initDeck.length, 18); // + 0, 5, +1 Heat
    expect(initDeck.any((c) => c.speedValue == 0), isTrue);
    expect(initDeck.any((c) => c.speedValue == 5), isTrue);
  });

  test('Cars are centered on spaces when alone and repères match next corner', () {
    final space = DeutschlandTrack.spaces.first;
    expect(space.positionForLane(0, isSharedSpace: false), space.position);
    expect(space.positionForLane(1, isSharedSpace: false), space.position);
    expect(
      space.positionForLane(0, isSharedSpace: true),
      isNot(equals(space.position)),
    );

    final fromSpace8 = DeutschlandTrack.nextCornerInfo(progress: 8);
    expect(fromSpace8.corner?.id, 1);
    expect(fromSpace8.spacesBeforeCorner, 3);
    expect(fromSpace8.markerProgressList, [9, 10, 11]);
  });

  test('Turn order resolves frontmost first with visible bot turns & Heat notice', () {
    final controller = HeatGameController(random: Random(42));
    expect(controller.step, RoundStep.diceRoll);
    expect(controller.includeStartingUpgrades, isFalse);

    controller.rollStartingDice();
    controller.startRaceAfterDiceRoll();
    expect(controller.step, RoundStep.shiftGears);

    // Passage ±2 en V3 : 1 Heat payé + notification explicite
    controller.selectTargetGear(3);
    controller.confirmShiftGear();
    expect(controller.gear, 3);
    expect(controller.engineHeat.length, 4);
    expect(controller.lastHeatNotice, isNotNull);
    expect(controller.step, RoundStep.playCards);

    // Jouer 3 cartes
    final playable = controller.hand.where((c) => c.canPlayNormally).take(3);
    for (final c in playable) {
      controller.onHandCardTapped(c);
    }
    controller.confirmPlayCards();

    // Avancer les bots devant le joueur si présents
    while (controller.step == RoundStep.botTurn) {
      expect(controller.activeBotOutcome, isNotNull);
      controller.proceedAfterBotTurn();
    }

    // Tour du joueur (Étapes 3 -> 9)
    expect(controller.step, RoundStep.revealAndMove);
    controller.autoFinishMovement();
    controller.proceedFromRevealAndMove();

    if (controller.step == RoundStep.adrenaline) {
      controller.chooseAdrenaline(activate: false);
    }
    expect(controller.step, RoundStep.react);
    controller.proceedFromReact();

    expect(controller.step, RoundStep.slipstream);
    controller.proceedFromSlipstream();

    expect(controller.step, RoundStep.checkCorner);
    controller.resolveCornersAndProceed();
    controller.resolveCornersAndProceed();

    expect(controller.step, RoundStep.discard);
    controller.confirmDiscard();

    expect(controller.step, RoundStep.replenishHand);
    controller.replenishAndStartNextRound();

    // Avancer les bots derrière le joueur si présents
    while (controller.step == RoundStep.botTurn) {
      expect(controller.activeBotOutcome, isNotNull);
      controller.proceedAfterBotTurn();
    }

    expect(controller.roundNumber, 2);
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.hand.length, 7);

    final bots = controller.standings.where((r) => !r.isHuman).toList();
    expect(bots.any((b) => b.progress > 0), isTrue);
  });

  testWidgets('Home -> Competition option -> Dice roll -> Race tracker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mode Compétition'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('LANCER LA COURSE'));
    await tester.tap(find.text('LANCER LA COURSE'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lancer les dés !'));
    await tester.tap(find.text('Lancer les dés !'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Démarrer la course !'));
    await tester.tap(find.text('Démarrer la course !'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ORDRE DE PASSAGE'), findsOneWidget);
    expect(find.textContaining('1. Changer de vitesse'), findsOneWidget);
  });
}
