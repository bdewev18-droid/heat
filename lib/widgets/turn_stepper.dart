import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/heat_theme.dart';

/// Barre des 9 étapes officielles du tour (style compteurs p. 4 du PDF)
/// + panneau d'action interactif pour l'étape active.
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
          _buildStepBadgesRow(step),
          const SizedBox(height: 10),
          _buildActiveStepContent(context, step),
        ],
      ),
    );
  }

  Widget _buildStepBadgesRow(RoundStep current) {
    final roundSteps =
        RoundStep.values.where((s) => s != RoundStep.finished).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: roundSteps.map((s) {
          final isActive = s == current;
          final isDone = current.number > s.number;
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
      case RoundStep.shiftGears:
        return _buildShiftGearsStep();
      case RoundStep.playCards:
        return _buildPlayCardsStep();
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
          'Reste au même rapport, change de ±1 gratuitement, ou de ±2 pour 1 Heat.',
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
                  gCost == 1 ? 'V$g (1 Heat)' : 'Vitesse $g',
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
                    ? 'Valider V$target (-1 Heat)'
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
              ? 'Main encombrée (p. 7) : tu n\'as pas assez de cartes jouables ! '
                  'Sélectionne tes cartes jouables et complète avec des cartes Heat (vitesse retombe en 1ère sans avancer).'
              : 'Clique sur $needed carte(s) dans ta main ci-dessous (les cartes Heat ne peuvent pas être jouées).',
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
          label: Text('Révéler & calculer la vitesse ($selected/$needed)'),
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
              ? 'Il te reste $pending case(s) à avancer. Clique sur "+1 Case" ou directement sur la pastille "+1" sur le circuit !'
              : 'Déplacement terminé (${controller.turnSpacesMoved} cases avancées). Passe à l\'étape suivante.',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        _buildMovementButtonsRow(
          onContinue: pending == 0 ? controller.proceedFromRevealAndMove : null,
          continueLabel: 'Étape 4 : Adrénaline',
        ),
      ],
    );
  }

  Widget _buildAdrenalineStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. Adrénaline (dernier pilote du tour)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Si tu joues en mode entraînement solo, tu peux simuler l\'Adrénaline '
          '(+1 Vitesse/case et +1 Refroidissement à l\'étape 5) ou passer.',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => controller.chooseAdrenaline(activate: true),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Activer Adrénaline'),
            ),
            ElevatedButton.icon(
              onPressed: () => controller.chooseAdrenaline(activate: false),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Passer → Réagir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactStep() {
    final pending = controller.pendingStepsToMove;
    final cooldowns = controller.remainingCooldowns;
    final heatInHand = controller.hand.where((c) => c.isHeat).length;

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
        const SizedBox(height: 4),
        Text(
          'Refroidissement disponible : $cooldowns (clique sur une carte Heat en main pour la renvoyer dans le moteur — $heatInHand Heat en main). '
          'Boost : paye 1 Heat du moteur pour retourner une carte Basic (+vitesse & cases).',
          style: const TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
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
                controller.boostUsed ? 'Boost utilisé' : 'Boost (1 Heat)',
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
        const Text(
          'Si tu arrives à côté ou juste derrière une autre voiture, tu peux avancer '
          'de 2 cases gratuitement (n\'augmente PAS ta vitesse pour les virages).',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        if (pending > 0)
          _buildMovementButtonsRow(onContinue: null, continueLabel: '')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: controller.canUseSlipstream
                    ? controller.activateSlipstream
                    : null,
                icon: const Icon(Icons.fast_forward, size: 18),
                label: const Text('Utiliser Aspiration (+2 cases)'),
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
                        danger ? Icons.warning_amber : Icons.check_circle,
                        size: 16,
                        color: danger
                            ? HeatColors.heatRed
                            : HeatColors.trackGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${e.corner.name} — Limite ${e.corner.speedLimit} '
                          '${danger ? "→ Coût : $diff Heat !" : "→ Vitesse OK"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
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
                            ? '${r.corner.name} (limite ${r.corner.speedLimit}) : '
                                '${r.heatPaid} Heat payé(s).'
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
          '8. Défausser (optionnel)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: HeatColors.cooldownBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Clique sur les cartes de ta main que tu souhaites défausser '
          '(impossible de défausser les cartes Stress et Heat).',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: controller.confirmDiscard,
          icon: const Icon(Icons.delete_sweep, size: 18),
          label: Text(
            selected > 0
                ? 'Défausser $selected carte(s) → Étape 9'
                : 'Ne rien défausser → Étape 9',
          ),
        ),
      ],
    );
  }

  Widget _buildReplenishStep() {
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
        const Text(
          'Défausse les cartes jouées et repioche jusqu\'à 7 cartes pour démarrer le tour suivant.',
          style: TextStyle(fontSize: 12.5, color: HeatColors.inkMuted),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: controller.replenishAndStartNextRound,
          style: ElevatedButton.styleFrom(
            backgroundColor: HeatColors.trackGreen,
          ),
          icon: const Icon(Icons.style, size: 18),
          label: Text(
            controller.hasCrossedFinishLine
                ? 'Franchir l\'arrivée !'
                : 'Compléter à 7 cartes & Tour suivant',
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DRAPEAU À DAMIER — COURSE TERMINÉE !',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: HeatColors.heatRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bravo ! Tu as bouclé les ${controller.totalLaps} tours du circuit '
          'Deutschland en ${controller.roundNumber} tours.',
          style: const TextStyle(fontSize: 13, color: HeatColors.inkDark),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => controller.resetRace(),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Recommencer une course'),
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
