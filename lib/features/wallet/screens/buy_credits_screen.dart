import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Credits pack configurations
enum CreditsPack {
  starter(100, 0.99, 'Starter Pack'),
  standard(500, 3.99, 'Standard Pack'),
  value(1200, 8.99, 'Value Pack'),
  premium(3000, 19.99, 'Premium Pack');

  final int credits;
  final double priceUsd;
  final String name;

  const CreditsPack(this.credits, this.priceUsd, this.name);

  String get description => '$credits Focus Credits';
  
  double get creditsPerDollar => credits / priceUsd;
  
  String get bonus {
    if (this == CreditsPack.starter) return '';
    final baseRate = CreditsPack.starter.creditsPerDollar;
    final bonus = ((creditsPerDollar / baseRate - 1) * 100).round();
    return '+$bonus% bonus';
  }
}

class BuyCreditsScreen extends ConsumerStatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  ConsumerState<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends ConsumerState<BuyCreditsScreen> {
  CreditsPack? _selectedPack;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _purchasePack(CreditsPack pack) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Call Cloud Function to create Stripe PaymentIntent
      // final functions = FirebaseService.functions;
      // final result = await functions
      //     .httpsCallable('createCreditsPurchaseIntent')
      //     .call({
      //   'packId': pack.name.toLowerCase().replaceAll(' ', '_'),
      //   'idempotencyKey': 'mobile_${DateTime.now().millisecondsSinceEpoch}',
      // });
      // 
      // final clientSecret = result.data['clientSecret'];
      // 
      // // Present Stripe payment sheet (requires stripe_flutter package)
      // await presentPaymentSheet(clientSecret);

      setState(() {
        _errorMessage = 'Payment integration coming soon';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Focus Credits'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.stars,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Focus Credits',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Commit credits to pledge sessions. Build discipline, earn rewards.',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Packs
            ...CreditsPack.values.map((pack) => _PackCard(
              pack: pack,
              isSelected: _selectedPack == pack,
              onTap: () => setState(() => _selectedPack = pack),
            )),
            
            const SizedBox(height: 24),

            // Purchase Button
            ElevatedButton(
              onPressed: _selectedPack != null && !_isLoading
                  ? () => _purchasePack(_selectedPack!)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _selectedPack != null
                          ? 'Purchase for \$${_selectedPack!.priceUsd.toStringAsFixed(2)}'
                          : 'Select a pack',
                    ),
            ),

            const SizedBox(height: 24),

            // Info Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.lock_outline,
                      text: 'Credits are used for pledge sessions',
                    ),
                    _InfoRow(
                      icon: Icons.local_fire_department,
                      text: 'Failed sessions convert credits to Ash',
                    ),
                    _InfoRow(
                      icon: Icons.diamond_outlined,
                      text: 'Ash → Obsidian through redemption',
                    ),
                    _InfoRow(
                      icon: Icons.shopping_bag_outlined,
                      text: 'Spend Obsidian in the shop',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Credits are non-refundable and cannot be withdrawn. This is a closed-loop skill-based system.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final CreditsPack pack;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackCard({
    required this.pack,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Pack info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pack.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (pack.bonus.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pack.bonus,
                              style: TextStyle(
                                color: theme.colorScheme.onSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pack.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Price
              Text(
                '\$${pack.priceUsd.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
