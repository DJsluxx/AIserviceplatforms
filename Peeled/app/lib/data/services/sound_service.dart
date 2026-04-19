import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The 4 sound events the game fires. Adding more? Add a value here, a
/// matching asset under `assets/audio/`, and a row in [_assetFor].
enum SoundEffect { peelPop, revealChime, missWhoosh, openFanfare }

/// Plays the small library of game SFX. Uses three rotating audio
/// players so a rapid sequence of taps never cuts itself off. Cheap to
/// keep alive — total in-memory footprint is just three players.
///
/// On web all the sound files are short WAVs that play through the HTML5
/// audio backend; the audioplayers package handles the platform branch
/// for us.
class SoundService {
  SoundService() {
    for (final p in _pool) {
      p.setReleaseMode(ReleaseMode.release);
    }
  }

  static const Map<SoundEffect, String> _assetFor = {
    SoundEffect.peelPop: 'audio/peel_pop.wav',
    SoundEffect.revealChime: 'audio/reveal_chime.wav',
    SoundEffect.missWhoosh: 'audio/miss_whoosh.wav',
    SoundEffect.openFanfare: 'audio/open_fanfare.wav',
  };

  bool _enabled = true;
  int _next = 0;
  final List<AudioPlayer> _pool =
      List.generate(3, (_) => AudioPlayer(playerId: 'peeled_sfx'));

  void setEnabled(bool v) => _enabled = v;

  Future<void> play(SoundEffect fx) async {
    if (!_enabled) return;
    final asset = _assetFor[fx];
    if (asset == null) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: _volumeFor(fx));
    } catch (e) {
      // Audio backends can throw on first interaction if the OS has
      // muted/restricted us. Swallow — sound is non-essential.
      if (kDebugMode) {
        debugPrint('SoundService.play($fx) failed: $e');
      }
    }
  }

  double _volumeFor(SoundEffect fx) {
    switch (fx) {
      case SoundEffect.peelPop:
        return 0.7;
      case SoundEffect.revealChime:
        return 0.85;
      case SoundEffect.missWhoosh:
        return 0.55;
      case SoundEffect.openFanfare:
        return 1.0;
    }
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
  }
}
