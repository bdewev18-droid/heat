import 'package:flutter/material.dart';
import '../models/heat_card.dart';

/// Tableau de bord du joueur : boîte de vitesses, moteur, pioche, main et défausse.
class PlayerDashboard extends StatelessWidget {
  const PlayerDashboard({
    super.key,
    required this.gear,
    required this.onGearChanged,
    required this.drawPile,
    required this.hand,
    required this.playedCards,
    required this.discardPile,
    required this.engineHeatCount,
    required this.onShuffleDeck,
    required this.onDrawToSeven,
    required this.onPlayCard,
    required this.onDiscardPlayed,
    required this.onReshuffleDiscard,
  });

  final int gear;
  final ValueChanged<int> onGearChanged;
  final List<HeatCard> drawPile;
  final List<HeatCard> hand;
  final List<HeatCard> playedCards;
  final List<HeatCard> discardPile;
  final int engineHeatCount;
  final VoidCallback onShuffleDeck;
  final VoidCallback onDrawToSeven;
  final ValueChanged<HeatCard> onPlayCard;
  final VoidCallback onDiscardPlayed;
  final VoidCallback onReshuffleDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGearboxAndEngine(),
          const SizedBox(height: 12),
          _buildPilesRow(),
          const SizedBox(height: 12),
          if (playedCards.isNotEmpty) ...[
            _buildPlayedSection(),
            const SizedBox(height: 12),
          ],
          _buildHandSection(),
        ],
      ),
    );
  }

  Widget _buildGearboxAndEngine() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF252932),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BOÎTE DE VITESSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3, 4].map((g) {
                    final selected = gear == g;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: g < 4 ? 6 : 0),
                        child: InkWell(
                          onTap: () => onGearChanged(g),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF16181E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white24,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$g',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: selected ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF252932),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MOTEUR (HEAT)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.deepOrangeAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$engineHeatCount',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPilesRow() {
    final topDiscard = discardPile.isEmpty ? null : discardPile.last;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF252932),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PIOCHE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white60,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${drawPile.length} cartes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onShuffleDeck,
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: const Text('Mélanger'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onDrawToSeven,
                      icon: const Icon(Icons.style, size: 16),
                      label: const Text('Piocher (7)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF252932),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DÉFAUSSE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white60,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${discardPile.length} cartes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (topDiscard != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: topDiscard.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: topDiscard.accentColor),
                        ),
                        child: Text(
                          topDiscard.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Vide',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    const Spacer(),
                    if (discardPile.isNotEmpty)
                      TextButton.icon(
                        onPressed: onReshuffleDiscard,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Remélanger'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayedSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF252932),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CARTES JOUÉES (${playedCards.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.amberAccent,
                ),
              ),
              TextButton.icon(
                onPressed: onDiscardPlayed,
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('Défausser'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: playedCards
                .map((card) => _HeatCardTile(card: card, compact: true))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MAIN (${hand.length}/7) — Clique sur une carte pour la jouer',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 8),
        if (hand.isEmpty)
          Container(
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF16181E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'Main vide — Clique sur "Piocher (7)"',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hand
                .map(
                  (card) => _HeatCardTile(
                    card: card,
                    onTap: () => onPlayCard(card),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _HeatCardTile extends StatelessWidget {
  const _HeatCardTile({
    required this.card,
    this.onTap,
    this.compact = false,
  });

  final HeatCard card;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 58.0 : 68.0;
    final height = compact ? 74.0 : 88.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              card.accentColor.withValues(alpha: 0.35),
              const Color(0xFF15171C),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: card.accentColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: card.type == HeatCardType.speed ? 24 : 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
