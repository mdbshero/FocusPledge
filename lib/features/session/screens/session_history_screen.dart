import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/session_history_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/format_helpers.dart';

/// Screen showing past session history with stats summary
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: sessionsAsync.when(
        loading: () => const LoadingView(message: 'Loading sessions...'),
        error: (error, _) => ErrorView(
          message: 'Error loading sessions: $error',
          onRetry: () => ref.invalidate(sessionHistoryProvider),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No sessions yet',
              subtitle:
                  'Start a pledge session to begin building your focus history.',
            );
          }

          final completed = sessions.where((s) => s.isCompleted).length;
          final failed = sessions.where((s) => s.isFailed).length;
          final active = sessions.where((s) => s.isActive).length;
          final successRate =
              (completed + failed) > 0
                  ? (completed / (completed + failed) * 100).round()
                  : 0;

          return CustomScrollView(
            slivers: [
              // Stats summary card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _StatChip(
                                label: 'Total',
                                value: '${sessions.length}',
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                label: 'Success',
                                value: '$completed',
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                label: 'Failed',
                                value: '$failed',
                                color: Colors.red,
                              ),
                              if (active > 0) ...[
                                const SizedBox(width: 12),
                                _StatChip(
                                  label: 'Active',
                                  value: '$active',
                                  color: Colors.blue,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Success rate bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: successRate / 100,
                                    minHeight: 8,
                                    backgroundColor: Colors.red.withOpacity(0.2),
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                          Colors.green,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$successRate% success rate',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Session list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final session = sessions[index];
                      return _SessionTile(session: session);
                    },
                    childCount: sessions.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = FormatHelpers.statusColor(session.status.toFirestore());
    final typeIcon = FormatHelpers.sessionTypeIcon(session.type.toFirestore());
    final isRedemption = session.type == SessionType.redemption;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(typeIcon, color: statusColor),
        ),
        title: Text(
          isRedemption ? 'Redemption Session' : 'Pledge Session',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.durationMinutes} min • ${isRedemption ? "Redemption" : "${session.pledgeAmount} FC pledged"}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              FormatHelpers.relativeTime(session.startTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            session.status.toFirestore(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
