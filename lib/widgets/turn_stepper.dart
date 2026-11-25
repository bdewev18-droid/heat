import 'dart:math';

import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/heat_theme.dart';
import 'heat_card_widget.dart';

/// Panneau de suivi complet :
/// 1. Suivi de l'ordre de passage des 3 voitures (au-dessus des étapes)
/// 2. Barre des 9 étapes officielles du tour
/// 3. Bandeau explicite des mouvements Heat / Moteur
/// 4. Contrôles de l'étape active (y compris tour visible des bots)
class TurnStepperPanel extends StatelessWidget {
  const TurnStepperPanel({
    super.key,
    required this.controller,
  });

  final HeatGameController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.step;

    return Container(
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.paperBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step != RoundStep.diceRoll && step != RoundStep.finished) ...[
            _buildTurnOrderTracker(),
            const SizedBox(height: 8),
            _buildStepBadgesRow(step),
            const SizedBox(height: 8),
            if (controller.canUndo || controller.canRestartRound) ...[
              _buildUndoControlsBar(),
              const SizedBox(height: 8),
            ],
          ],
          if (controller.lastHeatNotice != null &&
              step != RoundStep.diceRoll) ...[
            _buildHeatMovementBanner(
              controller.lastHeatNotice!,
              isCooldown: controller.lastHeatNoticeIsCooldown,
            ),
            const SizedBox(height: 8),
          ],
          _buildActiveStepContent(context, step),
        ],
      ),
    );
  }

  Widget _buildUndoControlsBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: controller.canUndo ? controller.undoLastAction : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: HeatColors.navyHeader,
            side: const BorderSide(color: HeatColors.navyHeader),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.undo_rounded, size: 16),
          label: const Text(
            'Annuler dernière action',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
        OutlinedButton.icon(
          onPressed:
              controller.canRestartRound ? controller.restartCurrentRound : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: HeatColors.heatOrange,
            side: const BorderSide(color: HeatColors.heatOrange),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.replay_rounded, size: 16),
          label: Text(
            'Recommencer manche #${controller.roundNumber}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  /// Suivi des tours de jeu au-dessus des 9 étapes : montre toujours celui qui
  /// est devant en premier, qui joue en ce moment, et qui attend son tour.
  Widget _buildTurnOrderTracker() {
    final order = controller.displayedTurnOrder;
    final inResolution = controller.turnOrderQueue.isNotEmpty;
    final activeIdx = controller.activeTurnIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: HeatColors.navyHeader,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HeatColors.heatGold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUIVI MANCHE #${controller.roundNumber} — ORDRE DE PASSAGE (1ER DEVANT)',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: HeatColors.heatGold,
                ),
              ),
              if (!inResolution)
                const Text(
                  'Simultané (1–2)',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: order.asMap().entries.map((entry) {
                final idx = entry.key;
                final driver = entry.value;
                final isCurrent = inResolution && idx == activeIdx;
                final isDone = inResolution && idx < activeIdx;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? driver.color
                            : (isDone
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? HeatColors.heatGold
                              : (isDone
                                  ? Colors.greenAccent.withValues(alpha: 0.6)
                                  : driver.color.withValues(alpha: 0.7)),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${idx + 1}e',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isCurrent
                                  ? HeatColors.heatGold
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.white : driver.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            driver.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isCurrent ? FontWeight.w900 : FontWeight.w700,
                              color: isDone ? Colors.white60 : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (isDone)
                            const Icon(
                              Icons.check_circle,
                              size: 13,
                              color: Colors.greenAccent,
                            )
                          else if (isCurrent)
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 15,
                              color: HeatColors.heatGold,
                            ),
                        ],
                      ),
                    ),
                    if (idx < order.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMovementBanner(String message, {required bool isCooldown}) {
    final color = isCooldown ? HeatColors.cooldownBlue : HeatColors.heatRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isCooldown ? Icons.ac_unit : Icons.local_fire_department,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadgesRow(RoundStep current) {
    final roundSteps = RoundStep.values
        .where(
          (s) =>
              s != RoundStep.diceRoll &&
              s != RoundStep.botTurn &&
              s != RoundStep.finished,
        )
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: roundSteps.map((s) {
          final isActive = s == current;
          final isDone = current != RoundStep.botTurn && current.number > s.number;
          final baseColor =
              s.isMandatory ? HeatColors.heatRed : HeatColors.cooldownBlue;

          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? baseColor
                  : (isDone
                      ? baseColor.withValues(alpha: 0.14)
                      : HeatColors.paperCream),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? HeatColors.navyHeader
                    : baseColor.withValues(alpha: isDone ? 0.45 : 0.35),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: isActive ? Colors.white : baseColor,
                  child: Text(
                    '${s.number}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isActive ? baseColor : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDone ? HeatColors.inkMuted : HeatColors.inkDark),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveStepContent(BuildContext context, RoundStep step) {
    switch (step) {
      case RoundStep.diceRoll:
        return _buildDiceRollStep();
      case RoundStep.shiftGears:
        return _buildShiftGearsStep();
      case RoundStep.playCards:
        return _buildPlayCardsStep();
      case RoundStep.botTurn:
        return _buildBotTurnStep();
      case RoundStep.revealAndMove:
        return _buildRevealAndMoveStep();
      case RoundStep.adrenaline:
        return _buildAdrenalineStep();
      case RoundStep.react:
        return _buildReactStep();
      case RoundStep.slipstream:
        return _buildSlipstreamStep();
      case RoundStep.checkCorner:
        return _buildCheckCornerStep();
      case RoundStep.discard:
        return _buildDiscardStep();
      case RoundStep.replenishHand:
        return _buildReplenishStep();
      case RoundStep.finished:
        return _buildFinishedStep();
    }
  }

  Widget _buildBotTurnStep() {
    final outcome = controller.activeBotOutcome;
    final animating = controller.isBotAnimating;
    final nextDriver = controller.nextDriverInQueue;

    if (outcome == null) return const SizedBox.shrink();

    final buttonLabel = nextDriver != null
        ? (nextDriver.isHuman
            ? 'À ton tour ! (${nextDriver.name}) →'
            : 'Pilote suivant : ${nextDriver.name} →')
        : 'Terminer la manche →';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: outcome.botColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outcome.botColor, width: 1.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: outcome.botColor,
                child: const Icon(
                  Icons.directions_car,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tour de ${outcome.botName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: outcome.botColor,
                  ),
                ),
              ),
              // Levier de vitesse + Vitesse totale
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HeatColors.navyHeader,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Levier V${outcome.previousGear}→V${outcome.finalGear} • Vit. ${outcome.speed}',
                  style: const TextStyle(
                    color: HeatColors.heatGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              if (animating) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Cartes jouées / révélées par le bot ce tour + chiffres explicites
          if (outcome.revealedCards.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...outcome.revealedCards.map(
                        (c) => HeatCardWidget(
                          card: c,
                          width: 48,
                          height: 68,
                          enabled: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HeatColors.navyHeader,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HeatColors.heatGold, width: 1.3),
                  ),
                  child: Text(
                    outcome.cardsFormula,
                    style: const TextStyle(
                      color: HeatColors.heatGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Bilan Heat restant / dépensé / manquant / refroidi
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _BotStatTag(
                label: '🔥 Moteur restant : ${outcome.engineHeatRemaining}',
                color: outcome.engineHeatRemaining <= 1
                    ? HeatColors.heatRed
                    : HeatColors.navyHeader,
              ),
              if (outcome.totalHeatSpent > 0)
                _BotStatTag(
                  label: '🔥 Heat dépensé : -${outcome.totalHeatSpent}',
                  color: HeatColors.heatOrange,
                ),
              if (outcome.cornerHeatMissing > 0)
                _BotStatTag(
                  label:
                      '❌ Manquait ${outcome.cornerHeatMissing} Heat → Tête-à-queue !',
                  color: HeatColors.heatRed,
                ),
              if (outcome.cooledHeatCount > 0)
                _BotStatTag(
                  label: '❄️ Refroidi : +${outcome.cooledHeatCount} Heat',
                  color: HeatColors.cooldownBlue,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Détails des étapes du tour du bot
          ...outcome.actionDetails.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $d',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: HeatColors.inkDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: controller.proceedAfterBotTurn,
            style: ElevatedButton.styleFrom(
              backgroundColor: nextDriver?.isHuman == true
                  ? HeatColors.heatRed
                  : outcome.botColor,
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceRollStep() {
    final rolled = controller.diceRolled;
    final standings = controller.standings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HeatSectionBanner(
          title: 'Grille de départ — Jet de dés',
          compact: true,
        ),
        const SizedBox(height: 8),
        Text(
          rolled
              ? 'Ordre de départ tiré au sort (${controller.playerCount} pilotes) ! Celui qui est devant commence toujours la résolution.'
              : 'Lance les dés pour déterminer qui part en Pole Position face aux ${controller.botCount} pilote(s) adverse(s) !',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkDark),
        ),
        const SizedBox(height: 10),
        if (rolled) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: standings.asMap().entries.map((entry) {
              final pos = entry.key + 1;
              final racer = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: racer.isHuman
                      ? HeatColors.heatGold.withValues(alpha: 0.22)
                      : HeatColors.paperCream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: racer.color,
                    width: racer.isHuman ? 2 : 1.3,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: racer.color,
                      child: Text(
                        'P$pos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      racer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: HeatColors.inkDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HeatColors.navyHeader,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.casino,
                            size: 13,
                            color: HeatColors.heatGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${racer.diceRoll}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: controller.startRaceAfterDiceRoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HeatColors.trackGreen,
                ),
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('Démarrer la course !'),
              ),
              OutlinedButton.icon(
                onPressed: controller.rollStartingDice,
                icon: const Icon(Icons.casino, size: 18),
                label: const Text('Relancer'),
              ),
            ],
          ),
        ] else
          ElevatedButton.icon(
            onPressed: controller.rollStartingDice,
            icon: const Icon(Icons.casino, size: 20),
            label: const Text('Lancer les dés !'),
          ),
      ],
    );
  }

  Widget _buildShiftGearsStep() {
    final target = controller.selectedTargetGear;
    final cost = controller.shiftHeatCost(target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Changer de vitesse (obligatoire)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.navyHeader,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vitesse actuelle : ${controller.roundStartGear}. '
          '±1 rapport gratuit • ±2 rapports = défausse 1 Heat du Moteur (${controller.engineHeat.length} disponibles).',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...[1, 2, 3, 4].map((g) {
              final enabled = controller.canSelectGear(g);
              final selected = target == g;
              final gCost = controller.shiftHeatCost(g);
              return ChoiceChip(
                label: Text(
                  gCost == 1 ? 'V$g (🔥 -1 Heat)' : 'Vitesse $g',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : (enabled ? HeatColors.inkDark : Colors.black38),
                  ),
                ),
                selected: selected,
                selectedColor: HeatColors.heatRed,
                backgroundColor: HeatColors.paperCream,
                onSelected:
                    enabled ? (_) => controller.selectTargetGear(g) : null,
              );
            }),
            ElevatedButton.icon(
              onPressed: controller.confirmShiftGear,
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                cost > 0
                    ? 'Valider V$target (🔥 1 Heat Moteur → Défausse)'
                    : 'Valider Vitesse $target',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayCardsStep() {
    final needed = controller.gear;
    final selected = controller.selectedCardIds.length;
    final cluttered = controller.isClutteredHand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Jouer exactement $needed carte(s) de ta main ($selected/$needed)',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.navyHeader,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          cluttered
              ? 'Main encombrée (p. 7) : sélectionne tes cartes jouables et complète avec des cartes Heat (vitesse remise en 1ère sans avancer).'
              : controller.botCount > 0
                  ? 'Clique sur $needed carte(s) ci-dessous. Les ${controller.botCount} adversaire(s) jouent leurs cartes simultanément, puis le 1er démarre !'
                  : 'Clique sur $needed carte(s) ci-dessous.',
          style: TextStyle(
            fontSize: 12.5,
            color: cluttered ? HeatColors.heatRed : HeatColors.inkMuted,
            fontWeight: cluttered ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed:
              controller.canConfirmPlayCards ? controller.confirmPlayCards : null,
          icon: const Icon(Icons.visibility, size: 18),
          label: Text('Valider mes cartes & lancer la manche ($selected/$needed)'),
        ),
      ],
    );
  }

  Widget _buildRevealAndMoveStep() {
    final pending = controller.pendingStepsToMove;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Révéler & Avancer — Vitesse : ${controller.turnSpeed}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.navyHeader,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pending > 0
              ? 'Il te reste $pending case(s) à avancer. Clique sur "+1 Case" ou sur la pastille "+1" sur la piste.'
              : 'Déplacement terminé (${controller.turnSpacesMoved} cases avancées).',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        _buildMovementButtonsRow(
          onContinue: pending == 0 ? controller.proceedFromRevealAndMove : null,
          continueLabel: controller.adrenalineEligible
              ? 'Étape 4 : Adrénaline !'
              : 'Étape 5 : Réagir',
        ),
      ],
    );
  }

  Widget _buildAdrenalineStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. Adrénaline (tu es dernier sur ce tour !)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'En tant que dernière voiture de la manche, tu bénéficies de l\'Adrénaline : '
          '+1 Vitesse/case optionnel et +1 Refroidissement à l\'étape 5.',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => controller.chooseAdrenaline(activate: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: HeatColors.cooldownBlue,
              ),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Activer Adrénaline → Réagir'),
            ),
            OutlinedButton(
              onPressed: () => controller.chooseAdrenaline(activate: false),
              child: const Text('Ignorer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactStep() {
    final pending = controller.pendingStepsToMove;
    final cooldowns = controller.remainingCooldowns;
    final heatInHand = controller.heatCardsInHandCount;
    final canCool = controller.canCooldownNow;
    final maxCoolNow = min(cooldowns, heatInHand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '5. Réagir — Refroidissement & Boost',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 6),

        // Encart TRÈS EXPLICITE quand le joueur a des cartes Heat à renvoyer au moteur !
        if (canCool)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HeatColors.cooldownBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HeatColors.cooldownBlue, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.ac_unit,
                      color: HeatColors.cooldownBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'REFROIDISSEMENT : tu peux renvoyer $maxCoolNow carte(s) Heat de ta main vers le Moteur !',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: HeatColors.navyHeader,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.cooldownOneHeat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HeatColors.cooldownBlue,
                      ),
                      icon: const Icon(Icons.ac_unit, size: 17),
                      label: const Text('Refroidir 1 Heat (Main → Moteur)'),
                    ),
                    if (maxCoolNow >= 2)
                      ElevatedButton.icon(
                        onPressed: controller.cooldownAllPossibleHeat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HeatColors.navyHeader,
                        ),
                        icon: const Icon(Icons.done_all, size: 17),
                        label: Text('Tout refroidir ($maxCoolNow Heat)'),
                      ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              cooldowns > 0
                  ? 'Refroidissement disponible ($cooldowns), mais aucune carte Heat dans ta main.'
                  : 'Refroidissement : 0 disponible en Vitesse ${controller.gear}.',
              style: const TextStyle(fontSize: 12, color: HeatColors.inkMuted),
            ),
          ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: (!controller.boostUsed &&
                      controller.engineHeat.isNotEmpty &&
                      pending == 0)
                  ? controller.activateBoost
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: HeatColors.heatOrange,
              ),
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: Text(
                controller.boostUsed
                    ? 'Boost utilisé'
                    : 'Boost (🔥 1 Heat Moteur → Défausse)',
              ),
            ),
            if (controller.adrenalineEnabled)
              ElevatedButton.icon(
                onPressed: (!controller.adrenalineSpeedUsed && pending == 0)
                    ? controller.activateAdrenalineSpeedBonus
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HeatColors.cooldownBlue,
                ),
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(
                  controller.adrenalineSpeedUsed
                      ? 'Adrénaline +1 utilisé'
                      : 'Adrénaline (+1 Vitesse)',
                ),
              ),
          ],
        ),
        if (pending > 0) ...[
          const SizedBox(height: 8),
          _buildMovementButtonsRow(onContinue: null, continueLabel: ''),
        ] else ...[
          const SizedBox(height: 8),
          if (canCool)
            OutlinedButton.icon(
              onPressed: controller.proceedFromReact,
              style: OutlinedButton.styleFrom(
                foregroundColor: HeatColors.heatOrange,
                side: const BorderSide(color: HeatColors.heatOrange),
              ),
              icon: const Icon(Icons.warning_amber, size: 18),
              label: const Text('Passer SANS refroidir → Étape 6'),
            )
          else
            ElevatedButton.icon(
              onPressed: controller.proceedFromReact,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Étape 6 : Aspiration'),
            ),
        ],
      ],
    );
  }

  Widget _buildSlipstreamStep() {
    final pending = controller.pendingStepsToMove;
    final hasTarget = controller.hasRealSlipstreamTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '6. Aspiration (Slipstream)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasTarget
              ? 'Un pilote adverse est juste à côté ou 1 case devant toi ! '
                  'Tu peux prendre l\'aspiration (+2 cases gratuites, ne compte PAS pour les virages).'
              : 'Aucune voiture adverse à côté ou 1 case devant toi ce tour.',
          style: TextStyle(
            fontSize: 12.5,
            color: hasTarget ? HeatColors.trackGreen : HeatColors.inkMuted,
            fontWeight: hasTarget ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        if (pending > 0)
          _buildMovementButtonsRow(onContinue: null, continueLabel: '')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasTarget)
                ElevatedButton.icon(
                  onPressed: controller.canUseSlipstream
                      ? controller.activateSlipstream
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HeatColors.trackGreen,
                  ),
                  icon: const Icon(Icons.fast_forward, size: 18),
                  label: const Text('Prendre l\'aspiration (+2 cases)'),
                ),
              ElevatedButton.icon(
                onPressed: controller.proceedFromSlipstream,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Étape 7 : Vérifier les virages'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCheckCornerStep() {
    final crossed = controller.crossedCornersThisTurn;
    final resolved = controller.cornersResolved;
    final results = controller.lastCornerResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '7. Vérifier les virages — Vitesse du tour : ${controller.turnSpeed}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 6),
        if (!resolved) ...[
          if (crossed.isEmpty)
            const Text(
              'Aucune ligne de virage franchie sur ce tour.',
              style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: crossed.map((e) {
                final diff = controller.turnSpeed - e.corner.speedLimit;
                final danger = diff > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        danger ? Icons.local_fire_department : Icons.check_circle,
                        size: 16,
                        color: danger
                            ? HeatColors.heatRed
                            : HeatColors.trackGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${e.corner.name} — Limite ${e.corner.speedLimit} '
                          '${danger ? "→ 🔥 Défausser $diff Heat (Moteur → Défausse) !" : "→ Vitesse OK"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: danger
                                ? HeatColors.heatRed
                                : HeatColors.trackGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: controller.resolveCornersAndProceed,
            icon: const Icon(Icons.verified, size: 18),
            label: Text(
              crossed.isEmpty
                  ? 'Confirmer (aucun virage)'
                  : 'Appliquer la règle des virages',
            ),
          ),
        ] else ...[
          if (results.isEmpty)
            const Text(
              'Virages vérifiés : aucune pénalité.',
              style: TextStyle(
                fontSize: 12.5,
                color: HeatColors.trackGreen,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: results.map((r) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: r.spunOut
                        ? HeatColors.heatRed.withValues(alpha: 0.14)
                        : (r.heatPaid > 0
                            ? HeatColors.heatOrange.withValues(alpha: 0.14)
                            : HeatColors.trackGreen.withValues(alpha: 0.14)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: r.spunOut
                          ? HeatColors.heatRed
                          : (r.heatPaid > 0
                              ? HeatColors.heatOrange
                              : HeatColors.trackGreen),
                    ),
                  ),
                  child: Text(
                    r.spunOut
                        ? 'TÊTE-À-QUEUE au ${r.corner.name} ! '
                            '(${r.heatRequired} Heat requis, ${r.heatPaid} payé) → '
                            'Retour avant le virage, +${r.stressTaken} Stress, vitesse 1.'
                        : (r.heatPaid > 0
                            ? '🔥 ${r.corner.name} (limite ${r.corner.speedLimit}) : '
                                '${r.heatPaid} Heat déplacée(s) Moteur → Défausse.'
                            : '${r.corner.name} (limite ${r.corner.speedLimit}) : '
                                'Virage parfaitement négocié !'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: HeatColors.inkDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: controller.resolveCornersAndProceed,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Étape 8 : Défausser'),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscardStep() {
    final selected = controller.selectedCardIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '8. Défausser des cartes de ta main (optionnel)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Clique sur les cartes Basic que tu veux défausser avant de repiocher. '
          'Les cartes Stress et Heat sont verrouillées (🔒 non défaussables).',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: controller.confirmDiscard,
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: Text(
            selected > 0
                ? 'Défausser $selected carte(s) → Étape 9'
                : 'Garder ma main → Étape 9',
          ),
        ),
      ],
    );
  }

  Widget _buildReplenishStep() {
    final nextDriver = controller.nextDriverInQueue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '9. Compléter sa main (obligatoire)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.heatRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nextDriver != null
              ? 'Défausse ta zone de jeu, repioche jusqu\'à 7 cartes, puis ${nextDriver.name} joue son tour.'
              : 'Défausse ta zone de jeu et repioche jusqu\'à 7 cartes pour lancer la manche suivante.',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: controller.replenishAndStartNextRound,
          style: ElevatedButton.styleFrom(
            backgroundColor: HeatColors.trackGreen,
          ),
          icon: const Icon(Icons.style, size: 18),
          label: Text(
            nextDriver != null
                ? 'Compléter à 7 → Tour de ${nextDriver.name}'
                : (controller.hasCrossedFinishLine
                    ? 'Franchir l\'arrivée !'
                    : 'Compléter à 7 cartes & Manche suivante'),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedStep() {
    final rank = controller.playerFinishRank ?? 1;
    final standings = controller.standings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRAPEAU À DAMIER — TU TERMINES ${rank}E !',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: HeatColors.heatRed,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: standings.asMap().entries.map((e) {
            final r = e.value;
            return Chip(
              avatar: CircleAvatar(
                backgroundColor: r.color,
                child: Text(
                  '${e.key + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              label: Text(
                r.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => controller.resetRace(),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Nouvelle course'),
        ),
      ],
    );
  }

  Widget _buildMovementButtonsRow({
    required VoidCallback? onContinue,
    required String continueLabel,
  }) {
    final pending = controller.pendingStepsToMove;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (pending > 0) ...[
          ElevatedButton.icon(
            onPressed: controller.stepCarForward,
            icon: const Icon(Icons.add, size: 18),
            label: Text('+1 Case (reste $pending)'),
          ),
          OutlinedButton.icon(
            onPressed: controller.stepCarBackward,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('-1'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.autoFinishMovement,
            icon: const Icon(Icons.double_arrow, size: 18),
            label: Text('Avancer tout ($pending)'),
          ),
        ] else if (onContinue != null)
          ElevatedButton.icon(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: HeatColors.trackGreen,
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(continueLabel),
          ),
      ],
    );
  }
}

class _BotStatTag extends StatelessWidget {
  const _BotStatTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
