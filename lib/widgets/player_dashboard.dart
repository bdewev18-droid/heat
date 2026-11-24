import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/heat_theme.dart';
import 'heat_card_widget.dart';

/// Plateau joueur inspiré du cockpit Heat (livret PDF p. 2, 3, 5) :
/// Pioche damier, Moteur (Heat), Défausse (carte du dessus), Boîte de vitesses,
/// Zone de jeu et Main du joueur.
class PlayerDashboard extends StatelessWidget {
  const PlayerDashboard({
    super.key,
    required this.controller,
  });

  final HeatGameController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCockpitMat(),
        if (controller.playArea.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildPlayArea(),
        ],
        const SizedBox(height: 10),
        _buildHandSection(),
        const SizedBox(height: 10),
        _buildEventLog(),
      ],
    );
  }

  Widget _buildCockpitMat() {
    final topDiscard =
        controller.discardPile.isEmpty ? null : controller.discardPile.last;
    final topEngine =
        controller.engineHeat.isEmpty ? null : controller.engineHeat.last;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HeatColors.navyHeader,
            Color(0xFF152A3E),
            Color(0xFF2B221D),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.heatGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 emplacements : Pioche, Moteur, Défausse
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                // Pioche
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PIOCHE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: HeatColors.heatGold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    HeatCardBackWidget(
                      width: 62,
                      height: 88,
                      count: controller.drawPile.length,
                      onTap: controller.shuffleDrawPile,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: controller.shuffleDrawPile,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shuffle, size: 12, color: Colors.white70),
                          SizedBox(width: 3),
                          Text(
                            'Mélanger',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Moteur (Heat)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MOTEUR (${controller.engineHeat.length})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFFFFA84D),
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (topEngine != null)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          HeatCardWidget(
                            card: topEngine,
                            width: 62,
                            height: 88,
                            enabled: true,
                          ),
                          Positioned(
                            top: 28,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: HeatColors.heatGold,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${controller.engineHeat.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      _EmptySlotBox(
                        width: 62,
                        height: 88,
                        icon: Icons.local_fire_department_outlined,
                        label: '0 Heat',
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Stress rés. ${controller.stressReserve.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),

                // Défausse (seule la carte du dessus est visible - règle p. 6)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DÉFAUSSE (${controller.discardPile.length})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (topDiscard != null)
                      HeatCardWidget(
                        card: topDiscard,
                        width: 62,
                        height: 88,
                        enabled: true,
                      )
                    else
                      const _EmptySlotBox(
                        width: 62,
                        height: 88,
                        icon: Icons.delete_outline,
                        label: 'Vide',
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dessus visible',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Boîte de vitesses verticale (4 en haut -> 1 en bas, comme le plateau p. 2 & 7)
          _buildVerticalGearbox(),
        ],
      ),
    );
  }

  Widget _buildVerticalGearbox() {
    final isShiftStep = controller.step == RoundStep.shiftGears;
    final activeGear =
        isShiftStep ? controller.selectedTargetGear : controller.gear;

    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF101923),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'VITESSES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: HeatColors.heatGold,
            ),
          ),
          const SizedBox(height: 6),
          ...[4, 3, 2, 1].map((g) {
            final isCurrent = activeGear == g;
            final selectable = isShiftStep && controller.canSelectGear(g);
            final cooldown = g == 1 ? 3 : (g == 2 ? 1 : 0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap:
                    selectable ? () => controller.selectTargetGear(g) : null,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? HeatColors.heatRed
                        : (selectable
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrent
                          ? HeatColors.heatGold
                          : (selectable ? Colors.white38 : Colors.white12),
                      width: isCurrent ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$g',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isCurrent
                              ? Colors.white
                              : (selectable ? Colors.white70 : Colors.white30),
                        ),
                      ),
                      if (cooldown > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.ac_unit,
                              size: 11,
                              color: Color(0xFF64B5F6),
                            ),
                            Text(
                              '$cooldown',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF90CAF9),
                              ),
                            ),
                          ],
                        )
                      else
                        const Icon(
                          Icons.speed,
                          size: 12,
                          color: Colors.white24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.heatOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ZONE DE JEU (CARTES RÉVÉLÉES)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: HeatColors.navyHeader,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: HeatColors.heatRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'VITESSE : ${controller.turnSpeed}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.playArea
                .map(
                  (card) => HeatCardWidget(
                    card: card,
                    width: 60,
                    height: 86,
                    enabled: true,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandSection() {
    final step = controller.step;
    final hint = switch (step) {
      RoundStep.playCards =>
        'Sélectionne ${controller.gear} carte(s) à jouer',
      RoundStep.react when controller.remainingCooldowns > 0 =>
        'Clique sur une carte Heat pour la refroidir (${controller.remainingCooldowns} restant)',
      RoundStep.discard =>
        'Clique sur les cartes à défausser (hors Stress/Heat)',
      _ => 'Main du pilote',
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.paperBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MAIN (${controller.hand.length}/7)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: HeatColors.navyHeader,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '• $hint',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: HeatColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.hand.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Aucune carte en main.',
                  style: TextStyle(color: HeatColors.inkMuted),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: controller.hand.map((card) {
                final selected = controller.selectedCardIds.contains(card.id);
                final interactive = controller.canToggleCardInHand(card);
                final highlightCooldown = step == RoundStep.react &&
                    controller.remainingCooldowns > 0 &&
                    card.isHeat;
                final showLockedDiscard =
                    step == RoundStep.discard && !card.canDiscard;
                final showSelectedDiscard =
                    step == RoundStep.discard && selected;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HeatCardWidget(
                      card: card,
                      width: 72,
                      height: 102,
                      selected: selected || highlightCooldown,
                      enabled: interactive ||
                          (step != RoundStep.playCards &&
                              step != RoundStep.discard &&
                              step != RoundStep.react),
                      onTap: interactive
                          ? () => controller.onHandCardTapped(card)
                          : null,
                    ),
                    if (highlightCooldown)
                      Positioned(
                        top: -10,
                        left: -2,
                        right: -2,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HeatColors.cooldownBlue,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Text(
                              '❄️ MOTEUR',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showSelectedDiscard)
                      Positioned(
                        top: -10,
                        left: -2,
                        right: -2,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HeatColors.heatRed,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Text(
                              'DÉFAUSSER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showLockedDiscard)
                      Positioned(
                        bottom: 20,
                        left: 4,
                        right: 4,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '🔒 Garder',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEventLog() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.paperBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, size: 15, color: HeatColors.navyHeader),
              SizedBox(width: 6),
              Text(
                'RÉCAP DES ACTIONS (CARTES • LEVIER • HEAT)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: HeatColors.navyHeader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (controller.recapEntries.isEmpty)
            Text(
              controller.eventLog.isNotEmpty
                  ? controller.eventLog.first
                  : 'Aucune action enregistrée pour le moment.',
              style: const TextStyle(fontSize: 11.5, color: HeatColors.inkMuted),
            )
          else
            SizedBox(
              height: 210,
              child: ListView.separated(
                itemCount: controller.recapEntries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _RecapEntryCard(entry: controller.recapEntries[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RecapEntryCard extends StatelessWidget {
  const _RecapEntryCard({required this.entry});

  final RaceRecapEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HeatColors.paperCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.spunOut
              ? HeatColors.heatRed
              : entry.racerColor.withValues(alpha: 0.65),
          width: entry.spunOut ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Manche, Pilote, Levier de vitesse, Vitesse & Case
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.racerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'M${entry.roundNumber} • ${entry.racerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
              ),
              _RecapBadge(
                text:
                    'Levier V${entry.previousGear}→V${entry.finalGear}${entry.shiftHeatPaid > 0 ? " (-1🔥)" : ""}',
                bg: HeatColors.navyHeader,
                fg: HeatColors.heatGold,
              ),
              _RecapBadge(
                text: 'Vit. ${entry.speed} → C${entry.spaceNumber}',
                bg: HeatColors.paperCard,
                fg: HeatColors.inkDark,
                border: HeatColors.paperBorder,
              ),
              _RecapBadge(
                text: 'Moteur : ${entry.engineHeatRemaining}🔥',
                bg: entry.engineHeatRemaining <= 1
                    ? HeatColors.heatRed.withValues(alpha: 0.16)
                    : HeatColors.heatOrange.withValues(alpha: 0.15),
                fg: entry.engineHeatRemaining <= 1
                    ? HeatColors.heatRed
                    : HeatColors.inkDark,
                border: entry.engineHeatRemaining <= 1
                    ? HeatColors.heatRed
                    : HeatColors.heatOrange,
              ),
              if (entry.heatSpent > 0)
                _RecapBadge(
                  text: '-${entry.heatSpent}🔥 dépensé',
                  bg: HeatColors.heatOrange.withValues(alpha: 0.18),
                  fg: HeatColors.heatRed,
                ),
              if (entry.heatMissing > 0)
                _RecapBadge(
                  text: '❌ Manquait ${entry.heatMissing}🔥',
                  bg: HeatColors.heatRed,
                  fg: Colors.white,
                ),
              if (entry.cooledHeat > 0)
                _RecapBadge(
                  text: '❄️ +${entry.cooledHeat} refroidi',
                  bg: HeatColors.cooldownBlue.withValues(alpha: 0.16),
                  fg: HeatColors.cooldownBlue,
                ),
            ],
          ),
          if (entry.cards.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: entry.cards
                  .map(
                    (c) => HeatCardWidget(
                      card: c,
                      width: 38,
                      height: 54,
                      enabled: true,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (entry.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.details.join(' • '),
              style: const TextStyle(
                fontSize: 10.5,
                color: HeatColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecapBadge extends StatelessWidget {
  const _RecapBadge({
    required this.text,
    required this.bg,
    required this.fg,
    this.border,
  });

  final String text;
  final Color bg;
  final Color fg;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _EmptySlotBox extends StatelessWidget {
  const _EmptySlotBox({
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
  });

  final double width;
  final double height;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white38, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
