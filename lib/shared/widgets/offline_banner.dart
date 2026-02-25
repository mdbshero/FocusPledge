import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connectivity_service.dart';

/// A banner that appears at the top of the screen when offline
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    if (connectivity == ConnectivityStatus.online) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        Icons.wifi_off,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
      content: Text(
        connectivity == ConnectivityStatus.checking
            ? 'Checking connection...'
            : 'You\'re offline. Some features may be unavailable.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      actions: [
        TextButton(
          onPressed: () {
            ref.read(connectivityProvider.notifier).recheck();
          },
          child: Text(
            'Retry',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }
}
