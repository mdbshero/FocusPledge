import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pledge/models/shop_item.dart';

void main() {
  group('ItemRarity', () {
    test('toFirestore returns uppercase name', () {
      expect(ItemRarity.common.toFirestore(), 'COMMON');
      expect(ItemRarity.uncommon.toFirestore(), 'UNCOMMON');
      expect(ItemRarity.rare.toFirestore(), 'RARE');
      expect(ItemRarity.legendary.toFirestore(), 'LEGENDARY');
    });

    test('fromFirestore parses valid values', () {
      expect(ItemRarity.fromFirestore('COMMON'), ItemRarity.common);
      expect(ItemRarity.fromFirestore('UNCOMMON'), ItemRarity.uncommon);
      expect(ItemRarity.fromFirestore('RARE'), ItemRarity.rare);
      expect(ItemRarity.fromFirestore('LEGENDARY'), ItemRarity.legendary);
    });

    test('fromFirestore defaults to common for unknown', () {
      expect(ItemRarity.fromFirestore('UNKNOWN'), ItemRarity.common);
      expect(ItemRarity.fromFirestore(''), ItemRarity.common);
    });

    test('roundtrips correctly', () {
      for (final rarity in ItemRarity.values) {
        expect(ItemRarity.fromFirestore(rarity.toFirestore()), rarity);
      }
    });
  });

  group('ItemCategory', () {
    test('toFirestore returns uppercase name', () {
      expect(ItemCategory.theme.toFirestore(), 'THEME');
      expect(ItemCategory.icon.toFirestore(), 'ICON');
      expect(ItemCategory.badge.toFirestore(), 'BADGE');
      expect(ItemCategory.title.toFirestore(), 'TITLE');
    });

    test('fromFirestore parses valid values', () {
      expect(ItemCategory.fromFirestore('THEME'), ItemCategory.theme);
      expect(ItemCategory.fromFirestore('ICON'), ItemCategory.icon);
      expect(ItemCategory.fromFirestore('BADGE'), ItemCategory.badge);
      expect(ItemCategory.fromFirestore('TITLE'), ItemCategory.title);
    });

    test('fromFirestore defaults to theme for unknown', () {
      expect(ItemCategory.fromFirestore('UNKNOWN'), ItemCategory.theme);
      expect(ItemCategory.fromFirestore(''), ItemCategory.theme);
    });

    test('roundtrips correctly', () {
      for (final category in ItemCategory.values) {
        expect(ItemCategory.fromFirestore(category.toFirestore()), category);
      }
    });
  });

  group('ShopItem', () {
    test('constructor creates item with required fields', () {
      const item = ShopItem(
        itemId: 'item-1',
        name: 'Dark Theme',
        description: 'A sleek dark theme',
        price: 50,
        rarity: ItemRarity.uncommon,
        category: ItemCategory.theme,
      );

      expect(item.itemId, 'item-1');
      expect(item.name, 'Dark Theme');
      expect(item.description, 'A sleek dark theme');
      expect(item.price, 50);
      expect(item.rarity, ItemRarity.uncommon);
      expect(item.category, ItemCategory.theme);
      expect(item.imageUrl, isNull);
      expect(item.isAvailable, true);
    });

    test('constructor with optional fields', () {
      const item = ShopItem(
        itemId: 'item-2',
        name: 'Gold Badge',
        description: 'A shiny badge',
        price: 200,
        rarity: ItemRarity.legendary,
        category: ItemCategory.badge,
        imageUrl: 'https://example.com/badge.png',
        isAvailable: false,
      );

      expect(item.imageUrl, 'https://example.com/badge.png');
      expect(item.isAvailable, false);
    });
  });

  group('ShopPurchase', () {
    test('constructor creates purchase with all fields', () {
      final purchase = ShopPurchase(
        purchaseId: 'purchase-1',
        userId: 'user-1',
        itemId: 'item-1',
        itemName: 'Dark Theme',
        pricePaid: 50,
        purchasedAt: DateTime(2025, 1, 15, 10, 30),
      );

      expect(purchase.purchaseId, 'purchase-1');
      expect(purchase.userId, 'user-1');
      expect(purchase.itemId, 'item-1');
      expect(purchase.itemName, 'Dark Theme');
      expect(purchase.pricePaid, 50);
      expect(purchase.purchasedAt, DateTime(2025, 1, 15, 10, 30));
    });
  });
}
