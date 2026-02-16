import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/backend_service.dart';

class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  int _pledgeAmount = 500;
  int _durationMinutes = 60;
  bool _isLoading = false;
  String? _errorMessage;

  final List<int> _presetAmounts = [100, 250, 500, 1000, 2000];
  final List<int> _presetDurations = [15, 30, 45, 60, 90, 120];

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call Cloud Function startSession
      final sessionId = await BackendService.startSession(
        pledgeAmount: _pledgeAmount,
        durationMinutes: _durationMinutes,
        idempotencyKey: 'mobile_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Navigate to active session screen
      if (mounted) {
        context.go('/session/active/$sessionId');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start session: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Start Pledge Session')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (wallet) {
          if (wallet == null) {
            return const Center(child: Text('No wallet data'));
          }

          final canStart = _pledgeAmount <= wallet.credits;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 48,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pledge Session',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lock credits and stay focused for the selected duration. Screen Time will block distractions.',
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

                // Available Credits
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Credits',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${wallet.credits} FC',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Pledge Amount Section
                Text(
                  'Pledge Amount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetAmounts.map((amount) {
                    return ChoiceChip(
                      label: Text('$amount FC'),
                      selected: _pledgeAmount == amount,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _pledgeAmount = amount);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _pledgeAmount.toDouble(),
                  min: 100,
                  max: wallet.credits.toDouble().clamp(100, 5000),
                  divisions:
                      ((wallet.credits.toDouble().clamp(100, 5000) - 100) / 50)
                          .round(),
                  label: '$_pledgeAmount FC',
                  onChanged: (value) {
                    setState(() => _pledgeAmount = value.round());
                  },
                ),
                Text(
                  'Selected: $_pledgeAmount FC',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
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

                // Outcomes Section
                Card(
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
                              'Credits returned + Impact Points earned',
                        ),
                        const SizedBox(height: 8),
                        _OutcomeRow(
                          icon: Icons.cancel_outlined,
                          color: Colors.red,
                          title: 'Failure',
                          description:
                              'Credits → Ash, Votes frozen, 24h redemption window',
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
                ElevatedButton(
                  onPressed: canStart && !_isLoading ? _startSession : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Start Session'),
                ),

                if (!canStart)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Insufficient credits. Need $_pledgeAmount FC, have ${wallet.credits} FC.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
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
