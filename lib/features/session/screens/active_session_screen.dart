import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/session.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../services/backend_service.dart';
import '../../../services/screen_time_service.dart';

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
  Timer? _failurePollTimer;
  Duration? _remainingTime;
  bool _isResolvingFailure = false;
  final ScreenTimeService _screenTimeService = ScreenTimeService();

  @override
  void initState() {
    super.initState();
    // Start heartbeat timer (send every 30 seconds)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
    // Start native failure polling timer (check every 5 seconds)
    _failurePollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollForFailure(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _failurePollTimer?.cancel();
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

  /// Poll the native side for session failure flags set by the DeviceActivity extension
  Future<void> _pollForFailure() async {
    if (_isResolvingFailure) return;

    try {
      final status = await _screenTimeService.checkSessionStatus(
        sessionId: widget.sessionId,
      );

      if (status['failed'] == true && mounted) {
        debugPrint('⚠️ Native failure detected: ${status['reason']}');
        _isResolvingFailure = true;
        _failurePollTimer?.cancel();

        try {
          await BackendService.resolveSession(
            sessionId: widget.sessionId,
            resolution: 'FAILURE',
            reason: status['reason'] as String? ?? 'app_opened',
            nativeEvidence: {
              'source': 'device_activity_monitor',
              'reason': status['reason'],
              'detectedAt': DateTime.now().toIso8601String(),
            },
          );
          debugPrint('✅ Session resolved as FAILURE on backend');
        } catch (e) {
          debugPrint('Error resolving failed session: $e');
          // The Firestore stream will still pick up the failure if backend eventually processes it
        }

        // Stop native session (remove shields)
        try {
          await _screenTimeService.stopSession(sessionId: widget.sessionId);
        } catch (e) {
          debugPrint('Error stopping native session: $e');
        }
      }
    } catch (e) {
      // Platform channel may fail on simulator - silently ignore
      debugPrint('Failure poll error: $e');
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
        _failurePollTimer?.cancel();
        _heartbeatTimer?.cancel();
        // Proactively stop native session when timer expires
        _screenTimeService.stopSession(sessionId: widget.sessionId).catchError((
          e,
        ) {
          debugPrint('Error stopping native session on timer expiry: $e');
          return false;
        });
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

class _CompletionScreen extends ConsumerStatefulWidget {
  final Session session;

  const _CompletionScreen({required this.session});

  @override
  ConsumerState<_CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<_CompletionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _contentController;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  Timer? _redemptionTimer;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );

    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentController.forward();
    });

    // Start redemption countdown timer for failures
    if (widget.session.isFailed) {
      _redemptionTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateRedemptionCountdown(),
      );
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
    _redemptionTimer?.cancel();
    super.dispose();
  }

  void _updateRedemptionCountdown() {
    // Trigger rebuild so consumer re-reads the provider
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final isSuccess = session.isCompleted;
    final redemptionExpiry = ref.watch(redemptionExpiryProvider).valueOrNull;

    // Calculate redemption remaining
    Duration? redemptionLeft;
    if (!isSuccess && redemptionExpiry != null) {
      final now = DateTime.now();
      if (now.isBefore(redemptionExpiry)) {
        redemptionLeft = redemptionExpiry.difference(now);
      }
    }

    final ashEarned = session.pledgeAmount; // 1:1 policy
    final frozenVotes = session.pledgeAmount; // 1:1 policy

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Animated icon
            ScaleTransition(
              scale: _iconScale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isSuccess ? Colors.green : Colors.red).withOpacity(
                    0.1,
                  ),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 100,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            FadeTransition(
              opacity: _contentFade,
              child: Text(
                isSuccess ? 'Session Complete!' : 'Session Failed',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            FadeTransition(
              opacity: _contentFade,
              child: Text(
                isSuccess
                    ? 'Great focus! Your credits have been returned.'
                    : 'Your credits have been converted to Ash.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Results card
            FadeTransition(
              opacity: _contentFade,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _ResultRow(
                        label: 'Pledged',
                        value: '${session.pledgeAmount} FC',
                        icon: Icons.stars,
                        iconColor: theme.colorScheme.primary,
                      ),
                      const Divider(height: 24),
                      _ResultRow(
                        label: 'Duration',
                        value: '${session.durationMinutes} min',
                        icon: Icons.timer_outlined,
                        iconColor: theme.colorScheme.secondary,
                      ),
                      const Divider(height: 24),
                      _ResultRow(
                        label: 'Outcome',
                        value: isSuccess ? 'Success' : 'Failure',
                        valueColor: isSuccess ? Colors.green : Colors.red,
                        icon: isSuccess
                            ? Icons.emoji_events
                            : Icons.warning_amber,
                        iconColor: isSuccess ? Colors.green : Colors.red,
                      ),
                      if (isSuccess) ...[
                        const Divider(height: 24),
                        _ResultRow(
                          label: 'Credits Returned',
                          value: '${session.pledgeAmount} FC',
                          icon: Icons.keyboard_return,
                          iconColor: Colors.green,
                          valueColor: Colors.green,
                        ),
                      ],
                      if (!isSuccess) ...[
                        const Divider(height: 24),
                        _ResultRow(
                          label: 'Ash Earned',
                          value: '$ashEarned',
                          icon: Icons.local_fire_department,
                          iconColor: Colors.grey,
                        ),
                        const Divider(height: 24),
                        _ResultRow(
                          label: 'Frozen Votes',
                          value: '+$frozenVotes',
                          icon: Icons.ac_unit,
                          iconColor: Colors.blue,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Redemption countdown for failures
            if (!isSuccess && redemptionLeft != null) ...[
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _contentFade,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.errorContainer,
                        theme.colorScheme.errorContainer.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        color: theme.colorScheme.onErrorContainer,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Redemption Window',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCountdown(redemptionLeft),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete a Redemption Session to rescue your Frozen Votes and convert Ash → Obsidian',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withOpacity(
                            0.8,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action buttons
            FadeTransition(
              opacity: _contentFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isSuccess && redemptionLeft != null)
                    ElevatedButton.icon(
                      onPressed: () => context.go('/session/redemption-setup'),
                      icon: const Icon(Icons.restore),
                      label: const Text('Start Redemption Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (!isSuccess && redemptionLeft != null)
                    const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/wallet'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Return to Wallet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
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
    );
  }
}
