import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/shadow_bot.dart';
import '../models/track_data.dart';
import '../theme/heat_theme.dart';
import 'heat_card_widget.dart';

/// Plateaux compacts des 2 adversaires (même disposition que le joueur :
/// Pioche, Moteur Heat, Défausse, Cartes jouées et Levier de vitesse 4→1,
/// sans jamais révéler leur main secrète).
class OpponentsPanel extends StatelessWidget {
  const OpponentsPanel({
    super.key,
    required this.controller,
  });

  final HeatGameController controller;

  @override
  Widget build(BuildContext context) {
    final bots = controller.opponentStates;
    final activeDriverId = controller.activeTurnIndex >= 0 &&
            controller.activeTurnIndex < controller.turnOrderQueue.length
        ? controller.turnOrderQueue[controller.activeTurnIndex].racerId
        : null;

    return Container(
      padding: const EdgeInsets.all(8),
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
              Icon(Icons.smart_toy_outlined, size: 15, color: HeatColors.navyHeader),
              SizedBox(width: 6),
              Text(
                'TABLEAUX DE BORD ADVERSES (MAIN CACHÉE)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: HeatColors.navyHeader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 500;
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < bots.length; i++) ...[
                      Expanded(
                        child: _CompactBotCockpit(
                          bot: bots[i],
                          totalLaps: controller.totalLaps,
                          isActive: activeDriverId == bots[i].id,
                        ),
                      ),
                      if (i < bots.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < bots.length; i++) ...[
                    _CompactBotCockpit(
                      bot: bots[i],
                      totalLaps: controller.totalLaps,
                      isActive: activeDriverId == bots[i].id,
                    ),
                    if (i < bots.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompactBotCockpit extends StatelessWidget {
  const _CompactBotCockpit({
    required this.bot,
    required this.totalLaps,
    required this.isActive,
  });

  final RacerTrackState bot;
  final int totalLaps;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final lap =
        DeutschlandTrack.lapForProgress(bot.progress).clamp(1, totalLaps);
    final spaceNum = DeutschlandTrack.spaceForProgress(bot.progress).spaceNumber;
    final lowHeat = bot.engineHeatCount <= 1;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HeatColors.navyHeader,
            Color(0xFF172C40),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? HeatColors.heatGold : bot.color.withValues(alpha: 0.8),
          width: isActive ? 2.2 : 1.3,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone principale : en-tête + compteurs Pioche/Moteur/Défausse + Cartes jouées
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête pilote
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: bot.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bot.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      bot.progress <= 0 ? 'Grille' : 'T$lap • C$spaceNum',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Ligne compacte Pioche / Moteur (Heat) / Défausse
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniMetricPill(
                      icon: Icons.style,
                      label: 'Pioche ${bot.drawPileCount}',
                      color: Colors.white70,
                    ),
                    _MiniMetricPill(
                      icon: Icons.local_fire_department,
                      label: 'Moteur ${bot.engineHeatCount}',
                      color: lowHeat
                          ? const Color(0xFFFF6E6E)
                          : const Color(0xFFFFB74D),
                      emphasized: lowHeat,
                    ),
                    _MiniMetricPill(
                      icon: Icons.delete_outline,
                      label:
                          'Déf. ${bot.discardPileCount}${bot.topDiscardCard != null ? " (${bot.topDiscardCard!.shortLabel})" : ""}',
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 7),

                // Cartes jouées ce tour (face cachée avant tour, révélées après)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: bot.revealedCardsThisRound.isNotEmpty
                          ? Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: bot.revealedCardsThisRound
                                  .map(
                                    (c) => HeatCardWidget(
                                      card: c,
                                      width: 40,
                                      height: 56,
                                      enabled: true,
                                    ),
                                  )
                                  .toList(),
                            )
                          : (bot.hiddenPlayedCount > 0
                              ? Wrap(
                                  spacing: 4,
                                  children: List.generate(
                                    bot.hiddenPlayedCount,
                                    (_) => const HeatCardBackWidget(
                                      width: 34,
                                      height: 48,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'En attente de cartes…',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )),
                    ),
                    if (bot.revealedCardsThisRound.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bot.color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: HeatColors.heatGold,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Vit. ${bot.turnSpeed}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          if (bot.lastHeatSpent > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '-${bot.lastHeatSpent}🔥',
                                style: const TextStyle(
                                  color: Color(0xFFFFAB40),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (bot.lastHeatMissing > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Manquait ${bot.lastHeatMissing}🔥',
                                style: const TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Levier de vitesse vertical compact (4 → 1, même disposition que le joueur)
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1721),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'V',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: HeatColors.heatGold,
                  ),
                ),
                const SizedBox(height: 2),
                ...[4, 3, 2, 1].map((g) {
                  final active = bot.gear == g;
                  return Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 24,
                    height: 20,
                    decoration: BoxDecoration(
                      color: active ? bot.color : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: active ? HeatColors.heatGold : Colors.white12,
                        width: active ? 1.5 : 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$g',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.white : Colors.white38,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricPill extends StatelessWidget {
  const _MiniMetricPill({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? HeatColors.heatRed.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasized ? const Color(0xFFFF6E6E) : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
