import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/track_data.dart';
import '../theme/heat_theme.dart';
import '../widgets/player_dashboard.dart';
import '../widgets/track_board.dart';
import '../widgets/turn_stepper.dart';

/// Écran de course complet sur Deutschland avec moteur de règles 9 étapes,
/// zoom fluide sur le circuit, avancement case par case et plateau joueur.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.totalLaps = DeutschlandTrack.defaultLaps,
  });

  final int totalLaps;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HeatGameController _controller;
  bool _showSpaceMarkers = false;

  @override
  void initState() {
    super.initState();
    _controller = HeatGameController(totalLaps: widget.totalLaps);
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
                '1. Changer de vitesse (obligatoire)',
                '±1 rapport gratuit, ±2 rapports = 1 Heat du moteur vers la défausse.',
              ),
              _RuleItem(
                '2. Jouer des cartes (obligatoire)',
                'Joue exactement autant de cartes que ta vitesse (1 à 4). Impossible de jouer Heat (sauf Main encombrée).',
              ),
              _RuleItem(
                '3. Révéler & Avancer (obligatoire)',
                'Additionne tes cartes. Chaque Stress (+) retourne des cartes jusqu\'à une Basic (1–4) ; les autres (0, 5, Stress, Heat) sont défaussées.',
              ),
              _RuleItem(
                '4. Adrénaline & 5. Réagir',
                'Refroidissement : Vitesse 1 → 3, Vitesse 2 → 1 (+1 si Adrénaline). Boost (1×/tour) : 1 Heat pour retourner une Basic (+vitesse & cases).',
              ),
              _RuleItem(
                '6. Aspiration',
                '+2 cases gratuites (n\'augmente PAS la vitesse pour les virages ; interdite pour franchir la ligne d\'arrivée).',
              ),
              _RuleItem(
                '7. Vérifier les virages',
                'Pour chaque virage franchi : si Vitesse > Limite, paie la différence en Heat. Pas assez de Heat = Tête-à-queue (retour avant le virage, +1 Stress en V1/V2 ou +2 en V3/V4, vitesse remise en 1ère).',
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
                title: Row(
                  children: [
                    const Icon(Icons.flag, color: HeatColors.heatGold, size: 22),
                    const SizedBox(width: 8),
                    const Flexible(
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
                    tooltip: 'Recommencer la course',
                    onPressed: () => _controller.resetRace(),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
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
                                _buildTelemetryBar(),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: TrackBoard(
                                    carProgress: _controller.carProgress,
                                    pendingStepsToMove:
                                        _controller.pendingStepsToMove,
                                    showSpaceMarkers: _showSpaceMarkers,
                                    onStepForwardTapped:
                                        _controller.stepCarForward,
                                  ),
                                ),
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

                  // Layout mobile / tablette
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _buildTelemetryBar(),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 310,
                          child: TrackBoard(
                            carProgress: _controller.carProgress,
                            pendingStepsToMove: _controller.pendingStepsToMove,
                            showSpaceMarkers: _showSpaceMarkers,
                            onStepForwardTapped: _controller.stepCarForward,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TurnStepperPanel(controller: _controller),
                        const SizedBox(height: 10),
                        PlayerDashboard(controller: _controller),
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

  Widget _buildTelemetryBar() {
    final space = _controller.currentSpace;
    final pending = _controller.pendingStepsToMove;
    final lapDisplay = _controller.currentLap.clamp(1, _controller.totalLaps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HeatColors.paperBorder, width: 1.5),
      ),
      child: Wrap(
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
                value: _controller.carProgress == 0
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
