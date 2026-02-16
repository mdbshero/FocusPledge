import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/session.dart';
import '../../../services/firebase_service.dart';
import '../../../services/backend_service.dart';

/// Provider for active session data
final activeSessionProvider = StreamProvider.family<Session?, String>((
  ref,
  sessionId,
) {
  return FirebaseService.firestore
      .collection('sessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return Session.fromFirestore(doc);
      });
});

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Timer? _timer;
  Timer? _heartbeatTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    // Start heartbeat timer (send every 30 seconds)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendHeartbeat() async {
    try {
      await BackendService.heartbeatSession(sessionId: widget.sessionId);
    } catch (e) {
      // Silently fail - backend scheduler will handle missing heartbeats
      debugPrint('Heartbeat failed: $e');
    }
  }

  void _startTimer(Session session) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remaining = session.remainingTime;
      setState(() {
        _remainingTime = remaining;
      });

      if (remaining == Duration.zero) {
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(activeSessionProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Session'),
        automaticallyImplyLeading: false,
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/wallet'),
                child: const Text('Return to Wallet'),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text('Session not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/wallet'),
                    child: const Text('Return to Wallet'),
                  ),
                ],
              ),
            );
          }

          // Start timer if session is active
          if (session.isActive && _timer == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startTimer(session);
            });
          }

          // Show completion screen if settled
          if (session.isCompleted || session.isFailed) {
            return _CompletionScreen(session: session);
          }

          // Active session "Pulse" view
          final remaining = _remainingTime ?? session.remainingTime;
          final progress =
              1.0 - (remaining.inSeconds / (session.durationMinutes * 60));

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),

                  // Countdown Circle
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(remaining),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'remaining',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Session Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pledged',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              Text(
                                '${session.pledgeAmount} FC',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Distractions are blocked. Opening blocked apps will end this session in failure.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  final Session session;

  const _CompletionScreen({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = session.isCompleted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 120,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              isSuccess ? 'Success!' : 'Session Failed',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            if (isSuccess)
              Text(
                'Credits returned and Impact Points earned!',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Credits converted to Ash. Complete a Redemption Session within 24h.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultRow(
                      label: 'Pledged Amount',
                      value: '${session.pledgeAmount} FC',
                    ),
                    const Divider(),
                    _ResultRow(
                      label: 'Duration',
                      value: '${session.durationMinutes} min',
                    ),
                    const Divider(),
                    _ResultRow(
                      label: 'Outcome',
                      value: isSuccess ? 'Success' : 'Failure',
                      valueColor: isSuccess ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/wallet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Return to Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
