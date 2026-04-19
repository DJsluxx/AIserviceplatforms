import 'package:flutter/foundation.dart';

enum PackageRarity { common, uncommon, rare, epic, legendary, mythic }

extension PackageRarityX on PackageRarity {
  String get label {
    switch (this) {
      case PackageRarity.common:
        return 'Common';
      case PackageRarity.uncommon:
        return 'Uncommon';
      case PackageRarity.rare:
        return 'Rare';
      case PackageRarity.epic:
        return 'Epic';
      case PackageRarity.legendary:
        return 'Legendary';
      case PackageRarity.mythic:
        return 'Mythic';
    }
  }

  String get token {
    switch (this) {
      case PackageRarity.common:
        return 'common';
      case PackageRarity.uncommon:
        return 'uncommon';
      case PackageRarity.rare:
        return 'rare';
      case PackageRarity.epic:
        return 'epic';
      case PackageRarity.legendary:
        return 'legendary';
      case PackageRarity.mythic:
        return 'mythic';
    }
  }
}

/// Outcome of a holder's single peel attempt. Every holder gets exactly
/// one attempt per hop — it either reveals a layer (hit) or doesn't
/// (miss). [none] means the holder hasn't tried yet.
enum PeelOutcome { none, miss, hit }

/// A single hand-off of the package. The duration is randomized
/// (30s..2h). The holder gets exactly one peel attempt in that window;
/// the outcome is recorded on the hop. Once they attempt, expiry shrinks
/// to ~3s so the package moves on quickly.
@immutable
class PackageHop {
  const PackageHop({
    required this.id,
    required this.holderId,
    required this.startedAt,
    required this.expiresAt,
    required this.outcome,
    required this.attemptedAt,
  });

  final String id;
  final String holderId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final PeelOutcome outcome;
  final DateTime? attemptedAt;

  bool get peelAttempted => outcome != PeelOutcome.none;
  bool get layerRevealed => outcome == PeelOutcome.hit;

  Duration get duration => expiresAt.difference(startedAt);
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
  Duration remaining(DateTime now) {
    final r = expiresAt.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  PackageHop copyWith({
    DateTime? expiresAt,
    PeelOutcome? outcome,
    DateTime? attemptedAt,
  }) =>
      PackageHop(
        id: id,
        holderId: holderId,
        startedAt: startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        outcome: outcome ?? this.outcome,
        attemptedAt: attemptedAt ?? this.attemptedAt,
      );
}

/// The live package in flight. `layersTotal` is hidden from the player:
/// only revealed layers count. Hints are concatenated as layers reveal.
@immutable
class Package {
  const Package({
    required this.id,
    required this.rarity,
    required this.layersTotal,
    required this.layersRevealed,
    required this.hints,
    required this.hops,
    required this.createdAt,
    this.opened = false,
  });

  final String id;
  final PackageRarity rarity;
  final int layersTotal;
  final int layersRevealed;
  final List<String> hints;
  final List<PackageHop> hops;
  final DateTime createdAt;
  final bool opened;

  PackageHop get currentHop => hops.last;
  PackageHop? get previousHop => hops.length >= 2 ? hops[hops.length - 2] : null;

  Package copyWith({
    int? layersRevealed,
    List<String>? hints,
    List<PackageHop>? hops,
    bool? opened,
  }) =>
      Package(
        id: id,
        rarity: rarity,
        layersTotal: layersTotal,
        layersRevealed: layersRevealed ?? this.layersRevealed,
        hints: hints ?? this.hints,
        hops: hops ?? this.hops,
        createdAt: createdAt,
        opened: opened ?? this.opened,
      );
}

/// One row in the live-feed strip on Home.
@immutable
class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.playerId,
    required this.packageId,
    required this.outcome,
    required this.at,
  });

  final String id;
  final String playerId;
  final String packageId;
  final PeelOutcome outcome;
  final DateTime at;

  bool get layerRevealed => outcome == PeelOutcome.hit;
}
