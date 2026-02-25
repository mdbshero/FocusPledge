import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/screen_time_service.dart';

/// Provider for Screen Time authorization status
final screenTimeStatusProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final service = ScreenTimeService();
  return service.getAuthorizationStatus();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final screenTimeStatus = ref.watch(screenTimeStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _SectionHeader(title: 'Account', theme: theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      user?.isAnonymous == true
                          ? Icons.person_outline
                          : Icons.person,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ??
                              (user?.isAnonymous == true
                                  ? 'Guest Account'
                                  : 'FocusPledge User'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ??
                              (user?.isAnonymous == true
                                  ? 'Sign in with Apple to save progress'
                                  : 'No email'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (user?.isAnonymous == true) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.apple,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                title: Text(
                  'Link Apple Account',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Secure your progress and wallet',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer.withOpacity(
                      0.7,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                onTap: () async {
                  try {
                    final authService = ref.read(authServiceProvider);
                    await authService.signInWithApple();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Apple account linked!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to link: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Screen Time Section
          _SectionHeader(title: 'Screen Time', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_locked),
                  title: const Text('Screen Time Permission'),
                  subtitle: screenTimeStatus.when(
                    loading: () => const Text('Checking...'),
                    error: (_, __) => const Text('Unable to check'),
                    data: (status) => Text(
                      status == 'approved'
                          ? 'Authorized ✓'
                          : status == 'denied'
                          ? 'Denied — enable in iOS Settings'
                          : 'Not configured',
                      style: TextStyle(
                        color: status == 'approved'
                            ? Colors.green
                            : status == 'denied'
                            ? Colors.red
                            : null,
                      ),
                    ),
                  ),
                  trailing: screenTimeStatus.when(
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Icon(Icons.error_outline),
                    data: (status) => status == 'approved'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : FilledButton.tonal(
                            onPressed: () async {
                              final service = ScreenTimeService();
                              await service.requestAuthorization();
                              ref.invalidate(screenTimeStatusProvider);
                            },
                            child: const Text('Enable'),
                          ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('Manage Blocked Apps'),
                  subtitle: const Text(
                    'Choose which apps to block during sessions',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final service = ScreenTimeService();
                    final status = await service.getAuthorizationStatus();
                    if (status != 'approved') {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enable Screen Time permission first',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await service.presentAppPicker();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'About', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: Text(
                    '1.0.0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/settings/terms-of-service'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/settings/privacy-policy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sign Out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text(
                      'Are you sure you want to sign out? If you\'re using a guest account, your progress will be lost.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
