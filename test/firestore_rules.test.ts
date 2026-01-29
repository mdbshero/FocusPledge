import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'focuspledge-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

describe('Firestore Security Rules', () => {
  describe('Users Collection', () => {
    const userId = 'user123';
    const userDoc = {
      uid: userId,
      wallet: {
        credits: 0,
        ash: 0,
        obsidian: 0,
        purgatoryVotes: 0,
        lifetimePurchased: 0,
      },
      deadlines: {},
      status: {},
    };

    test('authenticated user can read their own user document', async () => {
      const context = testEnv.authenticatedContext(userId);
      
      // Seed data with admin
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', userId), userDoc);
      });

      // User can read their own doc
      await assertSucceeds(
        getDoc(doc(context.firestore(), 'users', userId))
      );
    });

    test('user cannot read another user document', async () => {
      const context = testEnv.authenticatedContext(userId);
      const otherUserId = 'user456';

      // Seed data with admin
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', otherUserId), {
          ...userDoc,
          uid: otherUserId,
        });
      });

      // User cannot read other user's doc
      await assertFails(
        getDoc(doc(context.firestore(), 'users', otherUserId))
      );
    });

    test('user can create their own document with zero balances', async () => {
      const context = testEnv.authenticatedContext(userId);

      await assertSucceeds(
        setDoc(doc(context.firestore(), 'users', userId), userDoc)
      );
    });

    test('user cannot create document with non-zero balance', async () => {
      const context = testEnv.authenticatedContext(userId);

      await assertFails(
        setDoc(doc(context.firestore(), 'users', userId), {
          ...userDoc,
          wallet: { ...userDoc.wallet, credits: 100 },
        })
      );
    });

    test('user cannot modify wallet balances', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', userId), userDoc);
      });

      // Attempt to modify wallet
      await assertFails(
        updateDoc(doc(context.firestore(), 'users', userId), {
          'wallet.credits': 500,
        })
      );
    });

    test('user cannot modify deadlines', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', userId), userDoc);
      });

      // Attempt to modify deadlines
      await assertFails(
        updateDoc(doc(context.firestore(), 'users', userId), {
          'deadlines.redemptionExpiry': new Date(),
        })
      );
    });

    test('user can update non-protected fields', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', userId), userDoc);
      });

      // Update status (allowed)
      await assertSucceeds(
        updateDoc(doc(context.firestore(), 'users', userId), {
          'status.currentTheme': 'midnight_matte',
        })
      );
    });

    test('user cannot delete their document', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', userId), userDoc);
      });

      await assertFails(
        deleteDoc(doc(context.firestore(), 'users', userId))
      );
    });
  });

  describe('Sessions Collection', () => {
    const userId = 'user123';
    const sessionId = 'session456';
    const sessionDoc = {
      sessionId,
      userId,
      type: 'PLEDGE',
      status: 'ACTIVE',
      pledgeAmount: 500,
      durationMinutes: 60,
      startTime: new Date(),
      native: {
        lastCheckedAt: new Date(),
        failureFlag: false,
      },
      settlement: {},
    };

    test('user can read their own sessions', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc);
      });

      await assertSucceeds(
        getDoc(doc(context.firestore(), 'sessions', sessionId))
      );
    });

    test('user cannot read other user sessions', async () => {
      const context = testEnv.authenticatedContext('otherUser');

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc);
      });

      await assertFails(
        getDoc(doc(context.firestore(), 'sessions', sessionId))
      );
    });

    test('user cannot create sessions directly', async () => {
      const context = testEnv.authenticatedContext(userId);

      await assertFails(
        setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc)
      );
    });

    test('user can update native.lastCheckedAt only', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc);
      });

      // Update heartbeat (allowed)
      await assertSucceeds(
        updateDoc(doc(context.firestore(), 'sessions', sessionId), {
          'native.lastCheckedAt': new Date(),
        })
      );
    });

    test('user cannot update session status', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc);
      });

      await assertFails(
        updateDoc(doc(context.firestore(), 'sessions', sessionId), {
          status: 'COMPLETED',
        })
      );
    });

    test('user cannot update settlement fields', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'sessions', sessionId), sessionDoc);
      });

      await assertFails(
        updateDoc(doc(context.firestore(), 'sessions', sessionId), {
          'settlement.resolvedAt': new Date(),
        })
      );
    });
  });

  describe('Ledger Collection', () => {
    const userId = 'user123';
    const entryId = 'entry456';
    const ledgerEntry = {
      entryId,
      userId,
      kind: 'credits_purchase',
      amount: 1000,
      metadata: { packId: 'standard' },
      createdAt: new Date(),
      idempotencyKey: 'test_key',
    };

    test('user can read their own ledger entries', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'ledger', entryId), ledgerEntry);
      });

      await assertSucceeds(
        getDoc(doc(context.firestore(), 'ledger', entryId))
      );
    });

    test('user cannot read other user ledger entries', async () => {
      const context = testEnv.authenticatedContext('otherUser');

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'ledger', entryId), ledgerEntry);
      });

      await assertFails(
        getDoc(doc(context.firestore(), 'ledger', entryId))
      );
    });

    test('user cannot create ledger entries', async () => {
      const context = testEnv.authenticatedContext(userId);

      await assertFails(
        setDoc(doc(context.firestore(), 'ledger', entryId), ledgerEntry)
      );
    });

    test('user cannot modify ledger entries', async () => {
      const context = testEnv.authenticatedContext(userId);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'ledger', entryId), ledgerEntry);
      });

      await assertFails(
        updateDoc(doc(context.firestore(), 'ledger', entryId), {
          amount: 2000,
        })
      );
    });
  });

  describe('Shop Collections', () => {
    test('anyone can read catalog', async () => {
      const context = testEnv.authenticatedContext('user123');

      // Seed catalog item
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'shop/catalog/item1'), {
          name: 'Midnight Theme',
          price: 100,
          currency: 'obsidian',
        });
      });

      await assertSucceeds(
        getDoc(doc(context.firestore(), 'shop/catalog/item1'))
      );
    });

    test('user cannot modify catalog', async () => {
      const context = testEnv.authenticatedContext('user123');

      await assertFails(
        setDoc(doc(context.firestore(), 'shop/catalog/item1'), {
          name: 'Fake Item',
          price: 1,
        })
      );
    });

    test('user can read their own purchases', async () => {
      const userId = 'user123';
      const context = testEnv.authenticatedContext(userId);

      // Seed purchase
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'shop/purchases/purchase1'), {
          userId,
          itemId: 'item1',
          purchasedAt: new Date(),
        });
      });

      await assertSucceeds(
        getDoc(doc(context.firestore(), 'shop/purchases/purchase1'))
      );
    });

    test('user cannot create purchases directly', async () => {
      const context = testEnv.authenticatedContext('user123');

      await assertFails(
        setDoc(doc(context.firestore(), 'shop/purchases/purchase1'), {
          userId: 'user123',
          itemId: 'item1',
        })
      );
    });
  });
});
