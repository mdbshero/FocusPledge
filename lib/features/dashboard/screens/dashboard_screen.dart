import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final redemptionExpiryAsync = ref.watch(redemptionExpiryProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    final greeting = _getGreeting();
    final displayName = user?.displayName ?? 'Pledger';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Greeting
              Text(
                '$greeting,',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Redemption Warning (if applicable)
              redemptionExpiryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (expiry) {
                  if (expiry == null) return const SizedBox.shrink();
                  final now = DateTime.now();
                  if (now.isAfter(expiry)) return const SizedBox.shrink();
                  final remaining = expiry.difference(now);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Redemption Required',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatDuration(remaining)} remaining',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push('/wallet/session/redemption-setup'),
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Wallet Summary Card
              walletAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (err, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading wallet: $err'),
                  ),
                ),
                data: (wallet) {
                  if (wallet == null) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Focus Credits',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withOpacity(0.7),
                                ),
                              ),
                              Icon(
                                Icons.stars,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${wallet.credits}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _MiniBalance(
                                icon: Icons.local_fire_department,
                                label: 'Ash',
                                value: wallet.ash,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 24),
                              _MiniBalance(
                                icon: Icons.diamond,
                                label: 'Obsidian',
                                value: wallet.obsidian,
                                color: Colors.deepPurple,
                              ),
                              if (wallet.purgatoryVotes > 0) ...[
                                const SizedBox(width: 24),
                                _MiniBalance(
                                  icon: Icons.ac_unit,
                                  label: 'Frozen',
                                  value: wallet.purgatoryVotes,
                                  color: Colors.blue,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.play_arrow_rounded,
                      label: 'Start\nSession',
                      color: theme.colorScheme.primary,
                      onTap: () => context.push('/wallet/session/setup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_card,
                      label: 'Buy\nCredits',
                      color: theme.colorScheme.secondary,
                      onTap: () => context.push('/wallet/buy-credits'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.restore,
                      label: 'Redeem\nAsh',
                      color: theme.colorScheme.tertiary,
                      onTap: () =>
                          context.push('/wallet/session/redemption-setup'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // History shortcuts
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/wallet/session/history'),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Session History'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/wallet/transactions'),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Transactions'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // How It Works
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'The Focus Cycle',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CycleStep(
                        number: '1',
                        title: 'Pledge Credits',
                        description: 'Lock Focus Credits into a session',
                        color: theme.colorScheme.primary,
                      ),
                      _CycleStep(
                        number: '2',
                        title: 'Stay Focused',
                        description: 'Avoid blocked apps during your session',
                        color: theme.colorScheme.secondary,
                      ),
                      _CycleStep(
                        number: '3',
                        title: 'Earn Rewards',
                        description:
                            'Success → credits back. Fail → Ash → Obsidian',
                        color: theme.colorScheme.tertiary,
                      ),
                      _CycleStep(
                        number: '4',
                        title: 'Shop',
                        description: 'Spend Obsidian on exclusive rewards',
                        color: Colors.deepPurple,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _MiniBalance extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _MiniBalance({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Color color;
  final bool isLast;

  const _CycleStep({
    required this.number,
    required this.title,
    required this.description,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 20, color: color.withOpacity(0.3)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
      ),
    );
  }
}
