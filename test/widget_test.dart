import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heat/main.dart';
import 'package:heat/models/game_state.dart';
import 'package:heat/models/track_data.dart';

void main() {
  test('Deutschland track has 62 spaces and 6 official corners', () {
    expect(DeutschlandTrack.spaces.length, 62);
    expect(DeutschlandTrack.corners.length, 6);
    expect(
      DeutschlandTrack.corners.map((c) => c.speedLimit).toList(),
      [5, 2, 2, 6, 4, 4],
    );

    // Crossing from space 10 to space 13 crosses Corner 1 (after space 11, limit 5)
    final crossed = DeutschlandTrack.crossedCorners(
      fromProgress: 10,
      toProgress: 13,
    );
    expect(crossed.length, 1);
    expect(crossed.first.corner.id, 1);
    expect(crossed.first.corner.speedLimit, 5);
    expect(crossed.first.spaceBeforeCornerProgress, 11);

    // Chicane: space 22 to 26 crosses Corner 2 (23->24) AND Corner 3 (24->25)
    final chicane = DeutschlandTrack.crossedCorners(
      fromProgress: 22,
      toProgress: 26,
    );
    expect(chicane.length, 2);
    expect(chicane[0].corner.speedLimit, 2);
    expect(chicane[1].corner.speedLimit, 2);
  });

  test('HeatGameController enforces 9-step turn flow and ±2 gear Heat cost', () {
    final controller = HeatGameController(random: Random(42));
    expect(controller.step, RoundStep.shiftGears);
    expect(controller.engineHeat.length, 5);
    expect(controller.hand.length, 7);

    // Shifting from 1 to 3 costs 1 Heat
    expect(controller.shiftHeatCost(3), 1);
    controller.selectTargetGear(3);
    controller.confirmShiftGear();

    expect(controller.gear, 3);
    expect(controller.engineHeat.length, 4);
    expect(controller.step, RoundStep.playCards);

    // Select 3 playable cards
    final playable = controller.hand.where((c) => c.canPlayNormally).take(3);
    for (final c in playable) {
      controller.onHandCardTapped(c);
    }
    expect(controller.canConfirmPlayCards, isTrue);
    controller.confirmPlayCards();

    expect(controller.step, RoundStep.revealAndMove);
    expect(controller.pendingStepsToMove, controller.turnSpeed);

    // Advance car step-by-step
    final expectedSpeed = controller.turnSpeed;
    for (var i = 0; i < expectedSpeed; i++) {
      controller.stepCarForward();
    }
    expect(controller.pendingStepsToMove, 0);
    expect(controller.carProgress, expectedSpeed);

    // Proceed through steps 4 -> 9
    controller.proceedFromRevealAndMove();
    expect(controller.step, RoundStep.adrenaline);

    controller.chooseAdrenaline(activate: false);
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
  });

  testWidgets('Home screen -> Track selection (Deutschland) -> Game screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeatApp());
    await tester.pumpAndSettle();

    expect(find.text('HEAT'), findsWidgets);
    expect(find.text('JOUER'), findsOneWidget);

    await tester.tap(find.text('JOUER'));
    await tester.pumpAndSettle();

    expect(find.text('ALLEMAGNE — DEUTSCHLAND'), findsOneWidget);
    expect(find.text('LANCER LA COURSE'), findsOneWidget);

    await tester.ensureVisible(find.text('LANCER LA COURSE'));
    await tester.tap(find.text('LANCER LA COURSE'));
    await tester.pumpAndSettle();

    expect(find.text('HEAT — Deutschland'), findsOneWidget);
    expect(find.textContaining('1. Changer de vitesse'), findsOneWidget);
  });
}
