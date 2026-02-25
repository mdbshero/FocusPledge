import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pledge/models/wallet.dart';

void main() {
  group('Wallet', () {
    test('constructor creates wallet with required fields', () {
      const wallet = Wallet(
        credits: 100,
        ash: 50,
        obsidian: 25,
        purgatoryVotes: 3,
        lifetimePurchased: 200,
      );

      expect(wallet.credits, 100);
      expect(wallet.ash, 50);
      expect(wallet.obsidian, 25);
      expect(wallet.purgatoryVotes, 3);
      expect(wallet.lifetimePurchased, 200);
    });

    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'credits': 100,
          'ash': 50,
          'obsidian': 25,
          'purgatoryVotes': 3,
          'lifetimePurchased': 200,
        };

        final wallet = Wallet.fromJson(json);

        expect(wallet.credits, 100);
        expect(wallet.ash, 50);
        expect(wallet.obsidian, 25);
        expect(wallet.purgatoryVotes, 3);
        expect(wallet.lifetimePurchased, 200);
      });

      test('defaults missing fields to 0', () {
        final wallet = Wallet.fromJson({});

        expect(wallet.credits, 0);
        expect(wallet.ash, 0);
        expect(wallet.obsidian, 0);
        expect(wallet.purgatoryVotes, 0);
        expect(wallet.lifetimePurchased, 0);
      });

      test('defaults null fields to 0', () {
        final json = {
          'credits': null,
          'ash': null,
          'obsidian': null,
          'purgatoryVotes': null,
          'lifetimePurchased': null,
        };

        final wallet = Wallet.fromJson(json);

        expect(wallet.credits, 0);
        expect(wallet.ash, 0);
        expect(wallet.obsidian, 0);
        expect(wallet.purgatoryVotes, 0);
        expect(wallet.lifetimePurchased, 0);
      });

      test('handles partial JSON', () {
        final json = {'credits': 42, 'ash': 10};
        final wallet = Wallet.fromJson(json);

        expect(wallet.credits, 42);
        expect(wallet.ash, 10);
        expect(wallet.obsidian, 0);
        expect(wallet.purgatoryVotes, 0);
        expect(wallet.lifetimePurchased, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const wallet = Wallet(
          credits: 100,
          ash: 50,
          obsidian: 25,
          purgatoryVotes: 3,
          lifetimePurchased: 200,
        );

        final json = wallet.toJson();

        expect(json, {
          'credits': 100,
          'ash': 50,
          'obsidian': 25,
          'purgatoryVotes': 3,
          'lifetimePurchased': 200,
        });
      });

      test('roundtrips correctly', () {
        const original = Wallet(
          credits: 42,
          ash: 7,
          obsidian: 3,
          purgatoryVotes: 1,
          lifetimePurchased: 50,
        );

        final restored = Wallet.fromJson(original.toJson());

        expect(restored.credits, original.credits);
        expect(restored.ash, original.ash);
        expect(restored.obsidian, original.obsidian);
        expect(restored.purgatoryVotes, original.purgatoryVotes);
        expect(restored.lifetimePurchased, original.lifetimePurchased);
      });
    });

    group('copyWith', () {
      const wallet = Wallet(
        credits: 100,
        ash: 50,
        obsidian: 25,
        purgatoryVotes: 3,
        lifetimePurchased: 200,
      );

      test('copies with updated credits', () {
        final updated = wallet.copyWith(credits: 150);
        expect(updated.credits, 150);
        expect(updated.ash, 50);
        expect(updated.obsidian, 25);
        expect(updated.purgatoryVotes, 3);
        expect(updated.lifetimePurchased, 200);
      });

      test('copies with updated ash', () {
        final updated = wallet.copyWith(ash: 75);
        expect(updated.credits, 100);
        expect(updated.ash, 75);
      });

      test('copies with updated obsidian', () {
        final updated = wallet.copyWith(obsidian: 99);
        expect(updated.obsidian, 99);
      });

      test('copies with updated purgatoryVotes', () {
        final updated = wallet.copyWith(purgatoryVotes: 10);
        expect(updated.purgatoryVotes, 10);
      });

      test('copies with updated lifetimePurchased', () {
        final updated = wallet.copyWith(lifetimePurchased: 500);
        expect(updated.lifetimePurchased, 500);
      });

      test('copies with no changes returns equal wallet', () {
        final updated = wallet.copyWith();
        expect(updated.credits, wallet.credits);
        expect(updated.ash, wallet.ash);
        expect(updated.obsidian, wallet.obsidian);
        expect(updated.purgatoryVotes, wallet.purgatoryVotes);
        expect(updated.lifetimePurchased, wallet.lifetimePurchased);
      });

      test('copies with multiple fields', () {
        final updated = wallet.copyWith(credits: 0, ash: 100, obsidian: 50);
        expect(updated.credits, 0);
        expect(updated.ash, 100);
        expect(updated.obsidian, 50);
        expect(updated.purgatoryVotes, 3);
        expect(updated.lifetimePurchased, 200);
      });
    });
  });
}
