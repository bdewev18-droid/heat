import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/heat_card.dart';
import '../models/track_data.dart';
import '../services/app_update_service.dart';
import '../services/race_history_service.dart';
import '../theme/heat_theme.dart';
import '../widgets/heat_card_widget.dart';
import 'game_screen.dart';
import 'history_screen.dart';

/// Page d'accueil (HP) reprenant la charte graphique du livret PDF :
/// - Icône + Logo HEAT + Badge pilote Green Hornet (Vert)
/// - Option Cartes Bonus (Deckbuild : carte blanche vit. 1, -1 Heat, +3 Asp.)
/// - Accès Historique & Records locaux
/// - Bouton JOUER → choix du circuit (Allemagne), nb joueurs, position fixe/aléatoire
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showTrackSelection = false;
  int _selectedLaps = DeutschlandTrack.defaultLaps;
  int _playerCount = 3;
  bool _includeStartingUpgrades = false;
  bool _includeBonusCards = false;

  // Position sur la grille : Aléatoire ou Fixe (1.._playerCount)
  bool _randomStartPosition = true;
  int _fixedStartPosition = 5;

  RemoteAppVersion? _pendingUpdate;
  bool _isCheckingUpdate = false;
  RaceHistorySummary? _historySummary;

  @override
  void initState() {
    super.initState();
    _checkLaunchUpdate();
    _loadHistorySummary();
  }

  Future<void> _loadHistorySummary() async {
    final records = await RaceHistoryService.loadHistory();
    if (!mounted) return;
    setState(() {
      _historySummary = RaceHistoryService.computeSummary(records);
    });
  }

  Future<void> _checkLaunchUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (mounted) setState(() => _isCheckingUpdate = true);
    final update = await AppUpdateService.checkUpdate();
    if (!mounted) return;
    setState(() {
      _pendingUpdate = update;
      _isCheckingUpdate = false;
    });
  }

  void _startDeutschlandRace() {
    final effectiveFixed = _randomStartPosition
        ? null
        : _fixedStartPosition.clamp(1, _playerCount);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              totalLaps: _selectedLaps,
              includeStartingUpgrades: _includeStartingUpgrades,
              includeBonusCards: _includeBonusCards,
              playerCount: _playerCount,
              fixedStartPosition: effectiveFixed,
            ),
          ),
        )
        .then((_) => _loadHistorySummary());
  }

  void _openHistory() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HistoryScreen()))
        .then((_) => _loadHistorySummary());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _VintageRacingBgPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _showTrackSelection
                        ? _buildTrackSelectionView()
                        : _buildHeroHomeView(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHomeView() {
    final summary = _historySummary;
    final hasRaces = summary != null && summary.totalRaces > 0;

    return Column(
      key: const ValueKey('hero'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HeatColors.heatGold, width: 3),
            boxShadow: [
              BoxShadow(
                color: HeatColors.navyHeader.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        const HeatLogoWidget(scale: 0.94),
        const SizedBox(height: 14),

        // Badge Pilote Green Hornet
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: HeatColors.trackGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HeatColors.heatGold, width: 1.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car, color: Colors.white, size: 17),
              SizedBox(width: 7),
              Text(
                'PILOTE : ${HeatGameController.playerDisplayName} (VERT)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Encart principal HP + Option Cartes Bonus Deckbuild
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: HeatColors.paperCard.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HeatColors.heatGold, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: HeatColors.navyHeader.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'METS LE PIED AU PLANCHER !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: HeatColors.heatRed,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Entraîne-toi sur Deutschland de 1 à 8 pilotes selon les règles officielles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: HeatColors.inkDark,
                ),
              ),
              const SizedBox(height: 12),

              // Option HP : Cartes Bonus issues du deckbuild
              Material(
                color: HeatColors.paperCream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _includeBonusCards
                        ? HeatColors.trackGreen
                        : HeatColors.paperBorder,
                    width: _includeBonusCards ? 1.8 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      HeatCardWidget(
                        card: createWhiteSlipstreamBonusCard(),
                        width: 46,
                        height: 64,
                        enabled: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeThumbColor: HeatColors.trackGreen,
                          title: const Text(
                            'Cartes Bonus (Deckbuild)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: HeatColors.navyHeader,
                            ),
                          ),
                          subtitle: const Text(
                            'Ajoute ta Carte Blanche : Vitesse 1, coûte 1 Heat, +3 Aspiration (en plus des +2).',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: HeatColors.inkMuted,
                            ),
                          ),
                          value: _includeBonusCards,
                          onChanged: (v) =>
                              setState(() => _includeBonusCards = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Boutons JOUER + HISTORIQUE
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: 230,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showTrackSelection = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HeatColors.heatRed,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  side: const BorderSide(color: HeatColors.heatGold, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'JOUER',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _openHistory,
                style: OutlinedButton.styleFrom(
                  backgroundColor: HeatColors.paperCard,
                  foregroundColor: HeatColors.navyHeader,
                  side: const BorderSide(
                    color: HeatColors.navyHeader,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.emoji_events, color: HeatColors.heatOrange),
                label: Text(
                  hasRaces
                      ? 'HISTORIQUE (${summary.totalRaces} • Top3: ${summary.top3Count})'
                      : 'HISTORIQUE & RECORDS',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _buildUpdateStatusBar(),
      ],
    );
  }

  Widget _buildUpdateStatusBar() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final hasUpdate = _pendingUpdate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasUpdate
            ? HeatColors.cooldownBlue.withValues(alpha: 0.12)
            : HeatColors.paperCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUpdate ? HeatColors.cooldownBlue : HeatColors.paperBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.verified_outlined,
                size: 18,
                color: hasUpdate
                    ? HeatColors.cooldownBlue
                    : HeatColors.trackGreen,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isCheckingUpdate
                      ? 'Vérification des mises à jour…'
                      : hasUpdate
                          ? 'Mise à jour disponible : v${_pendingUpdate!.version} (Build ${_pendingUpdate!.buildNumber})'
                          : 'Heat v$appVersionLabel (Build $appBuildNumber)${isAndroid ? " • À jour" : " • Web"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HeatColors.navyHeader,
                  ),
                ),
              ),
              if (isAndroid && !_isCheckingUpdate && !hasUpdate) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _checkLaunchUpdate,
                  child: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: HeatColors.navyHeader,
                  ),
                ),
              ],
            ],
          ),
          if (hasUpdate) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => AppUpdateService.promptUpdate(
                context,
                _pendingUpdate!,
                isForced: false,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HeatColors.cooldownBlue,
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Installer la mise à jour'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackSelectionView() {
    final clampedFixed = _fixedStartPosition.clamp(1, _playerCount);

    return Column(
      key: const ValueKey('tracks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () {
                setState(() {
                  _showTrackSelection = false;
                });
              },
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour à l\'accueil',
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: HeatSectionBanner(title: 'Choix du circuit'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: HeatColors.paperCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HeatColors.navyHeader, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: DeutschlandTrack.imageAspectRatio,
                    child: Image.asset(
                      'assets/images/deutschland.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: HeatColors.navyHeader.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: HeatColors.heatGold,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'ALLEMAGNE — DEUTSCHLAND',
                        style: TextStyle(
                          color: HeatColors.heatGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const _TrackStatChip(label: '62 cases'),
                        const _TrackStatChip(
                          label: '6 virages (5 • 2 • 2 • 6 • 4 • 4)',
                        ),
                        const _TrackStatChip(label: '5 Heat moteur'),
                        const _TrackStatChip(label: '3 Stress départ'),
                        if (_includeBonusCards)
                          const _TrackStatChip(label: 'Carte Bonus Blanche activée'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Choix du nombre de joueurs (1 à 8)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre de joueurs : $_playerCount '
                          '(${_playerCount == 1 ? "Solo" : "Green Hornet + ${_playerCount - 1} bot${_playerCount - 1 > 1 ? "s" : ""}"})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: HeatColors.navyHeader,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(8, (index) {
                            final count = index + 1;
                            final selected = _playerCount == count;
                            return ChoiceChip(
                              label: Text('$count'),
                              selected: selected,
                              selectedColor: HeatColors.heatRed,
                              labelStyle: TextStyle(
                                color:
                                    selected ? Colors.white : HeatColors.inkDark,
                                fontWeight: FontWeight.w900,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _playerCount = count;
                                  if (_fixedStartPosition > _playerCount) {
                                    _fixedStartPosition = _playerCount;
                                  }
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Position sur la grille : Aléatoire ou Fixe (1..N)
                    if (_playerCount > 1) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Position sur la grille de départ :',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: HeatColors.navyHeader,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.casino, size: 16),
                                label: const Text('Aléatoire'),
                                selected: _randomStartPosition,
                                selectedColor: HeatColors.navyHeader,
                                labelStyle: TextStyle(
                                  color: _randomStartPosition
                                      ? Colors.white
                                      : HeatColors.inkDark,
                                  fontWeight: FontWeight.w800,
                                ),
                                onSelected: (_) => setState(
                                  () => _randomStartPosition = true,
                                ),
                              ),
                              ChoiceChip(
                                avatar: const Icon(Icons.pin_drop, size: 16),
                                label: Text('Position fixe (P$clampedFixed)'),
                                selected: !_randomStartPosition,
                                selectedColor: HeatColors.trackGreen,
                                labelStyle: TextStyle(
                                  color: !_randomStartPosition
                                      ? Colors.white
                                      : HeatColors.inkDark,
                                  fontWeight: FontWeight.w800,
                                ),
                                onSelected: (_) => setState(
                                  () => _randomStartPosition = false,
                                ),
                              ),
                            ],
                          ),
                          if (!_randomStartPosition) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(_playerCount, (index) {
                                final pos = index + 1;
                                final selected = clampedFixed == pos;
                                return ChoiceChip(
                                  label: Text('P$pos'),
                                  selected: selected,
                                  selectedColor: HeatColors.trackGreen,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : HeatColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  onSelected: (_) => setState(
                                    () => _fixedStartPosition = pos,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Nombre de tours
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Nombre de tours :',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: HeatColors.navyHeader,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('1 tour (Découverte)'),
                          selected: _selectedLaps == 1,
                          selectedColor: HeatColors.heatRed,
                          labelStyle: TextStyle(
                            color: _selectedLaps == 1
                                ? Colors.white
                                : HeatColors.inkDark,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _selectedLaps = 1),
                        ),
                        ChoiceChip(
                          label: const Text('2 tours (Officiel)'),
                          selected: _selectedLaps == 2,
                          selectedColor: HeatColors.heatRed,
                          labelStyle: TextStyle(
                            color: _selectedLaps == 2
                                ? Colors.white
                                : HeatColors.inkDark,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _selectedLaps = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cartes 0/5
                    Material(
                      color: HeatColors.paperCream,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: HeatColors.paperBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeThumbColor: HeatColors.heatRed,
                          title: const Text(
                            'Cartes Amélioration de départ (0, 5 & +1 Heat)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: HeatColors.navyHeader,
                            ),
                          ),
                          subtitle: Text(
                            _includeStartingUpgrades
                                ? 'Activé : paquet de 18 cartes (avec 0, 5 et 1 Heat de départ)'
                                : 'Désactivé (Mode Compétition) : 12 Basic + 3 Stress (sans 0 ni 5)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: HeatColors.inkMuted,
                            ),
                          ),
                          value: _includeStartingUpgrades,
                          onChanged: (v) =>
                              setState(() => _includeStartingUpgrades = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _startDeutschlandRace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HeatColors.heatRed,
                          side: const BorderSide(
                            color: HeatColors.heatGold,
                            width: 1.5,
                          ),
                        ),
                        icon: const Icon(Icons.sports_score, size: 24),
                        label: const Text(
                          'LANCER LA COURSE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackStatChip extends StatelessWidget {
  const _TrackStatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HeatColors.paperCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HeatColors.paperBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: HeatColors.navyHeader,
        ),
      ),
    );
  }
}

class _VintageRacingBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = HeatColors.paperCream,
    );

    final navyStripe = Paint()
      ..color = HeatColors.navyHeader.withValues(alpha: 0.06);
    final redStripe = Paint()
      ..color = HeatColors.heatRed.withValues(alpha: 0.07);

    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.36, 0)
      ..lineTo(0, size.height * 0.42)
      ..close();
    canvas.drawPath(path1, navyStripe);

    final path2 = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.58, size.height)
      ..lineTo(size.width, size.height * 0.48)
      ..close();
    canvas.drawPath(path2, redStripe);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 8),
      Paint()..color = HeatColors.navyHeader,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 8, size.width, 3),
      Paint()..color = HeatColors.heatGold,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 8, size.width, 8),
      Paint()..color = HeatColors.navyHeader,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
