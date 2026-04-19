import 'package:flutter/foundation.dart';

@immutable
class GameUser {
  const GameUser({
    required this.id,
    required this.handle,
    required this.avatarEmoji,
    required this.avatarUrl,
    required this.city,
    required this.flag,
    required this.coins,
    required this.gems,
    required this.packagesOpened,
    required this.layersPeeled,
    required this.totalPeels,
  });

  final String id;
  final String handle;
  final String avatarEmoji;
  final String avatarUrl;
  final String city;
  final String flag;
  final int coins;
  final int gems;
  final int packagesOpened;
  final int layersPeeled;
  final int totalPeels;

  /// Compatibility shim — old call sites used `.avatar` for the emoji.
  String get avatar => avatarEmoji;

  static const GameUser guest = GameUser(
    id: 'me',
    handle: 'you',
    avatarEmoji: '🎁',
    // Default real-portrait — replaced when the user picks one in Auth.
    avatarUrl: 'https://i.pravatar.cc/200?img=1',
    city: 'Earth',
    flag: '🌍',
    coins: 0,
    gems: 0,
    packagesOpened: 0,
    layersPeeled: 0,
    totalPeels: 0,
  );

  GameUser copyWith({
    String? handle,
    String? avatarEmoji,
    String? avatarUrl,
    String? city,
    String? flag,
    int? coins,
    int? gems,
    int? packagesOpened,
    int? layersPeeled,
    int? totalPeels,
  }) =>
      GameUser(
        id: id,
        handle: handle ?? this.handle,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        city: city ?? this.city,
        flag: flag ?? this.flag,
        coins: coins ?? this.coins,
        gems: gems ?? this.gems,
        packagesOpened: packagesOpened ?? this.packagesOpened,
        layersPeeled: layersPeeled ?? this.layersPeeled,
        totalPeels: totalPeels ?? this.totalPeels,
      );
}
