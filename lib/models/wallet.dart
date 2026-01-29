/// Wallet model representing user's currency balances
class Wallet {
  final int credits;
  final int ash;
  final int obsidian;
  final int purgatoryVotes;
  final int lifetimePurchased;

  const Wallet({
    required this.credits,
    required this.ash,
    required this.obsidian,
    required this.purgatoryVotes,
    required this.lifetimePurchased,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      credits: json['credits'] as int? ?? 0,
      ash: json['ash'] as int? ?? 0,
      obsidian: json['obsidian'] as int? ?? 0,
      purgatoryVotes: json['purgatoryVotes'] as int? ?? 0,
      lifetimePurchased: json['lifetimePurchased'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'credits': credits,
      'ash': ash,
      'obsidian': obsidian,
      'purgatoryVotes': purgatoryVotes,
      'lifetimePurchased': lifetimePurchased,
    };
  }

  Wallet copyWith({
    int? credits,
    int? ash,
    int? obsidian,
    int? purgatoryVotes,
    int? lifetimePurchased,
  }) {
    return Wallet(
      credits: credits ?? this.credits,
      ash: ash ?? this.ash,
      obsidian: obsidian ?? this.obsidian,
      purgatoryVotes: purgatoryVotes ?? this.purgatoryVotes,
      lifetimePurchased: lifetimePurchased ?? this.lifetimePurchased,
    );
  }
}
