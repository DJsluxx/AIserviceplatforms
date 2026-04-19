import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/game_user.dart';
import '../models/player.dart';
import 'notification_service.dart';
import 'sound_service.dart';

/// Tuning knobs the product owner cares about — centralised so they're
/// easy to rebalance.
class GameConfig {
  GameConfig._();

  static const Duration minHold = Duration(seconds: 30);
  static const Duration maxHold = Duration(hours: 2);

  static const Duration postAttemptGrace = Duration(seconds: 3);

  /// Probability a single peel attempt reveals a layer.
  static const double peelHitChance = 0.40;

  /// Per-tick chance an AI holder decides to peel. ~5 % = on average an
  /// AI attempts ~20 s in, well under the min 30 s window.
  static const double aiAttemptChancePerTick = 0.05;

  /// Per-package bias toward picking the user as next holder while
  /// the real-player base is small. 0.33 means ~1 in 3 hops lands in
  /// your hands — generous for single-device play-testing.
  static const double userHoldProbability = 0.33;

  static const int minLayers = 3;
  static const int maxLayers = 7;

  static const int minCoinsPerLayer = 50;
  static const int maxCoinsPerLayer = 500;

  /// How many "ambient" peel attempts to add to a package's running
  /// counter every tick to represent the (many thousands of) other
  /// players peeling worldwide. Region-scoped packages tick slower
  /// than the single global one.
  static const int globalAmbientPerTickMin = 8;
  static const int globalAmbientPerTickMax = 40;
  static const int regionAmbientPerTickMin = 0;
  static const int regionAmbientPerTickMax = 5;
}

const List<String> _layerHints = [
  'Smells like salt and cedar.',
  'A warm glow seeps from the corner.',
  'You hear a single chime, then silence.',
  'Paper, folded a thousand times.',
  'Something inside is humming a lullaby.',
  'A thread of gold catches the light.',
  'Tiny footprints circle the lid.',
  'Condensation beads on cold wax.',
  'A whisper repeats a single word: *soon*.',
  'Feathers — black at the tip, blue at the base.',
  'Faintly sweet, like caramel left in the sun.',
  'A single coin rolls free. It is warm.',
  'The seal bears a tiny crescent moon.',
  'A bee, carved from obsidian.',
  'The layer unpeels with a soft sigh.',
  'You see your own breath, but the room is warm.',
  'A map fragment — just an ocean, no land.',
  'A polaroid of a city you have never seen.',
  'A lock with no keyhole.',
  'A heartbeat, somewhere deeper in.',
];

const List<String> _rewardHeadlines = [
  'You opened the package.',
  'The package is yours.',
  'Final layer peeled.',
  'Unwrapped.',
  'Revealed.',
];

/// Snapshot of all the moving parts. Immutable; the notifier produces a
/// fresh one every tick so widgets rebuild cheaply.
@immutable
class GameState {
  const GameState({
    required this.players,
    required this.user,
    required this.packages,
    required this.feed,
    required this.now,
    required this.lastArrivedToUserAt,
    required this.lastOpenedAt,
    required this.lastPeelOutcomeAt,
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.notificationsEnabled,
  });

  final List<Player> players;
  final GameUser user;
  final List<Package> packages;
  final List<FeedEntry> feed;
  final DateTime now;

  final DateTime? lastArrivedToUserAt;
  final DateTime? lastOpenedAt;
  final DateTime? lastPeelOutcomeAt;

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool notificationsEnabled;

  /// Packages visible to the user in their region. Global scope is
  /// visible to everyone; region scope only to matching users.
  List<Package> visiblePackagesFor(String userRegion) {
    return packages.where((p) {
      if (p.scope == PackageScope.global) return true;
      return p.regionCode == userRegion;
    }).toList();
  }

  /// The package (if any) whose current hop holder is the user.
  Package? get userHeldPackage {
    for (final p in packages) {
      if (p.currentHop.holderId == user.id) return p;
    }
    return null;
  }

  Package? packageById(String id) {
    for (final p in packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  Player holderOf(Package p) {
    final id = p.currentHop.holderId;
    if (id == user.id) return _userAsPlayer();
    return AiPlayers.byId(id);
  }

  Player? previousHolderOf(Package p) {
    final prev = p.previousHop;
    if (prev == null) return null;
    if (prev.holderId == user.id) return _userAsPlayer();
    return AiPlayers.byId(prev.holderId);
  }

  Player _userAsPlayer() => Player(
        id: user.id,
        name: 'You',
        avatarEmoji: user.avatarEmoji,
        avatarUrl: user.avatarUrl,
        city: user.city,
        country: '',
        flag: user.flag,
        lat: 0,
        lon: 0,
        isUser: true,
      );

  GameState copyWith({
    List<Player>? players,
    GameUser? user,
    List<Package>? packages,
    List<FeedEntry>? feed,
    DateTime? now,
    DateTime? lastArrivedToUserAt,
    DateTime? lastOpenedAt,
    DateTime? lastPeelOutcomeAt,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? notificationsEnabled,
  }) =>
      GameState(
        players: players ?? this.players,
        user: user ?? this.user,
        packages: packages ?? this.packages,
        feed: feed ?? this.feed,
        now: now ?? this.now,
        lastArrivedToUserAt: lastArrivedToUserAt ?? this.lastArrivedToUserAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        lastPeelOutcomeAt: lastPeelOutcomeAt ?? this.lastPeelOutcomeAt,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}

/// Drives multiple live packages on a single 1-s timer. Each hop grants
/// the holder exactly one peel attempt; the package advances when the
/// window expires or shortly after an attempt.
class GameSimulator extends ChangeNotifier {
  GameSimulator({
    Random? random,
    SoundService? sounds,
    NotificationService? notifications,
  })  : _rng = random ?? Random(),
        _sounds = sounds ?? SoundService(),
        _notifications = notifications ?? NotificationService() {
    _state = _bootstrap();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Random _rng;
  final SoundService _sounds;
  final NotificationService _notifications;
  late GameState _state;
  Timer? _ticker;

  GameState get state => _state;
  SoundService get sounds => _sounds;
  NotificationService get notifications => _notifications;

  @override
  void dispose() {
    _ticker?.cancel();
    _sounds.dispose();
    _notifications.cancelAll();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Player tapped peel on [packageId]. Exactly one attempt per hop.
  PeelOutcome userPeel(String packageId) {
    final pkg = _state.packageById(packageId);
    if (pkg == null) return PeelOutcome.none;
    if (pkg.currentHop.holderId != _state.user.id) return PeelOutcome.none;
    if (pkg.currentHop.peelAttempted) return pkg.currentHop.outcome;
    final now = DateTime.now();
    final hit = _rng.nextDouble() < GameConfig.peelHitChance;
    return _applyAttempt(pkg: pkg, hit: hit, attemptedAt: now);
  }

  void setSoundEnabled(bool v) {
    _sounds.setEnabled(v);
    _state = _state.copyWith(soundEnabled: v);
    notifyListeners();
  }

  void setHapticsEnabled(bool v) {
    _state = _state.copyWith(hapticsEnabled: v);
    notifyListeners();
  }

  void setNotificationsEnabled(bool v) {
    _notifications.setEnabled(v);
    _state = _state.copyWith(notificationsEnabled: v);
    notifyListeners();
  }

  void setUserProfile(
      {String? handle, String? avatarEmoji, String? avatarUrl}) {
    _state = _state.copyWith(
      user: _state.user.copyWith(
        handle: handle,
        avatarEmoji: avatarEmoji,
        avatarUrl: avatarUrl,
      ),
    );
    notifyListeners();
  }

  Future<void> onAppPaused() => _notifications.scheduleBackgroundReminders();
  Future<void> onAppResumed() => _notifications.cancelAll();

  void resetProgress() {
    _state = _bootstrap();
    notifyListeners();
  }

  String newRewardHeadline() =>
      _rewardHeadlines[_rng.nextInt(_rewardHeadlines.length)];

  // ---------------------------------------------------------------------------
  // Tick loop
  // ---------------------------------------------------------------------------

  void _tick() {
    final now = DateTime.now();
    var packages = List<Package>.from(_state.packages);
    var stateChanged = false;

    // Per-package tick: ambient counter, expiry, AI attempt.
    for (int i = 0; i < packages.length; i++) {
      final original = packages[i];
      var pkg = original;

      // Ambient counter — simulates the "there are millions of users
      // peeling this right now" feel. Drives the climbing peels number.
      final ambient = pkg.scope == PackageScope.global
          ? GameConfig.globalAmbientPerTickMin +
              _rng.nextInt(GameConfig.globalAmbientPerTickMax -
                      GameConfig.globalAmbientPerTickMin +
                      1)
          : GameConfig.regionAmbientPerTickMin +
              _rng.nextInt(GameConfig.regionAmbientPerTickMax -
                      GameConfig.regionAmbientPerTickMin +
                      1);
      if (ambient > 0) {
        pkg = pkg.copyWith(peelsAccumulated: pkg.peelsAccumulated + ambient);
      }

      // Expired hop? Advance.
      if (pkg.currentHop.isExpired(now)) {
        pkg = _advanceHopOn(pkg, now);
      } else if (pkg.currentHop.holderId != _state.user.id &&
          !pkg.currentHop.peelAttempted) {
        // AI holder: maybe attempt.
        if (_rng.nextDouble() < GameConfig.aiAttemptChancePerTick) {
          final hit = _rng.nextDouble() < GameConfig.peelHitChance;
          pkg = _applyAttemptOn(pkg, hit: hit, attemptedAt: now);
        }
      }

      if (!identical(pkg, original)) {
        stateChanged = true;
      }
      packages[i] = pkg;
    }

    _state = _state.copyWith(now: now, packages: packages);
    if (stateChanged) {
      notifyListeners();
    } else {
      // Still re-emit so countdown widgets tick the UI.
      notifyListeners();
    }
  }

  /// Apply a user or AI peel attempt and return the new state's outcome.
  /// Kept as a convenience over [_applyAttemptOn] for the user path.
  PeelOutcome _applyAttempt({
    required Package pkg,
    required bool hit,
    required DateTime attemptedAt,
  }) {
    final updated = _applyAttemptOn(pkg, hit: hit, attemptedAt: attemptedAt);
    final idx = _state.packages.indexWhere((p) => p.id == pkg.id);
    final packages = List<Package>.from(_state.packages);
    packages[idx] = updated;

    var user = _state.user;
    var feed = _state.feed;
    DateTime? lastOpened = _state.lastOpenedAt;
    DateTime? lastOutcome = _state.lastPeelOutcomeAt;

    final isUser = updated.currentHop.holderId == user.id;
    if (isUser) {
      user = user.copyWith(totalPeels: user.totalPeels + 1);
      _sounds.play(SoundEffect.peelPop);
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        _sounds.play(hit ? SoundEffect.revealChime : SoundEffect.missWhoosh);
      });
      if (hit) {
        final coins = GameConfig.minCoinsPerLayer +
            _rng.nextInt(
                GameConfig.maxCoinsPerLayer - GameConfig.minCoinsPerLayer + 1);
        user = user.copyWith(
          coins: user.coins + coins,
          layersPeeled: user.layersPeeled + 1,
        );
        if (updated.opened) {
          user = user.copyWith(packagesOpened: user.packagesOpened + 1);
          lastOpened = attemptedAt;
          Future<void>.delayed(const Duration(milliseconds: 350), () {
            _sounds.play(SoundEffect.openFanfare);
          });
        }
      }
      lastOutcome = attemptedAt;
    }

    feed = _prependFeed(FeedEntry(
      id: _newId('feed'),
      playerId: updated.currentHop.holderId,
      packageId: updated.id,
      outcome: updated.currentHop.outcome,
      at: attemptedAt,
    ));

    _state = _state.copyWith(
      now: attemptedAt,
      packages: packages,
      user: user,
      feed: feed,
      lastOpenedAt: lastOpened,
      lastPeelOutcomeAt: lastOutcome,
    );
    notifyListeners();
    return updated.currentHop.outcome;
  }

  /// Like [_applyAttempt] but pure — it only returns the updated
  /// Package, it does not touch the user stats / sounds / feed. Used
  /// from inside the tick loop for AI attempts; the outer loop then
  /// appends a feed row.
  Package _applyAttemptOn(
    Package pkg, {
    required bool hit,
    required DateTime attemptedAt,
  }) {
    final outcome = hit ? PeelOutcome.hit : PeelOutcome.miss;
    final newExpiry = attemptedAt.add(GameConfig.postAttemptGrace);
    final updatedHop = pkg.currentHop.copyWith(
      outcome: outcome,
      attemptedAt: attemptedAt,
      expiresAt: newExpiry,
    );
    var updated = pkg.copyWith(
      hops: [...pkg.hops..removeLast(), updatedHop],
      peelsAccumulated: pkg.peelsAccumulated + 1,
    );
    if (hit) {
      final layersRevealed = updated.layersRevealed + 1;
      final hints = [...updated.hints, _randomHint()];
      final opened = layersRevealed >= updated.layersTotal;
      updated = updated.copyWith(
        layersRevealed: layersRevealed,
        hints: hints,
        opened: opened,
      );
    }

    // AI attempts aren't tracked through _applyAttempt, so fabricate a
    // feed row here too.
    if (pkg.currentHop.holderId != _state.user.id) {
      _state = _state.copyWith(
        feed: _prependFeed(FeedEntry(
          id: _newId('feed'),
          playerId: pkg.currentHop.holderId,
          packageId: pkg.id,
          outcome: outcome,
          at: attemptedAt,
        )),
      );
    }
    return updated;
  }

  /// Advance one package's hop chain — either bounces to the next holder
  /// or spawns a fresh package if the current one is open.
  Package _advanceHopOn(Package pkg, DateTime now) {
    if (pkg.opened) {
      return _freshPackage(
        scope: pkg.scope,
        regionCode: pkg.regionCode,
        regionLabel: pkg.regionLabel,
        regionEmoji: pkg.regionEmoji,
        theme: pkg.theme,
        name: pkg.name,
        now: now,
        startingAccumulated: pkg.peelsAccumulated, // keep the counter
      );
    }
    final prevHolder = pkg.currentHop.holderId;
    final nextHolder = _pickNextHolder(prevHolder);
    final hop = _newHop(holderId: nextHolder, now: now);

    if (nextHolder == _state.user.id) {
      // Fire the arrival hook on the state level.
      _state = _state.copyWith(lastArrivedToUserAt: now);
      _sounds.play(SoundEffect.revealChime);
      _notifications.showImmediate(
        'Open PEELED — you have one peel attempt waiting.',
      );
    }
    return pkg.copyWith(hops: [...pkg.hops, hop]);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  GameState _bootstrap() {
    final now = DateTime.now();
    // Two starter packages: a long-running global one and a regional
    // USA one. The global one is seeded with a big "accumulated peels"
    // number so the counter on Home looks instantly alive.
    final global = _freshPackage(
      scope: PackageScope.global,
      regionCode: 'global',
      regionLabel: 'Worldwide',
      regionEmoji: '🌍',
      theme: PackageTheme.rarity,
      name: 'Global Package',
      now: now,
      startingAccumulated: 48213 + _rng.nextInt(900),
      rarity: PackageRarity.epic,
      layersTotal: 50,
    );
    final usa = _freshPackage(
      scope: PackageScope.region,
      regionCode: 'usa',
      regionLabel: 'United States',
      regionEmoji: '🇺🇸',
      theme: PackageTheme.usaFlag,
      name: 'USA Drop',
      now: now,
      startingAccumulated: 2047 + _rng.nextInt(500),
      rarity: PackageRarity.rare,
      layersTotal: 10,
    );
    return GameState(
      players: AiPlayers.all,
      user: GameUser.guest,
      packages: [global, usa],
      feed: const [],
      now: now,
      lastArrivedToUserAt: null,
      lastOpenedAt: null,
      lastPeelOutcomeAt: null,
      soundEnabled: true,
      hapticsEnabled: true,
      notificationsEnabled: true,
    );
  }

  /// Build a brand-new package (fresh hop chain, zero layers revealed).
  Package _freshPackage({
    required PackageScope scope,
    required String regionCode,
    required String regionLabel,
    required String regionEmoji,
    required PackageTheme theme,
    required String name,
    required DateTime now,
    required int startingAccumulated,
    PackageRarity? rarity,
    int? layersTotal,
  }) {
    final starter = AiPlayers.all[_rng.nextInt(AiPlayers.all.length)].id;
    final hop = _newHop(holderId: starter, now: now);
    return Package(
      id: _newId('pkg_${regionCode}'),
      name: name,
      scope: scope,
      regionCode: regionCode,
      regionLabel: regionLabel,
      regionEmoji: regionEmoji,
      theme: theme,
      rarity: rarity ?? _pickRarity(),
      layersTotal: layersTotal ??
          GameConfig.minLayers +
              _rng.nextInt(GameConfig.maxLayers - GameConfig.minLayers + 1),
      layersRevealed: 0,
      hints: const [],
      hops: [hop],
      createdAt: now,
      peelsAccumulated: startingAccumulated,
    );
  }

  PackageHop _newHop({required String holderId, required DateTime now}) {
    final holdSeconds = GameConfig.minHold.inSeconds +
        _rng.nextInt(
            GameConfig.maxHold.inSeconds - GameConfig.minHold.inSeconds + 1);
    return PackageHop(
      id: _newId('hop'),
      holderId: holderId,
      startedAt: now,
      expiresAt: now.add(Duration(seconds: holdSeconds)),
      outcome: PeelOutcome.none,
      attemptedAt: null,
    );
  }

  String _pickNextHolder(String prev) {
    if (_rng.nextDouble() < GameConfig.userHoldProbability) {
      return _state.user.id;
    }
    final candidates = AiPlayers.all.where((p) => p.id != prev).toList();
    return candidates[_rng.nextInt(candidates.length)].id;
  }

  PackageRarity _pickRarity() {
    final roll = _rng.nextDouble();
    if (roll < 0.45) return PackageRarity.common;
    if (roll < 0.72) return PackageRarity.uncommon;
    if (roll < 0.88) return PackageRarity.rare;
    if (roll < 0.96) return PackageRarity.epic;
    if (roll < 0.995) return PackageRarity.legendary;
    return PackageRarity.mythic;
  }

  String _randomHint() => _layerHints[_rng.nextInt(_layerHints.length)];

  List<FeedEntry> _prependFeed(FeedEntry e) {
    final updated = [e, ..._state.feed];
    if (updated.length > 30) return updated.sublist(0, 30);
    return updated;
  }

  int _idCounter = 0;
  String _newId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }
}
