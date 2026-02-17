import 'package:cloud_firestore/cloud_firestore.dart';

/// Shop item rarity tiers
enum ItemRarity {
  common,
  uncommon,
  rare,
  legendary;

  String toFirestore() => name.toUpperCase();

  static ItemRarity fromFirestore(String value) {
    return ItemRarity.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => ItemRarity.common,
    );
  }
}

/// Shop item categories
enum ItemCategory {
  theme,
  icon,
  badge,
  title;

  String toFirestore() => name.toUpperCase();

  static ItemCategory fromFirestore(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => ItemCategory.theme,
    );
  }
}

/// A purchasable item in the shop catalog
class ShopItem {
  final String itemId;
  final String name;
  final String description;
  final int price; // in Obsidian
  final ItemRarity rarity;
  final ItemCategory category;
  final String? imageUrl;
  final bool isAvailable;

  const ShopItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.rarity,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory ShopItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopItem(
      itemId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: data['price'] as int? ?? 0,
      rarity: ItemRarity.fromFirestore(data['rarity'] as String? ?? 'COMMON'),
      category: ItemCategory.fromFirestore(
        data['category'] as String? ?? 'THEME',
      ),
      imageUrl: data['imageUrl'] as String?,
      isAvailable: data['isAvailable'] as bool? ?? true,
    );
  }
}

/// A record of a user's purchase
class ShopPurchase {
  final String purchaseId;
  final String userId;
  final String itemId;
  final String itemName;
  final int pricePaid;
  final DateTime purchasedAt;

  const ShopPurchase({
    required this.purchaseId,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.pricePaid,
    required this.purchasedAt,
  });

  factory ShopPurchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopPurchase(
      purchaseId: doc.id,
      userId: data['userId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      pricePaid: data['pricePaid'] as int? ?? 0,
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
    );
  }
}
