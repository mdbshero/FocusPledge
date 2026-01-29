import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/auth_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final redemptionExpiryAsync = ref.watch(redemptionExpiryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading wallet: $error'),
            ],
          ),
        ),
        data: (wallet) {
          if (wallet == null) {
            return const Center(child: Text('No wallet data'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(walletProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Redemption Deadline Warning (if applicable)
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
                        child: Column(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.onErrorContainer,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Redemption Required',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete a Redemption Session within ${_formatDuration(remaining)}',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Primary Balance: Focus Credits
                  _BalanceCard(
                    title: 'Focus Credits',
                    amount: wallet.credits,
                    icon: Icons.stars,
                    color: theme.colorScheme.primary,
                    subtitle: 'Available for pledge sessions',
                  ),
                  const SizedBox(height: 12),

                  // Currency Balances Row
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceCard(
                          title: 'Ash',
                          amount: wallet.ash,
                          icon: Icons.local_fire_department,
                          color: Colors.grey,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceCard(
                          title: 'Obsidian',
                          amount: wallet.obsidian,
                          icon: Icons.diamond,
                          color: Colors.deepPurple,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Frozen Votes (Purgatory)
                  if (wallet.purgatoryVotes > 0)
                    _BalanceCard(
                      title: 'Frozen Votes',
                      amount: wallet.purgatoryVotes,
                      icon: Icons.ac_unit,
                      color: Colors.blue,
                      subtitle: 'Rescue these with a Redemption Session',
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: () => context.push('/buy-credits'),
                    icon: const Icon(Icons.add_card),
                    label: const Text('Buy Focus Credits'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: wallet.credits >= 100
                        ? () => context.push('/session/setup')
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Pledge Session'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  
                  if (wallet.credits < 100)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Need at least 100 credits to start a session',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: wallet.obsidian > 0
                        ? () => context.push('/shop')
                        : null,
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Browse Shop'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistics',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _StatRow(
                            label: 'Lifetime Purchased',
                            value: '${wallet.lifetimePurchased} FC',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _BalanceCard extends StatelessWidget {
  final String title;
  final int amount;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool compact;

  const _BalanceCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(icon, color: color, size: compact ? 20 : 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              amount.toString(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: compact ? 24 : 32,
              ),
              textAlign: compact ? TextAlign.center : TextAlign.left,
            ),
            if (subtitle != null && !compact) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
