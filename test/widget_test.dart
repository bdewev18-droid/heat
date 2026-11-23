import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';
import 'package:heat/models/game_state.dart';
import 'package:heat/models/track_data.dart';

void main() {
  test('Deutschland track repères between car and next corner', () {
    expect(DeutschlandTrack.spaces.length, 62);
    expect(DeutschlandTrack.corners.length, 6);

    // Depuis Pole Position (progress = 0), 11 cases avant Virage 1 (limite 5)
    final fromGrid = DeutschlandTrack.nextCornerInfo(progress: 0);
    expect(fromGrid.corner?.id, 1);
    expect(fromGrid.corner?.speedLimit, 5);
    expect(fromGrid.spacesBeforeCorner, 11);
    expect(fromGrid.spacesToCrossCorner, 12);
    expect(fromGrid.markerProgressList.length, 11);

    // Depuis case 8, il reste 3 cases avant Virage 1 (9, 10, 11)
    final fromSpace8 = DeutschlandTrack.nextCornerInfo(progress: 8);
    expect(fromSpace8.corner?.id, 1);
    expect(fromSpace8.spacesBeforeCorner, 3);
    expect(fromSpace8.markerProgressList, [9, 10, 11]);

    // Depuis case 11 (collé au virage 1), 0 case avant, 1+ franchit
    final fromSpace11 = DeutschlandTrack.nextCornerInfo(progress: 11);
    expect(fromSpace11.corner?.id, 1);
    expect(fromSpace11.spacesBeforeCorner, 0);
    expect(fromSpace11.spacesToCrossCorner, 1);
  });

  test('Dice roll starting grid + 2 shadow bots + full 9-step turn flow', () {
    final controller = HeatGameController(random: Random(42));
    expect(controller.step, RoundStep.diceRoll);
    expect(controller.standings.length, 3);

    controller.rollStartingDice();
    expect(controller.diceRolled, isTrue);
    expect(controller.playerDiceRoll, inInclusiveRange(1, 6));

    // Les 3 pilotes ont des jets distincts pour un classement clair
    final rolls = controller.standings.map((r) => r.diceRoll).toSet();
    expect(rolls.length, 3);

    controller.startRaceAfterDiceRoll();
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.engineHeat.length, 5);
    expect(controller.hand.length, 7);

    // Passage en V3 (±2 = 1 Heat)
    controller.selectTargetGear(3);
    controller.confirmShiftGear();
    expect(controller.gear, 3);
    expect(controller.engineHeat.length, 4);
    expect(controller.step, RoundStep.playCards);

    // Jouer 3 cartes
    final playable = controller.hand.where((c) => c.canPlayNormally).take(3);
    for (final c in playable) {
      controller.onHandCardTapped(c);
    }
    controller.confirmPlayCards();

    expect(controller.step, RoundStep.revealAndMove);
    controller.autoFinishMovement();
    expect(controller.pendingStepsToMove, 0);

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
    expect(controller.roundNumber, 2);
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.hand.length, 7);

    // Les 2 bots ont avancé sur la piste lors de la manche 1
    final bots = controller.standings.where((r) => !r.isHuman).toList();
    expect(bots.length, 2);
    expect(bots.any((b) => b.progress > 0), isTrue);
  });

  testWidgets('Home -> Track selection -> Dice roll -> Race start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    expect(find.text('HEAT'), findsWidgets);
    expect(find.text('JOUER'), findsOneWidget);

    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    expect(find.text('ALLEMAGNE — DEUTSCHLAND'), findsOneWidget);
    await tester.ensureVisible(find.text('LANCER LA COURSE'));
    await tester.tap(find.text('LANCER LA COURSE'));
    await tester.pumpAndSettle();

    expect(find.text('Lancer les dés !'), findsOneWidget);
    await tester.ensureVisible(find.text('Lancer les dés !'));
    await tester.tap(find.text('Lancer les dés !'));
    await tester.pumpAndSettle();

    expect(find.text('Démarrer la course !'), findsOneWidget);
    await tester.ensureVisible(find.text('Démarrer la course !'));
    await tester.tap(find.text('Démarrer la course !'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1. Changer de vitesse'), findsOneWidget);
  });
}
