import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pledge/shared/widgets/error_view.dart';
import 'package:focus_pledge/shared/widgets/loading_view.dart';
import 'package:focus_pledge/shared/widgets/empty_state.dart';
import 'package:focus_pledge/shared/widgets/balance_chip.dart';
import 'package:focus_pledge/shared/widgets/section_header.dart';

/// Helper to wrap a widget in MaterialApp for testing
Widget _wrapApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ErrorView', () {
    testWidgets('displays message', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const ErrorView(message: 'Something went wrong')),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button when callback provided', (tester) async {
      var retryTapped = false;
      await tester.pumpWidget(
        _wrapApp(
          ErrorView(message: 'Error', onRetry: () => retryTapped = true),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retryTapped, isTrue);
    });

    testWidgets('hides retry button when no callback', (tester) async {
      await tester.pumpWidget(_wrapApp(const ErrorView(message: 'Error')));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('shows custom icon', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const ErrorView(message: 'No connection', icon: Icons.wifi_off),
        ),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });
  });

  group('LoadingView', () {
    testWidgets('shows progress indicator', (tester) async {
      await tester.pumpWidget(_wrapApp(const LoadingView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const LoadingView(message: 'Loading wallet...')),
      );

      expect(find.text('Loading wallet...'), findsOneWidget);
    });

    testWidgets('hides message when not provided', (tester) async {
      await tester.pumpWidget(_wrapApp(const LoadingView()));

      // Only the progress indicator should be present
      expect(find.byType(Text), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('displays icon and title', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const EmptyState(icon: Icons.inbox, title: 'No sessions yet')),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const EmptyState(
            icon: Icons.inbox,
            title: 'No sessions',
            subtitle: 'Start a pledge to begin',
          ),
        ),
      );

      expect(find.text('Start a pledge to begin'), findsOneWidget);
    });

    testWidgets('shows action button when both label and callback provided', (
      tester,
    ) async {
      var actionTapped = false;
      await tester.pumpWidget(
        _wrapApp(
          EmptyState(
            icon: Icons.inbox,
            title: 'No sessions',
            actionLabel: 'Get Started',
            onAction: () => actionTapped = true,
          ),
        ),
      );

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      expect(actionTapped, isTrue);
    });

    testWidgets('hides action when no label', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          EmptyState(icon: Icons.inbox, title: 'No sessions', onAction: () {}),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('BalanceChip', () {
    testWidgets('displays value and label in normal mode', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const BalanceChip(
            icon: Icons.stars,
            value: 100,
            label: 'Credits',
            color: Colors.amber,
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);
    });

    testWidgets('hides label in compact mode', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const BalanceChip(
            icon: Icons.stars,
            value: 100,
            label: 'Credits',
            color: Colors.amber,
            compact: true,
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.text('Credits'), findsNothing);
    });

    testWidgets('credits factory shows correct icon', (tester) async {
      await tester.pumpWidget(_wrapApp(BalanceChip.credits(50)));

      expect(find.text('50'), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);
    });

    testWidgets('ash factory shows correct icon', (tester) async {
      await tester.pumpWidget(_wrapApp(BalanceChip.ash(25)));

      expect(find.text('25'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('obsidian factory shows correct icon', (tester) async {
      await tester.pumpWidget(_wrapApp(BalanceChip.obsidian(10)));

      expect(find.text('10'), findsOneWidget);
      expect(find.byIcon(Icons.diamond), findsOneWidget);
    });

    testWidgets('frozenVotes factory shows correct icon', (tester) async {
      await tester.pumpWidget(_wrapApp(BalanceChip.frozenVotes(3)));

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('displays title', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const SectionHeader(title: 'Statistics')),
      );

      expect(find.text('Statistics'), findsOneWidget);
    });

    testWidgets('displays trailing widget', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const SectionHeader(
            title: 'Sessions',
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
      );

      expect(find.text('Sessions'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });
}
