import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/wallet/screens/wallet_screen.dart';
import '../features/wallet/screens/buy_credits_screen.dart';
import '../features/session/screens/session_setup_screen.dart';
import '../features/session/screens/active_session_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../providers/auth_provider.dart';

/// Application routing configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/sign-in',
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isOnSignIn = state.matchedLocation == '/sign-in';

      // Redirect unauthenticated users to sign-in
      if (!isAuthenticated && !isOnSignIn) {
        return '/sign-in';
      }

      // Redirect authenticated users away from sign-in
      if (isAuthenticated && isOnSignIn) {
        return '/wallet';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/buy-credits',
        name: 'buy-credits',
        builder: (context, state) => const BuyCreditsScreen(),
      ),
      GoRoute(
        path: '/session/setup',
        name: 'session-setup',
        builder: (context, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: '/session/active/:sessionId',
        name: 'active-session',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return ActiveSessionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/shop',
        name: 'shop',
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
