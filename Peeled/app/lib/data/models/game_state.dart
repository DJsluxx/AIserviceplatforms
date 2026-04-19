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

/// Outcome of a holder's single peel attempt.
enum PeelOutcome { none, miss, hit }

/// Visual theme used by the package renderer. `rarity` uses the
/// rarity-coloured SVG sprite; specialised themes (`usaFlag`, ...)
/// paint a distinct branded look.
enum PackageTheme { rarity, usaFlag }

/// Scope that decides who sees a package. `global` is shown to every
/// player on Earth; `region` is only shown to players from that
/// region.
enum PackageScope { global, region }

/// A single hand-off of a package.
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

/// A live package. `layersTotal` is hidden from the player (only
/// revealed layers count). Hints are appended as layers reveal.
///
/// [peelsAccumulated] is the total number of peel attempts that have
/// been made against this package across *all* players and *all* hops
/// in its lifetime. For single-device testing we seed a high starting
/// number and advance it every tick so the counter visibly climbs;
/// in production this would be sourced from the server.
@immutable
class Package {
  const Package({
    required this.id,
    required this.name,
    required this.scope,
    required this.regionCode,
    required this.regionLabel,
    required this.regionEmoji,
    required this.theme,
    required this.rarity,
    required this.layersTotal,
    required this.layersRevealed,
    required this.hints,
    required this.hops,
    required this.createdAt,
    required this.peelsAccumulated,
    this.opened = false,
  });

  final String id;
  final String name;
  final PackageScope scope;
  final String regionCode;
  final String regionLabel;
  final String regionEmoji;
  final PackageTheme theme;
  final PackageRarity rarity;
  final int layersTotal;
  final int layersRevealed;
  final List<String> hints;
  final List<PackageHop> hops;
  final DateTime createdAt;
  final int peelsAccumulated;
  final bool opened;

  PackageHop get currentHop => hops.last;
  PackageHop? get previousHop => hops.length >= 2 ? hops[hops.length - 2] : null;

  Package copyWith({
    int? layersRevealed,
    List<String>? hints,
    List<PackageHop>? hops,
    bool? opened,
    int? peelsAccumulated,
  }) =>
      Package(
        id: id,
        name: name,
        scope: scope,
        regionCode: regionCode,
        regionLabel: regionLabel,
        regionEmoji: regionEmoji,
        theme: theme,
        rarity: rarity,
        layersTotal: layersTotal,
        layersRevealed: layersRevealed ?? this.layersRevealed,
        hints: hints ?? this.hints,
        hops: hops ?? this.hops,
        createdAt: createdAt,
        peelsAccumulated: peelsAccumulated ?? this.peelsAccumulated,
        opened: opened ?? this.opened,
      );
}

/// One row in the live-feed strip.
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
