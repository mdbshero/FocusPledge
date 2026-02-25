import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/wallet/screens/wallet_screen.dart';
import '../features/wallet/screens/buy_credits_screen.dart';
import '../features/wallet/screens/transaction_history_screen.dart';
import '../features/session/screens/session_setup_screen.dart';
import '../features/session/screens/active_session_screen.dart';
import '../features/session/screens/redemption_setup_screen.dart';
import '../features/session/screens/session_history_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/privacy_policy_screen.dart';
import '../features/settings/screens/terms_of_service_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

/// Tracks whether onboarding has been completed
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});

/// Application routing configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: '/sign-in',
    observers: [AnalyticsService.observer],
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isOnSignIn = state.matchedLocation == '/sign-in';
      final isOnOnboarding = state.matchedLocation == '/onboarding';
      final hasCompletedOnboarding = onboardingComplete.value ?? false;

      // Redirect unauthenticated users to sign-in
      if (!isAuthenticated && !isOnSignIn) {
        return '/sign-in';
      }

      // Redirect authenticated users away from sign-in
      if (isAuthenticated && isOnSignIn) {
        // Check if onboarding is needed
        if (!hasCompletedOnboarding) {
          return '/onboarding';
        }
        return '/dashboard';
      }

      // If authenticated, done onboarding, but on onboarding screen — redirect
      if (isAuthenticated && isOnOnboarding && hasCompletedOnboarding) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Auth (outside shell)
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),

      // Onboarding (outside shell)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main app shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard / Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Wallet & Sessions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                name: 'wallet',
                builder: (context, state) => const WalletScreen(),
                routes: [
                  GoRoute(
                    path: 'buy-credits',
                    name: 'buy-credits',
                    builder: (context, state) => const BuyCreditsScreen(),
                  ),
                  GoRoute(
                    path: 'session/setup',
                    name: 'session-setup',
                    builder: (context, state) => const SessionSetupScreen(),
                  ),
                  GoRoute(
                    path: 'session/active/:sessionId',
                    name: 'active-session',
                    builder: (context, state) {
                      final sessionId = state.pathParameters['sessionId']!;
                      return ActiveSessionScreen(sessionId: sessionId);
                    },
                  ),
                  GoRoute(
                    path: 'session/redemption-setup',
                    name: 'redemption-setup',
                    builder: (context, state) => const RedemptionSetupScreen(),
                  ),
                  GoRoute(
                    path: 'session/history',
                    name: 'session-history',
                    builder: (context, state) =>
                        const SessionHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'transactions',
                    name: 'transactions',
                    builder: (context, state) =>
                        const TransactionHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Shop
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                name: 'shop',
                builder: (context, state) => const ShopScreen(),
              ),
            ],
          ),

          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy-policy',
                    name: 'privacy-policy',
                    builder: (context, state) =>
                        const PrivacyPolicyScreen(),
                  ),
                  GoRoute(
                    path: 'terms-of-service',
                    name: 'terms-of-service',
                    builder: (context, state) =>
                        const TermsOfServiceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
