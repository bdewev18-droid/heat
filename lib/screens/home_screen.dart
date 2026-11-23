import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/track_data.dart';
import '../services/app_update_service.dart';
import '../theme/heat_theme.dart';
import 'game_screen.dart';

/// Page d'accueil (HP) reprenant la charte graphique du livret PDF :
/// Icône + Logo HEAT, gestion de mise à jour APK, bouton JOUER, puis sélection
/// du circuit (Allemagne uniquement).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showTrackSelection = false;
  int _selectedLaps = DeutschlandTrack.defaultLaps;

  RemoteAppVersion? _pendingUpdate;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkLaunchUpdate();
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(totalLaps: _selectedLaps),
      ),
    );
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
    return Column(
      key: const ValueKey('hero'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emblème / Icône du jeu
        Container(
          width: 96,
          height: 96,
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
        const SizedBox(height: 12),
        const HeatLogoWidget(scale: 0.98),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: HeatColors.paperCard.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HeatColors.heatGold, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: HeatColors.navyHeader.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'METS LE PIED AU PLANCHER !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: HeatColors.heatRed,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Affronte 2 pilotes adverses en mode Shadow (vrais paquets, aucune triche) '
                'selon les 9 étapes officielles : jet de dés de départ, boîte de vitesses, '
                'cartes Stress & Heat, aspiration et gestion des virages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: HeatColors.inkDark,
                ),
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _InfoPill(icon: Icons.smart_toy, text: '2 Bots Shadow'),
                  _InfoPill(icon: Icons.casino, text: 'Jet de dés'),
                  _InfoPill(icon: Icons.flag, text: 'Allemagne'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: 260,
          height: 56,
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
            icon: const Icon(Icons.play_arrow_rounded, size: 30),
            label: const Text(
              'JOUER',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
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
        const SizedBox(height: 18),
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
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TrackStatChip(label: '62 cases'),
                        _TrackStatChip(
                          label: '6 virages (5 • 2 • 2 • 6 • 4 • 4)',
                        ),
                        _TrackStatChip(label: '5 Heat moteur'),
                        _TrackStatChip(label: '3 Stress départ'),
                        _TrackStatChip(label: 'Toi + 2 Bots Shadow'),
                      ],
                    ),
                    const SizedBox(height: 14),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HeatColors.navyHeader.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HeatColors.navyHeader.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: HeatColors.navyHeader),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HeatColors.navyHeader,
            ),
          ),
        ],
      ),
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
