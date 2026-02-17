import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/backend_service.dart';
import '../../../services/screen_time_service.dart';

class RedemptionSetupScreen extends ConsumerStatefulWidget {
  const RedemptionSetupScreen({super.key});

  @override
  ConsumerState<RedemptionSetupScreen> createState() =>
      _RedemptionSetupScreenState();
}

class _RedemptionSetupScreenState extends ConsumerState<RedemptionSetupScreen> {
  int _durationMinutes = 30;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _expiryTimer;

  final List<int> _presetDurations = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    // Tick every second for live countdown
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRedemption() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionId = await BackendService.startRedemptionSession(
        durationMinutes: _durationMinutes,
      );

      // Start native Screen Time monitoring and shielding
      try {
        final screenTimeService = ScreenTimeService();
        await screenTimeService.startSession(
          sessionId: sessionId,
          durationMinutes: _durationMinutes,
        );
        debugPrint('✅ Native Screen Time redemption session started');
      } catch (e) {
        debugPrint('⚠️ Native Screen Time start failed (may be simulator): $e');
      }

      if (mounted) {
        context.go('/session/active/$sessionId');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start redemption: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(walletProvider);
    final redemptionExpiryAsync = ref.watch(redemptionExpiryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Redemption Session')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (wallet) {
          if (wallet == null) {
            return const Center(child: Text('No wallet data'));
          }

          return redemptionExpiryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (expiry) {
              // Check if redemption window is still valid
              final now = DateTime.now();
              final hasValidWindow = expiry != null && now.isBefore(expiry);
              final remaining = hasValidWindow ? expiry!.difference(now) : null;

              if (!hasValidWindow) {
                return _ExpiredView(theme: theme);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Redemption countdown banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.errorContainer,
                            theme.colorScheme.errorContainer.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hourglass_bottom,
                            color: theme.colorScheme.onErrorContainer,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Redemption Window Closing',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCountdown(remaining!),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Explanation card
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restore,
                              size: 48,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Prove Your Focus',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete this focus session to rescue your Frozen Votes and convert Ash into Obsidian. No credits are locked for redemption sessions.',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // What's at stake
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What\'s at Stake',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StakeRow(
                              icon: Icons.ac_unit,
                              iconColor: Colors.blue,
                              label: 'Frozen Votes',
                              value: '${wallet.purgatoryVotes}',
                              description:
                                  'Rescued on success, lost on failure',
                            ),
                            const SizedBox(height: 12),
                            _StakeRow(
                              icon: Icons.local_fire_department,
                              iconColor: Colors.grey,
                              label: 'Ash',
                              value: '${wallet.ash}',
                              description: 'Converted to Obsidian on success',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Duration Section
                    Text(
                      'Focus Duration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetDurations.map((duration) {
                        return ChoiceChip(
                          label: Text('$duration min'),
                          selected: _durationMinutes == duration,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _durationMinutes = duration);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Outcomes
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Possible Outcomes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _OutcomeRow(
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                              title: 'Success',
                              description:
                                  'Frozen Votes rescued + Ash → Obsidian',
                            ),
                            const SizedBox(height: 8),
                            _OutcomeRow(
                              icon: Icons.cancel_outlined,
                              color: Colors.red,
                              title: 'Failure',
                              description:
                                  'Frozen Votes lost permanently. Ash remains.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Start Button
                    ElevatedButton.icon(
                      onPressed: !_isLoading ? _startRedemption : null,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      label: const Text('Begin Redemption'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Shown when the redemption window has expired
class _ExpiredView extends StatelessWidget {
  final ThemeData theme;

  const _ExpiredView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_off,
              size: 80,
              color: theme.colorScheme.error.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Redemption Window Expired',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your Frozen Votes have been lost. Focus harder next time!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => context.go('/wallet'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Return to Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StakeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String description;

  const _StakeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OutcomeRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
