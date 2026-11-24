import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/track_data.dart';
import '../theme/heat_theme.dart';
import '../widgets/opponents_panel.dart';
import '../widgets/player_dashboard.dart';
import '../widgets/track_board.dart';
import '../widgets/turn_stepper.dart';

/// Écran de course complet sur Deutschland :
/// - 3 pilotes (Toi + 2 Bots Shadow sans triche) & jet de dés de départ
/// - Zoom & déplacement fluide de la carte sans conflit de scroll
/// - Repères calculés entre la voiture et le prochain virage
/// - Moteur de règles officiel 9 étapes
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.totalLaps = DeutschlandTrack.defaultLaps,
    this.includeStartingUpgrades = false,
  });

  final int totalLaps;
  final bool includeStartingUpgrades;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HeatGameController _controller;
  bool _showSpaceMarkers = true;
  bool _isTouchingBoard = false;

  @override
  void initState() {
    super.initState();
    _controller = HeatGameController(
      totalLaps: widget.totalLaps,
      includeStartingUpgrades: widget.includeStartingUpgrades,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showRulesDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HeatColors.paperCard,
        title: const HeatSectionBanner(
          title: 'Aide-mémoire — Règles de base',
          compact: true,
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleItem(
                '0. Grille & Mode Shadow',
                'Le jet de dés décide de l\'ordre de départ. Les 2 pilotes adverses jouent chacun avec leur propre paquet (18 cartes, 5 Heat) et les mêmes règles, sans triche.',
              ),
              _RuleItem(
                '1. Changer de vitesse (obligatoire)',
                '±1 rapport gratuit, ±2 rapports = 1 Heat du moteur vers la défausse.',
              ),
              _RuleItem(
                '2. Jouer des cartes (obligatoire)',
                'Joue exactement autant de cartes que ta vitesse (1 à 4). Les bots choisissent leurs cartes en simultané.',
              ),
              _RuleItem(
                '3. Révéler & Avancer (obligatoire)',
                'Résolution du 1er au dernier ! Chaque Stress (+) retourne des cartes jusqu\'à une Basic (1–4). Max 2 voitures par case.',
              ),
              _RuleItem(
                '4. Adrénaline & 5. Réagir',
                'Le dernier pilote reçoit l\'Adrénaline (+1 Vitesse/case et +1 Refroidissement). Refroidissement : V1 → 3, V2 → 1. Boost (1×/tour) : 1 Heat → retourne une Basic.',
              ),
              _RuleItem(
                '6. Aspiration',
                'Si une voiture est à côté ou 1 case devant toi : +2 cases gratuites (n\'augmente PAS la vitesse pour les virages).',
              ),
              _RuleItem(
                '7. Vérifier les virages',
                'Pour chaque virage franchi : si Vitesse > Limite, paie la différence en Heat. Pas assez de Heat = Tête-à-queue (retour avant le virage, +1 Stress en V1/V2 ou +2 en V3/V4, vitesse 1).',
              ),
              _RuleItem(
                '8. Défausser & 9. Compléter à 7',
                'Défausse les cartes voulues (jamais Stress ni Heat), puis défausse la zone de jeu et repioche jusqu\'à 7 cartes.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                _controller.stepCarForward,
            const SingleActivator(LogicalKeyboardKey.space):
                _controller.stepCarForward,
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                _controller.stepCarBackward,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                title: const Row(
                  children: [
                    Icon(Icons.flag, color: HeatColors.heatGold, size: 22),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'HEAT — Deutschland',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showSpaceMarkers = !_showSpaceMarkers;
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: Icon(
                      _showSpaceMarkers
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 18,
                      color: HeatColors.heatGold,
                    ),
                    label: const Text('Repères'),
                  ),
                  IconButton(
                    tooltip: 'Aide-mémoire des règles',
                    onPressed: _showRulesDialog,
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  IconButton(
                    tooltip: 'Nouvelle course',
                    onPressed: () => _controller.resetRace(),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final activeDriverId = _controller.activeTurnIndex >= 0 &&
                          _controller.activeTurnIndex <
                              _controller.turnOrderQueue.length
                      ? _controller
                          .turnOrderQueue[_controller.activeTurnIndex].racerId
                      : null;

                  final board = TrackBoard(
                    racers: _controller.standings,
                    playerProgress: _controller.carProgress,
                    nextCornerInfo: _controller.nextCornerInfo,
                    pendingStepsToMove: _controller.pendingStepsToMove,
                    showSpaceMarkers: _showSpaceMarkers,
                    activeRacerId: activeDriverId,
                    onStepForwardTapped: _controller.stepCarForward,
                    onBoardTouchChanged: (touching) {
                      if (_isTouchingBoard != touching) {
                        setState(() => _isTouchingBoard = touching);
                      }
                    },
                  );

                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildTelemetryAndStandings(),
                                const SizedBox(height: 10),
                                Expanded(child: board),
                                const SizedBox(height: 10),
                                OpponentsPanel(controller: _controller),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  TurnStepperPanel(controller: _controller),
                                  const SizedBox(height: 10),
                                  PlayerDashboard(controller: _controller),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mobile / tablette : verrouille le scroll vertical pendant le zoom/pan sur la carte
                  return SingleChildScrollView(
                    physics: _isTouchingBoard
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _buildTelemetryAndStandings(),
                        const SizedBox(height: 8),
                        SizedBox(height: 330, child: board),
                        const SizedBox(height: 10),
                        TurnStepperPanel(controller: _controller),
                        const SizedBox(height: 10),
                        PlayerDashboard(controller: _controller),
                        const SizedBox(height: 10),
                        OpponentsPanel(controller: _controller),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryAndStandings() {
    final space = _controller.currentSpace;
    final pending = _controller.pendingStepsToMove;
    final lapDisplay = _controller.currentLap.clamp(1, _controller.totalLaps);
    final standings = _controller.standings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.paperBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _TelemetryBadge(
                    label: 'MANCHE',
                    value: '#${_controller.roundNumber}',
                  ),
                  _TelemetryBadge(
                    label: 'TOUR',
                    value: '$lapDisplay/${_controller.totalLaps}',
                  ),
                  _TelemetryBadge(
                    label: 'CASE',
                    value: _controller.carProgress <= 0
                        ? 'Grille'
                        : '${space.spaceNumber}/62',
                  ),
                  _TelemetryBadge(
                    label: 'VITESSE',
                    value: '${_controller.turnSpeed}',
                    highlight: _controller.turnSpeed > 0,
                  ),
                  _TelemetryBadge(
                    label: 'AVANCÉ',
                    value: '${_controller.turnSpacesMoved}',
                  ),
                ],
              ),
              if (pending > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _controller.stepCarBackward,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('-1'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: _controller.stepCarForward,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('+1 Case ($pending)'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Classement Shadow (positions uniquement, aucun plateau adverse exposé)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: standings.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final racer = entry.value;
              final rLap = DeutschlandTrack.lapForProgress(racer.progress)
                  .clamp(1, _controller.totalLaps);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: racer.isHuman
                      ? HeatColors.heatGold.withValues(alpha: 0.2)
                      : HeatColors.paperCream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: racer.color,
                    width: racer.isHuman ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: racer.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$rank. ${racer.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            racer.isHuman ? FontWeight.w900 : FontWeight.w700,
                        color: HeatColors.inkDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      racer.finished ? '(Arrivé)' : '(T$rLap)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: HeatColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TelemetryBadge extends StatelessWidget {
  const _TelemetryBadge({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? HeatColors.heatRed.withValues(alpha: 0.14)
            : HeatColors.paperCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? HeatColors.heatRed : HeatColors.paperBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: HeatColors.inkMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: highlight ? HeatColors.heatRed : HeatColors.navyHeader,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: HeatColors.navyHeader,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: HeatColors.inkDark),
          ),
        ],
      ),
    );
  }
}
