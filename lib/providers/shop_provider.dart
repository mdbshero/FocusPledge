import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_item.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// Provides the shop catalog (all available items)
final shopCatalogProvider = StreamProvider<List<ShopItem>>((ref) {
  return FirebaseService.firestore
      .collection('shop')
      .doc('catalog')
      .collection('items')
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => ShopItem.fromFirestore(doc)).toList()
              ..sort((a, b) => a.price.compareTo(b.price)),
      );
});

/// Provides the current user's purchases (owned items)
final userPurchasesProvider = StreamProvider<List<ShopPurchase>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return FirebaseService.firestore
      .collection('shop')
      .doc('purchases')
      .collection('records')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ShopPurchase.fromFirestore(doc))
            .toList(),
      );
});

/// Provides a Set of item IDs the user already owns for quick lookup
final ownedItemIdsProvider = Provider<Set<String>>((ref) {
  final purchases = ref.watch(userPurchasesProvider).valueOrNull ?? [];
  return purchases.map((p) => p.itemId).toSet();
});
