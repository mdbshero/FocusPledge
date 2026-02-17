import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shop_item.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/backend_service.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(shopCatalogProvider);
    final walletAsync = ref.watch(walletProvider);
    final ownedIds = ref.watch(ownedItemIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          // Obsidian balance chip
          walletAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (wallet) {
              if (wallet == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(
                    Icons.diamond,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  label: Text(
                    '${wallet.obsidian}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading catalog: $error'),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Shop Coming Soon',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Earn Obsidian through Redemption Sessions to unlock cosmetics here.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Group by category
          final grouped = <ItemCategory, List<ShopItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _categoryLabel(entry.key),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (context, index) {
                    final item = entry.value[index];
                    final isOwned = ownedIds.contains(item.itemId);
                    return _ShopItemCard(item: item, isOwned: isOwned);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  String _categoryLabel(ItemCategory category) {
    switch (category) {
      case ItemCategory.theme:
        return '🎨 Themes';
      case ItemCategory.icon:
        return '✨ Icons';
      case ItemCategory.badge:
        return '🏅 Badges';
      case ItemCategory.title:
        return '📛 Titles';
    }
  }
}

class _ShopItemCard extends ConsumerStatefulWidget {
  final ShopItem item;
  final bool isOwned;

  const _ShopItemCard({required this.item, required this.isOwned});

  @override
  ConsumerState<_ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends ConsumerState<_ShopItemCard> {
  bool _isPurchasing = false;

  Future<void> _purchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Purchase ${widget.item.name}?'),
        content: Text(
          'This will cost ${widget.item.price} Obsidian. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPurchasing = true);

    try {
      await BackendService.purchaseShopItem(itemId: widget.item.itemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.item.name} purchased!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final isOwned = widget.isOwned;
    final wallet = ref.watch(walletProvider).valueOrNull;
    final canAfford = wallet != null && wallet.obsidian >= item.price;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOwned
            ? BorderSide(color: Colors.green.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOwned || !canAfford || _isPurchasing ? null : _purchase,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rarity badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _rarityColor(item.rarity).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.rarity.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _rarityColor(item.rarity),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isOwned)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
              const Spacer(),

              // Item icon placeholder
              Center(
                child: Icon(
                  _categoryIcon(item.category),
                  size: 48,
                  color: _rarityColor(item.rarity).withOpacity(0.7),
                ),
              ),
              const Spacer(),

              // Name
              Text(
                item.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Description
              Text(
                item.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Price / Owned
              if (isOwned)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OWNED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.diamond,
                      size: 16,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: canAfford
                            ? Colors.deepPurple
                            : theme.colorScheme.error,
                      ),
                    ),
                    if (_isPurchasing) ...[
                      const Spacer(),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rarityColor(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return Colors.grey;
      case ItemRarity.uncommon:
        return Colors.green;
      case ItemRarity.rare:
        return Colors.blue;
      case ItemRarity.legendary:
        return Colors.orange;
    }
  }

  IconData _categoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.theme:
        return Icons.palette;
      case ItemCategory.icon:
        return Icons.auto_awesome;
      case ItemCategory.badge:
        return Icons.military_tech;
      case ItemCategory.title:
        return Icons.title;
    }
  }
}
