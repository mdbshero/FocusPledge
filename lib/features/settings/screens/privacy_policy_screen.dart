import 'package:flutter/material.dart';

/// Displays the Privacy Policy in a scrollable view
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading('Privacy Policy'),
            _Updated('Last Updated: February 2025'),
            SizedBox(height: 16),

            _Section('Introduction'),
            _Body(
              'FocusPledge ("we," "us," or "our") is committed to protecting your privacy. '
              'This Privacy Policy explains how we collect, use, and safeguard your information '
              'when you use the FocusPledge mobile application ("the App").',
            ),

            _Section('Information We Collect'),
            _SubSection('Account Information'),
            _Body(
              'We use Sign in with Apple to create your account. We receive your Apple ID '
              'user identifier, and optionally your name and email address (if you choose to '
              'share them). We do not receive or store your Apple ID password.',
            ),
            _SubSection('Screen Time Data'),
            _Body(
              'FocusPledge uses Apple\'s Screen Time API (Family Controls / DeviceActivity frameworks) '
              'to monitor app usage during active focus sessions. This data is processed entirely on '
              'your device by the operating system. We do NOT receive, transmit, or store which specific '
              'apps you use.\n\n'
              'We record only whether you stayed focused during a session (pass/fail), session duration, '
              'and heartbeat timestamps.',
            ),
            _SubSection('Financial Information'),
            _Body(
              'Purchases are processed securely by Stripe. We do not store your credit card number or '
              'full payment details. We store only transaction identifiers, purchase amounts, and credit '
              'pack information.\n\n'
              'We track your virtual currency balances (Focus Credits, Ash, Obsidian, Frozen Votes) and '
              'transaction ledger entries for the in-app closed-loop economy.',
            ),
            _SubSection('Analytics & Crash Data'),
            _Body(
              'We collect anonymized usage analytics (screen views, feature engagement) via Firebase Analytics '
              'to improve the App. We also collect anonymous crash reports via Firebase Crashlytics to '
              'diagnose and fix bugs.',
            ),

            _Section('How We Use Your Information'),
            _Body(
              '• Provide the Service: account management, focus sessions, virtual currency balances, in-app shop.\n'
              '• Process Payments: facilitate credit purchases through Stripe.\n'
              '• Improve the App: analyze anonymized usage patterns and fix crashes.\n'
              '• Prevent Abuse: enforce session integrity and maintain economy.',
            ),

            _Section('Data Storage & Security'),
            _Body(
              '• Account and economy data are stored in Google Firebase (Firestore) with security rules.\n'
              '• All data transmission uses HTTPS/TLS encryption.\n'
              '• Payment data is handled by Stripe (PCI DSS compliant).\n'
              '• Screen Time enforcement data never leaves your device.',
            ),

            _Section('Virtual Currency Disclaimer'),
            _Body(
              'Focus Credits, Ash, Obsidian, and Frozen Votes are virtual items with no real-world monetary value. '
              'They cannot be exchanged for cash, transferred to other users, or redeemed outside the App.',
            ),

            _Section('Your Rights'),
            _Body(
              'You have the right to access, correct, and delete your personal data. '
              'Contact support@focuspledge.app to exercise these rights.',
            ),

            _Section("Children's Privacy"),
            _Body(
              'FocusPledge is not intended for children under 13. We do not knowingly collect '
              'personal information from children under 13.',
            ),

            _Section('Contact Us'),
            _Body('Email: support@focuspledge.app'),

            SizedBox(height: 32),
            _Body(
              'This privacy policy is provided as a draft for review by legal counsel before publication.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _Updated extends StatelessWidget {
  final String text;
  const _Updated(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _SubSection extends StatelessWidget {
  final String text;
  const _SubSection(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}
