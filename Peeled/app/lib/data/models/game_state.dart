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

/// A single hand-off of the package. `peelsRequired` and the hop duration
/// are both randomized at creation time — the user asked for variable
/// windows (30s..2h) and variable peel-counts (10k..100k).
@immutable
class PackageHop {
  const PackageHop({
    required this.id,
    required this.holderId,
    required this.startedAt,
    required this.expiresAt,
    required this.peelsRequired,
    required this.peelsDone,
    required this.layerRevealed,
  });

  final String id;
  final String holderId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final int peelsRequired;
  final int peelsDone;
  final bool layerRevealed;

  Duration get duration => expiresAt.difference(startedAt);
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
  Duration remaining(DateTime now) {
    final r = expiresAt.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  double get peelProgress =>
      peelsRequired == 0 ? 0 : (peelsDone / peelsRequired).clamp(0.0, 1.0);

  PackageHop copyWith({int? peelsDone, bool? layerRevealed}) => PackageHop(
        id: id,
        holderId: holderId,
        startedAt: startedAt,
        expiresAt: expiresAt,
        peelsRequired: peelsRequired,
        peelsDone: peelsDone ?? this.peelsDone,
        layerRevealed: layerRevealed ?? this.layerRevealed,
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
    required this.peelsDone,
    required this.layerRevealed,
    required this.at,
  });

  final String id;
  final String playerId;
  final String packageId;
  final int peelsDone;
  final bool layerRevealed;
  final DateTime at;
}
