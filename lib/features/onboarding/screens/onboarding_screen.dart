import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/screen_time_service.dart';
import '../../../app/router.dart';

/// Three-page onboarding flow: Welcome → How It Works → Screen Time Permission
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      // Invalidate the onboarding provider to trigger re-evaluation
      ref.invalidate(onboardingCompleteProvider);
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _WelcomePage(theme: theme),
                  _HowItWorksPage(theme: theme),
                  _ScreenTimePermissionPage(
                    theme: theme,
                    onComplete: _completeOnboarding,
                  ),
                ],
              ),
            ),

            // Page indicator + next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page dots
                  Row(
                    children: List.generate(3, (index) {
                      return Container(
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started button
                  if (_currentPage < 2)
                    FilledButton(
                      onPressed: _nextPage,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Next'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 1: Welcome
class _WelcomePage extends StatelessWidget {
  final ThemeData theme;

  const _WelcomePage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 80,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome to\nFocusPledge',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Put real skin in the game. Pledge credits, stay focused, and build lasting discipline through accountability.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Page 2: How It Works
class _HowItWorksPage extends StatelessWidget {
  final ThemeData theme;

  const _HowItWorksPage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How It Works',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _StepTile(
            theme: theme,
            icon: Icons.lock_outline,
            title: 'Pledge Credits',
            description:
                'Choose how many Focus Credits to stake and how long to stay focused.',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          _StepTile(
            theme: theme,
            icon: Icons.phone_locked,
            title: 'Block Distractions',
            description:
                'Screen Time blocks your chosen apps. Stay off them to succeed.',
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 20),
          _StepTile(
            theme: theme,
            icon: Icons.emoji_events_outlined,
            title: 'Earn or Burn',
            description:
                'Succeed → get credits back. Fail → credits become Ash. Redeem Ash into Obsidian for shop rewards.',
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _StepTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 3: Screen Time Permission
class _ScreenTimePermissionPage extends StatefulWidget {
  final ThemeData theme;
  final VoidCallback onComplete;

  const _ScreenTimePermissionPage({
    required this.theme,
    required this.onComplete,
  });

  @override
  State<_ScreenTimePermissionPage> createState() =>
      _ScreenTimePermissionPageState();
}

class _ScreenTimePermissionPageState extends State<_ScreenTimePermissionPage> {
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  String _permissionStatus = 'notDetermined';
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await _screenTimeService.getAuthorizationStatus();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);
    final granted = await _screenTimeService.requestAuthorization();
    if (mounted) {
      setState(() {
        _permissionStatus = granted ? 'approved' : 'denied';
        _isRequesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isGranted = _permissionStatus == 'approved';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withOpacity(0.1)
                  : theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle : Icons.phone_locked,
              size: 64,
              color: isGranted
                  ? Colors.green
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Screen Time Access',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isGranted
                ? 'Screen Time access granted! You\'re ready to start pledging.'
                : 'FocusPledge uses Screen Time to block distracting apps during your pledge sessions. This is what gives your pledge real teeth.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (!isGranted)
            FilledButton.icon(
              onPressed: _isRequesting ? null : _requestPermission,
              icon: _isRequesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.security),
              label: const Text('Enable Screen Time'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Get Started / Continue button
          SizedBox(
            width: double.infinity,
            child: isGranted
                ? FilledButton(
                    onPressed: widget.onComplete,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Get Started'),
                  )
                : TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Continue without Screen Time'),
                  ),
          ),
        ],
      ),
    );
  }
}
