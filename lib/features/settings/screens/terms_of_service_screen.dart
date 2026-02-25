import 'package:flutter/material.dart';

/// Displays the Terms of Service in a scrollable view
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading('Terms of Service'),
            _Updated('Last Updated: February 2025'),
            SizedBox(height: 16),

            _Section('1. Acceptance of Terms'),
            _Body(
              'By downloading, installing, or using the FocusPledge application ("the App"), '
              'you agree to be bound by these Terms of Service. If you do not agree, do not use the App.',
            ),

            _Section('2. Description of Service'),
            _Body(
              'FocusPledge is a focus and productivity application that uses a skill-based closed-loop '
              'virtual economy to incentivize screen time management. Users pledge virtual currency '
              '(Focus Credits) on focus sessions, and the outcome depends on whether they successfully '
              'avoid distraction during the session.',
            ),

            _Section('3. Eligibility'),
            _Body('You must be at least 13 years of age to use the App.'),

            _Section('4. Virtual Currency & Economy'),
            _Body(
              'Focus Credits are virtual items purchased with real money through Stripe. '
              'All purchases are final and non-refundable except as required by applicable law.\n\n'
              'The App operates a closed-loop virtual economy:\n'
              '• Focus Credits — purchased with real money, pledged on sessions\n'
              '• Ash — earned when a session fails\n'
              '• Obsidian — converted from Ash via redemption sessions\n'
              '• Frozen Votes — created on failure, must be redeemed within 24 hours\n\n'
              'IMPORTANT: Virtual currencies have NO real-world monetary value. They cannot be '
              'exchanged for cash, transferred between users, or redeemed outside the App.',
            ),

            _Section('5. Skill-Based System'),
            _Body(
              'Session outcomes are determined entirely by your behavior. This is a skill-based system, '
              'not a game of chance. You have full control over whether you succeed or fail.',
            ),

            _Section('6. Session Rules'),
            _Body(
              '• Sessions are enforced using Apple\'s Screen Time / Family Controls API.\n'
              '• A session fails if you use blocked apps or the heartbeat is lost.\n'
              '• Session resolution is performed server-side and is final.\n'
              '• Attempting to circumvent monitoring may result in automatic failure.',
            ),

            _Section('7. Payments & Refunds'),
            _Body(
              'All real-money transactions are processed by Stripe. Refund requests should be directed '
              'to Apple through the App Store, or by contacting us.',
            ),

            _Section('8. Prohibited Conduct'),
            _Body(
              '• Attempting to manipulate or exploit the virtual economy\n'
              '• Using automated tools, bots, or scripts\n'
              '• Reverse-engineering or decompiling the App\n'
              '• Interfering with security features\n'
              '• Using the App for any illegal purpose',
            ),

            _Section('9. Disclaimer of Warranties'),
            _Body(
              'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, '
              'EITHER EXPRESS OR IMPLIED.',
            ),

            _Section('10. Limitation of Liability'),
            _Body(
              'To the maximum extent permitted by law, FocusPledge shall not be liable for any indirect, '
              'incidental, special, consequential, or punitive damages. Our total liability shall not exceed '
              'the amount you paid us in the twelve months preceding the claim.',
            ),

            _Section('11. Termination'),
            _Body(
              'You may stop using the App at any time and request account deletion. '
              'We may suspend or terminate your account for violation of these Terms. '
              'Upon termination, all virtual currency balances are forfeited.',
            ),

            _Section('12. Governing Law'),
            _Body(
              'These Terms shall be governed by the laws of the State of California, United States.',
            ),

            _Section('13. Contact Information'),
            _Body('Email: support@focuspledge.app'),

            SizedBox(height: 32),
            _Body(
              'These terms of service are provided as a draft for review by legal counsel before publication.',
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

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}
