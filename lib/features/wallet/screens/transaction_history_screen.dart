import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/session_history_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/format_helpers.dart';

/// Screen showing the user's ledger / transaction history
class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ledgerHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: ledgerAsync.when(
        loading: () =>
            const LoadingView(message: 'Loading transactions...'),
        error: (error, _) => ErrorView(
          message: 'Error loading transactions: $error',
          onRetry: () => ref.invalidate(ledgerHistoryProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long,
              title: 'No transactions yet',
              subtitle: 'Your balance changes will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _TransactionTile(entry: entry, theme: theme);
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final LedgerEntry entry;
  final ThemeData theme;

  const _TransactionTile({required this.entry, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.isPositive;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(entry.icon, color: color, size: 20),
        ),
        title: Text(
          entry.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          FormatHelpers.shortDateTime(entry.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        trailing: Text(
          '${isPositive ? "+" : "−"}${entry.amount}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
