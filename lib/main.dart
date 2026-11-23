import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/heat_card.dart';
import 'models/track_data.dart';
import 'widgets/player_dashboard.dart';
import 'widgets/track_board.dart';

void main() {
  runApp(const HeatApp());
}

class HeatApp extends StatelessWidget {
  const HeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heat - Deutschland',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
      ),
      home: const HeatGamePage(),
    );
  }
}

class HeatGamePage extends StatefulWidget {
  const HeatGamePage({super.key});

  @override
  State<HeatGamePage> createState() => _HeatGamePageState();
}

class _HeatGamePageState extends State<HeatGamePage> {
  final _random = Random();

  // État de la voiture sur le circuit (index 0..61)
  int _totalSpacesMoved = 0;
  int _turnMoveCounter = 0;
  bool _showSpaceMarkers = false;

  // État du joueur (tableau de bord, pioche, main, défausse)
  int _gear = 1;
  late List<HeatCard> _drawPile;
  final List<HeatCard> _hand = [];
  final List<HeatCard> _playedCards = [];
  final List<HeatCard> _discardPile = [];
  late List<HeatCard> _engineHeat;

  int get _currentSpaceIndex =>
      _totalSpacesMoved % DeutschlandTrack.totalSpaces;

  int get _currentLap =>
      (_totalSpacesMoved ~/ DeutschlandTrack.totalSpaces) + 1;

  @override
  void initState() {
    super.initState();
    _drawPile = createBaseStarterDeck()..shuffle(_random);
    _engineHeat = createBaseEngineHeatCards();
    _drawToSeven();
  }

  void _stepForward() {
    setState(() {
      _totalSpacesMoved++;
      _turnMoveCounter++;
    });
  }

  void _stepBackward() {
    if (_totalSpacesMoved == 0) return;
    setState(() {
      _totalSpacesMoved--;
      if (_turnMoveCounter > 0) {
        _turnMoveCounter--;
      }
    });
  }

  void _endTurn() {
    setState(() {
      _turnMoveCounter = 0;
      if (_playedCards.isNotEmpty) {
        _discardPile.addAll(_playedCards);
        _playedCards.clear();
      }
    });
  }

  void _resetPosition() {
    setState(() {
      _totalSpacesMoved = 0;
      _turnMoveCounter = 0;
    });
  }

  void _jumpToSpace(int spaceIndex) {
    setState(() {
      final lapOffset =
          (_totalSpacesMoved ~/ DeutschlandTrack.totalSpaces) *
          DeutschlandTrack.totalSpaces;
      final newTotal = lapOffset + spaceIndex;
      _turnMoveCounter += (newTotal - _totalSpacesMoved);
      _totalSpacesMoved = newTotal;
    });
  }

  void _shuffleDrawPile() {
    setState(() {
      _drawPile.shuffle(_random);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pioche mélangée !'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _drawToSeven() {
    setState(() {
      while (_hand.length < 7) {
        if (_drawPile.isEmpty) {
          if (_discardPile.isEmpty) break;
          _drawPile.addAll(_discardPile);
          _discardPile.clear();
          _drawPile.shuffle(_random);
        }
        _hand.add(_drawPile.removeLast());
      }
    });
  }

  void _playCard(HeatCard card) {
    setState(() {
      _hand.remove(card);
      _playedCards.add(card);
    });
  }

  void _discardPlayed() {
    setState(() {
      _discardPile.addAll(_playedCards);
      _playedCards.clear();
    });
  }

  void _reshuffleDiscardIntoDraw() {
    setState(() {
      _drawPile.addAll(_discardPile);
      _discardPile.clear();
      _drawPile.shuffle(_random);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _stepForward,
        const SingleActivator(LogicalKeyboardKey.space): _stepForward,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _stepBackward,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF161920),
            title: const Row(
              children: [
                Icon(Icons.flag, color: Color(0xFFE53935)),
                SizedBox(width: 8),
                Text(
                  'HEAT — Deutschland',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                icon: Icon(
                  _showSpaceMarkers ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                label: const Text('Repères (62)'),
              ),
              const SizedBox(width: 8),
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
                            _buildMovementBar(),
                            const SizedBox(height: 10),
                            Expanded(
                              child: TrackBoard(
                                carSpaceIndex: _currentSpaceIndex,
                                showSpaceMarkers: _showSpaceMarkers,
                                onSpaceTapped: _jumpToSpace,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: PlayerDashboard(
                            gear: _gear,
                            onGearChanged: (g) => setState(() => _gear = g),
                            drawPile: _drawPile,
                            hand: _hand,
                            playedCards: _playedCards,
                            discardPile: _discardPile,
                            engineHeatCount: _engineHeat.length,
                            onShuffleDeck: _shuffleDrawPile,
                            onDrawToSeven: _drawToSeven,
                            onPlayCard: _playCard,
                            onDiscardPlayed: _discardPlayed,
                            onReshuffleDiscard: _reshuffleDiscardIntoDraw,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    _buildMovementBar(),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 360,
                      child: TrackBoard(
                        carSpaceIndex: _currentSpaceIndex,
                        showSpaceMarkers: _showSpaceMarkers,
                        onSpaceTapped: _jumpToSpace,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PlayerDashboard(
                      gear: _gear,
                      onGearChanged: (g) => setState(() => _gear = g),
                      drawPile: _drawPile,
                      hand: _hand,
                      playedCards: _playedCards,
                      discardPile: _discardPile,
                      engineHeatCount: _engineHeat.length,
                      onShuffleDeck: _shuffleDrawPile,
                      onDrawToSeven: _drawToSeven,
                      onPlayCard: _playCard,
                      onDiscardPlayed: _discardPlayed,
                      onReshuffleDiscard: _reshuffleDiscardIntoDraw,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMovementBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatBadge(
                label: 'DÉPLACEMENT',
                value: '$_turnMoveCounter',
                highlight: true,
              ),
              const SizedBox(width: 10),
              _StatBadge(
                label: 'CASE',
                value:
                    '${_currentSpaceIndex + 1}/${DeutschlandTrack.totalSpaces}',
              ),
              const SizedBox(width: 10),
              _StatBadge(
                label: 'TOUR',
                value: '$_currentLap/${DeutschlandTrack.totalLaps}',
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _totalSpacesMoved > 0 ? _stepBackward : null,
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('-1 Case'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _stepForward,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+1 Case'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _endTurn,
                child: const Text('Fin de tour'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Remettre au départ',
                onPressed: _resetPosition,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFE53935).withValues(alpha: 0.2)
            : const Color(0xFF252932),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? const Color(0xFFE53935) : Colors.white12,
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
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.white60,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
