import 'package:flutter/material.dart';

/// Compact balance chip showing an icon + value label.
/// Used across dashboard, wallet, shop, etc.
class BalanceChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool compact;

  const BalanceChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.compact = false,
  });

  /// Focus Credits chip
  factory BalanceChip.credits(int value, {bool compact = false}) {
    return BalanceChip(
      icon: Icons.stars,
      value: value,
      label: 'Credits',
      color: Colors.amber,
      compact: compact,
    );
  }

  /// Ash chip
  factory BalanceChip.ash(int value, {bool compact = false}) {
    return BalanceChip(
      icon: Icons.local_fire_department,
      value: value,
      label: 'Ash',
      color: Colors.grey,
      compact: compact,
    );
  }

  /// Obsidian chip
  factory BalanceChip.obsidian(int value, {bool compact = false}) {
    return BalanceChip(
      icon: Icons.diamond,
      value: value,
      label: 'Obsidian',
      color: Colors.deepPurple,
      compact: compact,
    );
  }

  /// Frozen Votes chip
  factory BalanceChip.frozenVotes(int value, {bool compact = false}) {
    return BalanceChip(
      icon: Icons.ac_unit,
      value: value,
      label: 'Frozen',
      color: Colors.blue,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 14 : 18, color: color),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: textStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (!compact) ...[
          const SizedBox(width: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }
}
