import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/game_user.dart';
import '../models/player.dart';

/// Tuning knobs the product owner cares about — centralised so they're easy
/// to rebalance without hunting through screens.
class GameConfig {
  GameConfig._();

  static const Duration minHold = Duration(seconds: 30);
  static const Duration maxHold = Duration(hours: 2);

  static const int minPeelsPerHop = 10000;
  static const int maxPeelsPerHop = 100000;

  /// How often the user is chosen as next holder vs an AI.
  /// Start generous (1/3) while the player base is small so the app feels
  /// live on a single device; drop this once real players exist.
  static const double userHoldProbability = 0.33;

  /// Random layers per package (hidden from the player).
  static const int minLayers = 3;
  static const int maxLayers = 7;

  /// Coins earned per revealed layer.
  static const int minCoinsPerLayer = 50;
  static const int maxCoinsPerLayer = 500;

  /// AI "speed" — fraction of remaining peels an AI chips away each tick.
  /// With a 1s tick that means an AI typically clears its quota in a couple
  /// of minutes — much faster than its expiry timer, so a layer reveal is
  /// the common outcome (feels alive), and a time-out is rare (feels tense).
  static const double aiPeelChipRate = 0.04;
}

/// A couple dozen curated hint lines. The concrete text doesn't matter much
/// right now; what matters is that *something* teases the package after each
/// layer comes off, so the player feels pulled to the next one.
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

/// Reward headlines used on final-layer open.
const List<String> _rewardHeadlines = [
  'You opened the package.',
  'The package is yours.',
  'Final layer peeled.',
  'Unwrapped.',
  'Revealed.',
];

/// Snapshot of all the moving parts. Immutable; the notifier produces a new
/// one every tick so widgets rebuild cheaply.
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
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.notificationsEnabled,
  });

  final List<Player> players;
  final GameUser user;
  final Package package;
  final List<FeedEntry> feed;
  final DateTime now;

  /// Bumps whenever the package flips into the user's hands. UI reads this
  /// to fire a "it's your turn" banner once per arrival.
  final DateTime? lastArrivedToUserAt;

  /// Bumps when a new package is opened by the user. Drives the reward overlay.
  final DateTime? lastOpenedAt;

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

  GameState copyWith({
    List<Player>? players,
    GameUser? user,
    Package? package,
    List<FeedEntry>? feed,
    DateTime? now,
    DateTime? lastArrivedToUserAt,
    DateTime? lastOpenedAt,
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
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}

/// Drives the single live package. Runs on a 1s timer; every tick the
/// current holder does "some peeling" (if AI), and the clock can also
/// flip expiry. On layer-reveal or expiry, the hop is handed off to the
/// next holder (round-robin-ish with a bias toward the user).
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

  /// Player-tapped peel (only valid when the user is the current holder).
  /// One tap = one peel, but we also "fast-track" by adding a small boost
  /// so the peel-counter visibly moves (otherwise going 0 -> 100,000 by
  /// single taps would be mathematically impossible inside 30s..2h).
  void peelTap() {
    final hop = _state.package.currentHop;
    if (hop.holderId != _state.user.id) return;
    if (hop.layerRevealed) return;

    // Each tap counts for 1 real peel and ~2% of the remaining quota as
    // crowd-simulation. Feels punchy, lets users clear a hop in ~50 taps.
    final remaining = hop.peelsRequired - hop.peelsDone;
    final boost = (remaining * 0.02).clamp(20, 4000).toInt();
    final newPeels = (hop.peelsDone + 1 + boost).clamp(0, hop.peelsRequired);

    var user = _state.user.copyWith(totalPeels: _state.user.totalPeels + 1);

    final layerDone = newPeels >= hop.peelsRequired;
    final updatedHop = hop.copyWith(
      peelsDone: newPeels,
      layerRevealed: layerDone,
    );

    var pkg = _state.package
        .copyWith(hops: [..._state.package.hops..removeLast(), updatedHop]);

    var feed = _state.feed;
    DateTime? lastOpenedAt = _state.lastOpenedAt;

    if (layerDone) {
      final layersRevealed = pkg.layersRevealed + 1;
      final hints = [...pkg.hints, _randomHint()];
      final coins = GameConfig.minCoinsPerLayer +
          _rng.nextInt(
              GameConfig.maxCoinsPerLayer - GameConfig.minCoinsPerLayer + 1);
      user = user.copyWith(
        coins: user.coins + coins,
        layersPeeled: user.layersPeeled + 1,
      );

      feed = _prependFeed(FeedEntry(
        id: _newId('feed'),
        playerId: user.id,
        packageId: pkg.id,
        peelsDone: newPeels,
        layerRevealed: true,
        at: _state.now,
      ));

      if (layersRevealed >= pkg.layersTotal) {
        user = user.copyWith(packagesOpened: user.packagesOpened + 1);
        pkg = pkg.copyWith(
          layersRevealed: layersRevealed,
          hints: hints,
          opened: true,
        );
        lastOpenedAt = _state.now;
        _state = _state.copyWith(
          package: pkg,
          user: user,
          feed: feed,
          lastOpenedAt: lastOpenedAt,
        );
        _startNewPackage(); // resets state and notifies
        return;
      }

      pkg = pkg.copyWith(layersRevealed: layersRevealed, hints: hints);
    }

    _state = _state.copyWith(
      package: pkg,
      user: user,
      feed: feed,
      lastOpenedAt: lastOpenedAt,
    );
    notifyListeners();
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

  // ---------------------------------------------------------------------------
  // Tick loop
  // ---------------------------------------------------------------------------

  void _tick() {
    final now = DateTime.now();
    final hop = _state.package.currentHop;

    // 1) Hop expired? Hand off.
    if (hop.isExpired(now)) {
      final feed = _prependFeed(FeedEntry(
        id: _newId('feed'),
        playerId: hop.holderId,
        packageId: _state.package.id,
        peelsDone: hop.peelsDone,
        layerRevealed: hop.layerRevealed,
        at: now,
      ));
      _state = _state.copyWith(now: now, feed: feed);
      _advanceHop();
      return;
    }

    // 2) AI holder: chip away.
    if (hop.holderId != _state.user.id && !hop.layerRevealed) {
      final remaining = hop.peelsRequired - hop.peelsDone;
      // AI progresses by a noisy fraction of the remaining pool each tick.
      final chip = (remaining * GameConfig.aiPeelChipRate *
              (0.5 + _rng.nextDouble()))
          .round()
          .clamp(1, remaining);
      final newPeels = hop.peelsDone + chip;
      if (newPeels >= hop.peelsRequired) {
        final updatedHop = hop.copyWith(
          peelsDone: hop.peelsRequired,
          layerRevealed: true,
        );
        final layersRevealed = _state.package.layersRevealed + 1;
        final hints = [..._state.package.hints, _randomHint()];
        var pkg = _state.package.copyWith(
          hops: [..._state.package.hops..removeLast(), updatedHop],
          layersRevealed: layersRevealed,
          hints: hints,
        );
        final feed = _prependFeed(FeedEntry(
          id: _newId('feed'),
          playerId: hop.holderId,
          packageId: pkg.id,
          peelsDone: hop.peelsRequired,
          layerRevealed: true,
          at: now,
        ));
        if (layersRevealed >= pkg.layersTotal) {
          pkg = pkg.copyWith(opened: true);
          _state = _state.copyWith(now: now, package: pkg, feed: feed);
          _startNewPackage();
          return;
        }
        _state = _state.copyWith(now: now, package: pkg, feed: feed);
        _advanceHop();
        return;
      }
      final updatedHop = hop.copyWith(peelsDone: newPeels);
      final pkg = _state.package.copyWith(
        hops: [..._state.package.hops..removeLast(), updatedHop],
      );
      _state = _state.copyWith(now: now, package: pkg);
      notifyListeners();
      return;
    }

    // 3) User is holder: just tick the clock so countdowns update.
    _state = _state.copyWith(now: now);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  GameState _bootstrap() {
    final now = DateTime.now();
    // Pick a random starter from the AI pool (keeps the first load feeling
    // like the package is already in motion somewhere in the world).
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
      soundEnabled: true,
      hapticsEnabled: true,
      notificationsEnabled: true,
    );
  }

  void _advanceHop() {
    final prevHolder = _state.package.currentHop.holderId;
    final nextHolder = _pickNextHolder(prevHolder);
    final now = DateTime.now();
    final hop = _newHop(holderId: nextHolder, now: now);
    final pkg = _state.package.copyWith(hops: [..._state.package.hops, hop]);

    DateTime? arrived = _state.lastArrivedToUserAt;
    if (nextHolder == _state.user.id) {
      arrived = now;
    }

    _state = _state.copyWith(
      now: now,
      package: pkg,
      lastArrivedToUserAt: arrived,
    );
    notifyListeners();
  }

  void _startNewPackage() {
    final now = DateTime.now();
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
    final peelsRequired = GameConfig.minPeelsPerHop +
        _rng.nextInt(
            GameConfig.maxPeelsPerHop - GameConfig.minPeelsPerHop + 1);
    return PackageHop(
      id: _newId('hop'),
      holderId: holderId,
      startedAt: now,
      expiresAt: now.add(Duration(seconds: holdSeconds)),
      peelsRequired: peelsRequired,
      peelsDone: 0,
      layerRevealed: false,
    );
  }

  String _pickNextHolder(String prev) {
    if (_rng.nextDouble() < GameConfig.userHoldProbability) {
      return _state.user.id;
    }
    // Pick an AI that isn't the one who just had it.
    final candidates = AiPlayers.all.where((p) => p.id != prev).toList();
    return candidates[_rng.nextInt(candidates.length)].id;
  }

  PackageRarity _pickRarity() {
    // Weighted roll: mostly common/uncommon, rare chance of legendary/mythic.
    final roll = _rng.nextDouble();
    if (roll < 0.45) return PackageRarity.common;
    if (roll < 0.72) return PackageRarity.uncommon;
    if (roll < 0.88) return PackageRarity.rare;
    if (roll < 0.96) return PackageRarity.epic;
    if (roll < 0.995) return PackageRarity.legendary;
    return PackageRarity.mythic;
  }

  String _randomHint() => _layerHints[_rng.nextInt(_layerHints.length)];

  String newRewardHeadline() =>
      _rewardHeadlines[_rng.nextInt(_rewardHeadlines.length)];

  List<FeedEntry> _prependFeed(FeedEntry e) {
    final updated = [e, ..._state.feed];
    if (updated.length > 30) {
      return updated.sublist(0, 30);
    }
    return updated;
  }

  int _idCounter = 0;
  String _newId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }
}
