import 'package:flutter/material.dart';
import '../services/race_history_service.dart';
import '../theme/heat_theme.dart';

/// Écran Historique & Records locaux de Green Hornet.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<RaceResultRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await RaceHistoryService.loadHistory();
    if (!mounted) return;
    setState(() {
      _records = data;
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HeatColors.paperCard,
        title: const Text(
          'Effacer l\'historique ?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: HeatColors.navyHeader,
          ),
        ),
        content: const Text(
          'Toutes les courses enregistrées localement seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await RaceHistoryService.clearHistory();
      await _load();
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final summary = RaceHistoryService.computeSummary(_records);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: HeatColors.heatGold),
            SizedBox(width: 8),
            Text(
              'Historique — Green Hornet',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'Effacer l\'historique',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const HeatSectionBanner(
                  title: 'Records personnels (Local)',
                  compact: true,
                ),
                const SizedBox(height: 10),
                if (summary.totalRaces == 0)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: HeatColors.paperCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HeatColors.paperBorder),
                    ),
                    child: const Text(
                      'Aucune course terminée pour le moment. '
                      'Termine une course sur Deutschland pour enregistrer tes records !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HeatColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _RecordTile(
                        icon: Icons.sports_score,
                        label: 'Courses terminées',
                        value: '${summary.totalRaces}',
                        color: HeatColors.navyHeader,
                      ),
                      _RecordTile(
                        icon: Icons.emoji_events,
                        label: 'Victoires (1er)',
                        value: '${summary.winsCount}',
                        color: HeatColors.heatRed,
                      ),
                      _RecordTile(
                        icon: Icons.workspace_premium,
                        label: 'Podiums (Top 3)',
                        value: '${summary.top3Count}',
                        color: HeatColors.trackGreen,
                      ),
                      _RecordTile(
                        icon: Icons.military_tech,
                        label: 'Meilleure place',
                        value:
                            '${summary.bestRank}e / ${summary.bestRankPlayerCount}',
                        color: HeatColors.heatOrange,
                      ),
                      _RecordTile(
                        icon: Icons.straighten,
                        label: 'Max après ligne',
                        value: '+${summary.maxFinishLineDistance} cases',
                        color: HeatColors.cooldownBlue,
                      ),
                      if (summary.bestRoundsTwoLaps != null)
                        _RecordTile(
                          icon: Icons.timer,
                          label: 'Record 2 tours',
                          value: '${summary.bestRoundsTwoLaps} manches',
                          color: HeatColors.navyHeader,
                        ),
                      if (summary.bestRoundsOneLap != null)
                        _RecordTile(
                          icon: Icons.timer_outlined,
                          label: 'Record 1 tour',
                          value: '${summary.bestRoundsOneLap} manches',
                          color: HeatColors.navyHeader,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const HeatSectionBanner(
                    title: 'Dernières courses',
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                  ..._records.map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HeatColors.paperCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: r.isWin
                              ? HeatColors.heatGold
                              : (r.isTop3
                                  ? HeatColors.trackGreen
                                  : HeatColors.paperBorder),
                          width: r.isTop3 ? 1.8 : 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: r.isWin
                                      ? HeatColors.heatRed
                                      : (r.isTop3
                                          ? HeatColors.trackGreen
                                          : HeatColors.navyHeader),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${r.finalRank}e / ${r.playerCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (r.isTop3)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HeatColors.heatGold
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: HeatColors.heatGold),
                                  ),
                                  child: Text(
                                    r.isWin ? '🏆 VICTOIRE' : '🥇 TOP 3',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: HeatColors.navyHeader,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                _formatDate(r.playedAtIso),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: HeatColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetaPill('Circuit : ${r.trackName}'),
                              _MetaPill('Départ : P${r.startPosition}'),
                              _MetaPill('${r.totalLaps} tour(s)'),
                              _MetaPill('${r.roundsCount} manches'),
                              _MetaPill(
                                'Distance ligne : +${r.finishLineDistance} cases',
                              ),
                              if (r.includeBonusCards)
                                const _MetaPill('Carte Bonus Blanche'),
                              if (r.includeStartingUpgrades)
                                const _MetaPill('Avec 0/5'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HeatColors.paperCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HeatColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HeatColors.paperCream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HeatColors.paperBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HeatColors.inkDark,
        ),
      ),
    );
  }
}
