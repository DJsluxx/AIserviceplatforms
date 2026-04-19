import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/game_user.dart';
import '../models/player.dart';

/// Tuning knobs the product owner cares about — centralised so they're
/// easy to rebalance without hunting through screens.
class GameConfig {
  GameConfig._();

  static const Duration minHold = Duration(seconds: 30);
  static const Duration maxHold = Duration(hours: 2);

  /// After a holder attempts their peel, we shrink the expiry to this
  /// so the package moves on quickly (player sees the result, then it
  /// hops).
  static const Duration postAttemptGrace = Duration(seconds: 3);

  /// Probability a single peel attempt reveals a layer. Tuned a little
  /// generous so single-device playtesting still feels rewarding.
  static const double peelHitChance = 0.40;

  /// Every 1-s tick while an AI holds the package, this is its chance
  /// of deciding to attempt the peel. ~4 % = attempt in about 25 s on
  /// average, well under the minimum 30 s window.
  static const double aiAttemptChancePerTick = 0.05;

  /// Bias toward the user being picked as the next holder. Start
  /// generous (1/3) while the player base is small; drop later.
  static const double userHoldProbability = 0.33;

  static const int minLayers = 3;
  static const int maxLayers = 7;

  static const int minCoinsPerLayer = 50;
  static const int maxCoinsPerLayer = 500;
}

/// A couple dozen curated hint lines. The concrete text doesn't matter
/// much yet; what matters is that something teases the package after
/// each layer so the player feels pulled to the next one.
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

/// Snapshot of all the moving parts. Immutable; the notifier produces
/// a new one every tick so widgets rebuild cheaply.
@immutable
class GameState {
  const GameState({
    required this.players,
    required this.user,
    required this.package,
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
  final Package package;
  final List<FeedEntry> feed;
  final DateTime now;

  /// Bumps whenever the package flips into the user's hands. UI reads
  /// this to fire a "it's your turn" banner once per arrival.
  final DateTime? lastArrivedToUserAt;

  /// Bumps when the user opens a package. Drives the reward overlay.
  final DateTime? lastOpenedAt;

  /// Bumps when the current user-held hop resolves to an outcome.
  /// Lets the UI show a "hit" or "miss" flash once.
  final DateTime? lastPeelOutcomeAt;

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool notificationsEnabled;

  bool get userHoldsPackage => package.currentHop.holderId == user.id;

  Player get currentHolder {
    final id = package.currentHop.holderId;
    if (id == user.id) {
      return Player(
        id: user.id,
        name: 'You',
        avatar: user.avatar,
        city: user.city,
        country: '',
        flag: user.flag,
        lat: 0,
        lon: 0,
        isUser: true,
      );
    }
    return AiPlayers.byId(id);
  }

  /// The previous holder, if any. Used by the map trail.
  Player? get previousHolder {
    final prev = package.previousHop;
    if (prev == null) return null;
    if (prev.holderId == user.id) {
      return Player(
        id: user.id,
        name: 'You',
        avatar: user.avatar,
        city: user.city,
        country: '',
        flag: user.flag,
        lat: 0,
        lon: 0,
        isUser: true,
      );
    }
    return AiPlayers.byId(prev.holderId);
  }

  GameState copyWith({
    List<Player>? players,
    GameUser? user,
    Package? package,
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
        package: package ?? this.package,
        feed: feed ?? this.feed,
        now: now ?? this.now,
        lastArrivedToUserAt: lastArrivedToUserAt ?? this.lastArrivedToUserAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        lastPeelOutcomeAt: lastPeelOutcomeAt ?? this.lastPeelOutcomeAt,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
      );
}

/// Drives the single live package on a 1-s timer. Each hop grants the
/// holder exactly one peel attempt; whether they peel or not, the
/// package advances when the window expires (or soon after an attempt).
class GameSimulator extends ChangeNotifier {
  GameSimulator({Random? random}) : _rng = random ?? Random() {
    _state = _bootstrap();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Random _rng;
  late GameState _state;
  Timer? _ticker;

  GameState get state => _state;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API the UI calls
  // ---------------------------------------------------------------------------

  /// Player tapped the peel button. Exactly one attempt per hop.
  /// Returns the outcome (or [PeelOutcome.none] if not allowed).
  PeelOutcome userPeel() {
    final hop = _state.package.currentHop;
    if (hop.holderId != _state.user.id) return PeelOutcome.none;
    if (hop.peelAttempted) return hop.outcome;
    final now = DateTime.now();
    final hit = _rng.nextDouble() < GameConfig.peelHitChance;
    return _applyAttempt(hit: hit, attemptedAt: now);
  }

  void setSoundEnabled(bool v) {
    _state = _state.copyWith(soundEnabled: v);
    notifyListeners();
  }

  void setHapticsEnabled(bool v) {
    _state = _state.copyWith(hapticsEnabled: v);
    notifyListeners();
  }

  void setNotificationsEnabled(bool v) {
    _state = _state.copyWith(notificationsEnabled: v);
    notifyListeners();
  }

  void setUserProfile({String? handle, String? avatar}) {
    _state = _state.copyWith(
      user: _state.user.copyWith(handle: handle, avatar: avatar),
    );
    notifyListeners();
  }

  /// Wipes progress. Destructive; confirm in UI.
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
    final hop = _state.package.currentHop;

    // 1) Hop expired? Hand off.
    if (hop.isExpired(now)) {
      _advanceHop(now);
      return;
    }

    // 2) AI holder that hasn't peeled yet: random chance to attempt.
    if (hop.holderId != _state.user.id && !hop.peelAttempted) {
      if (_rng.nextDouble() < GameConfig.aiAttemptChancePerTick) {
        final hit = _rng.nextDouble() < GameConfig.peelHitChance;
        _applyAttempt(hit: hit, attemptedAt: now, fromAi: true);
        return;
      }
    }

    // 3) Just tick the clock so countdowns update.
    _state = _state.copyWith(now: now);
    notifyListeners();
  }

  PeelOutcome _applyAttempt({
    required bool hit,
    required DateTime attemptedAt,
    bool fromAi = false,
  }) {
    var pkg = _state.package;
    var hop = pkg.currentHop;
    var user = _state.user;
    var feed = _state.feed;

    final outcome = hit ? PeelOutcome.hit : PeelOutcome.miss;

    // After an attempt, the hop expires quickly so the package moves on.
    final newExpiry = attemptedAt.add(GameConfig.postAttemptGrace);
    hop = hop.copyWith(
      outcome: outcome,
      attemptedAt: attemptedAt,
      expiresAt: newExpiry,
    );

    final isUser = hop.holderId == user.id;
    if (isUser) {
      user = user.copyWith(totalPeels: user.totalPeels + 1);
    }

    if (hit) {
      final layersRevealed = pkg.layersRevealed + 1;
      final hints = [...pkg.hints, _randomHint()];
      final coins = GameConfig.minCoinsPerLayer +
          _rng.nextInt(
              GameConfig.maxCoinsPerLayer - GameConfig.minCoinsPerLayer + 1);

      if (isUser) {
        user = user.copyWith(
          coins: user.coins + coins,
          layersPeeled: user.layersPeeled + 1,
        );
      }

      if (layersRevealed >= pkg.layersTotal) {
        if (isUser) {
          user = user.copyWith(packagesOpened: user.packagesOpened + 1);
        }
        pkg = pkg.copyWith(
          layersRevealed: layersRevealed,
          hints: hints,
          opened: true,
          hops: [...pkg.hops..removeLast(), hop],
        );
      } else {
        pkg = pkg.copyWith(
          layersRevealed: layersRevealed,
          hints: hints,
          hops: [...pkg.hops..removeLast(), hop],
        );
      }
    } else {
      pkg = pkg.copyWith(hops: [...pkg.hops..removeLast(), hop]);
    }

    feed = _prependFeed(FeedEntry(
      id: _newId('feed'),
      playerId: hop.holderId,
      packageId: pkg.id,
      outcome: outcome,
      at: attemptedAt,
    ));

    final lastOutcomeAt = isUser ? attemptedAt : _state.lastPeelOutcomeAt;

    _state = _state.copyWith(
      now: attemptedAt,
      package: pkg,
      user: user,
      feed: feed,
      lastPeelOutcomeAt: lastOutcomeAt,
    );

    // If that was the final layer, spawn a fresh package after the grace.
    if (pkg.opened) {
      final lastOpened = isUser ? attemptedAt : _state.lastOpenedAt;
      _state = _state.copyWith(lastOpenedAt: lastOpened);
    }

    notifyListeners();
    return outcome;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  GameState _bootstrap() {
    final now = DateTime.now();
    // Start the first hop a few seconds ago so the remaining timer isn't
    // suspiciously round — and pick a random AI city so the user sees
    // motion immediately.
    final starter = AiPlayers.all[_rng.nextInt(AiPlayers.all.length)].id;
    final hop = _newHop(holderId: starter, now: now);
    final pkg = Package(
      id: _newId('pkg'),
      rarity: _pickRarity(),
      layersTotal: GameConfig.minLayers +
          _rng.nextInt(GameConfig.maxLayers - GameConfig.minLayers + 1),
      layersRevealed: 0,
      hints: const [],
      hops: [hop],
      createdAt: now,
    );
    return GameState(
      players: AiPlayers.all,
      user: GameUser.guest,
      package: pkg,
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

  void _advanceHop(DateTime now) {
    if (_state.package.opened) {
      _startNewPackage(now);
      return;
    }
    final prevHolder = _state.package.currentHop.holderId;
    final nextHolder = _pickNextHolder(prevHolder);
    final hop = _newHop(holderId: nextHolder, now: now);
    final pkg = _state.package.copyWith(hops: [..._state.package.hops, hop]);

    DateTime? arrived = _state.lastArrivedToUserAt;
    if (nextHolder == _state.user.id) arrived = now;

    _state = _state.copyWith(
      now: now,
      package: pkg,
      lastArrivedToUserAt: arrived,
    );
    notifyListeners();
  }

  void _startNewPackage(DateTime now) {
    final starter = _pickNextHolder(_state.package.currentHop.holderId);
    final hop = _newHop(holderId: starter, now: now);
    final pkg = Package(
      id: _newId('pkg'),
      rarity: _pickRarity(),
      layersTotal: GameConfig.minLayers +
          _rng.nextInt(GameConfig.maxLayers - GameConfig.minLayers + 1),
      layersRevealed: 0,
      hints: const [],
      hops: [hop],
      createdAt: now,
    );
    DateTime? arrived = _state.lastArrivedToUserAt;
    if (starter == _state.user.id) arrived = now;
    _state = _state.copyWith(
      now: now,
      package: pkg,
      lastArrivedToUserAt: arrived,
    );
    notifyListeners();
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
